// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Scenario: Vault Chemical Fire & NFPA 2001 Total Flooding
// Language: Dream Maker (DM)

#ifndef PLENUM_SCENARIOS_CHEMICAL_FIRE_DM
#define PLENUM_SCENARIOS_CHEMICAL_FIRE_DM

#include "../core/datum.dm"
#include "../core/turf.dm"
#include "../safety/fire_suppression.dm"
#include "../safety/containment.dm"

/datum/scenario_chemical_fire
    var/scenario_name = "Process Vault Thermal Runaway & Inergen Suppression"
    var/fire_extinguished = FALSE

/datum/scenario_chemical_fire/proc/ExecuteScenarioStep(turf/plenum_turf/vault_turf, obj/machinery/fire_suppression_system/fss, obj/machinery/containment_door/door, delta_time_s)
    // 1. High temperature detected
    if(vault_turf.temperature > 350.0 && fss.system_state == FIRE_SUPPRESSION_IDLE)
        fss.InitiateDischarge()
        door.SealDoor()

    // Fast forward countdown for testing
    fss.countdown_elapsed_seconds = fss.pre_discharge_delay_seconds
    fss.ProcessTick(delta_time_s)

    // Check O2 percentage in turf atmosphere
    if(vault_turf.air)
        var/o2_fraction = vault_turf.air.GetMolarFraction(GAS_O2)
        if(o2_fraction < 0.12) // Below combustion threshold
            fire_extinguished = TRUE

    return fire_extinguished

#endif // PLENUM_SCENARIOS_CHEMICAL_FIRE_DM
