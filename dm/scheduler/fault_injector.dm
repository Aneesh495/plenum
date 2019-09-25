// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Deterministic Fault Injection & Cyber-Physical Stress Engine
// Language: Dream Maker (DM)

#ifndef PLENUM_SCHEDULER_FAULT_INJECTOR_DM
#define PLENUM_SCHEDULER_FAULT_INJECTOR_DM

#include "../core/datum.dm"
#include "../core/obj.dm"
#include "../hydraulics/pipe_network.dm"
#include "../hydraulics/valve.dm"
#include "../microgrid/switchgear.dm"

#define FAULT_SENSOR_DRIFT             1
#define FAULT_SENSOR_FREEZE            2
#define FAULT_VALVE_STICTION           3
#define FAULT_BREAKER_FAILED_TO_TRIP   4
#define FAULT_PIPE_RUPTURE             5
#define FAULT_CYBER_INTRUSION          6

/datum/active_fault
    var/fault_id = "FLT-001"
    var/fault_type = FAULT_SENSOR_DRIFT
    var/target_component = null
    var/severity = 1.0
    var/duration_seconds = 30.0
    var/elapsed_seconds = 0.0
    var/is_active = FALSE

/datum/active_fault/New(id, type, target, sev = 1.0, dur = 30.0)
    ..()
    fault_id = id
    fault_type = type
    target_component = target
    severity = sev
    duration_seconds = dur

/datum/fault_injection_engine
    var/list/active_faults = list()

/datum/fault_injection_engine/proc/InjectSensorDrift(obj/machinery/sensor/target_sensor, drift_rate_per_sec = 0.5, duration_s = 60.0)
    if(!target_sensor) return null
    var/datum/active_fault/flt = new /datum/active_fault("FLT-DRIFT", FAULT_SENSOR_DRIFT, target_sensor, drift_rate_per_sec, duration_s)
    flt.is_active = TRUE
    active_faults += flt
    return flt

/datum/fault_injection_engine/proc/InjectPipeRupture(datum/pipe_segment/target_pipe, rupture_area_fraction = 0.25)
    if(!target_pipe) return null
    target_pipe.is_ruptured = TRUE
    var/datum/active_fault/flt = new /datum/active_fault("FLT-RUPTURE", FAULT_PIPE_RUPTURE, target_pipe, rupture_area_fraction, 999999.0)
    flt.is_active = TRUE
    active_faults += flt
    return flt

/datum/fault_injection_engine/proc/InjectValveStiction(obj/machinery/control_valve/target_valve, stiction_band_percent = 15.0)
    if(!target_valve) return null
    var/datum/active_fault/flt = new /datum/active_fault("FLT-STICTION", FAULT_VALVE_STICTION, target_valve, stiction_band_percent, 999999.0)
    flt.is_active = TRUE
    active_faults += flt
    return flt

/datum/fault_injection_engine/proc/ProcessFaultsTick(delta_time_seconds)
    for(var/datum/active_fault/flt in active_faults)
        if(!flt.is_active)
            continue
        flt.elapsed_seconds += delta_time_seconds

        switch(flt.fault_type)
            if(FAULT_SENSOR_DRIFT)
                var/obj/machinery/sensor/s = flt.target_component
                if(s)
                    s.calibration_drift_bias += flt.severity * delta_time_seconds

            if(FAULT_VALVE_STICTION)
                var/obj/machinery/control_valve/v = flt.target_component
                if(v)
                    // Hysteresis deadband: valve ignores changes smaller than stiction band
                    var/pos_diff = abs(v.target_position - v.stem_position) * 100.0
                    if(pos_diff < flt.severity)
                        v.target_position = v.stem_position // Jammed in place

        if(flt.elapsed_seconds >= flt.duration_seconds)
            flt.is_active = FALSE // Auto-clear fault

#endif // PLENUM_SCHEDULER_FAULT_INJECTOR_DM
