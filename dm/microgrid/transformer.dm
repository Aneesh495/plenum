// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Power Transformers, Saturation & On-Load Tap Changers
// Language: Dream Maker (DM)

#ifndef PLENUM_MICROGRID_TRANSFORMER_DM
#define PLENUM_MICROGRID_TRANSFORMER_DM

#include "bus.dm"

/datum/power_transformer
    var/transformer_id = "XFMR-01"
    var/datum/electrical_bus/primary_bus = null
    var/datum/electrical_bus/secondary_bus = null
    
    // Nameplate Ratings
    var/rated_mva = 20.0
    var/primary_rated_kv = 13.8
    var/secondary_rated_kv = 4.16
    
    // Per-Unit Leakage Impedance
    var/r_leakage_pu = 0.008             // Winding resistance
    var/x_leakage_pu = 0.065             // Leakage reactance
    
    // On-Load Tap Changer (OLTC)
    var/tap_ratio = 1.000                // Current voltage turns ratio
    var/tap_position = 0                 // Neutral = 0, range [-16, +16]
    var/tap_step_percent = 0.625         // 5/8 % per step (standard IEEE +/- 10% range)
    var/auto_tap_enabled = TRUE
    var/target_secondary_pu = 1.000
    var/voltage_deadband_pu = 0.015

    // Core Magnetics & Thermal State (IEEE C57.91)
    var/core_loss_kw = 25.0              // No-load iron loss
    var/top_oil_temperature_c = 45.0     // Ambient + rise
    var/winding_hot_spot_c = 55.0        // Hottest spot in winding insulation
    var/max_hot_spot_limit_c = 110.0     // Thermal aging threshold

    var/is_energized = TRUE

/datum/power_transformer/New(id, datum/electrical_bus/p_bus, datum/electrical_bus/s_bus, mva = 20.0, p_kv = 13.8, s_kv = 4.16)
    ..()
    transformer_id = id
    primary_bus = p_bus
    secondary_bus = s_bus
    rated_mva = mva
    primary_rated_kv = p_kv
    secondary_rated_kv = s_kv

/datum/power_transformer/proc/AdjustTap(step_delta)
    tap_position = max(-16, min(16, tap_position + step_delta))
    tap_ratio = 1.000 + (tap_position * tap_step_percent * 0.01)
    return tap_ratio

/datum/power_transformer/proc/EvaluateOLTCServo()
    if(!auto_tap_enabled || !secondary_bus || !is_energized)
        return tap_ratio

    var/v_sec = secondary_bus.voltage_magnitude_pu
    var/v_err = target_secondary_pu - v_sec

    if(abs(v_err) > voltage_deadband_pu)
        if(v_err > 0.0 && tap_position < 16)
            AdjustTap(1) // Step up secondary voltage
        else if(v_err < 0.0 && tap_position > -16)
            AdjustTap(-1) // Step down secondary voltage

    return tap_ratio

/datum/power_transformer/proc/UpdateThermalModel(throughput_mva, ambient_c = 25.0, delta_time_seconds = 10.0)
    // IEEE C57.91 two-node thermal differential equations
    var/load_ratio = throughput_mva / max(0.1, rated_mva)
    var/oil_time_constant_hrs = 3.0
    var/winding_time_constant_min = 6.0

    // Rated top-oil and hot-spot temperature rises over ambient
    var/rated_oil_rise_c = 45.0
    var/rated_hot_spot_rise_c = 25.0

    // Steady-state ultimate temperatures:
    // Delta_theta_oil = Delta_theta_oil_rated * ((K^2 * R + 1) / (R + 1))^0.8 where R = load_loss / no_load_loss
    var/loss_ratio_r = 5.0
    var/oil_factor = ((load_ratio * load_ratio * loss_ratio_r + 1.0) / (loss_ratio_r + 1.0)) ** 0.8
    var/target_oil_rise = rated_oil_rise_c * oil_factor
    var/target_oil_temp = ambient_c + target_oil_rise

    // Integrate top-oil temperature
    var/dt_hrs = delta_time_seconds / 3600.0
    top_oil_temperature_c += (target_oil_temp - top_oil_temperature_c) * (dt_hrs / oil_time_constant_hrs)

    // Hot-spot gradient over top-oil: Delta_theta_hs = Delta_theta_hs_rated * K^1.6
    var/target_hs_gradient = rated_hot_spot_rise_c * (load_ratio ** 1.6)
    var/target_hot_spot = top_oil_temperature_c + target_hs_gradient
    
    var/dt_min = delta_time_seconds / 60.0
    winding_hot_spot_c += (target_hot_spot - winding_hot_spot_c) * (dt_min / winding_time_constant_min)

    return winding_hot_spot_c

#endif // PLENUM_MICROGRID_TRANSFORMER_DM
