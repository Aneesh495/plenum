// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Arrhenius Chemical Kinetics, Flame Fronts & Auto-Ignition
// Language: Dream Maker (DM)

#ifndef PLENUM_PHYSICS_COMBUSTION_DM
#define PLENUM_PHYSICS_COMBUSTION_DM

#include "gas_mixture.dm"

/datum/combustion_engine
    var/tag_name = "combustion_engine"
    
    // Activation energies (J / mol)
    var/ea_ch4 = 1.3e5   // Methane oxidation
    var/ea_h2  = 7.0e4   // Hydrogen oxidation
    var/ea_co  = 1.0e5   // Carbon monoxide oxidation

    // Pre-exponential frequency factors A
    var/pre_exp_ch4 = 5.0e7
    var/pre_exp_h2  = 1.0e9
    var/pre_exp_co  = 2.0e7

    // Lower & Upper Explosive Limits (Volume / Molar Fraction in air)
    var/lel_ch4 = 0.050  // 5.0%
    var/uel_ch4 = 0.150  // 15.0%
    var/auto_ignite_ch4_k = 810.0 // 537 C

    var/lel_h2 = 0.040   // 4.0%
    var/uel_h2 = 0.750   // 75.0%
    var/auto_ignite_h2_k = 845.0  // 572 C

/datum/combustion_engine/proc/EvaluateReactionTick(datum/gas_mixture/mix, delta_time_seconds, external_spark = FALSE)
    if(!mix || mix.total_moles <= EPSILON_MOLES)
        return 0.0

    var/total_heat_released_joules = 0.0
    var/vol_m3 = mix.volume_liters * 0.001
    var/temp = mix.temperature
    var/o2_moles = mix.GetMoles(GAS_O2)

    if(o2_moles <= EPSILON_MOLES)
        return 0.0

    // ------------------------------------------------------------------------
    // Methane Combustion: CH4 + 2 O2 -> CO2 + 2 H2O  (Delta H = -891 kJ/mol)
    // ------------------------------------------------------------------------
    var/ch4_moles = mix.GetMoles(GAS_CH4)
    if(ch4_moles > EPSILON_MOLES)
        var/ch4_fraction = ch4_moles / mix.total_moles
        var/can_ignite = external_spark || (temp >= auto_ignite_ch4_k && ch4_fraction >= lel_ch4 && ch4_fraction <= uel_ch4)
        
        if(can_ignite)
            // Arrhenius reaction rate: r = A * exp(-Ea / (R*T)) * [CH4]^0.2 * [O2]^1.3
            var/c_ch4 = ch4_moles / vol_m3
            var/c_o2 = o2_moles / vol_m3
            var/k_rate = pre_exp_ch4 * exp(-ea_ch4 / (R_IDEAL_GAS_CONSTANT * temp))
            var/rate_mol_m3_s = k_rate * (c_ch4 ** 0.2) * (c_o2 ** 1.3)
            var/moles_reacted = rate_mol_m3_s * vol_m3 * delta_time_seconds
            
            // Stoichiometric cap: 1 mol CH4 needs 2 mol O2
            moles_reacted = min(moles_reacted, ch4_moles)
            moles_reacted = min(moles_reacted, o2_moles / 2.0)

            if(moles_reacted > 0.0)
                mix.AdjustMoles(GAS_CH4, -moles_reacted)
                mix.AdjustMoles(GAS_O2, -moles_reacted * 2.0)
                mix.AdjustMoles(GAS_CO2, moles_reacted)
                mix.AdjustMoles(GAS_H2O, moles_reacted * 2.0)
                
                var/q_release = moles_reacted * 891000.0 // 891 kJ / mol
                mix.AddThermalEnergy(q_release)
                total_heat_released_joules += q_release

    // ------------------------------------------------------------------------
    // Hydrogen Combustion: 2 H2 + O2 -> 2 H2O  (Delta H = -286 kJ/mol)
    // ------------------------------------------------------------------------
    var/h2_moles = mix.GetMoles(GAS_H2)
    o2_moles = mix.GetMoles(GAS_O2)
    if(h2_moles > EPSILON_MOLES && o2_moles > EPSILON_MOLES)
        var/h2_fraction = h2_moles / mix.total_moles
        var/can_ignite_h2 = external_spark || (temp >= auto_ignite_h2_k && h2_fraction >= lel_h2 && h2_fraction <= uel_h2)
        
        if(can_ignite_h2)
            var/c_h2 = h2_moles / vol_m3
            var/c_o2 = o2_moles / vol_m3
            var/k_rate_h2 = pre_exp_h2 * exp(-ea_h2 / (R_IDEAL_GAS_CONSTANT * temp))
            var/rate_h2 = k_rate_h2 * c_h2 * c_o2
            var/moles_h2_reacted = rate_h2 * vol_m3 * delta_time_seconds
            
            moles_h2_reacted = min(moles_h2_reacted, h2_moles)
            moles_h2_reacted = min(moles_h2_reacted, o2_moles * 2.0)

            if(moles_h2_reacted > 0.0)
                mix.AdjustMoles(GAS_H2, -moles_h2_reacted)
                mix.AdjustMoles(GAS_O2, -moles_h2_reacted * 0.5)
                mix.AdjustMoles(GAS_H2O, moles_h2_reacted)
                
                var/q_h2 = moles_h2_reacted * 286000.0 // 286 kJ / mol
                mix.AddThermalEnergy(q_h2)
                total_heat_released_joules += q_h2

    return total_heat_released_joules

#endif // PLENUM_PHYSICS_COMBUSTION_DM
