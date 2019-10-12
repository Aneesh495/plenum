// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Scenario: Microgrid Islanding & Fast Frequency Regulation
// Language: Dream Maker (DM)

#ifndef PLENUM_SCENARIOS_MICROGRID_ISLAND_DM
#define PLENUM_SCENARIOS_MICROGRID_ISLAND_DM

#include "../core/datum.dm"
#include "../microgrid/bus.dm"
#include "../models/bess_pcs.dm"

/datum/scenario_microgrid_island
    var/scenario_name = "Microgrid Islanding & BESS Fast Frequency Response"
    var/frequency_stabilized = FALSE

/datum/scenario_microgrid_island/proc/ExecuteScenarioStep(datum/electrical_bus/island_bus, obj/machinery/bess_pcs_inverter/pcs, delta_time_s)
    // Motor trip causes over-frequency condition: 60.6 Hz
    island_bus.frequency_hz = 60.6

    // PCS detects over-frequency and absorbs power into battery
    var/curtail_p = pcs.CalculateVirtualSynchronousResponse(island_bus.frequency_hz, delta_time_s)
    if(curtail_p < 0.0) // Negative power = charging battery to brake system
        island_bus.frequency_hz = max(60.0, island_bus.frequency_hz - (0.3 * delta_time_s))
        if(abs(island_bus.frequency_hz - 60.0) <= 0.05)
            frequency_stabilized = TRUE

    return frequency_stabilized

#endif // PLENUM_SCENARIOS_MICROGRID_ISLAND_DM
