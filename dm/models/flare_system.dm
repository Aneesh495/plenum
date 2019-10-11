// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Flare Knockout Drum, Smokeless Stack & Radiation Radius (API 521)
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_FLARE_SYSTEM_DM
#define PLENUM_MODELS_FLARE_SYSTEM_DM

#include "../core/obj.dm"
#include "../physics/gas_mixture.dm"

/obj/machinery/flare_system
    name = "elevated smokeless emergency flare stack"
    desc = "API 521 certified self-supported flare stack with sonic tip, steam injection, and knockout drum."
    var/flare_id = "FLR-01"
    
    // Geometry & Structural Dimensions
    var/stack_height_meters = 60.0
    var/tip_diameter_meters = 1.2
    var/knockout_drum_volume_m3 = 45.0
    
    // Combustion State
    var/pilot_flame_proven = TRUE
    var/current_flare_gas_kg_s = 0.0
    var/steam_assist_flow_kg_s = 0.0
    var/combustion_efficiency = 0.995    // 99.5% destruction removal efficiency (DRE)
    var/max_relief_capacity_kg_s = 150.0

/obj/machinery/flare_system/proc/CalculateGroundRadiationFlux(radial_distance_m)
    // API 521 Point Source Radiant Heat Flux:
    // K = (tau * F * Q) / (4 * pi * R^2)
    if(current_flare_gas_kg_s <= 0.001)
        return 0.0

    var/heat_release_watts = current_flare_gas_kg_s * 48000000.0 // ~48 MJ/kg hydrocarbon blend
    var/f_radiation = 0.25 // Fraction of heat radiated as luminous thermal radiation
    var/transmissivity_tau = 0.95
    
    var/r_dist = sqrt((radial_distance_m * radial_distance_m) + (stack_height_meters * stack_height_meters))
    var/area_sphere = 4.0 * 3.14159265 * (r_dist * r_dist)

    var/heat_flux_w_m2 = (transmissivity_tau * f_radiation * heat_release_watts) / area_sphere
    return heat_flux_w_m2 * 0.001 // Return in kW / m^2 (Threshold: 4.73 kW/m^2 max personnel exposure)

/obj/machinery/flare_system/proc/BurnReliefGas(datum/gas_mixture/relief_packet)
    if(!relief_packet || relief_packet.total_moles <= EPSILON_MOLES)
        current_flare_gas_kg_s = 0.0
        return 0.0

    // Compute mass relief rate
    var/moles = relief_packet.total_moles
    current_flare_gas_kg_s = moles * 0.02897
    
    // Steam injection automatically proportional to mass flow: ~ 0.3 kg steam / kg hydrocarbon
    steam_assist_flow_kg_s = current_flare_gas_kg_s * 0.32

    // Evacuate packet to products of combustion
    qdel(relief_packet)
    return current_flare_gas_kg_s

#endif // PLENUM_MODELS_FLARE_SYSTEM_DM
