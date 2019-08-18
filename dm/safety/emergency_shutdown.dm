// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Emergency Shutdown (ESD) Hierarchy & Flare Depressurization
// Language: Dream Maker (DM)

#ifndef PLENUM_SAFETY_EMERGENCY_SHUTDOWN_DM
#define PLENUM_SAFETY_EMERGENCY_SHUTDOWN_DM

#include "../defines.dm"
#include "../core/datum.dm"

/datum/esd_sequencer
    var/current_esd_level = ESD_STAGE_NONE
    var/list/unit_esd_valves = list()     // Automated fail-closed isolation valves
    var/list/depressurization_valves = list() // Automated fail-open blowdown valves
    var/list/main_power_breakers = list() // Medium-voltage feeder breakers
    var/blowdown_active = FALSE
    var/sequence_timer_s = 0.0

/datum/esd_sequencer/proc/TriggerESD(target_level)
    if(target_level <= current_esd_level)
        return // Already at equal or higher trip state

    current_esd_level = target_level
    sequence_timer_s = 0.0

    switch(current_esd_level)
        if(ESD_STAGE_WARN)
            // Level 1: Sound plant alarm, halt batch sequencing
            world.log << "ESD LEVEL 1 ACTIVATED: Unit Warning & Production Halt"

        if(ESD_STAGE_PROCESS_TRIP)
            // Level 2: Slam shut feed isolation valves, isolate fuel gas
            world.log << "ESD LEVEL 2 ACTIVATED: Process Trip & Isolation"
            for(var/obj/machinery/control_valve/v in unit_esd_valves)
                v.target_position = 0.0 // Fast slam shut

        if(ESD_STAGE_FACILITY_BLACK)
            // Level 3: Total facility emergency blowdown & electrical blackout
            world.log << "ESD LEVEL 3 ACTIVATED: Total Blowdown & Plant Blackout"
            blowdown_active = TRUE
            // Trip all grid incoming breakers
            for(var/obj/machinery/circuit_breaker/bkr in main_power_breakers)
                bkr.TripBreaker("ESD-3 Blackout Trip")
            // Open all flare depressurization valves
            for(var/obj/machinery/control_valve/bd_v in depressurization_valves)
                bd_v.target_position = 1.0 // Slam fully open to flare header

/datum/esd_sequencer/proc/EvaluateDepressurizationBlowdown(datum/gas_mixture/vessel_gas, delta_time_seconds, flare_backpressure_pa = 120000.0)
    // Emergency Depressurization (EDP) per API 521 standards:
    // Depressurize vessel to 50% of design pressure within 15 minutes
    if(!blowdown_active || !vessel_gas || vessel_gas.total_moles <= EPSILON_MOLES)
        return
    
    var/p_vessel = vessel_gas.CalculatePressurePascals()
    if(p_vessel <= flare_backpressure_pa)
        return // Blowdown complete to flare backpressure

    var/delta_p = p_vessel - flare_backpressure_pa
    var/vent_orifice_area_m2 = 0.015 // 6-inch flare orifice
    // Compute choked or subsonic vent rate
    var/datum/fluid_dynamics_solver/cfd = new /datum/fluid_dynamics_solver()
    var/mass_flow_kg_s = cfd.CalculateMassFlowOrifice(p_vessel, flare_backpressure_pa, vessel_gas.temperature, 0.62, vent_orifice_area_m2)
    qdel(cfd)

    var/moles_vented = (mass_flow_kg_s * delta_time_seconds) / 0.02897
    moles_vented = min(moles_vented, vessel_gas.total_moles * 0.20)
    
    if(moles_vented > 0.0)
        var/fraction = moles_vented / vessel_gas.total_moles
        var/datum/gas_mixture/vented_packet = vessel_gas.RemoveMolesFraction(fraction)
        if(vented_packet)
            qdel(vented_packet) // Routed to flare burn stack

/datum/esd_sequencer/proc/ResetESD()
    current_esd_level = ESD_STAGE_NONE
    blowdown_active = FALSE
    sequence_timer_s = 0.0
    world.log << "ESD RESET: Facility returned to normal ready state"

#endif // PLENUM_SAFETY_EMERGENCY_SHUTDOWN_DM
