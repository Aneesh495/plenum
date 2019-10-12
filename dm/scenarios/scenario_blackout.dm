// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Scenario: Total Grid Blackout & Microgrid Islanding Transition
// Language: Dream Maker (DM)

#ifndef PLENUM_SCENARIOS_BLACKOUT_DM
#define PLENUM_SCENARIOS_BLACKOUT_DM

#include "../core/datum.dm"
#include "../microgrid/bus.dm"
#include "../microgrid/switchgear.dm"
#include "../microgrid/storage.dm"
#include "../models/diesel_genset.dm"

/datum/scenario_blackout
    var/scenario_name = "Facility Loss of Offsite Power (LOOP)"
    var/elapsed_time_s = 0.0
    var/is_completed = FALSE

/datum/scenario_blackout/proc/ExecuteScenarioStep(datum/electrical_bus/main_bus, obj/machinery/circuit_breaker/incomer, datum/bess_unit/bess, obj/machinery/diesel_genset/edg, delta_time_s)
    elapsed_time_s += delta_time_s

    // Event 1: at t = 2.0s, utility grid fails (incomer breaker trips)
    if(elapsed_time_s >= 2.0 && incomer.breaker_state == BREAKER_STATE_CLOSED)
        incomer.TripBreaker("LOOP: Loss of 115kV Transmission Line")
        main_bus.frequency_hz = 59.2 // Transient frequency dip
        // Signal EDG auto-crank
        edg.InitiateAutoStart()

    // Event 2: at t = 2.1s, BESS instantaneous sub-cycle injection stabilizes frequency
    if(elapsed_time_s >= 2.1 && elapsed_time_s < 10.0)
        bess.CommandDispatch(3.0, 0.8, delta_time_s) // 3 MW fast frequency support
        main_bus.frequency_hz = 59.8

    // Event 3: at t = 10.5s, EDG reaches rated speed and synchronizes
    if(elapsed_time_s >= 10.5 && edg.is_running_rated)
        main_bus.frequency_hz = 60.0
        is_completed = TRUE

    return is_completed

#endif // PLENUM_SCENARIOS_BLACKOUT_DM
