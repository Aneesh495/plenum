// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Scenario: Blocked Discharge Overpressure & Flare Blowdown
// Language: Dream Maker (DM)

#ifndef PLENUM_SCENARIOS_OVERPRESSURE_DM
#define PLENUM_SCENARIOS_OVERPRESSURE_DM

#include "../core/datum.dm"
#include "../hydraulics/vessel.dm"
#include "../hydraulics/valve.dm"
#include "../models/flare_system.dm"

/datum/scenario_overpressure
    var/scenario_name = "Vessel Blocked Discharge & ASME Safety Relief to Flare"
    var/psv_cleared_safely = FALSE

/datum/scenario_overpressure/proc/ExecuteScenarioStep(obj/machinery/process_vessel/vessel, obj/machinery/safety_relief_valve/psv, obj/machinery/flare_system/flare, delta_time_s)
    // Inflow continues while outlet is blocked
    vessel.ullage_gas.AddThermalEnergy(50000.0 * delta_time_s) // Thermal expansion pressurization
    var/p_vessel = vessel.ullage_gas.CalculatePressurePascals()

    // Evaluate PSV lift
    var/is_lifting = psv.EvaluateRelief(p_vessel)
    if(is_lifting)
        // Vent gas to flare stack
        var/datum/gas_mixture/relief_packet = vessel.ullage_gas.RemoveMolesFraction(0.15)
        if(relief_packet)
            flare.BurnReliefGas(relief_packet)
        psv_cleared_safely = TRUE

    return psv_cleared_safely

#endif // PLENUM_SCENARIOS_OVERPRESSURE_DM
