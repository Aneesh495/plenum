// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: ISA 18.2 Industrial Alarm Management & Shelving Lifecycle
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_ALARMS_DM
#define PLENUM_AUTOMATION_ALARMS_DM

#include "../defines.dm"
#include "../core/datum.dm"

/datum/isa_alarm
    var/alarm_tag = "PAL-301"
    var/description = "Pressure Vessel High Overpressure Alarm"
    var/priority = ALARM_PRIORITY_HIGH   // 1=Low, 2=Medium, 3=High, 4=Critical
    var/alarm_state = ALARM_STATE_NORMAL
    
    // Setpoints & Deadbands
    var/trip_setpoint = 850000.0         // 8.5 bar
    var/deadband = 15000.0              // 0.15 bar hysteresis to prevent chattering
    var/is_high_trip = TRUE             // TRUE = Trip on PV > Setpoint, FALSE = Trip on PV < Setpoint
    
    // Timing & Shelving
    var/trip_timestamp = 0
    var/ack_timestamp = 0
    var/shelve_duration_seconds = 300.0 // 5 minutes max shelving window
    var/shelved_elapsed_seconds = 0.0
    var/consequential_suppressed = FALSE

/datum/isa_alarm/New(tag, desc, prio, sp, db = 0.0, is_high = TRUE)
    ..()
    alarm_tag = tag
    description = desc
    priority = prio
    trip_setpoint = sp
    deadband = db
    is_high_trip = is_high

/datum/isa_alarm/proc/EvaluateProcessValue(pv)
    if(alarm_state == ALARM_STATE_SHELVED)
        return alarm_state

    var/condition_active = FALSE
    if(is_high_trip)
        if(alarm_state == ALARM_STATE_NORMAL || alarm_state == ALARM_STATE_CLEARED_UNACK)
            condition_active = (pv >= trip_setpoint)
        else
            condition_active = (pv >= (trip_setpoint - deadband)) // Hysteresis
    else
        if(alarm_state == ALARM_STATE_NORMAL || alarm_state == ALARM_STATE_CLEARED_UNACK)
            condition_active = (pv <= trip_setpoint)
        else
            condition_active = (pv <= (trip_setpoint + deadband))

    // State Transitions per ISA 18.2 State Chart
    switch(alarm_state)
        if(ALARM_STATE_NORMAL)
            if(condition_active && !consequential_suppressed)
                alarm_state = ALARM_STATE_ACTIVE_UNACK
                trip_timestamp = world.time

        if(ALARM_STATE_ACTIVE_UNACK)
            if(!condition_active)
                alarm_state = ALARM_STATE_CLEARED_UNACK

        if(ALARM_STATE_ACTIVE_ACKED)
            if(!condition_active)
                alarm_state = ALARM_STATE_NORMAL

        if(ALARM_STATE_CLEARED_UNACK)
            if(condition_active)
                alarm_state = ALARM_STATE_ACTIVE_UNACK

    return alarm_state

/datum/isa_alarm/proc/Acknowledge(operator_id)
    if(alarm_state == ALARM_STATE_ACTIVE_UNACK)
        alarm_state = ALARM_STATE_ACTIVE_ACKED
        ack_timestamp = world.time
        return TRUE
    else if(alarm_state == ALARM_STATE_CLEARED_UNACK)
        alarm_state = ALARM_STATE_NORMAL
        ack_timestamp = world.time
        return TRUE
    return FALSE

/datum/isa_alarm/proc/Shelve(operator_id, duration_s = 300.0)
    if(alarm_state != ALARM_STATE_NORMAL)
        alarm_state = ALARM_STATE_SHELVED
        shelve_duration_seconds = duration_s
        shelved_elapsed_seconds = 0.0
        return TRUE
    return FALSE

/datum/isa_alarm/proc/ProcessTick(delta_time_seconds)
    if(alarm_state == ALARM_STATE_SHELVED)
        shelved_elapsed_seconds += delta_time_seconds
        if(shelved_elapsed_seconds >= shelve_duration_seconds)
            // Un-shelve back to active unacknowledged
            alarm_state = ALARM_STATE_ACTIVE_UNACK
            shelved_elapsed_seconds = 0.0

/datum/alarm_manager
    var/list/alarms = list()
    var/critical_unack_count = 0

/datum/alarm_manager/proc/RegisterAlarm(datum/isa_alarm/alm)
    if(alm && !(alm in alarms))
        alarms += alm

/datum/alarm_manager/proc/CountActiveUnacknowledged()
    var/count = 0
    critical_unack_count = 0
    for(var/datum/isa_alarm/alm in alarms)
        if(alm.alarm_state == ALARM_STATE_ACTIVE_UNACK || alm.alarm_state == ALARM_STATE_CLEARED_UNACK)
            count++
            if(alm.priority == ALARM_PRIORITY_CRITICAL)
                critical_unack_count++
    return count

#endif // PLENUM_AUTOMATION_ALARMS_DM
