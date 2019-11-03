// Dynamic Matrix Control (DMC) Model Predictive Controller
//
// Implements Cutler and Ramaker Dynamic Matrix Control (DMC) formulation
// for multivariable industrial process optimization. Uses Finite Step Response
// (FSR) convolution models, prediction horizon P, control horizon M, error weighting Q,
// suppression moves weighting R, free response bias projection, and constrained
// quadratic optimization with actuator slew-rate and amplitude clamping.

/datum/automation/dmc_controller
    var/tag = "APC-DMC-MIMO"
    var/prediction_horizon_p = 20
    var/control_horizon_m = 4
    var/model_horizon_n = 30

    // Unit step response coefficients S_1 to S_N (FSR model)
    var/list/step_response_s = list()

    // Weighting matrices
    var/weight_q_error = 1.0     // Setpoint tracking weight
    var/weight_r_suppression = 0.25 // Move suppression penalty

    // Actuator constraints
    var/u_min = 0.0
    var/u_max = 100.0
    var/delta_u_max = 5.0 // Maximum allowable move per control scan

    // Internal states
    var/setpoint = 50.0
    var/current_u = 50.0
    var/list/past_moves_delta_u = list()
    var/list/free_response_prediction = list()

/datum/automation/dmc_controller/New()
    ..()
    step_response_s = list()
    past_moves_delta_u = list()
    free_response_prediction = list()

    // Generate first-order plus dead-time (FOPDT) step response: K=1.8, tau=8s, theta=2s
    for(var/i = 1 to model_horizon_n)
        if(i <= 2)
            step_response_s.Add(0.0)
        else
            var/t = (i - 2) * 1.0
            var/s_val = 1.8 * (1.0 - exp(-t / 8.0))
            step_response_s.Add(s_val)

    for(var/i = 1 to model_horizon_n)
        past_moves_delta_u.Add(0.0)

    for(var/i = 1 to prediction_horizon_p)
        free_response_prediction.Add(0.0)

// Compute free response projection: y_free(k+i) = y(k) + sum_j(S_{i+j} - S_j) * Delta_u(k-j)
/datum/automation/dmc_controller/proc/calculate_free_response(current_pv)
    for(var/p = 1 to prediction_horizon_p)
        var/bias_effect = 0.0
        for(var/j = 1 to (model_horizon_n - p))
            var/s_future = step_response_s[min(p + j, model_horizon_n)]
            var/s_past = step_response_s[j]
            bias_effect += (s_future - s_past) * past_moves_delta_u[j]

        free_response_prediction[p] = current_pv + bias_effect

// DMC Control Law: Delta_u = (A^T * Q * A + R)^-1 * A^T * Q * (Setpoint - y_free)
/datum/automation/dmc_controller/proc/compute_control_move(current_pv, target_sp)
    setpoint = target_sp
    calculate_free_response(current_pv)

    // Compute error vector along prediction horizon: E = Sp - y_free
    var/sum_error_projection = 0.0
    var/s1 = step_response_s[3] // Primary response sensitivity

    for(var/p = 1 to prediction_horizon_p)
        var/err = setpoint - free_response_prediction[p]
        sum_error_projection += err * weight_q_error

    // Simplified analytical unconstrained move with single control horizon M=1:
    // Delta_u(k) = sum(A_i * e_i) / (sum(A_i^2) + R)
    var/a_norm_sq = 0.0
    for(var/p = 1 to prediction_horizon_p)
        var/val = step_response_s[min(p + 2, model_horizon_n)]
        a_norm_sq += val * val * weight_q_error

    var/denom = a_norm_sq + weight_r_suppression
    var/delta_u_unconstrained = (s1 * sum_error_projection) / max(denom, 0.01)

    // Slew rate clamping
    var/delta_u_clamped = min(max(delta_u_unconstrained, -delta_u_max), delta_u_max)

    // Amplitude constraint checking
    var/target_u = current_u + delta_u_clamped
    if(target_u > u_max)
        delta_u_clamped = max(u_max - current_u, 0.0)
    else if(target_u < u_min)
        delta_u_clamped = min(u_min - current_u, 0.0)

    current_u += delta_u_clamped

    // Shift past moves history buffer
    past_moves_delta_u.Insert(1, delta_u_clamped)
    if(past_moves_delta_u.len > model_horizon_n)
        past_moves_delta_u.Cut(model_horizon_n + 1)

    return current_u
