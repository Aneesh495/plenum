// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Fickian Molecular & Convective Species Diffusion
// Language: Dream Maker (DM)

#ifndef PLENUM_PHYSICS_DIFFUSION_DM
#define PLENUM_PHYSICS_DIFFUSION_DM

#include "gas_mixture.dm"

/datum/diffusion_engine
    var/default_binary_diffusivity_m2_s = 2.0e-5 // ~0.2 cm^2 / s for air species
    var/barrier_porosity_factor = 0.05           // Attenuation through seals

/datum/diffusion_engine/proc/CalculateChapmanEnskogDiffusivity(gas_a, gas_b, temp_k, pressure_pa)
    // Chapman-Enskog kinetic theory for binary gas diffusion
    if(temp_k <= 0.0 || pressure_pa <= 0.0)
        return 0.0
    
    var/p_atm = pressure_pa / 101325.0
    var/ma = 28.97
    var/mb = 28.97

    if(gas_a == GAS_H2) ma = 2.016
    else if(gas_a == GAS_CH4) ma = 16.04
    else if(gas_a == GAS_CO2) ma = 44.01
    else if(gas_a == GAS_SF6) ma = 146.06

    if(gas_b == GAS_H2) mb = 2.016
    else if(gas_b == GAS_CH4) mb = 16.04
    else if(gas_b == GAS_CO2) mb = 44.01
    else if(gas_b == GAS_SF6) mb = 146.06

    var/m_reduced = (1.0 / ma) + (1.0 / mb)
    // D_AB = (0.001858 * T^1.5 * sqrt(1/Ma + 1/Mb)) / (P_atm * sigma_AB^2 * Omega)
    // Approximate sigma_AB ~ 3.5 Angstroms, Omega ~ 1.0
    var/d_ab_cm2_s = (0.001858 * (temp_k ** 1.5) * sqrt(m_reduced)) / (p_atm * 12.25)
    return d_ab_cm2_s * 0.0001 // Convert cm^2/s to m^2/s

/datum/diffusion_engine/proc/DiffuseCellPair(datum/gas_mixture/mix_a, datum/gas_mixture/mix_b, contact_area_m2 = 7.5, distance_m = 2.5, delta_time_seconds = 1.0)
    // Fick's Second Law discrete species equalization
    if(!mix_a || !mix_b)
        return
    
    var/vol_a_m3 = mix_a.volume_liters * 0.001
    var/vol_b_m3 = mix_b.volume_liters * 0.001

    for(var/i = 1 to GAS_SPECIES_COUNT)
        var/moles_a = mix_a.moles[i]
        var/moles_b = mix_b.moles[i]
        
        // Concentrations (mol / m^3)
        var/c_a = moles_a / vol_a_m3
        var/c_b = moles_b / vol_b_m3
        var/delta_c = c_a - c_b

        if(abs(delta_c) < 0.000001)
            continue

        // J = -D * (dC / dx)
        var/diffusivity = CalculateChapmanEnskogDiffusivity(i, GAS_N2, (mix_a.temperature + mix_b.temperature) * 0.5, (mix_a.CalculatePressurePascals() + mix_b.CalculatePressurePascals()) * 0.5)
        var/molar_flux = diffusivity * (delta_c / distance_m) // mol / (m^2 * s)
        var/moles_transferred = molar_flux * contact_area_m2 * delta_time_seconds

        // Limit transfer to 45% of donor moles per tick to guarantee numerical stability
        if(moles_transferred > 0.0)
            moles_transferred = min(moles_transferred, moles_a * 0.45)
            mix_a.AdjustMoles(i, -moles_transferred)
            mix_b.AdjustMoles(i, moles_transferred)
        else if(moles_transferred < 0.0)
            var/abs_transferred = min(-moles_transferred, moles_b * 0.45)
            mix_a.AdjustMoles(i, abs_transferred)
            mix_b.AdjustMoles(i, -abs_transferred)

#endif // PLENUM_PHYSICS_DIFFUSION_DM
