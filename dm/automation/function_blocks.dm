// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: IEC 61131-3 Function Blocks (Timers, Counters, Filters, Latches)
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_FUNCTION_BLOCKS_DM
#define PLENUM_AUTOMATION_FUNCTION_BLOCKS_DM

#include "plc.dm"

/datum/iec_function_block
    var/block_id = "FB-01"

/datum/iec_function_block/proc/ExecuteBlock(datum/plc_controller/plc, delta_time_seconds)
    return

// ----------------------------------------------------------------------------
// IEC 61131-3 Timers: TON, TOF, TP
// ----------------------------------------------------------------------------

/datum/iec_function_block/timer_on_delay // TON
    var/input_in = FALSE
    var/preset_time_s = 5.0              // PT
    var/elapsed_time_s = 0.0             // ET
    var/output_q = FALSE                 // Q

/datum/iec_function_block/timer_on_delay/ExecuteBlock(datum/plc_controller/plc, delta_time_seconds)
    if(input_in)
        elapsed_time_s = min(preset_time_s, elapsed_time_s + delta_time_seconds)
        output_q = (elapsed_time_s >= preset_time_s)
    else
        elapsed_time_s = 0.0
        output_q = FALSE

/datum/iec_function_block/timer_off_delay // TOF
    var/input_in = FALSE
    var/preset_time_s = 5.0
    var/elapsed_time_s = 0.0
    var/output_q = FALSE

/datum/iec_function_block/timer_off_delay/ExecuteBlock(datum/plc_controller/plc, delta_time_seconds)
    if(input_in)
        output_q = TRUE
        elapsed_time_s = 0.0
    else if(output_q)
        elapsed_time_s += delta_time_seconds
        if(elapsed_time_s >= preset_time_s)
            output_q = FALSE

/datum/iec_function_block/pulse_timer // TP
    var/input_in = FALSE
    var/preset_time_s = 2.0
    var/elapsed_time_s = 0.0
    var/output_q = FALSE
    var/last_in = FALSE

/datum/iec_function_block/pulse_timer/ExecuteBlock(datum/plc_controller/plc, delta_time_seconds)
    // Trigger on rising edge of IN
    if(input_in && !last_in && !output_q)
        output_q = TRUE
        elapsed_time_s = 0.0

    if(output_q)
        elapsed_time_s += delta_time_seconds
        if(elapsed_time_s >= preset_time_s)
            output_q = FALSE

    last_in = input_in

// ----------------------------------------------------------------------------
// IEC 61131-3 Counters: CTU (Count Up)
// ----------------------------------------------------------------------------

/datum/iec_function_block/counter_up // CTU
    var/count_up_cu = FALSE
    var/reset_r = FALSE
    var/preset_value_pv = 10
    var/current_value_cv = 0
    var/output_q = FALSE
    var/last_cu = FALSE

/datum/iec_function_block/counter_up/ExecuteBlock(datum/plc_controller/plc, delta_time_seconds)
    if(reset_r)
        current_value_cv = 0
        output_q = FALSE
    else if(count_up_cu && !last_cu) // Rising edge trigger
        if(current_value_cv < 32767)
            current_value_cv++
        output_q = (current_value_cv >= preset_value_pv)

    last_cu = count_up_cu

// ----------------------------------------------------------------------------
// Bistable Latches: SR (Set-Dominant) & RS (Reset-Dominant)
// ----------------------------------------------------------------------------

/datum/iec_function_block/bistable_sr
    var/set_s1 = FALSE
    var/reset_r = FALSE
    var/state_q1 = FALSE

/datum/iec_function_block/bistable_sr/ExecuteBlock(datum/plc_controller/plc, delta_time_seconds)
    // S1 takes precedence over R
    state_q1 = set_s1 || (!reset_r && state_q1)

/datum/iec_function_block/bistable_rs
    var/set_s = FALSE
    var/reset_r1 = FALSE
    var/state_q1 = FALSE

/datum/iec_function_block/bistable_rs/ExecuteBlock(datum/plc_controller/plc, delta_time_seconds)
    // R1 takes precedence over S
    state_q1 = !reset_r1 && (set_s || state_q1)

// ----------------------------------------------------------------------------
// Signal Conditioning: First Order Lag Filter (Low-Pass Filter)
// ----------------------------------------------------------------------------

/datum/iec_function_block/first_order_lag
    var/input_x = 0.0
    var/time_constant_tau_s = 1.0        // Filter time constant tau
    var/gain_k = 1.0
    var/output_y = 0.0

/datum/iec_function_block/first_order_lag/ExecuteBlock(datum/plc_controller/plc, delta_time_seconds)
    // Discretized Euler low-pass: y[k] = y[k-1] + (dt / (tau + dt)) * (K * x[k] - y[k-1])
    var/alpha = delta_time_seconds / (time_constant_tau_s + delta_time_seconds)
    output_y += alpha * ((gain_k * input_x) - output_y)

#endif // PLENUM_AUTOMATION_FUNCTION_BLOCKS_DM
