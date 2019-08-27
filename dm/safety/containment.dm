// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Blast-Rated Hermetic Doors & Airlock Interlocks
// Language: Dream Maker (DM)

#ifndef PLENUM_SAFETY_CONTAINMENT_DM
#define PLENUM_SAFETY_CONTAINMENT_DM

#include "../core/obj.dm"
#include "../core/turf.dm"

/obj/machinery/containment_door
    name = "hermetic blast door"
    desc = "Motorized steel blast door with pneumatic inflatable silicone seals."
    density = TRUE
    opacity = TRUE
    var/door_id = "DOOR-REACTOR-A"
    
    // Physical State: 0=Open, 1=Closing, 2=Closed, 3=Sealed, 4=Opening
    var/door_state = 3                   // Default Sealed
    var/seal_pressure_bar = 3.5          // Pneumatic seal inflation pressure
    var/target_seal_pressure_bar = 3.5
    var/stroke_percent = 100.0           // 0.0 = Open, 100.0 = Fully shut
    var/is_emergency_locked = FALSE
    var/interlocked_door_id = "DOOR-REACTOR-B" // Paired airlock door

/obj/machinery/containment_door/proc/SealDoor()
    if(stroke_percent < 99.0)
        return FALSE // Cannot inflate seal unless fully seated
    door_state = 3
    target_seal_pressure_bar = 3.5
    density = TRUE
    opacity = TRUE
    
    // Invalidate turf permeability to gas
    if(isturf(loc))
        var/turf/plenum_turf/T = loc
        T.permeability_flags = T.permeability_flags & ~PASS_GAS
    return TRUE

/obj/machinery/containment_door/proc/UnsealAndOpen()
    if(is_emergency_locked)
        return FALSE
    
    // Deflate seals first
    target_seal_pressure_bar = 0.0
    seal_pressure_bar = 0.0
    door_state = 4 // Opening
    stroke_percent = 0.0
    density = FALSE
    opacity = FALSE

    if(isturf(loc))
        var/turf/plenum_turf/T = loc
        T.permeability_flags = T.permeability_flags | PASS_GAS
    return TRUE

/datum/airlock_controller
    var/airlock_id = "AIRLOCK-01"
    var/obj/machinery/containment_door/door_inner = null
    var/obj/machinery/containment_door/door_outer = null
    var/obj/machinery/control_valve/vent_valve = null
    var/is_purging = FALSE
    var/purge_timer_s = 0.0

/datum/airlock_controller/proc/RequestEntry()
    // Ingress sequence: Outer opens -> Enter airlock -> Outer closes & seals -> Purge/equalize -> Inner opens
    if(door_inner && door_inner.door_state != 3) // Inner must be sealed
        return FALSE
    if(door_outer)
        door_outer.UnsealAndOpen()
        return TRUE
    return FALSE

/datum/airlock_controller/proc/CycleAirlock(delta_time_seconds)
    if(is_purging)
        purge_timer_s += delta_time_seconds
        if(purge_timer_s >= 10.0) // 10s nitrogen wash
            is_purging = FALSE
            if(door_inner)
                door_inner.UnsealAndOpen()

#endif // PLENUM_SAFETY_CONTAINMENT_DM
