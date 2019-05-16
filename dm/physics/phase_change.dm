// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Antoine Saturation Vapor Pressure & Phase Change Kinetics
// Language: Dream Maker (DM)

#ifndef PLENUM_PHYSICS_PHASE_CHANGE_DM
#define PLENUM_PHYSICS_PHASE_CHANGE_DM

#include "gas_mixture.dm"

/datum/phase_change_solver
    var/tag_name = "phase_change_solver"

    // Antoine Parameters for Water (P in bar, T in Kelvin, range 273 - 373 K)
    // log10(P_bar) = A - B / (T + C)
    var/antoine_a_water = 4.6543
    var/antoine_b_water = 1435.264
    var/antoine_c_water = -64.848

    // Antoine Parameters for Refrigerant R-134a
    var/antoine_a_r134a = 4.06206
    var/antoine_b_r134a = 932.18
    var/antoine_c_r134a = -34.8

/datum/phase_change_solver/proc/CalculateSaturationPressureWaterPa(temp_k)
    temp_k = max(250.0, min(500.0, temp_k))
    // log10(P_bar) = A - B / (T + C)
    var/exponent = antoine_a_water - (antoine_b_water / (temp_k + antoine_c_water))
    var/p_sat_bar = 10.0 ** exponent
    return p_sat_bar * 100000.0 // Convert bar to Pascals

/datum/phase_change_solver/proc/CalculateSaturationPressureR134aPa(temp_k)
    temp_k = max(180.0, min(370.0, temp_k))
    var/exponent = antoine_a_r134a - (antoine_b_r134a / (temp_k + antoine_c_r134a))
    var/p_sat_bar = 10.0 ** exponent
    return p_sat_bar * 100000.0

/datum/phase_change_solver/proc/ProcessCondensationEvaporation(datum/gas_mixture/mix, turf/plenum_turf/T, delta_time_seconds)
    if(!mix || !T)
        return
    
    var/temp = mix.temperature
    var/p_sat_water = CalculateSaturationPressureWaterPa(temp)
    var/vol_m3 = mix.volume_liters * 0.001
    
    // Partial pressure of water vapor: P_i = (n_i * R * T) / V
    var/h2o_moles = mix.GetMoles(GAS_H2O)
    var/p_partial_h2o = (h2o_moles * R_IDEAL_GAS_CONSTANT * temp) / vol_m3

    if(p_partial_h2o > p_sat_water)
        // Super-saturated: Condensation occurs
        var/delta_p = p_partial_h2o - p_sat_water
        var/moles_to_condense = (delta_p * vol_m3) / (R_IDEAL_GAS_CONSTANT * temp)
        // Rate-limited condensation kinetics
        var/rate_coeff = 0.5
        var/actual_condense_moles = min(moles_to_condense * rate_coeff * delta_time_seconds, h2o_moles)

        if(actual_condense_moles > 0.0)
            mix.AdjustMoles(GAS_H2O, -actual_condense_moles)
            // Water condensation adds to turf fluid depth (1 mol H2O = 0.018 kg, density = 1000 kg/m3)
            var/condensed_kg = actual_condense_moles * MOLAR_MASS_H2O
            var/cell_area_m2 = 6.25 // 2.5m x 2.5m
            T.fluid_depth_meters += (condensed_kg / 1000.0) / cell_area_m2
            
            // Release latent heat of condensation into gas atmosphere
            var/heat_released = actual_condense_moles * (WATER_LATENT_HEAT_VAPORIZATION * MOLAR_MASS_H2O)
            mix.AddThermalEnergy(heat_released)

    else if(T.fluid_depth_meters > 0.0001 && p_partial_h2o < p_sat_water)
        // Sub-saturated with liquid pool: Evaporation occurs
        var/delta_p = p_sat_water - p_partial_h2o
        var/evaporation_potential_moles = (delta_p * vol_m3) / (R_IDEAL_GAS_CONSTANT * temp)
        var/max_pool_kg = T.fluid_depth_meters * 6.25 * 1000.0
        var/max_pool_moles = max_pool_kg / MOLAR_MASS_H2O
        
        var/actual_evap_moles = min(evaporation_potential_moles * 0.1 * delta_time_seconds, max_pool_moles)
        if(actual_evap_moles > 0.0)
            mix.AdjustMoles(GAS_H2O, actual_evap_moles)
            var/evap_kg = actual_evap_moles * MOLAR_MASS_H2O
            T.fluid_depth_meters = max(0.0, T.fluid_depth_meters - (evap_kg / 1000.0) / 6.25)
            
            // Absorb latent heat of vaporization (evaporative cooling)
            var/heat_absorbed = actual_evap_moles * (WATER_LATENT_HEAT_VAPORIZATION * MOLAR_MASS_H2O)
            mix.AddThermalEnergy(-heat_absorbed)

#endif // PLENUM_PHYSICS_PHASE_CHANGE_DM
