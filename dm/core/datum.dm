// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Core Datum Hierarchy and Event Bus
// Language: Dream Maker (DM)

#ifndef PLENUM_CORE_DATUM_DM
#define PLENUM_CORE_DATUM_DM

// Signal Definitions for Event-Driven Telemetry and Process Loops
#define SIG_PRESSURE_CHANGED        "sig_pressure_changed"
#define SIG_TEMPERATURE_CHANGED     "sig_temp_changed"
#define SIG_GAS_COMPOSITION_CHANGED "sig_gas_changed"
#define SIG_VOLTAGE_SAG             "sig_voltage_sag"
#define SIG_BREAKER_TRIP            "sig_breaker_trip"
#define SIG_VALVE_ACTUATED          "sig_valve_actuated"
#define SIG_PUMP_STATE_CHANGED      "sig_pump_changed"
#define SIG_ALARM_STATE_CHANGED     "sig_alarm_changed"
#define SIG_ESD_TRIGGERED           "sig_esd_triggered"
#define SIG_CONTAINMENT_BREACH      "sig_containment_breach"
#define SIG_OBJECT_DESTROYED        "sig_obj_destroyed"

// Global unique identifier counter for datums
var/global/plenum_datum_uid_counter = 0

/datum/plenum_datum
    var/uid = 0
    var/tag_name = "datum"
    var/is_destroyed = FALSE
    var/creation_tick = 0
    var/last_modified_tick = 0
    var/list/signal_subscribers = null // Associative list: signal_name -> list(targets)
    var/list/metadata = null           // Key-value store for arbitrary instrumentation tags

/datum/plenum_datum/New()
    ..()
    uid = ++plenum_datum_uid_counter
    creation_tick = world.time
    last_modified_tick = world.time

/datum/plenum_datum/proc/Destroy()
    if(is_destroyed)
        return
    is_destroyed = TRUE
    SendSignal(SIG_OBJECT_DESTROYED, list("uid" = uid))
    
    // Clear all subscribed listeners
    if(signal_subscribers)
        signal_subscribers.Cut()
        signal_subscribers = null
    
    if(metadata)
        metadata.Cut()
        metadata = null

/datum/plenum_datum/proc/RegisterSignal(signal_name, /datum/plenum_datum/target, target_proc)
    if(!signal_name || !target || !target_proc)
        return FALSE
    if(!signal_subscribers)
        signal_subscribers = list()
    if(!signal_subscribers[signal_name])
        signal_subscribers[signal_name] = list()
    
    var/list/listeners = signal_subscribers[signal_name]
    listeners[target] = target_proc
    return TRUE

/datum/plenum_datum/proc/UnregisterSignal(signal_name, /datum/plenum_datum/target)
    if(!signal_subscribers || !signal_subscribers[signal_name])
        return FALSE
    var/list/listeners = signal_subscribers[signal_name]
    listeners.Remove(target)
    if(listeners.len == 0)
        signal_subscribers.Remove(signal_name)
    return TRUE

/datum/plenum_datum/proc/SendSignal(signal_name, list/params = null)
    if(!signal_subscribers || !signal_subscribers[signal_name])
        return 0
    
    var/list/listeners = signal_subscribers[signal_name]
    var/dispatch_count = 0
    for(var/datum/plenum_datum/listener in listeners)
        if(!listener || listener.is_destroyed)
            continue
        var/proc_name = listeners[listener]
        call(listener, proc_name)(src, params)
        dispatch_count++
    
    return dispatch_count

/datum/plenum_datum/proc/SetMetadata(key, value)
    if(!metadata)
        metadata = list()
    metadata[key] = value
    last_modified_tick = world.time

/datum/plenum_datum/proc/GetMetadata(key, default_val = null)
    if(!metadata || !metadata[key])
        return default_val
    return metadata[key]

/datum/plenum_datum/proc/Serialize()
    var/list/serialized = list(
        "uid" = uid,
        "tag_name" = tag_name,
        "creation_tick" = creation_tick,
        "last_modified_tick" = last_modified_tick
    )
    if(metadata && metadata.len > 0)
        serialized["metadata"] = metadata.Copy()
    return serialized

/datum/plenum_datum/proc/Deserialize(list/data)
    if(!data)
        return FALSE
    if(data["tag_name"])
        tag_name = data["tag_name"]
    if(data["metadata"])
        var/list/meta = data["metadata"]
        metadata = meta.Copy()
    last_modified_tick = world.time
    return TRUE

#endif // PLENUM_CORE_DATUM_DM
