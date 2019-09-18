// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Multi-Rate Discrete-Event Simulation Kernel
// Language: Dream Maker (DM)

#ifndef PLENUM_SCHEDULER_TICK_KERNEL_DM
#define PLENUM_SCHEDULER_TICK_KERNEL_DM

#include "../core/datum.dm"

/datum/multi_rate_kernel
    var/simulation_time_seconds = 0.0
    var/base_tick_ms = 1.0              // 1 ms base resolution (1000 Hz)
    var/is_running = FALSE
    var/real_time_factor = 1.0
    
    // Sub-harmonic dividers
    var/substep_100hz_counter = 0        // Fires every 10 base ticks (10 ms)
    var/substep_10hz_counter = 0         // Fires every 100 base ticks (100 ms)
    var/substep_1hz_counter = 0          // Fires every 1000 base ticks (1000 ms)

    // Registered subsystem listener registries
    var/list/tier1_electrical_listeners = list() // 1000 Hz
    var/list/tier2_hydraulic_listeners = list()  // 100 Hz
    var/list/tier3_thermal_listeners = list()    // 10 Hz
    var/list/tier4_scada_listeners = list()      // 1 Hz

/datum/multi_rate_kernel/proc/AdvanceSimulationStep(delta_time_seconds)
    simulation_time_seconds += delta_time_seconds
    
    // Tier 1: High-Frequency Electrical Relaying & Fast Transients (Every tick)
    for(var/datum/target in tier1_electrical_listeners)
        if(target) target:ProcessTick(delta_time_seconds)

    // Tier 2: Hydraulic Momentum & Flow (100 Hz)
    substep_100hz_counter++
    if(substep_100hz_counter >= 10)
        substep_100hz_counter = 0
        var/dt_100hz = delta_time_seconds * 10.0
        for(var/datum/target in tier2_hydraulic_listeners)
            if(target) target:ProcessTick(dt_100hz)

    // Tier 3: Atmospheric Thermodynamics & Diffusion (10 Hz)
    substep_10hz_counter++
    if(substep_10hz_counter >= 100)
        substep_10hz_counter = 0
        var/dt_10hz = delta_time_seconds * 100.0
        for(var/datum/target in tier3_thermal_listeners)
            if(target) target:ProcessTick(dt_10hz)

    // Tier 4: Supervisory SCADA, PLC Ladder Logic & Robotics (1 Hz)
    substep_1hz_counter++
    if(substep_1hz_counter >= 1000)
        substep_1hz_counter = 0
        var/dt_1hz = delta_time_seconds * 1000.0
        for(var/datum/target in tier4_scada_listeners)
            if(target) target:ProcessTick(dt_1hz)

    return simulation_time_seconds

#endif // PLENUM_SCHEDULER_TICK_KERNEL_DM
