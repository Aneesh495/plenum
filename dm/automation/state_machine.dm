// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: ISA-88 / PackML Hierarchical Finite State Machine
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_STATE_MACHINE_DM
#define PLENUM_AUTOMATION_STATE_MACHINE_DM

#include "plc.dm"

// ISA-88 / PackML Standard Operating States
#define STATE_CLEARED          0
#define STATE_STOPPED          1
#define STATE_STARTING         2
#define STATE_IDLE             3
#define STATE_SUSPENDED        4
#define STATE_EXECUTE          5
#define STATE_STOPPING         6
#define STATE_ABORTING         7
#define STATE_ABORTED          8
#define STATE_HOLDING          9
#define STATE_HELD             10
#define STATE_UNHOLDING        11
#define STATE_COMPLETING       12
#define STATE_COMPLETE         13
#define STATE_RESETTING        14

/datum/fsm_transition
    var/from_state = STATE_IDLE
    var/to_state = STATE_EXECUTE
    var/trigger_signal = "cmd_start"
    var/guard_proc_name = "" // Optional predicate proc

/datum/fsm_transition/New(from_s, to_s, trigger, guard = "")
    ..()
    from_state = from_s
    to_state = to_s
    trigger_signal = trigger
    guard_proc_name = guard

/datum/packml_state_machine
    var/fsm_id = "UNIT-FSM-01"
    var/current_state = STATE_STOPPED
    var/previous_state = STATE_STOPPED
    var/state_dwell_time_seconds = 0.0
    var/state_timeout_limit_seconds = 60.0
    var/list/transition_table = list()
    var/list/state_history = list()

/datum/packml_state_machine/New(id = "UNIT-FSM-01")
    ..()
    fsm_id = id
    SetupStandardTransitions()

/datum/packml_state_machine/proc/SetupStandardTransitions()
    transition_table += new /datum/fsm_transition(STATE_STOPPED, STATE_RESETTING, "cmd_reset")
    transition_table += new /datum/fsm_transition(STATE_RESETTING, STATE_IDLE, "reset_complete")
    transition_table += new /datum/fsm_transition(STATE_IDLE, STATE_STARTING, "cmd_start")
    transition_table += new /datum/fsm_transition(STATE_STARTING, STATE_EXECUTE, "startup_complete")
    transition_table += new /datum/fsm_transition(STATE_EXECUTE, STATE_HOLDING, "cmd_hold")
    transition_table += new /datum/fsm_transition(STATE_HOLDING, STATE_HELD, "hold_complete")
    transition_table += new /datum/fsm_transition(STATE_HELD, STATE_UNHOLDING, "cmd_unhold")
    transition_table += new /datum/fsm_transition(STATE_UNHOLDING, STATE_EXECUTE, "unhold_complete")
    transition_table += new /datum/fsm_transition(STATE_EXECUTE, STATE_COMPLETING, "batch_finished")
    transition_table += new /datum/fsm_transition(STATE_COMPLETING, STATE_COMPLETE, "completion_complete")
    transition_table += new /datum/fsm_transition(STATE_COMPLETE, STATE_RESETTING, "cmd_reset")
    
    // Universal Abort Transitions from any active state
    transition_table += new /datum/fsm_transition(STATE_EXECUTE, STATE_ABORTING, "cmd_abort")
    transition_table += new /datum/fsm_transition(STATE_STARTING, STATE_ABORTING, "cmd_abort")
    transition_table += new /datum/fsm_transition(STATE_HOLDING, STATE_ABORTING, "cmd_abort")
    transition_table += new /datum/fsm_transition(STATE_ABORTING, STATE_ABORTED, "abort_complete")
    transition_table += new /datum/fsm_transition(STATE_ABORTED, STATE_CLEARED, "cmd_clear")
    transition_table += new /datum/fsm_transition(STATE_CLEARED, STATE_STOPPED, "cmd_stop")

/datum/packml_state_machine/proc/DispatchEvent(signal_name)
    for(var/datum/fsm_transition/t in transition_table)
        if(t.from_state == current_state && t.trigger_signal == signal_name)
            TransitionTo(t.to_state)
            return TRUE
    return FALSE

/datum/packml_state_machine/proc/TransitionTo(new_state)
    if(new_state == current_state)
        return
    
    previous_state = current_state
    current_state = new_state
    state_dwell_time_seconds = 0.0

    state_history += list("from" = previous_state, "to" = current_state, "time" = world.time)
    if(state_history.len > 50)
        state_history.Cut(1, 2) // Retain rolling ring buffer

/datum/packml_state_machine/proc/ProcessTick(delta_time_seconds)
    state_dwell_time_seconds += delta_time_seconds
    
    // Automatic SC (State Complete) transitions for acting states
    switch(current_state)
        if(STATE_RESETTING)
            if(state_dwell_time_seconds >= 2.0)
                DispatchEvent("reset_complete")
        if(STATE_STARTING)
            if(state_dwell_time_seconds >= 3.0)
                DispatchEvent("startup_complete")
        if(STATE_HOLDING)
            if(state_dwell_time_seconds >= 1.5)
                DispatchEvent("hold_complete")
        if(STATE_UNHOLDING)
            if(state_dwell_time_seconds >= 1.5)
                DispatchEvent("unhold_complete")
        if(STATE_COMPLETING)
            if(state_dwell_time_seconds >= 2.0)
                DispatchEvent("completion_complete")
        if(STATE_ABORTING)
            if(state_dwell_time_seconds >= 0.5)
                DispatchEvent("abort_complete")

#endif // PLENUM_AUTOMATION_STATE_MACHINE_DM
