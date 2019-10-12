// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Scenario: Flange Gas Leak Plume & Robotic Localization
// Language: Dream Maker (DM)

#ifndef PLENUM_SCENARIOS_GAS_LEAK_DM
#define PLENUM_SCENARIOS_GAS_LEAK_DM

#include "../core/datum.dm"
#include "../core/turf.dm"
#include "../robotics/inspection_drone.dm"

/datum/scenario_gas_leak
    var/scenario_name = "High-Pressure Flange Rupture & Aerial Gas Plume Sniffing"
    var/elapsed_time_s = 0.0
    var/leak_isolated = FALSE

/datum/scenario_gas_leak/proc/ExecuteScenarioStep(turf/plenum_turf/leak_turf, mob/plenum_mob/robot/inspection_drone/drone, delta_time_s)
    elapsed_time_s += delta_time_s

    // Event 1: Pinhole leak injects methane into local turf atmosphere
    if(!leak_isolated && leak_turf.air)
        leak_turf.air.AdjustMoles(GAS_CH4, 5.0 * delta_time_s) // 5 mol/s leak

    // Event 2: Drone arrives and sniffs gas plume
    drone.loc = leak_turf
    var/ppm = drone.SampleAtmosphericSniffer()
    if(ppm >= 1000.0)
        // Drone commands isolation valve shut
        leak_isolated = TRUE

    return leak_isolated

#endif // PLENUM_SCENARIOS_GAS_LEAK_DM
