// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Advanced Thermodynamics, Enthalpy & Heat Transfer
// Language: Dream Maker (DM)

#ifndef PLENUM_PHYSICS_THERMODYNAMICS_DM
#define PLENUM_PHYSICS_THERMODYNAMICS_DM

#include "gas_mixture.dm"

/datum/thermodynamics_solver
    var/tag_name = "thermo_solver"

/datum/thermodynamics_solver/proc/CalculateEnthalpyJoules(datum/gas_mixture/mix)
    if(!mix || mix.total_moles <= EPSILON_MOLES)
        return 0.0
    // H = U + P*V = Cv*T + n*R*T = (Cv + n*R) * T = Cp * T
    var/u_internal = mix.GetThermalEnergyJoules()
    var/pv_flow_work = mix.total_moles * R_IDEAL_GAS_CONSTANT * mix.temperature
    return u_internal + pv_flow_work

/datum/thermodynamics_solver/proc/CalculateEntropy(datum/gas_mixture/mix, reference_pressure_pa = 101325.0)
    // S = sum(n_i * (Cp_i * ln(T / T0) - R * ln(P_i / P0)))
    if(!mix || mix.total_moles <= EPSILON_MOLES || mix.temperature <= EPSILON_TEMPERATURE)
        return 0.0
    
    var/entropy_total = 0.0
    var/p_total = mix.CalculatePressurePascals()
    var/t_ratio = mix.temperature / STANDARD_TEMPERATURE_KELVIN
    if(t_ratio <= 0.0001) t_ratio = 0.0001
    var/ln_t = log(t_ratio)

    for(var/i = 1 to GAS_SPECIES_COUNT)
        var/ni = mix.moles[i]
        if(ni <= EPSILON_MOLES)
            continue
        var/pi = (ni / mix.total_moles) * p_total
        var/p_ratio = pi / reference_pressure_pa
        if(p_ratio <= 0.0001) p_ratio = 0.0001
        var/ln_p = log(p_ratio)
        
        // Cp = Cv + R for ideal polyatomic gases
        var/cp_i = CV_O2 + R_IDEAL_GAS_CONSTANT
        var/si = ni * (cp_i * ln_t - R_IDEAL_GAS_CONSTANT * ln_p)
        entropy_total += si

    return entropy_total

/datum/thermodynamics_solver/proc/RadiativeExchange(atom/plenum_atom/surface, datum/gas_mixture/gas, contact_area_m2 = 1.0)
    // Stefan-Boltzmann radiative transfer: Q = epsilon * sigma * A * (T_surf^4 - T_gas^4)
    if(!surface || !gas || contact_area_m2 <= 0.0)
        return 0.0
    
    var/t_s4 = (surface.temperature / 100.0) ** 4
    var/t_g4 = (gas.temperature / 100.0) ** 4
    
    // Scale sigma by 1e8 since T was divided by 100: (T/100)^4 * 1e8 = T^4
    var/sigma_scaled = STEFAN_BOLTZMANN_CONSTANT * 100000000.0
    var/heat_flux_watts = surface.emissivity * sigma_scaled * contact_area_m2 * (t_s4 - t_g4)
    return heat_flux_watts

/datum/thermodynamics_solver/proc/ConvectiveExchange(atom/plenum_atom/surface, datum/gas_mixture/gas, contact_area_m2 = 1.0, gas_velocity_mps = 1.0)
    // Newton's Law of Cooling: Q = h * A * (T_s - T_gas)
    // Heat transfer coefficient h via simplified turbulent boundary correlation:
    // h = 10.45 - v + 10 * sqrt(v) (Jurges equation for forced convection)
    if(!surface || !gas || contact_area_m2 <= 0.0)
        return 0.0
    
    var/v = max(0.1, gas_velocity_mps)
    var/h_conv = 10.45 - v + (10.0 * sqrt(v))
    var/delta_t = surface.temperature - gas.temperature
    var/heat_flux_watts = h_conv * contact_area_m2 * delta_t
    return heat_flux_watts

/datum/thermodynamics_solver/proc/JouleThomsonThrottling(datum/gas_mixture/upstream_mix, downstream_pressure_pa)
    // Throttling process across an expansion valve / orifice at constant enthalpy (isenthalpic)
    // For an ideal gas: dT = 0. For real gases with non-zero intermolecular forces:
    // mu_JT = (1 / Cp) * (T * (dV/dT)_P - V)
    if(!upstream_mix || upstream_mix.total_moles <= EPSILON_MOLES)
        return upstream_mix.temperature
    
    var/p_upstream = upstream_mix.CalculatePressurePascals()
    var/delta_p = downstream_pressure_pa - p_upstream
    if(delta_p >= 0.0)
        return upstream_mix.temperature // Throttling requires a pressure drop

    // Real gas Joule-Thomson coefficient approximation for hydrocarbon and refrigerant blends
    // mu_JT ~ (2 * a / (R * T) - b) / Cp
    var/ch4_fraction = upstream_mix.GetMolarFraction(GAS_CH4)
    var/r134a_fraction = upstream_mix.GetMolarFraction(GAS_R134A)
    var/h2_fraction = upstream_mix.GetMolarFraction(GAS_H2)
    
    // Most gases cool on expansion at room temp (positive mu_JT), but H2 warms up (negative mu_JT)
    var/mu_jt_k_per_pa = (ch4_fraction * 0.0000045) + (r134a_fraction * 0.000012) - (h2_fraction * 0.0000003) + 0.000002
    var/delta_t = mu_jt_k_per_pa * delta_p
    var/new_temp = max(EPSILON_TEMPERATURE, upstream_mix.temperature + delta_t)
    return new_temp

#endif // PLENUM_PHYSICS_THERMODYNAMICS_DM
