// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Industrial PID Controller with Anti-Reset Windup & Gain Scheduling
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_PID_CONTROLLER_DM
#define PLENUM_AUTOMATION_PID_CONTROLLER_DM

#include "plc.dm"

/datum/pid_controller
    var/loop_tag = "TIC-101"
    
    // Tuning Parameters
    var/kp = 2.5                        // Proportional gain
    var/ti_seconds = 12.0               // Integral reset time (s)
    var/td_seconds = 1.8                // Derivative time (s)
    var/derivative_filter_n = 10.0      // Filter pole ratio (typically 8 to 20)
    
    // Operating Limits
    var/output_min = 0.0                // Lower saturation clamp (0% valve)
    var/output_max = 100.0              // Upper saturation clamp (100% valve)
    var/deadband = 0.10                 // Error deadband threshold
    var/is_reverse_acting = FALSE       // Direct (cooling) or Reverse (heating)
    
    // Process Signals
    var/setpoint_sp = 50.0
    var/process_variable_pv = 50.0
    var/control_output_cv = 0.0
    var/manual_output_cv = 0.0
    var/is_manual_mode = FALSE          // Auto / Manual bumpless transfer
    
    // Internal States
    var/integral_accumulator = 0.0
    var/last_pv = 50.0
    var/filtered_derivative = 0.0

/datum/pid_controller/New(tag, p = 2.5, i = 12.0, d = 1.8)
    ..()
    loop_tag = tag
    kp = p
    ti_seconds = max(0.001, i)
    td_seconds = d

/datum/pid_controller/proc/SetManualMode(manual_state, manual_val = 0.0)
    if(manual_state && !is_manual_mode)
        // Transition to Manual: lock output
        manual_output_cv = control_output_cv
    else if(!manual_state && is_manual_mode)
        // Bumpless transfer to Auto: initialize integral accumulator to match current manual output
        integral_accumulator = manual_output_cv - (kp * (setpoint_sp - process_variable_pv))
        integral_accumulator = max(output_min, min(output_max, integral_accumulator))
    
    is_manual_mode = manual_state
    if(is_manual_mode)
        manual_output_cv = max(output_min, min(output_max, manual_val))

/datum/pid_controller/proc/ComputeStep(delta_time_seconds)
    if(is_manual_mode)
        control_output_cv = manual_output_cv
        return control_output_cv

    if(delta_time_seconds <= 0.0)
        return control_output_cv

    // Calculate error: e = SP - PV (or PV - SP for direct acting)
    var/error = setpoint_sp - process_variable_pv
    if(is_reverse_acting)
        error = -error

    // Deadband suppression to avoid hunting and actuator chatter
    if(abs(error) < deadband)
        error = 0.0

    // 1. Proportional Term: P = Kp * e
    var/p_term = kp * error

    // 2. Derivative on PV (to prevent setpoint derivative kick):
    // D[k] = (Td / (Td + N*dt)) * D[k-1] - (Kp * Td * N / (Td + N*dt)) * (PV[k] - PV[k-1])
    var/d_pv = process_variable_pv - last_pv
    var/alpha_d = td_seconds / (td_seconds + (derivative_filter_n * delta_time_seconds))
    var/beta_d = (kp * td_seconds * derivative_filter_n) / (td_seconds + (derivative_filter_n * delta_time_seconds))
    filtered_derivative = (alpha_d * filtered_derivative) - (beta_d * d_pv)
    var/d_term = filtered_derivative
    last_pv = process_variable_pv

    // 3. Preliminary Output before Integral update
    var/unsaturated_cv = p_term + integral_accumulator + d_term

    // 4. Integral Update with Conditional Anti-Reset Windup Clamping
    var/is_saturated_high = (unsaturated_cv >= output_max)
    var/is_saturated_low = (unsaturated_cv <= output_min)

    // Only integrate if not saturated in the direction of the error
    if((!is_saturated_high || error < 0.0) && (!is_saturated_low || error > 0.0))
        var/i_step = (kp / ti_seconds) * error * delta_time_seconds
        integral_accumulator += i_step

    // Final Clamped Output
    var/total_cv = p_term + integral_accumulator + d_term
    control_output_cv = max(output_min, min(output_max, total_cv))
    return control_output_cv

#endif // PLENUM_AUTOMATION_PID_CONTROLLER_DM
