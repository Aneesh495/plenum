// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Clean-Agent Total Flooding Fire Suppression (NFPA 2001)
// Language: Dream Maker (DM)

#ifndef PLENUM_SAFETY_FIRE_SUPPRESSION_DM
#define PLENUM_SAFETY_FIRE_SUPPRESSION_DM

#include "../core/obj.dm"
#include "../physics/gas_mixture.dm"

#define FIRE_SUPPRESSION_IDLE        0
#define FIRE_SUPPRESSION_COUNTDOWN   1
#define FIRE_SUPPRESSION_DISCHARGING 2
#define FIRE_SUPPRESSION_HOLDING     3
#define FIRE_SUPPRESSION_EXHAUSTED   4

/obj/machinery/fire_suppression_system
    name = "total flooding clean-agent system"
    desc = "NFPA 2001 certified inert gas total flooding cylinder bank with pre-discharge evacuation delay."
    var/system_id = "FSS-SWITCHGEAR-01"
    
    // System State
    var/system_state = FIRE_SUPPRESSION_IDLE
    var/pre_discharge_delay_seconds = 30.0 // 30s life-safety evacuation strobe
    var/countdown_elapsed_seconds = 0.0
    var/discharge_duration_seconds = 10.0  // Rapid 10s agent dump
    var/discharge_elapsed_seconds = 0.0
    
    // Agent Storage (Nitrogen / Inergen blend: 52% N2, 40% Ar, 8% CO2)
    var/agent_cylinder_count = 12
    var/cylinder_pressure_bar = 200.0     // 200 bar storage
    var/total_agent_moles = 15000.0       // Moles of extinguishing gas
    var/area_target_id = "ZONE-ELEC-SWG"

/obj/machinery/fire_suppression_system/proc/InitiateDischarge()
    if(system_state != FIRE_SUPPRESSION_IDLE)
        return
    system_state = FIRE_SUPPRESSION_COUNTDOWN
    countdown_elapsed_seconds = 0.0
    
    // Trip HVAC isolation dampers in target area immediately
    if(isturf(loc))
        var/turf/plenum_turf/T = loc
        if(T.zone)
            T.zone.TriggerFireLockdown()

/obj/machinery/fire_suppression_system/proc/AbortCountdown()
    if(system_state == FIRE_SUPPRESSION_COUNTDOWN)
        system_state = FIRE_SUPPRESSION_IDLE
        countdown_elapsed_seconds = 0.0

/obj/machinery/fire_suppression_system/ProcessTick(delta_time_seconds)
    ..()
    switch(system_state)
        if(FIRE_SUPPRESSION_COUNTDOWN)
            countdown_elapsed_seconds += delta_time_seconds
            if(countdown_elapsed_seconds >= pre_discharge_delay_seconds)
                system_state = FIRE_SUPPRESSION_DISCHARGING
                discharge_elapsed_seconds = 0.0

        if(FIRE_SUPPRESSION_DISCHARGING)
            discharge_elapsed_seconds += delta_time_seconds
            var/fraction = delta_time_seconds / discharge_duration_seconds
            var/moles_to_inject = total_agent_moles * fraction

            // Inject inert gas into current turf atmosphere
            if(isturf(loc))
                var/turf/plenum_turf/T = loc
                if(T.air)
                    // Inergen blend: 52% N2, 40% Ar, 8% CO2
                    T.air.AdjustMoles(GAS_N2, moles_to_inject * 0.52)
                    T.air.AdjustMoles(GAS_AR, moles_to_inject * 0.40)
                    T.air.AdjustMoles(GAS_CO2, moles_to_inject * 0.08)

            if(discharge_elapsed_seconds >= discharge_duration_seconds)
                system_state = FIRE_SUPPRESSION_HOLDING

#endif // PLENUM_SAFETY_FIRE_SUPPRESSION_DM
