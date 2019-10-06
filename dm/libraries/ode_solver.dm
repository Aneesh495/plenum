// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Numerical Ordinary Differential Equation (ODE) Solvers (RK4, RKF45)
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_ODE_SOLVER_DM
#define PLENUM_LIBRARIES_ODE_SOLVER_DM

#include "../core/datum.dm"

/datum/ode_system
    var/state_dimension = 1

/datum/ode_system/proc/ComputeDerivatives(t, list/y)
    // Virtual hook: returns list of dy/dt values
    var/list/dydt = list()
    dydt.len = y.len
    for(var/i = 1 to y.len)
        dydt[i] = 0.0
    return dydt

/datum/ode_solver_rk4
    var/step_size_h = 0.01

/datum/ode_solver_rk4/New(h = 0.01)
    ..()
    step_size_h = h

/datum/ode_solver_rk4/proc/Step(datum/ode_system/sys, t, list/y)
    // 4th-Order Classical Runge-Kutta
    var/n = y.len
    var/h = step_size_h
    var/h_half = h * 0.5

    // k1 = f(t, y)
    var/list/k1 = sys.ComputeDerivatives(t, y)

    // k2 = f(t + h/2, y + (h/2)*k1)
    var/list/y_temp = list()
    y_temp.len = n
    for(var/i = 1 to n)
        y_temp[i] = y[i] + (h_half * k1[i])
    var/list/k2 = sys.ComputeDerivatives(t + h_half, y_temp)

    // k3 = f(t + h/2, y + (h/2)*k2)
    for(var/i = 1 to n)
        y_temp[i] = y[i] + (h_half * k2[i])
    var/list/k3 = sys.ComputeDerivatives(t + h_half, y_temp)

    // k4 = f(t + h, y + h*k3)
    for(var/i = 1 to n)
        y_temp[i] = y[i] + (h * k3[i])
    var/list/k4 = sys.ComputeDerivatives(t + h, y_temp)

    // y_{n+1} = y_n + (h / 6) * (k1 + 2*k2 + 2*k3 + k4)
    var/list/y_next = list()
    y_next.len = n
    for(var/i = 1 to n)
        y_next[i] = y[i] + (h / 6.0) * (k1[i] + (2.0 * k2[i]) + (2.0 * k3[i]) + k4[i])

    return y_next

/datum/ode_solver_rkf45
    var/tolerance = 1.0e-6
    var/min_step = 1.0e-5
    var/max_step = 0.5
    var/current_step = 0.01

/datum/ode_solver_rkf45/proc/AdaptiveStep(datum/ode_system/sys, t, list/y)
    // Runge-Kutta-Fehlberg Embedded 4th/5th Order
    var/n = y.len
    var/h = current_step

    var/list/k1 = sys.ComputeDerivatives(t, y)
    
    var/list/y_work = list()
    y_work.len = n
    for(var/i = 1 to n)
        y_work[i] = y[i] + h * (1.0 / 4.0) * k1[i]
    var/list/k2 = sys.ComputeDerivatives(t + h * (1.0 / 4.0), y_work)

    for(var/i = 1 to n)
        y_work[i] = y[i] + h * ((3.0 / 32.0) * k1[i] + (9.0 / 32.0) * k2[i])
    var/list/k3 = sys.ComputeDerivatives(t + h * (3.0 / 8.0), y_work)

    for(var/i = 1 to n)
        y_work[i] = y[i] + h * ((1932.0 / 2197.0) * k1[i] - (7200.0 / 2197.0) * k2[i] + (7296.0 / 2197.0) * k3[i])
    var/list/k4 = sys.ComputeDerivatives(t + h * (12.0 / 13.0), y_work)

    for(var/i = 1 to n)
        y_work[i] = y[i] + h * ((439.0 / 216.0) * k1[i] - 8.0 * k2[i] + (3680.0 / 513.0) * k3[i] - (845.0 / 4104.0) * k4[i])
    var/list/k5 = sys.ComputeDerivatives(t + h, y_work)

    for(var/i = 1 to n)
        y_work[i] = y[i] + h * ((-8.0 / 27.0) * k1[i] + 2.0 * k2[i] - (3544.0 / 2565.0) * k3[i] + (1859.0 / 4104.0) * k4[i] - (11.0 / 40.0) * k5[i])
    var/list/k6 = sys.ComputeDerivatives(t + h * 0.5, y_work)

    // 4th order solution y_4
    var/list/y4 = list()
    y4.len = n
    // 5th order solution y_5
    var/list/y5 = list()
    y5.len = n
    var/max_err = 0.0

    for(var/i = 1 to n)
        y4[i] = y[i] + h * ((25.0 / 216.0) * k1[i] + (1408.0 / 2565.0) * k3[i] + (2197.0 / 4104.0) * k4[i] - (1.0 / 5.0) * k5[i])
        y5[i] = y[i] + h * ((16.0 / 135.0) * k1[i] + (6656.0 / 12825.0) * k3[i] + (28561.0 / 56430.0) * k4[i] - (9.0 / 50.0) * k5[i] + (2.0 / 55.0) * k6[i])
        var/err = abs(y5[i] - y4[i])
        if(err > max_err)
            max_err = err

    // Optimal step size adjustment factor
    var/scale = 0.84 * ((tolerance / (max_err + 0.0000000001)) ** 0.25)
    scale = max(0.2, min(4.0, scale))
    current_step = max(min_step, min(max_step, h * scale))

    return y5

#endif // PLENUM_LIBRARIES_ODE_SOLVER_DM
