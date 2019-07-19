// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: IEC 61131-3 Ladder Logic Rungs, Contacts & Coils
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_LADDER_LOGIC_DM
#define PLENUM_AUTOMATION_LADDER_LOGIC_DM

#include "plc.dm"

#define CONTACT_NORMALLY_OPEN       1 // XIC
#define CONTACT_NORMALLY_CLOSED     2 // XIO
#define CONTACT_RISING_EDGE         3 // Positive transition
#define CONTACT_FALLING_EDGE        4 // Negative transition

#define COIL_NORMAL                 1 // OTE
#define COIL_SET_LATCH              2 // OTL
#define COIL_RESET_UNLATCH          3 // OTU

/datum/ladder_contact
    var/contact_type = CONTACT_NORMALLY_OPEN
    var/memory_table = "IX"             // "IX", "QX", or "MX"
    var/channel_index = 1
    var/last_state = FALSE

/datum/ladder_contact/New(type = CONTACT_NORMALLY_OPEN, table = "IX", idx = 1)
    ..()
    contact_type = type
    memory_table = table
    channel_index = idx

/datum/ladder_contact/proc/Evaluate(datum/plc_controller/plc)
    var/raw_state = FALSE
    if(memory_table == "IX")
        raw_state = plc.discrete_inputs[channel_index]
    else if(memory_table == "QX")
        raw_state = plc.discrete_outputs[channel_index]
    else if(memory_table == "MX")
        raw_state = plc.memory_flags[channel_index]

    var/result = FALSE
    switch(contact_type)
        if(CONTACT_NORMALLY_OPEN)
            result = raw_state
        if(CONTACT_NORMALLY_CLOSED)
            result = !raw_state
        if(CONTACT_RISING_EDGE)
            result = (raw_state && !last_state)
        if(CONTACT_FALLING_EDGE)
            result = (!raw_state && last_state)

    last_state = raw_state
    return result

/datum/ladder_coil
    var/coil_type = COIL_NORMAL
    var/memory_table = "QX"
    var/channel_index = 1

/datum/ladder_coil/New(type = COIL_NORMAL, table = "QX", idx = 1)
    ..()
    coil_type = type
    memory_table = table
    channel_index = idx

/datum/ladder_coil/proc/Execute(datum/plc_controller/plc, rung_power_flow)
    if(coil_type == COIL_NORMAL)
        if(memory_table == "QX")
            plc.discrete_outputs[channel_index] = rung_power_flow
        else if(memory_table == "MX")
            plc.memory_flags[channel_index] = rung_power_flow
    else if(coil_type == COIL_SET_LATCH)
        if(rung_power_flow)
            if(memory_table == "QX")
                plc.discrete_outputs[channel_index] = TRUE
            else if(memory_table == "MX")
                plc.memory_flags[channel_index] = TRUE
    else if(coil_type == COIL_RESET_UNLATCH)
        if(rung_power_flow)
            if(memory_table == "QX")
                plc.discrete_outputs[channel_index] = FALSE
            else if(memory_table == "MX")
                plc.memory_flags[channel_index] = FALSE

/datum/ladder_rung
    var/rung_id = 1
    var/list/series_contacts = list()
    var/list/parallel_branches = list()
    var/list/output_coils = list()

/datum/ladder_rung/proc/EvaluateRung(datum/plc_controller/plc)
    // Evaluate series contacts along the main rung rail: AND logic
    var/power_flow = TRUE
    for(var/datum/ladder_contact/c in series_contacts)
        if(!c.Evaluate(plc))
            power_flow = FALSE
            break

    // Evaluate parallel OR branches if main line is open
    if(!power_flow && parallel_branches.len > 0)
        for(var/datum/ladder_contact/pb in parallel_branches)
            if(pb.Evaluate(plc))
                power_flow = TRUE
                break

    // Actuate all destination coils with final power flow
    for(var/datum/ladder_coil/coil in output_coils)
        coil.Execute(plc, power_flow)

    return power_flow

#endif // PLENUM_AUTOMATION_LADDER_LOGIC_DM
