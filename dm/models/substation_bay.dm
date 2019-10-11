// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Substation Bay, Bus Coupler & Synchrocheck Interlock (ANSI 25)
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_SUBSTATION_BAY_DM
#define PLENUM_MODELS_SUBSTATION_BAY_DM

#include "../core/obj.dm"
#include "../microgrid/bus.dm"
#include "../microgrid/switchgear.dm"

/datum/substation_bay
    var/bay_id = "BAY-115KV-01"
    var/datum/electrical_bus/bus_a = null
    var/datum/electrical_bus/bus_b = null
    var/obj/machinery/circuit_breaker/bus_coupler_breaker = null
    
    // Synchrocheck (ANSI 25) Permissive Thresholds
    var/synch_max_voltage_diff_pu = 0.05 // 5% max voltage magnitude difference
    var/synch_max_frequency_diff_hz = 0.10 // 0.10 Hz slip frequency
    var/synch_max_angle_diff_deg = 15.0    // 15 degrees max phase angle difference

/datum/substation_bay/proc/EvaluateSynchrocheckPermissive()
    if(!bus_a || !bus_b)
        return FALSE

    var/v_diff = abs(bus_a.voltage_magnitude_pu - bus_b.voltage_magnitude_pu)
    if(v_diff > synch_max_voltage_diff_pu)
        return FALSE

    var/f_diff = abs(bus_a.frequency_hz - bus_b.frequency_hz)
    if(f_diff > synch_max_frequency_diff_hz)
        return FALSE

    // Phase angle difference in degrees
    var/angle_diff_rad = abs(bus_a.voltage_angle_rad - bus_b.voltage_angle_rad)
    var/angle_diff_deg = angle_diff_rad * 57.2957795
    if(angle_diff_deg > synch_max_angle_diff_deg)
        return FALSE

    return TRUE // Permissive granted for safe tie closure without transient shock

/datum/substation_bay/proc/CloseBusTie()
    if(!bus_coupler_breaker)
        return FALSE

    var/is_synchronized = EvaluateSynchrocheckPermissive()
    if(!is_synchronized)
        return FALSE // Synchrocheck blocks out-of-phase closure

    return bus_coupler_breaker.CloseBreaker()

#endif // PLENUM_MODELS_SUBSTATION_BAY_DM
