// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Transmission Line & Cable PI-Equivalent Impedance Modeling
// Language: Dream Maker (DM)

#ifndef PLENUM_MICROGRID_LINE_DM
#define PLENUM_MICROGRID_LINE_DM

#include "bus.dm"

/datum/transmission_line
    var/line_id = "LINE-01-02"
    var/datum/electrical_bus/from_bus = null
    var/datum/electrical_bus/to_bus = null
    
    // Per-Unit Impedance Parameters (R + jX) on System Base MVA
    var/r_pu = 0.02                      // Series resistance
    var/x_pu = 0.08                      // Series inductive reactance
    var/b_charging_pu = 0.01             // Total line shunt charging susceptance
    
    // Line Ratings & Thermal Constraints
    var/thermal_mva_rating = 15.0        // Continuous Ampacity MVA limit
    var/emergency_mva_rating = 18.0      // 15-minute emergency rating
    
    // Real-Time Branch Power Flows
    var/p_from_to_mw = 0.0
    var/q_from_to_mvar = 0.0
    var/p_to_from_mw = 0.0
    var/q_to_from_mvar = 0.0
    var/apparent_power_mva = 0.0
    var/is_in_service = TRUE

/datum/transmission_line/New(id, datum/electrical_bus/f_bus, datum/electrical_bus/t_bus, r = 0.02, x = 0.08, b = 0.01, rating = 15.0)
    ..()
    line_id = id
    from_bus = f_bus
    to_bus = t_bus
    r_pu = r
    x_pu = x
    b_charging_pu = b
    thermal_mva_rating = rating
    if(from_bus) from_bus.connected_lines += src
    if(to_bus) to_bus.connected_lines += src

/datum/transmission_line/proc/GetSeriesAdmittanceG()
    // g = R / (R^2 + X^2)
    var/denom = (r_pu * r_pu) + (x_pu * x_pu)
    if(denom <= 0.0000001) return 1000.0
    return r_pu / denom

/datum/transmission_line/proc/GetSeriesAdmittanceB()
    // b = -X / (R^2 + X^2)
    var/denom = (r_pu * r_pu) + (x_pu * x_pu)
    if(denom <= 0.0000001) return -1000.0
    return -x_pu / denom

/datum/transmission_line/proc/CalculateBranchPowerFlow()
    if(!is_in_service || !from_bus || !to_bus)
        p_from_to_mw = 0.0
        q_from_to_mvar = 0.0
        p_to_from_mw = 0.0
        q_to_from_mvar = 0.0
        apparent_power_mva = 0.0
        return

    var/v_i = from_bus.voltage_magnitude_pu
    var/v_j = to_bus.voltage_magnitude_pu
    var/theta_i = from_bus.voltage_angle_rad
    var/theta_j = to_bus.voltage_angle_rad
    var/theta_diff = theta_i - theta_j

    var/g_ij = GetSeriesAdmittanceG()
    var/b_ij = GetSeriesAdmittanceB()
    var/b_half = b_charging_pu * 0.5
    var/base_s = from_bus.base_mva

    // P_ij = V_i^2 * g_ij - V_i * V_j * (g_ij * cos(theta_diff) + b_ij * sin(theta_diff))
    var/p_ij_pu = (v_i * v_i * g_ij) - (v_i * v_j * (g_ij * cos(theta_diff) + b_ij * sin(theta_diff)))
    
    // Q_ij = -V_i^2 * (b_ij + b_half) - V_i * V_j * (g_ij * sin(theta_diff) - b_ij * cos(theta_diff))
    var/q_ij_pu = (-v_i * v_i * (b_ij + b_half)) - (v_i * v_j * (g_ij * sin(theta_diff) - b_ij * cos(theta_diff)))

    // Opposite end: P_ji and Q_ji
    var/theta_rev = theta_j - theta_i
    var/p_ji_pu = (v_j * v_j * g_ij) - (v_j * v_i * (g_ij * cos(theta_rev) + b_ij * sin(theta_rev)))
    var/q_ji_pu = (-v_j * v_j * (b_ij + b_half)) - (v_j * v_i * (g_ij * sin(theta_rev) - b_ij * cos(theta_rev)))

    p_from_to_mw = p_ij_pu * base_s
    q_from_to_mvar = q_ij_pu * base_s
    p_to_from_mw = p_ji_pu * base_s
    q_to_from_mvar = q_ji_pu * base_s

    apparent_power_mva = sqrt((p_from_to_mw * p_from_to_mw) + (q_from_to_mvar * q_from_to_mvar))

/datum/transmission_line/proc/GetLoadingPercentage()
    if(thermal_mva_rating <= 0.0) return 0.0
    return (apparent_power_mva / thermal_mva_rating) * 100.0

/datum/transmission_line/proc/GetActiveLossesMW()
    return abs(p_from_to_mw + p_to_from_mw)

#endif // PLENUM_MICROGRID_LINE_DM
