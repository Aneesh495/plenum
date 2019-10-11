// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Industrial Steam Boiler & 3-Element Drum Level Control
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_BOILER_DM
#define PLENUM_MODELS_BOILER_DM

#include "../core/obj.dm"
#include "../hydraulics/vessel.dm"
#include "../hydraulics/valve.dm"

/obj/machinery/steam_boiler
    name = "industrial natural circulation steam boiler"
    desc = "High-pressure water-tube boiler with steam drum, radiant furnace, superheater, and economizer."
    var/boiler_id = "BLR-01"
    
    // Operating Ratings
    var/steam_capacity_tph = 65.0       // 65 metric tons / hour of superheated steam
    var/operating_pressure_bar = 42.0   // 42 bar (4.2 MPa)
    var/steam_temperature_c = 440.0     // 440 C superheated steam
    
    // Steam Drum State
    var/drum_level_mm = 0.0             // Normal Water Level (NWL = 0 mm, range [-250, +250] mm)
    var/drum_volume_m3 = 12.0
    var/steam_flow_kg_s = 18.0
    var/feedwater_flow_kg_s = 18.0
    var/fuel_firing_rate_mw = 52.0
    
    // 3-Element Level Control State (Feedwater Flow, Steam Flow, Drum Level)
    var/level_controller_integral = 0.0
    var/feedwater_valve_demand = 0.50

/obj/machinery/steam_boiler/proc/ComputeThreeElementDrumControl(delta_time_seconds)
    // 3-Element Drum Level Algorithm:
    // Level error + (Steam Flow - Feedwater Flow) feedforward
    var/level_err_mm = 0.0 - drum_level_mm // SP = 0 mm
    var/flow_mismatch_kg_s = steam_flow_kg_s - feedwater_flow_kg_s
    
    var/kp_level = 0.002
    var/ki_level = 0.0005
    var/kf_flow = 0.025

    level_controller_integral += ki_level * level_err_mm * delta_time_seconds
    level_controller_integral = max(-0.25, min(0.25, level_controller_integral))

    var/demand = 0.50 + (kp_level * level_err_mm) + level_controller_integral + (kf_flow * flow_mismatch_kg_s)
    feedwater_valve_demand = max(0.0, min(1.0, demand))

    // Water level dynamics with shrink and swell phenomena
    // Net mass inflow: Delta_M = (Feedwater - Steam) * dt
    var/net_mass_kg = (feedwater_flow_kg_s - steam_flow_kg_s) * delta_time_seconds
    var/water_density = 800.0 // kg / m^3 at 42 bar saturation
    var/water_surface_area_m2 = 6.0 // Drum surface area
    var/delta_h_mm = (net_mass_kg / (water_density * water_surface_area_m2)) * 1000.0

    drum_level_mm = max(-300.0, min(300.0, drum_level_mm + delta_h_mm))
    return drum_level_mm

/obj/machinery/steam_boiler/ProcessTick(delta_time_seconds)
    ..()
    if(operating_state == 1)
        ComputeThreeElementDrumControl(delta_time_seconds)

#endif // PLENUM_MODELS_BOILER_DM
