// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Constrained Model Predictive Control (MPC) Quadratic Programming
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_MPC_CONTROLLER_DM
#define PLENUM_AUTOMATION_MPC_CONTROLLER_DM

#include "plc.dm"

/datum/mpc_controller
    var/controller_tag = "MPC-MULTI-01"
    var/prediction_horizon_np = 10
    var/control_horizon_nc = 3
    
    // State Space Matrices: x[k+1] = A*x[k] + B*u[k], y[k] = C*x[k]
    // 2-State, 2-Input, 2-Output system (e.g. Temperature & Pressure MIMO loop)
    var/list/matrix_a = list(0.85, 0.05, 0.02, 0.90) // Flat 2x2
    var/list/matrix_b = list(0.40, 0.00, 0.05, 0.35) // Flat 2x2
    var/list/matrix_c = list(1.00, 0.00, 0.00, 1.00) // Flat 2x2

    // Cost Function Weights: Q (tracking error) and R (actuator effort)
    var/weight_q1 = 10.0
    var/weight_q2 = 5.0
    var/weight_r1 = 1.0
    var/weight_r2 = 1.0

    // Actuator Constraints: u_min <= u <= u_max
    var/u1_min = 0.0
    var/u1_max = 100.0
    var/u2_min = 0.0
    var/u2_max = 100.0

    // Current State Vector [x1, x2] and Setpoints [r1, r2]
    var/state_x1 = 20.0
    var/state_x2 = 101.3
    var/setpoint_r1 = 25.0
    var/setpoint_r2 = 105.0

    // Optimal Actuator Commands [u1, u2]
    var/actuator_u1 = 0.0
    var/actuator_u2 = 0.0

/datum/mpc_controller/New(tag = "MPC-MULTI-01")
    ..()
    controller_tag = tag

/datum/mpc_controller/proc/SolveProjectedGradientOptimization(iterations = 15, learning_rate = 0.02)
    // Projected Gradient Descent on Quadratic Cost Objective:
    // J = sum( (y - r)^T * Q * (y - r) ) + sum( u^T * R * u )
    var/opt_u1 = actuator_u1
    var/opt_u2 = actuator_u2

    for(var/iter = 1 to iterations)
        // Forward roll-out over prediction horizon
        var/sim_x1 = state_x1
        var/sim_x2 = state_x2
        var/grad_u1 = 0.0
        var/grad_u2 = 0.0

        for(var/k = 1 to prediction_horizon_np)
            // Predict next state: x[k+1] = A * x[k] + B * u
            var/next_x1 = (matrix_a[1] * sim_x1) + (matrix_a[2] * sim_x2) + (matrix_b[1] * opt_u1) + (matrix_b[2] * opt_u2)
            var/next_x2 = (matrix_a[3] * sim_x1) + (matrix_a[4] * sim_x2) + (matrix_b[3] * opt_u1) + (matrix_b[4] * opt_u2)
            sim_x1 = next_x1
            sim_x2 = next_x2

            // Tracking errors
            var/err1 = sim_x1 - setpoint_r1
            var/err2 = sim_x2 - setpoint_r2

            // Accumulate analytical cost gradients
            grad_u1 += (2.0 * weight_q1 * err1 * matrix_b[1]) + (2.0 * weight_q2 * err2 * matrix_b[3])
            grad_u2 += (2.0 * weight_q1 * err1 * matrix_b[2]) + (2.0 * weight_q2 * err2 * matrix_b[4])

        // Add control effort regularization penalty
        grad_u1 += 2.0 * weight_r1 * opt_u1
        grad_u2 += 2.0 * weight_r2 * opt_u2

        // Gradient descent update step
        opt_u1 -= learning_rate * grad_u1
        opt_u2 -= learning_rate * grad_u2

        // Box Projection onto physical actuator limits
        opt_u1 = max(u1_min, min(u1_max, opt_u1))
        opt_u2 = max(u2_min, min(u2_max, opt_u2))

    actuator_u1 = opt_u1
    actuator_u2 = opt_u2
    return list(actuator_u1, actuator_u2)

/datum/mpc_controller/proc/UpdateMeasuredState(m_x1, m_x2)
    state_x1 = m_x1
    state_x2 = m_x2

#endif // PLENUM_AUTOMATION_MPC_CONTROLLER_DM
