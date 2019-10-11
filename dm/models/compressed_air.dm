// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Rotary Screw Compressor & Instrument Air Systems
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_COMPRESSED_AIR_DM
#define PLENUM_MODELS_COMPRESSED_AIR_DM

#include "../core/obj.dm"

/obj/machinery/instrument_air_compressor
    name = "oil-free rotary screw air compressor"
    desc = "Two-stage rotary screw compressor with intercooler, aftercooler, and desiccant dryer."
    var/compressor_id = "IAC-01"
    
    // Pressure Limits
    var/load_pressure_bar = 6.5         // Start loading when receiver drops below 6.5 bar
    var/unload_pressure_bar = 7.5       // Unload when receiver reaches 7.5 bar
    var/receiver_pressure_bar = 7.0
    var/receiver_volume_m3 = 15.0       // 15 m^3 buffer receiver vessel
    
    // Performance
    var/free_air_delivery_fpm = 1200.0  // 1200 CFM (34 m^3 / min)
    var/motor_rating_kw = 250.0
    var/is_loaded = TRUE
    var/pressure_dew_point_c = -40.0    // ISO 8573-1 Class 2 moisture purity

/obj/machinery/instrument_air_compressor/proc/UpdateCompressorPressure(plant_air_consumption_m3_min, delta_time_seconds)
    var/delivery_m3_min = is_loaded ? (free_air_delivery_fpm * 0.0283168) : 0.0
    var/net_inflow_m3_min = delivery_m3_min - plant_air_consumption_m3_min

    // Receiver pressure change: dP = (P_atm / V) * dV_net
    var/p_atm_bar = 1.01325
    var/dt_min = delta_time_seconds / 60.0
    var/delta_p_bar = (p_atm_bar / receiver_volume_m3) * (net_inflow_m3_min * dt_min)
    receiver_pressure_bar += delta_p_bar

    // Dual-action load / unload control band
    if(receiver_pressure_bar >= unload_pressure_bar)
        is_loaded = FALSE
    else if(receiver_pressure_bar <= load_pressure_bar)
        is_loaded = TRUE

    // Electrical load: 100% when loaded, ~25% when idling unloaded
    var/eff_kw = is_loaded ? motor_rating_kw : (motor_rating_kw * 0.25)
    power_draw_watts = eff_kw * 1000.0

    return receiver_pressure_bar

#endif // PLENUM_MODELS_COMPRESSED_AIR_DM
