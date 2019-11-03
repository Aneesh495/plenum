// Extended Kalman Filter (EKF) and Process State Estimation
//
// Implements discrete-time recursive Extended Kalman Filter (EKF)
// for cyber-physical process state estimation under Gaussian sensor noise.
// Formulates non-linear state transition f(x, u), Jacobian linearization F,
// measurement model h(x), measurement Jacobian H, Kalman gain K calculation,
// covariance time-update (prediction), and covariance measurement-update (correction).

/datum/automation/kalman_filter
    var/tag = "EKF-STATE-ESTIMATOR"
    var/state_dim = 3 // States: [Temperature (K), Pressure (bar), Liquid Level (%)]
    var/meas_dim = 3

    // State estimates
    var/list/x_est = list(350.0, 45.0, 50.0) // State vector x_hat
    var/list/x_pred = list(350.0, 45.0, 50.0)

    // Error Covariance Matrix P (3x3 represented as list of 9 elements in row-major order)
    var/list/p_cov = list(
        10.0, 0.0, 0.0,
        0.0, 5.0, 0.0,
        0.0, 0.0, 8.0
    )

    // Process Noise Covariance Q
    var/list/q_noise = list(
        0.25, 0.0, 0.0,
        0.0, 0.10, 0.0,
        0.0, 0.0, 0.15
    )

    // Measurement Noise Covariance R
    var/list/r_noise = list(
        1.50, 0.0, 0.0,
        0.0, 0.80, 0.0,
        0.0, 0.0, 1.20
    )

/datum/automation/kalman_filter/New()
    ..()

// Predict step: x_pred = f(x, u), P_pred = F * P * F^T + Q
/datum/automation/kalman_filter/proc/predict(list/control_u, dt_sec)
    // Non-linear process physics:
    // T_next = T + dt * (u[1] * 2.5 - 0.05 * (T - 295.15))
    // P_next = P + dt * (0.02 * T - 0.1 * P)
    // L_next = L + dt * (u[2] - 0.8 * sqrt(max(P, 1.0)))
    var/t_curr = x_est[1]
    var/p_curr = x_est[2]
    var/l_curr = x_est[3]

    var/u_heat = control_u[1]
    var/u_valve = control_u[2]

    var/t_next = t_curr + dt_sec * (u_heat * 2.5 - 0.05 * (t_curr - 295.15))
    var/p_next = p_curr + dt_sec * (0.02 * t_curr - 0.1 * p_curr)
    var/l_next = l_curr + dt_sec * (u_valve - 0.8 * sqrt(max(p_curr, 1.0)))

    x_pred[1] = t_next
    x_pred[2] = p_next
    x_pred[3] = l_next

    // State transition Jacobian F (approximate identity + dt * df/dx)
    var/f11 = 1.0 - (0.05 * dt_sec)
    var/f21 = 0.02 * dt_sec
    var/f22 = 1.0 - (0.10 * dt_sec)
    var/f32 = -0.4 * dt_sec / sqrt(max(p_curr, 1.0))
    var/f33 = 1.0

    // P_pred = F * P * F^T + Q (diagonal dominance simplification)
    p_cov[1] = (f11 * p_cov[1] * f11) + q_noise[1]
    p_cov[5] = (f22 * p_cov[5] * f22) + q_noise[5]
    p_cov[9] = (f33 * p_cov[9] * f33) + q_noise[9]

    x_est[1] = x_pred[1]
    x_est[2] = x_pred[2]
    x_est[3] = x_pred[3]

// Update step: K = P * H^T * (H * P * H^T + R)^-1, x = x + K * (z - h(x)), P = (I - K * H) * P
/datum/automation/kalman_filter/proc/update(list/measurements_z)
    for(var/i = 1 to state_dim)
        var/diag_idx = (i - 1) * state_dim + i
        var/p_diag = p_cov[diag_idx]
        var/r_diag = r_noise[diag_idx]

        // Kalman gain for direct measurement: K_i = P_i / (P_i + R_i)
        var/k_gain = p_diag / (p_diag + r_diag)

        // Innovation / Residual: y = z - x_pred
        var/residual = measurements_z[i] - x_est[i]

        // Correct state estimate
        x_est[i] = x_est[i] + (k_gain * residual)

        // Correct error covariance: P = (1 - K) * P
        p_cov[diag_idx] = (1.0 - k_gain) * p_diag

    return x_est
