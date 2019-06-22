// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Medium-Voltage Switchgear & Vacuum Circuit Breakers
// Language: Dream Maker (DM)

#ifndef PLENUM_MICROGRID_SWITCHGEAR_DM
#define PLENUM_MICROGRID_SWITCHGEAR_DM

#include "bus.dm"
#include "../core/obj.dm"

/obj/machinery/circuit_breaker
    name = "vacuum circuit breaker"
    desc = "Metal-clad medium-voltage drawout circuit breaker with motorized spring charging mechanism."
    var/breaker_id = "VCB-52-01"
    var/datum/electrical_bus/bus_source = null
    var/datum/electrical_bus/bus_load = null
    
    // Ratings
    var/rated_voltage_kv = 15.0
    var/continuous_current_a = 1200.0
    var/interrupting_current_ka = 25.0   // Symmetrical breaking capacity
    var/opening_time_cycles = 3.0        // 50 milliseconds at 60 Hz
    
    // Operating State: 0=Open, 1=Closed, 2=Tripped
    var/breaker_state = BREAKER_STATE_CLOSED
    var/spring_charged = TRUE
    var/trip_count = 0
    var/contact_wear_percentage = 0.0

    // Arc-Flash Physics (IEEE 1584 standard)
    var/working_distance_mm = 610.0      // 24 inches
    var/arc_duration_seconds = 0.05      // Cleared in 3 cycles

/obj/machinery/circuit_breaker/New(loc, id, datum/electrical_bus/src_b, datum/electrical_bus/load_b)
    ..(loc)
    breaker_id = id
    bus_source = src_b
    bus_load = load_b
    if(bus_source) bus_source.connected_breakers += src
    if(bus_load) bus_load.connected_breakers += src

/obj/machinery/circuit_breaker/proc/TripBreaker(reason = "Overcurrent Protection")
    if(breaker_state == BREAKER_STATE_OPEN)
        return
    breaker_state = BREAKER_STATE_TRIPPED
    trip_count++
    contact_wear_percentage = min(100.0, contact_wear_percentage + 1.5)
    
    // Disconnect buses electrically
    if(bus_load)
        bus_load.p_load_mw = 0.0
        bus_load.q_load_mvar = 0.0
        bus_load.voltage_magnitude_pu = 0.0

    if(event_hub)
        event_hub.SendSignal(SIG_BREAKER_TRIP, list("id" = breaker_id, "reason" = reason))

/obj/machinery/circuit_breaker/proc/CloseBreaker()
    if(contact_wear_percentage >= 100.0)
        return FALSE // Contacts eroded past safety envelope
    breaker_state = BREAKER_STATE_CLOSED
    spring_charged = TRUE
    return TRUE

/obj/machinery/circuit_breaker/proc/OpenBreaker()
    breaker_state = BREAKER_STATE_OPEN

/obj/machinery/circuit_breaker/proc/CalculateArcFlashIncidentEnergy(fault_current_ka)
    // IEEE 1584 Arc Flash Incident Energy in cal / cm^2
    // Log10(E) = k1 + k2 + 1.0811*Log10(Ia) + 0.0011*G
    if(fault_current_ka <= 0.0)
        return 0.0

    var/i_a = fault_current_ka
    var/log_ia = log(i_a) / log(10.0)
    var/g_mm = 32.0 // Bus gap (mm)
    
    // Normalized incident energy log
    var/log_en = -0.555 + (1.0811 * log_ia) + (0.0011 * g_mm)
    var/e_norm = 10.0 ** log_en
    
    // Incident energy at working distance: E = 4.184 * Cf * En * (t / 0.2) * (610 / D)^x
    var/c_f = 1.5 // Enclosed switchgear box
    var/dist_factor = (610.0 / working_distance_mm) ** 1.473
    var/time_factor = arc_duration_seconds / 0.20
    var/e_cal_cm2 = (e_norm * c_f * time_factor * dist_factor)
    return e_cal_cm2

#endif // PLENUM_MICROGRID_SWITCHGEAR_DM
