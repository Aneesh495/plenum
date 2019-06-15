// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Protective Relaying & Inverse-Time Overcurrent Trip Curves
// Language: Dream Maker (DM)

#ifndef PLENUM_MICROGRID_PROTECTION_DM
#define PLENUM_MICROGRID_PROTECTION_DM

#include "bus.dm"
#include "line.dm"

// Curve Types per IEC 60255 & IEEE C37.112
#define CURVE_IEC_STANDARD_INVERSE       1
#define CURVE_IEC_VERY_INVERSE           2
#define CURVE_IEC_EXTREMELY_INVERSE      3
#define CURVE_IEEE_MODERATELY_INVERSE    4

/datum/protective_relay
    var/relay_id = "51-FEEDER-01"
    var/ansi_device_number = 51         // 50=Instantaneous, 51=Time Overcurrent, 27=Undervoltage
    var/datum/electrical_bus/monitored_bus = null
    var/datum/transmission_line/monitored_line = null
    
    // Relay Settings
    var/pickup_current_a = 600.0         // Current threshold I_s
    var/instantaneous_pickup_a = 3000.0  // ANSI 50 instantaneous threshold
    var/time_multiplier_setting = 0.10   // TMS (IEC) or Time Dial TD (IEEE)
    var/curve_type = CURVE_IEC_STANDARD_INVERSE

    // Timing state
    var/accumulator_time_s = 0.0
    var/is_tripped = FALSE
    var/trip_target_breaker_id = "BKR-01"

/datum/protective_relay/New(id, ansi_num = 51, pickup = 600.0, tms = 0.1)
    ..()
    relay_id = id
    ansi_device_number = ansi_num
    pickup_current_a = pickup
    time_multiplier_setting = tms

/datum/protective_relay/proc/CalculateOperatingTimeSeconds(current_a)
    if(current_a <= pickup_current_a)
        return 999999.0 // No trip below pickup

    var/m = current_a / pickup_current_a // Multiplier of pickup setting (I / I_s)

    // Check ANSI 50 Instantaneous Overcurrent
    if(current_a >= instantaneous_pickup_a)
        return 0.020 // 20 ms instantaneous electronic trip

    var/a_coeff = 0.14
    var/p_exp = 0.02
    var/b_const = 0.0

    switch(curve_type)
        if(CURVE_IEC_STANDARD_INVERSE)
            a_coeff = 0.14
            p_exp = 0.02
            b_const = 0.0
        if(CURVE_IEC_VERY_INVERSE)
            a_coeff = 13.5
            p_exp = 1.00
            b_const = 0.0
        if(CURVE_IEC_EXTREMELY_INVERSE)
            a_coeff = 80.0
            p_exp = 2.00
            b_const = 0.0
        if(CURVE_IEEE_MODERATELY_INVERSE)
            a_coeff = 0.0515
            p_exp = 0.02
            b_const = 0.114

    // IEC 60255 trip formula: t = TMS * [ A / (M^p - 1) + B ]
    var/denom = (m ** p_exp) - 1.0
    if(denom <= 0.000001) return 999999.0
    var/t_op = time_multiplier_setting * ((a_coeff / denom) + b_const)
    return max(0.020, t_op)

/datum/protective_relay/proc/EvaluateTick(current_a, delta_time_seconds)
    if(is_tripped)
        return TRUE

    if(current_a > pickup_current_a)
        var/t_trip = CalculateOperatingTimeSeconds(current_a)
        // Accumulate fractional trip disk rotation
        accumulator_time_s += (delta_time_seconds / t_trip)
        if(accumulator_time_s >= 1.0)
            is_tripped = TRUE
            return TRUE
    else
        // Disk resets when current falls below pickup
        accumulator_time_s = max(0.0, accumulator_time_s - (delta_time_seconds * 2.0))

    return FALSE

/datum/protective_relay/proc/ResetTrip()
    is_tripped = FALSE
    accumulator_time_s = 0.0

#endif // PLENUM_MICROGRID_PROTECTION_DM
