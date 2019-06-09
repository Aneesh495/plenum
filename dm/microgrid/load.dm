// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: ZIP Load Modeling & Induction Motor Inrush Dynamics
// Language: Dream Maker (DM)

#ifndef PLENUM_MICROGRID_LOAD_DM
#define PLENUM_MICROGRID_LOAD_DM

#include "bus.dm"

/datum/electrical_load
    var/load_id = "LOAD-01"
    var/datum/electrical_bus/connected_bus = null
    
    // Nominal Ratings at 1.0 pu Voltage
    var/nominal_p_mw = 1.5
    var/nominal_q_mvar = 0.5
    
    // Polynomial ZIP Coefficients (Sum of coefficients = 1.0)
    var/coeff_z = 0.30                   // Constant Impedance (P ~ V^2)
    var/coeff_i = 0.30                   // Constant Current (P ~ V)
    var/coeff_p = 0.40                   // Constant Power (P ~ const)

    var/coeff_q_z = 0.40
    var/coeff_q_i = 0.30
    var/coeff_q_p = 0.30

    // Dynamic Induction Motor Inrush Parameters
    var/is_induction_motor = FALSE
    var/motor_state = 1                  // 0=Stopped, 1=Running, 2=Starting
    var/motor_slip = 0.03                // Normal operating slip ~ 3%
    var/inrush_multiplier = 6.0          // Inrush current multiplier at start
    var/startup_time_constant_s = 1.5    // Acceleration time to reach nominal speed
    var/starting_elapsed_s = 0.0

    // Protection & Shedding
    var/is_shed = FALSE
    var/shed_priority = 1                // 1=Lowest (shed first), 5=Critical (shed last)

/datum/electrical_load/New(id, datum/electrical_bus/bus, mw = 1.5, mvar = 0.5)
    ..()
    load_id = id
    connected_bus = bus
    nominal_p_mw = mw
    nominal_q_mvar = mvar
    if(connected_bus)
        connected_bus.connected_loads += src

/datum/electrical_load/proc/CalculateVoltageDependentPower()
    if(is_shed || !connected_bus)
        return list(0.0, 0.0)

    var/v_pu = connected_bus.voltage_magnitude_pu
    var/v2 = v_pu * v_pu

    // Standard IEEE ZIP Load Formulation:
    // P = P0 * [ a1 * (V/V0)^2 + a2 * (V/V0) + a3 ]
    var/p_factor = (coeff_z * v2) + (coeff_i * v_pu) + coeff_p
    var/q_factor = (coeff_q_z * v2) + (coeff_q_i * v_pu) + coeff_q_p

    var/actual_p = nominal_p_mw * p_factor
    var/actual_q = nominal_q_mvar * q_factor

    // Handle Induction Motor Starting Transient
    if(is_induction_motor && motor_state == 2)
        // Decaying inrush envelope
        var/decay = exp(-starting_elapsed_s / startup_time_constant_s)
        var/inrush_factor = 1.0 + ((inrush_multiplier - 1.0) * decay)
        actual_p *= (inrush_factor * 0.5)
        actual_q *= inrush_factor // High reactive current during locked-rotor starting

    return list(actual_p, actual_q)

/datum/electrical_load/proc/ProcessTick(delta_time_seconds)
    if(is_shed)
        return

    if(is_induction_motor && motor_state == 2)
        starting_elapsed_s += delta_time_seconds
        if(starting_elapsed_s >= startup_time_constant_s * 3.0)
            motor_state = 1 // Acceleration complete, steady running
            starting_elapsed_s = 0.0

    var/list/pq = CalculateVoltageDependentPower()
    if(connected_bus)
        connected_bus.p_load_mw = pq[1]
        connected_bus.q_load_mvar = pq[2]

/datum/electrical_load/proc/StartMotor()
    if(!is_induction_motor) return
    motor_state = 2
    starting_elapsed_s = 0.0

#endif // PLENUM_MICROGRID_LOAD_DM
