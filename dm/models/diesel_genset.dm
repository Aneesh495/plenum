// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Emergency Diesel Generator (EDG) & Black Start Auto-Sequencing
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_DIESEL_GENSET_DM
#define PLENUM_MODELS_DIESEL_GENSET_DM

#include "../core/obj.dm"
#include "../microgrid/generator.dm"

/obj/machinery/diesel_genset
    name = "emergency diesel generator set"
    desc = "NFPA 110 Level 1 certified standby diesel generator with compressed air starting and ISO 8528 governor."
    var/genset_id = "EDG-01"
    
    // Nameplate Ratings
    var/rated_power_mw = 3.5
    var/fuel_day_tank_liters = 5000.0   // 8 hours continuous full-load run
    var/specific_fuel_consumption_g_kwh = 215.0
    
    // Auto-Starting Transient State (NFPA 110: 10s start)
    var/start_sequence_active = FALSE
    var/start_elapsed_seconds = 0.0
    var/time_to_rated_speed_s = 8.5
    var/is_running_rated = FALSE
    
    // Coupled Alternator
    var/datum/power_generator/synchronous_alternator/coupled_alternator = null

/obj/machinery/diesel_genset/New(loc, id = "EDG-01")
    ..(loc)
    genset_id = id
    coupled_alternator = new /datum/power_generator/synchronous_alternator(id + "-ALT", null, rated_power_mw)
    coupled_alternator.is_online = FALSE

/obj/machinery/diesel_genset/proc/InitiateAutoStart()
    if(is_running_rated || start_sequence_active)
        return
    start_sequence_active = TRUE
    start_elapsed_seconds = 0.0

/obj/machinery/diesel_genset/ProcessTick(delta_time_seconds)
    ..()
    if(start_sequence_active)
        start_elapsed_seconds += delta_time_seconds
        if(start_elapsed_seconds >= time_to_rated_speed_s)
            start_sequence_active = FALSE
            is_running_rated = TRUE
            if(coupled_alternator)
                coupled_alternator.is_online = TRUE

    if(is_running_rated && coupled_alternator)
        // Fuel consumption: m_dot = P_kw * SFOC
        var/p_kw = coupled_alternator.current_output_mw * 1000.0
        var/fuel_g_per_sec = (p_kw * specific_fuel_consumption_g_kwh) / 3600.0
        var/fuel_liters_sec = (fuel_g_per_sec / 850.0) // Diesel density ~ 850 g/L
        fuel_day_tank_liters = max(0.0, fuel_day_tank_liters - (fuel_liters_sec * delta_time_seconds))

#endif // PLENUM_MODELS_DIESEL_GENSET_DM
