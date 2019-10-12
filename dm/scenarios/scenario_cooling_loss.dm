// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Scenario: Loss of Cooling Water & Chiller Condenser Overpressure
// Language: Dream Maker (DM)

#ifndef PLENUM_SCENARIOS_COOLING_LOSS_DM
#define PLENUM_SCENARIOS_COOLING_LOSS_DM

#include "../core/datum.dm"
#include "../hydraulics/pump.dm"
#include "../models/cooling_tower.dm"
#include "../models/chiller_plant.dm"

/datum/scenario_cooling_loss
    var/scenario_name = "Primary Cooling Water Pump Trip & Thermal Runaway Mitigation"
    var/elapsed_time_s = 0.0
    var/is_mitigated = FALSE

/datum/scenario_cooling_loss/proc/ExecuteScenarioStep(obj/machinery/centrifugal_pump/primary_pump, obj/machinery/centrifugal_pump/standby_pump, obj/machinery/centrifugal_chiller/chiller, delta_time_s)
    elapsed_time_s += delta_time_s

    // Event 1: At t = 3.0s, primary cooling pump experiences catastrophic bearing seizure
    if(elapsed_time_s >= 3.0 && primary_pump.operating_state == 1)
        primary_pump.operating_state = 2 // Tripped
        primary_pump.flow_rate_m3_s = 0.0

    // Event 2: Chiller condenser temperature rises rapidly
    if(elapsed_time_s >= 3.0 && primary_pump.operating_state == 2 && standby_pump.operating_state == 0)
        chiller.condenser_water_outlet_c += 2.5 * delta_time_s
        // Auto-switchgear activates standby pump
        standby_pump.operating_state = 1
        standby_pump.flow_rate_m3_s = 0.045 // 45 L/s restored

    // Event 3: Cooling restored
    if(standby_pump.operating_state == 1 && chiller.condenser_water_outlet_c > 35.0)
        chiller.condenser_water_outlet_c = max(35.0, chiller.condenser_water_outlet_c - 1.5 * delta_time_s)
        if(chiller.condenser_water_outlet_c <= 35.5)
            is_mitigated = TRUE

    return is_mitigated

#endif // PLENUM_SCENARIOS_COOLING_LOSS_DM
