// Protective Relay Coordination: IEC 60255 IDMT, Distance 21, and Diff 87T
//
// Implements electrical utility and industrial protection relays.
// Formulates IEC 60255 Inverse Definite Minimum Time (IDMT) curves
// (Standard Inverse, Very Inverse, Extremely Inverse), three-zone Distance (21)
// mho impedance circle reach polygons, and Transformer Percentage Differential (87T)
// with dual-slope bias and 2nd/5th harmonic inrush magnetizing restraint.

/datum/microgrid/relay
    var/tag = "SEL-451-RELAY"

    // Overcurrent (50/51) Parameters
    var/curve_type = "IEC_EXTREMELY_INVERSE" // "IEC_STANDARD", "IEC_VERY", "IEC_EXTREMELY", "IEEE_MODERATELY"
    var/pickup_current_a = 400.0
    var/time_dial_multiplier = 0.25 // TMS
    var/instantaneous_pickup_a = 3200.0 // 50 element (instantaneous trip)

    // Distance Protection (21) Zones (in secondary ohms)
    var/zone1_reach_ohm = 2.45 // 80% line reach (instantaneous 0 ms)
    var/zone2_reach_ohm = 3.68 // 120% line reach (300 ms time delay)
    var/zone3_reach_ohm = 5.50 // Remote backup reach (600 ms time delay)
    var/zone2_delay_sec = 0.300
    var/zone3_delay_sec = 0.600

    // Transformer Differential (87T) Parameters
    var/diff_min_pickup_pu = 0.20
    var/slope_1_pct = 25.0 // Through-fault restraint slope 1
    var/slope_2_pct = 60.0 // Saturation restraint slope 2
    var/slope_1_break_pu = 1.50
    var/harmonic_2nd_restraint_pct = 15.0 // Magnetizing inrush blocking (>15% 2nd harmonic)

    // Dynamic states
    var/measured_current_rms_a = 385.0
    var/measured_voltage_rms_v = 69.3
    var/apparent_impedance_ohm = 8.5
    var/trip_signal = 0
    var/trip_reason = "NONE"
    var/accumulated_integral = 0.0

/datum/microgrid/relay/New()
    ..()

// IEC 60255 IDMT Tripping Time (seconds):
// t = TMS * [alpha / ((I / I_pickup)^beta - 1)]
/datum/microgrid/relay/proc/calculate_idmt_trip_time(current_a)
    if(current_a <= pickup_current_a)
        return 999999.0 // Infinite time (no trip)

    var/i_ratio = current_a / pickup_current_a
    var/alpha = 0.14
    var/beta = 0.02

    switch(curve_type)
        if("IEC_STANDARD")
            alpha = 0.14
            beta = 0.02
        if("IEC_VERY")
            alpha = 13.5
            beta = 1.00
        if("IEC_EXTREMELY")
            alpha = 80.0
            beta = 2.00
        if("IEEE_MODERATELY")
            alpha = 0.0515
            beta = 0.02

    var/denom = exp(beta * log(i_ratio)) - 1.0
    if(denom <= 1e-6)
        return 999999.0

    var/t_op = time_dial_multiplier * (alpha / denom)
    return max(t_op, 0.020) // Minimum 20 ms breaker clearing time

// Mho Distance Relay Characteristic (Zone 1/2/3 Circle in R-X Impedance Plane):
// |Z_apparent - Z_reach / 2| <= |Z_reach / 2|
/datum/microgrid/relay/proc/evaluate_distance_mho(r_ohm, x_ohm, dt_sec)
    var/z_mag = sqrt((r_ohm * r_ohm) + (x_ohm * x_ohm))
    apparent_impedance_ohm = z_mag

    // Angle of impedance: theta
    var/theta = arctan(x_ohm / max(r_ohm, 0.001))
    // Mho boundary reach: R_mho = Z_reach * cos(theta - line_angle)
    var/line_angle = 1.309 // 75 degrees in radians
    var/cos_factor = cos(theta - line_angle)

    if(cos_factor > 0.0)
        var/reach_limit_z1 = zone1_reach_ohm * cos_factor
        if(z_mag <= reach_limit_z1)
            trip_signal = 1
            trip_reason = "ZONE_1_MHO_TRIP"
            return 1

        var/reach_limit_z2 = zone2_reach_ohm * cos_factor
        if(z_mag <= reach_limit_z2)
            accumulated_integral += dt_sec
            if(accumulated_integral >= zone2_delay_sec)
                trip_signal = 1
                trip_reason = "ZONE_2_TIMED_MHO_TRIP"
                return 1

    return 0

// Transformer Percentage Differential 87T Characteristic:
// I_diff = |I_primary - I_secondary|
// I_restraint = (|I_primary| + |I_secondary|) / 2
/datum/microgrid/relay/proc/evaluate_differential_87t(i_pri_pu, i_sec_pu, harmonic_2nd_ratio)
    // Inrush restraint check
    if(harmonic_2nd_ratio > (harmonic_2nd_restraint_pct * 0.01))
        return 0 // Blocked by 2nd harmonic magnetizing inrush

    var/i_diff = abs(i_pri_pu - i_sec_pu)
    var/i_rest = (abs(i_pri_pu) + abs(i_sec_pu)) * 0.5

    // Dual-slope threshold
    var/i_thresh = diff_min_pickup_pu
    if(i_rest <= slope_1_break_pu)
        i_thresh += (slope_1_pct * 0.01) * i_rest
    else
        i_thresh += ((slope_1_pct * 0.01) * slope_1_break_pu) + ((slope_2_pct * 0.01) * (i_rest - slope_1_break_pu))

    if(i_diff >= i_thresh)
        trip_signal = 1
        trip_reason = "87T_INTERNAL_FAULT_DIFF_TRIP"
        return 1

    return 0

// Step protective relay evaluation loop
/datum/microgrid/relay/proc/step_relay(current_a, voltage_v, dt_sec)
    measured_current_rms_a = current_a
    measured_voltage_rms_v = voltage_v

    // 1. Instantaneous 50 Overcurrent
    if(current_a >= instantaneous_pickup_a)
        trip_signal = 1
        trip_reason = "50_INSTANTANEOUS_OVERCURRENT"
        return 1

    // 2. Timed IDMT 51 Overcurrent integration
    if(current_a > pickup_current_a)
        var/t_trip = calculate_idmt_trip_time(current_a)
        accumulated_integral += dt_sec / t_trip
        if(accumulated_integral >= 1.0)
            trip_signal = 1
            trip_reason = "51_IDMT_OVERCURRENT_TRIP"
            return 1
    else
        accumulated_integral = max(accumulated_integral - (dt_sec * 2.0), 0.0) // Electromechanical reset

    return 0
