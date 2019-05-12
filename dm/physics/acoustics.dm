// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Acoustic Propagation, Resonances & Shock Damping
// Language: Dream Maker (DM)

#ifndef PLENUM_PHYSICS_ACOUSTICS_DM
#define PLENUM_PHYSICS_ACOUSTICS_DM

#include "gas_mixture.dm"

/datum/acoustics_engine
    var/reference_sound_pressure_pa = 2.0e-5 // 0 dB SPL reference in air (20 microPascals)
    var/atmospheric_absorption_db_per_meter = 0.005 // Attenuation in dry air at 1 kHz

/datum/acoustics_engine/proc/CalculateSpeedOfSound(datum/gas_mixture/mix)
    // Speed of sound: c = sqrt(gamma * R * T / M_avg)
    if(!mix || mix.total_moles <= EPSILON_MOLES || mix.temperature <= EPSILON_TEMPERATURE)
        return 343.0 // STP air fallback (m / s)

    var/m_total_kg = 0.0
    m_total_kg += mix.moles[GAS_O2]    * MOLAR_MASS_O2
    m_total_kg += mix.moles[GAS_N2]    * MOLAR_MASS_N2
    m_total_kg += mix.moles[GAS_CO2]   * MOLAR_MASS_CO2
    m_total_kg += mix.moles[GAS_H2O]   * MOLAR_MASS_H2O
    m_total_kg += mix.moles[GAS_H2]    * MOLAR_MASS_H2
    m_total_kg += mix.moles[GAS_CH4]   * MOLAR_MASS_CH4
    m_total_kg += mix.moles[GAS_CO]    * MOLAR_MASS_CO
    m_total_kg += mix.moles[GAS_AR]    * MOLAR_MASS_AR
    m_total_kg += mix.moles[GAS_SF6]   * MOLAR_MASS_SF6
    m_total_kg += mix.moles[GAS_R134A] * MOLAR_MASS_R134A

    var/m_avg = m_total_kg / mix.total_moles
    var/c = sqrt((AIR_SPECIFIC_HEAT_RATIO * R_IDEAL_GAS_CONSTANT * mix.temperature) / m_avg)
    return max(50.0, min(2000.0, c))

/datum/acoustics_engine/proc/PropagateSound(source_db_spl, distance_meters, list/barriers_crossed = null)
    // Inverse square law geometric spreading + atmospheric absorption + barrier insertion loss
    if(distance_meters <= 1.0)
        return source_db_spl

    // Geometric spreading: -20 * log10(r)
    var/geo_loss = 20.0 * log(distance_meters) / log(10.0)
    var/air_loss = atmospheric_absorption_db_per_meter * distance_meters
    
    var/barrier_loss = 0.0
    if(barriers_crossed)
        for(var/atom/plenum_atom/B in barriers_crossed)
            barrier_loss += B.acoustic_damping_db

    var/received_spl = source_db_spl - geo_loss - air_loss - barrier_loss
    return max(0.0, received_spl)

/datum/acoustics_engine/proc/CalculatePipeResonantFrequencies(pipe_length_meters, speed_of_sound_mps = 343.0, harmonics = 3)
    // Standing wave resonance in open-open or closed-closed pipe: fn = n * c / (2 * L)
    var/list/res_freqs = list()
    if(pipe_length_meters <= 0.01)
        return res_freqs

    var/fundamental = speed_of_sound_mps / (2.0 * pipe_length_meters)
    for(var/n = 1 to harmonics)
        res_freqs += (n * fundamental)
    return res_freqs

/datum/acoustics_engine/proc/DetectUltrasonicLeakEmission(p_internal_pa, p_external_pa, orifice_diameter_mm = 1.0)
    // Ultrasonic acoustic emission signature from high pressure gas puncture
    var/p_ratio = p_internal_pa / max(1.0, p_external_pa)
    if(p_ratio < 1.1)
        return 0.0 // Insufficient pressure drop for acoustic cavitation/choking

    // Empirical high-frequency decibel output: SPL ~ 20 * log10(P_drop) + 10 * log10(d^2)
    var/p_drop_bar = (p_internal_pa - p_external_pa) / 100000.0
    var/ultrasonic_db = 40.0 + (25.0 * log(max(0.1, p_drop_bar)) / log(10.0)) + (10.0 * log(max(0.01, orifice_diameter_mm)) / log(10.0))
    return max(0.0, ultrasonic_db)

#endif // PLENUM_PHYSICS_ACOUSTICS_DM
