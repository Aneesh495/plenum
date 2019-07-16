// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Cyclic PLC Execution Engine & I/O Image Table
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_PLC_DM
#define PLENUM_AUTOMATION_PLC_DM

#include "../defines.dm"
#include "../core/datum.dm"

/datum/plc_controller
    var/plc_id = "PLC-UNIT-01"
    var/operating_mode = PLC_STATE_RUNNING // 0=Stop, 1=Run, 2=Fault
    var/scan_time_ms = 10.0               // Target scan cycle duration
    var/last_scan_duration_ms = 8.5
    var/max_scan_time_watchdog_ms = 50.0  // Hardware watchdog limit
    var/scan_cycle_count = 0
    var/is_redundant_pair = TRUE
    var/is_primary_cpu = TRUE
    
    // I/O Memory Image Tables (IEC 61131-3 addressing standard)
    var/list/discrete_inputs = null       // %IX bit array
    var/list/discrete_outputs = null      // %QX bit array
    var/list/memory_flags = null          // %MX internal bit memory
    var/list/analog_inputs = null         // %IW integer/float registers
    var/list/analog_outputs = null        // %QW integer/float registers
    var/list/holding_registers = null     // %MW 16-bit word memory

    // Registered execution routines
    var/list/ladder_rungs = list()
    var/list/function_blocks = list()
    var/list/pid_loops = list()

/datum/plc_controller/New(id = "PLC-UNIT-01")
    ..()
    plc_id = id
    
    // Initialize 256 bits of discrete memory
    discrete_inputs = list()
    discrete_inputs.len = 256
    discrete_outputs = list()
    discrete_outputs.len = 256
    memory_flags = list()
    memory_flags.len = 512

    // Initialize 128 analog channels
    analog_inputs = list()
    analog_inputs.len = 128
    analog_outputs = list()
    analog_outputs.len = 128
    holding_registers = list()
    holding_registers.len = 256

    for(var/i = 1 to 256)
        discrete_inputs[i] = FALSE
        discrete_outputs[i] = FALSE
        holding_registers[i] = 0
    for(var/i = 1 to 512)
        memory_flags[i] = FALSE
    for(var/i = 1 to 128)
        analog_inputs[i] = 0.0
        analog_outputs[i] = 0.0

/datum/plc_controller/proc/SetDiscreteInput(channel, state)
    if(channel >= 1 && channel <= discrete_inputs.len)
        discrete_inputs[channel] = state ? TRUE : FALSE

/datum/plc_controller/proc/GetDiscreteOutput(channel)
    if(channel >= 1 && channel <= discrete_outputs.len)
        return discrete_outputs[channel]
    return FALSE

/datum/plc_controller/proc/SetAnalogInput(channel, value)
    if(channel >= 1 && channel <= analog_inputs.len)
        analog_inputs[channel] = value

/datum/plc_controller/proc/GetAnalogOutput(channel)
    if(channel >= 1 && channel <= analog_outputs.len)
        return analog_outputs[channel]
    return 0.0

/datum/plc_controller/proc/ExecuteCyclicScan(delta_time_seconds)
    if(operating_mode != PLC_STATE_RUNNING)
        return
    
    scan_cycle_count++
    
    // Step 1: Execute IEC 61131-3 Ladder Logic Rungs
    for(var/datum/ladder_rung/rung in ladder_rungs)
        rung.EvaluateRung(src)

    // Step 2: Execute Function Blocks (Timers, Counters, Latches)
    for(var/datum/iec_function_block/fb in function_blocks)
        fb.ExecuteBlock(src, delta_time_seconds)

    // Step 3: Execute PID Closed-Loop Regulators
    for(var/datum/pid_controller/pid in pid_loops)
        pid.ComputeStep(delta_time_seconds)

    // Step 4: Watchdog Scan Verification
    if(last_scan_duration_ms > max_scan_time_watchdog_ms)
        operating_mode = PLC_STATE_FAULT
        if(event_hub)
            event_hub.SendSignal(SIG_ALARM_STATE_CHANGED, list("plc" = plc_id, "error" = "WATCHDOG_TIMEOUT"))

#endif // PLENUM_AUTOMATION_PLC_DM
