// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Newton-Raphson & Fast Decoupled Power Flow Solver
// Language: Dream Maker (DM)

#ifndef PLENUM_MICROGRID_POWER_FLOW_DM
#define PLENUM_MICROGRID_POWER_FLOW_DM

#include "bus.dm"
#include "line.dm"

/datum/power_flow_solver
    var/max_iterations = 25
    var/convergence_tolerance_pu = 0.0001
    var/list/buses = list()
    var/list/lines = list()
    var/list/y_bus_g = null              // N x N real conductance matrix
    var/list/y_bus_b = null              // N x N imaginary susceptance matrix
    var/is_converged = FALSE
    var/iterations_executed = 0

/datum/power_flow_solver/New(list/b_list, list/l_list)
    ..()
    if(b_list) buses = b_list
    if(l_list) lines = l_list

/datum/power_flow_solver/proc/BuildBusAdmittanceMatrix()
    var/n = buses.len
    y_bus_g = list()
    y_bus_b = list()
    y_bus_g.len = n * n
    y_bus_b.len = n * n

    for(var/k = 1 to n * n)
        y_bus_g[k] = 0.0
        y_bus_b[k] = 0.0

    // Incorporate transmission line series and shunt parameters
    for(var/datum/transmission_line/L in lines)
        if(!L.is_in_service)
            continue
        var/i = buses.Find(L.from_bus)
        var/j = buses.Find(L.to_bus)
        if(i <= 0 || j <= 0)
            continue

        var/g_line = L.GetSeriesAdmittanceG()
        var/b_line = L.GetSeriesAdmittanceB()
        var/b_half = L.b_charging_pu * 0.5

        // Off-diagonal elements: Y_ij = -y_line
        var/idx_ij = (i - 1) * n + j
        var/idx_ji = (j - 1) * n + i
        y_bus_g[idx_ij] -= g_line
        y_bus_b[idx_ij] -= b_line
        y_bus_g[idx_ji] -= g_line
        y_bus_b[idx_ji] -= b_line

        // Diagonal elements: Y_ii += y_line + j*(b_half)
        var/idx_ii = (i - 1) * n + i
        var/idx_jj = (j - 1) * n + j
        y_bus_g[idx_ii] += g_line
        y_bus_b[idx_ii] += (b_line + b_half)
        y_bus_g[idx_jj] += g_line
        y_bus_b[idx_jj] += (b_line + b_half)

/datum/power_flow_solver/proc/CalculateInjectedPower(bus_index)
    var/n = buses.len
    var/datum/electrical_bus/B_i = buses[bus_index]
    var/v_i = B_i.voltage_magnitude_pu
    var/theta_i = B_i.voltage_angle_rad

    var/p_calc = 0.0
    var/q_calc = 0.0

    for(var/j = 1 to n)
        var/datum/electrical_bus/B_j = buses[j]
        var/v_j = B_j.voltage_magnitude_pu
        var/theta_j = B_j.voltage_angle_rad
        var/theta_ij = theta_i - theta_j

        var/idx = (bus_index - 1) * n + j
        var/g_ij = y_bus_g[idx]
        var/b_ij = y_bus_b[idx]

        // P_i = sum( V_i * V_j * (G_ij * cos(theta_ij) + B_ij * sin(theta_ij)) )
        p_calc += v_i * v_j * (g_ij * cos(theta_ij) + b_ij * sin(theta_ij))
        // Q_i = sum( V_i * V_j * (G_ij * sin(theta_ij) - B_ij * cos(theta_ij)) )
        q_calc += v_i * v_j * (g_ij * sin(theta_ij) - b_ij * cos(theta_ij))

    return list(p_calc, q_calc)

/datum/power_flow_solver/proc/SolveNewtonRaphson()
    BuildBusAdmittanceMatrix()
    var/n = buses.len
    is_converged = FALSE
    iterations_executed = 0

    while(iterations_executed < max_iterations)
        iterations_executed++
        var/max_mismatch = 0.0

        // Evaluate power mismatches
        for(var/i = 1 to n)
            var/datum/electrical_bus/B = buses[i]
            if(B.bus_type == BUS_TYPE_SLACK)
                continue

            var/list/pq_calc = CalculateInjectedPower(i)
            var/p_spec = B.GetNetRealPowerPU()
            var/delta_p = p_spec - pq_calc[1]
            max_mismatch = max(max_mismatch, abs(delta_p))

            // Update voltage angle via decoupled gradient step
            var/diag_idx = (i - 1) * n + i
            var/b_ii = abs(y_bus_b[diag_idx])
            if(b_ii > 0.0001)
                B.voltage_angle_rad += (delta_p / b_ii) * 0.5

            if(B.bus_type == BUS_TYPE_PQ)
                var/q_spec = B.GetNetReactivePowerPU()
                var/delta_q = q_spec - pq_calc[2]
                max_mismatch = max(max_mismatch, abs(delta_q))
                // Update voltage magnitude
                B.voltage_magnitude_pu += (delta_q / b_ii) * 0.5
                B.voltage_magnitude_pu = max(0.6, min(1.4, B.voltage_magnitude_pu))

        if(max_mismatch < convergence_tolerance_pu)
            is_converged = TRUE
            break

    // Update branch power flows on all connected lines
    for(var/datum/transmission_line/L in lines)
        L.CalculateBranchPowerFlow()

    return is_converged

#endif // PLENUM_MICROGRID_POWER_FLOW_DM
