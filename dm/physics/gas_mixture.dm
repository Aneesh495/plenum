// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Multi-Component Gas Mixture & Equation of State
// Language: Dream Maker (DM)

#ifndef PLENUM_PHYSICS_GAS_MIXTURE_DM
#define PLENUM_PHYSICS_GAS_MIXTURE_DM

#include "../defines.dm"
#include "../core/datum.dm"

/datum/gas_mixture
    var/volume_liters = 2500.0          // Chamber volume in Liters (dm^3)
    var/temperature = 293.15            // Bulk temperature in Kelvin
    var/list/moles = null               // Array of length GAS_SPECIES_COUNT
    var/total_moles = 0.0               // Cached sum of species moles
    var/last_calculated_pressure = 0.0  // Pressure in Pascals

/datum/gas_mixture/New(vol_liters = 2500.0)
    ..()
    volume_liters = max(0.1, vol_liters)
    moles = list()
    moles.len = GAS_SPECIES_COUNT
    for(var/i = 1 to GAS_SPECIES_COUNT)
        moles[i] = 0.0
    temperature = STANDARD_TEMPERATURE_KELVIN
    total_moles = 0.0

/datum/gas_mixture/proc/SetCompositionSTP(pressure_kpa = 101.325, temp_k = 293.15, o2_ratio = 0.21, n2_ratio = 0.79)
    temperature = max(EPSILON_TEMPERATURE, temp_k)
    // n = (P * V) / (R * T) where V is in m^3 (liters * 0.001) and P in Pa (kpa * 1000)
    var/volume_m3 = volume_liters * 0.001
    var/pressure_pa = pressure_kpa * 1000.0
    var/n_total = (pressure_pa * volume_m3) / (R_IDEAL_GAS_CONSTANT * temperature)
    
    for(var/i = 1 to GAS_SPECIES_COUNT)
        moles[i] = 0.0

    moles[GAS_O2] = n_total * o2_ratio
    moles[GAS_N2] = n_total * n2_ratio
    UpdateTotalMoles()

/datum/gas_mixture/proc/UpdateTotalMoles()
    total_moles = 0.0
    for(var/i = 1 to GAS_SPECIES_COUNT)
        var/m = moles[i]
        if(m < 0.0)
            moles[i] = 0.0
            m = 0.0
        total_moles += m
    return total_moles

/datum/gas_mixture/proc/GetMoles(gas_id)
    if(gas_id < 1 || gas_id > GAS_SPECIES_COUNT)
        return 0.0
    return moles[gas_id]

/datum/gas_mixture/proc/SetMoles(gas_id, new_moles)
    if(gas_id < 1 || gas_id > GAS_SPECIES_COUNT)
        return
    moles[gas_id] = max(0.0, new_moles)
    UpdateTotalMoles()

/datum/gas_mixture/proc/AdjustMoles(gas_id, delta_moles)
    if(gas_id < 1 || gas_id > GAS_SPECIES_COUNT)
        return
    moles[gas_id] = max(0.0, moles[gas_id] + delta_moles)
    UpdateTotalMoles()

/datum/gas_mixture/proc/GetMolarFraction(gas_id)
    if(total_moles <= EPSILON_MOLES || gas_id < 1 || gas_id > GAS_SPECIES_COUNT)
        return 0.0
    return moles[gas_id] / total_moles

/datum/gas_mixture/proc/GetHeatCapacityCv()
    // Constant-volume heat capacity in Joules / Kelvin
    // Cv_total = sum(n_i * Cv_i)
    var/cv_sum = 0.0
    cv_sum += moles[GAS_O2]    * CV_O2
    cv_sum += moles[GAS_N2]    * CV_N2
    cv_sum += moles[GAS_CO2]   * CV_CO2
    cv_sum += moles[GAS_H2O]   * CV_H2O
    cv_sum += moles[GAS_H2]    * CV_H2
    cv_sum += moles[GAS_CH4]   * CV_CH4
    cv_sum += moles[GAS_CO]    * CV_CO
    cv_sum += moles[GAS_AR]    * CV_AR
    cv_sum += moles[GAS_SF6]   * CV_SF6
    cv_sum += moles[GAS_R134A] * CV_R134A
    return max(0.0001, cv_sum)

/datum/gas_mixture/proc/GetThermalEnergyJoules()
    return GetHeatCapacityCv() * temperature

/datum/gas_mixture/proc/AddThermalEnergy(delta_joules)
    var/cv = GetHeatCapacityCv()
    if(cv > 0.0001)
        temperature += delta_joules / cv
        if(temperature < EPSILON_TEMPERATURE)
            temperature = EPSILON_TEMPERATURE
    return temperature

/datum/gas_mixture/proc/CalculatePressureIdeal()
    // Ideal Gas Law: P = (n * R * T) / V
    if(total_moles <= EPSILON_MOLES || volume_liters <= 0.0001)
        last_calculated_pressure = 0.0
        return 0.0
    var/volume_m3 = volume_liters * 0.001
    last_calculated_pressure = (total_moles * R_IDEAL_GAS_CONSTANT * temperature) / volume_m3
    return last_calculated_pressure

