// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Centrifugal Pumps, Affinity Laws & Cavitation Inception
// Language: Dream Maker (DM)

#ifndef PLENUM_HYDRAULICS_PUMP_DM
#define PLENUM_HYDRAULICS_PUMP_DM

#include "pipe_network.dm"
#include "../core/obj.dm"

/obj/machinery/centrifugal_pump
    name = "variable-speed process water pump"
    desc = "High-pressure centrifugal pump with induction motor drive and seal flush plan."
    var/pump_id = "PMP-101A"
    
    // Operating Speed & VFD
    var/rpm_rated = 1780.0
    var/rpm_current = 1780.0
    var/vfd_speed_ratio = 1.00          // N / N_rated [0.0, 1.20]
    
    // Head Curve Coefficients at Rated Speed: H = H0 - A * Q^2
    var/shutoff_head_meters = 65.0      // H0 at Q = 0
    var/curve_coeff_a = 12000.0         // Quadratic drop factor
    
    // Hydraulic State
    var/flow_rate_m3_s = 0.045          // 45 liters / second
    var/developed_head_meters = 40.0
    var/hydraulic_efficiency = 0.78     // 78% efficiency at BEP (Best Efficiency Point)
    
    // Cavitation & NPSH (Net Positive Suction Head)
    var/npsh_required_meters = 3.5      // NPSH_R from manufacturer test
    var/npsh_available_meters = 5.2     // NPSH_A from suction condition
    var/is_cavitating = FALSE
    var/cavitation_damage_factor = 0.0

/obj/machinery/centrifugal_pump/proc/CalculatePumpHead(q_flow)
    // Pump Affinity Law scaling:
    // H(Q, N) = (N/N0)^2 * H0 - A * Q^2
    var/n_ratio = vfd_speed_ratio
    var/h0_scaled = shutoff_head_meters * (n_ratio * n_ratio)
    var/head = h0_scaled - (curve_coeff_a * q_flow * q_flow)
    developed_head_meters = max(0.0, head)
    return developed_head_meters

/obj/machinery/centrifugal_pump/proc/EvaluateCavitation(suction_pressure_pa, vapor_pressure_pa, fluid_density = 1000.0)
    // NPSH_A = (P_suction - P_vapor) / (rho * g)
    var/head_suction = (suction_pressure_pa - vapor_pressure_pa) / (fluid_density * STANDARD_GRAVITY_ACCEL)
    npsh_available_meters = max(0.0, head_suction)
    
    if(npsh_available_meters < npsh_required_meters)
        is_cavitating = TRUE
        cavitation_damage_factor += 0.01
        vibration_rms_velocity_mms = 8.5 // Severe high-frequency vibration spike
    else
        is_cavitating = FALSE
        vibration_rms_velocity_mms = 1.2
    
    return is_cavitating

/obj/machinery/centrifugal_pump/proc/CalculateElectricalPowerDrawWatts(fluid_density = 1000.0)
    if(operating_state == 0 || vfd_speed_ratio <= 0.01)
        power_draw_watts = 0.0
        return 0.0

    // Hydraulic Power: P_hyd = rho * g * Q * H
    var/p_hydraulic_watts = fluid_density * STANDARD_GRAVITY_ACCEL * flow_rate_m3_s * developed_head_meters
    // Electrical Power: P_elec = P_hyd / (eta_pump * eta_motor * eta_vfd)
    var/overall_efficiency = hydraulic_efficiency * 0.94 * 0.97 // 94% motor, 97% VFD
    power_draw_watts = p_hydraulic_watts / max(0.1, overall_efficiency)
    return power_draw_watts

#endif // PLENUM_HYDRAULICS_PUMP_DM