/datum/gas_mixture/proc/CalculatePressurePengRobinson()
    // Peng-Robinson Equation of State for high-density and real gas effects
    // P = (R*T)/(Vm - b) - a(T)/(Vm^2 + 2*b*Vm - b^2)
    if(total_moles <= EPSILON_MOLES || volume_liters <= 0.0001)
        last_calculated_pressure = 0.0
        return 0.0

    var/volume_m3 = volume_liters * 0.001
    var/vm = volume_m3 / total_moles // Molar volume (m^3 / mol)

    // Calculate pure component a_i(T) and b_i parameters
    var/list/a_coeffs = list(
        GAS_O2 = CalculatePR_A(TC_O2, PC_O2, ACENTRIC_O2),
        GAS_N2 = CalculatePR_A(TC_N2, PC_N2, ACENTRIC_N2),
        GAS_CO2 = CalculatePR_A(TC_CO2, PC_CO2, ACENTRIC_CO2),
        GAS_H2O = CalculatePR_A(TC_H2O, PC_H2O, ACENTRIC_H2O),
        GAS_H2 = CalculatePR_A(TC_H2, PC_H2, ACENTRIC_H2),
        GAS_CH4 = CalculatePR_A(TC_CH4, PC_CH4, ACENTRIC_CH4),
        GAS_CO = CalculatePR_A(TC_CO, PC_CO, ACENTRIC_CO),
        GAS_AR = CalculatePR_A(TC_AR, PC_AR, ACENTRIC_AR),
        GAS_SF6 = CalculatePR_A(TC_SF6, PC_SF6, ACENTRIC_SF6),
        GAS_R134A = CalculatePR_A(TC_R134A, PC_R134A, ACENTRIC_R134A)
    )

    var/list/b_coeffs = list(
        GAS_O2 = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_O2) / PC_O2,
        GAS_N2 = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_N2) / PC_N2,
        GAS_CO2 = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_CO2) / PC_CO2,
        GAS_H2O = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_H2O) / PC_H2O,
        GAS_H2 = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_H2) / PC_H2,
        GAS_CH4 = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_CH4) / PC_CH4,
        GAS_CO = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_CO) / PC_CO,
        GAS_AR = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_AR) / PC_AR,
        GAS_SF6 = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_SF6) / PC_SF6,
        GAS_R134A = (0.07780 * R_IDEAL_GAS_CONSTANT * TC_R134A) / PC_R134A
    )

    // Van der Waals quadratic mixing rules
    var/a_mix = 0.0
    var/b_mix = 0.0
    for(var/i = 1 to GAS_SPECIES_COUNT)
        var/yi = moles[i] / total_moles
        if(yi <= 0.0)
            continue
        b_mix += yi * b_coeffs[i]
        for(var/j = 1 to GAS_SPECIES_COUNT)
            var/yj = moles[j] / total_moles
            if(yj <= 0.0)
                continue
            a_mix += yi * yj * sqrt(a_coeffs[i] * a_coeffs[j])

    // Prevent singularity near co-volume b
    if(vm <= b_mix * 1.05)
        // High density compression limit: clamp to repulsive wall
        vm = b_mix * 1.05

    var/denom1 = vm - b_mix
    var/denom2 = vm * vm + 2.0 * b_mix * vm - b_mix * b_mix
    
    var/p_pr = (R_IDEAL_GAS_CONSTANT * temperature / denom1) - (a_mix / denom2)
    if(p_pr < 0.0)
        p_pr = 0.0
    last_calculated_pressure = p_pr
    return last_calculated_pressure

/datum/gas_mixture/proc/CalculatePR_A(tc, pc, acentric)
    var/tr = temperature / tc
    var/kappa = 0.37464 + 1.54226 * acentric - 0.26992 * acentric * acentric
    var/alpha = (1.0 + kappa * (1.0 - sqrt(tr))) ** 2
    return (0.45724 * R_IDEAL_GAS_CONSTANT * R_IDEAL_GAS_CONSTANT * tc * tc * alpha) / pc

/datum/gas_mixture/proc/CalculatePressurePascals()
    // For moderate pressures (< 50 bar), Ideal gas matches PR closely with faster execution
    return CalculatePressureIdeal()

/datum/gas_mixture/proc/MergeMixture(datum/gas_mixture/source)
    if(!source || source.total_moles <= EPSILON_MOLES)
        return
    
    var/cv_self = GetHeatCapacityCv()
    var/cv_src = source.GetHeatCapacityCv()
    var/energy_total = (cv_self * temperature) + (cv_src * source.temperature)

    for(var/i = 1 to GAS_SPECIES_COUNT)
        moles[i] += source.moles[i]
    UpdateTotalMoles()

    var/cv_new = GetHeatCapacityCv()
    if(cv_new > 0.0001)
        temperature = energy_total / cv_new

/datum/gas_mixture/proc/RemoveMolesFraction(fraction)
    fraction = max(0.0, min(1.0, fraction))
    if(fraction <= 0.0 || total_moles <= EPSILON_MOLES)
        return null

    var/datum/gas_mixture/removed = new /datum/gas_mixture(volume_liters * fraction)
    removed.temperature = temperature

    for(var/i = 1 to GAS_SPECIES_COUNT)
        var/delta = moles[i] * fraction
        moles[i] -= delta
        removed.moles[i] = delta

    UpdateTotalMoles()
    removed.UpdateTotalMoles()
    return removed

#endif // PLENUM_PHYSICS_GAS_MIXTURE_DM
