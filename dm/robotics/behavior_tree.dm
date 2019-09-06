// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Autonomous Robotics Behavior Trees & Blackboard
// Language: Dream Maker (DM)

#ifndef PLENUM_ROBOTICS_BEHAVIOR_TREE_DM
#define PLENUM_ROBOTICS_BEHAVIOR_TREE_DM

#include "../core/datum.dm"

#define BT_STATUS_SUCCESS     1
#define BT_STATUS_FAILURE     2
#define BT_STATUS_RUNNING     3

/datum/bt_blackboard
    var/list/data_store = list()

/datum/bt_blackboard/proc/Set(key, value)
    data_store[key] = value

/datum/bt_blackboard/proc/Get(key, default_val = null)
    if(data_store[key] != null)
        return data_store[key]
    return default_val

/datum/bt_node
    var/node_name = "BT_Node"

/datum/bt_node/proc/Tick(mob/plenum_mob/agent, datum/bt_blackboard/blackboard, delta_time_seconds)
    return BT_STATUS_SUCCESS

// ----------------------------------------------------------------------------
// Composite Nodes: Selector & Sequence
// ----------------------------------------------------------------------------

/datum/bt_node/selector
    var/list/children = list()

/datum/bt_node/selector/Tick(mob/plenum_mob/agent, datum/bt_blackboard/blackboard, delta_time_seconds)
    for(var/datum/bt_node/child in children)
        var/status = child.Tick(agent, blackboard, delta_time_seconds)
        if(status != BT_STATUS_FAILURE)
            return status
    return BT_STATUS_FAILURE

/datum/bt_node/sequence
    var/list/children = list()

/datum/bt_node/sequence/Tick(mob/plenum_mob/agent, datum/bt_blackboard/blackboard, delta_time_seconds)
    for(var/datum/bt_node/child in children)
        var/status = child.Tick(agent, blackboard, delta_time_seconds)
        if(status != BT_STATUS_SUCCESS)
            return status
    return BT_STATUS_SUCCESS

// ----------------------------------------------------------------------------
// Decorator Nodes: Inverter
// ----------------------------------------------------------------------------

/datum/bt_node/inverter
    var/datum/bt_node/child = null

/datum/bt_node/inverter/Tick(mob/plenum_mob/agent, datum/bt_blackboard/blackboard, delta_time_seconds)
    if(!child) return BT_STATUS_FAILURE
    var/status = child.Tick(agent, blackboard, delta_time_seconds)
    if(status == BT_STATUS_SUCCESS)
        return BT_STATUS_FAILURE
    else if(status == BT_STATUS_FAILURE)
        return BT_STATUS_SUCCESS
    return status

// ----------------------------------------------------------------------------
// Leaf Task Nodes
// ----------------------------------------------------------------------------

/datum/bt_node/condition/battery_low
    var/threshold_joules = 100000.0 // 20% battery

/datum/bt_node/condition/battery_low/Tick(mob/plenum_mob/agent, datum/bt_blackboard/blackboard, delta_time_seconds)
    if(agent && agent.energy_storage_joules <= threshold_joules)
        return BT_STATUS_SUCCESS
    return BT_STATUS_FAILURE

/datum/bt_node/action/navigate_to_charger

/datum/bt_node/action/navigate_to_charger/Tick(mob/plenum_mob/agent, datum/bt_blackboard/blackboard, delta_time_seconds)
    if(!agent) return BT_STATUS_FAILURE
    agent.agent_status = ROBOT_STATE_CHARGING
    // Charge battery
    agent.energy_storage_joules = min(agent.max_energy_joules, agent.energy_storage_joules + (15000.0 * delta_time_seconds))
    if(agent.energy_storage_joules >= agent.max_energy_joules * 0.95)
        agent.agent_status = ROBOT_STATE_IDLE
        return BT_STATUS_SUCCESS
    return BT_STATUS_RUNNING

/datum/behavior_tree
    var/datum/bt_node/root_node = null
    var/datum/bt_blackboard/blackboard = null

/datum/behavior_tree/New()
    ..()
    blackboard = new /datum/bt_blackboard()

/datum/behavior_tree/proc/Evaluate(mob/plenum_mob/agent, delta_time_seconds)
    if(!root_node)
        return BT_STATUS_FAILURE
    return root_node.Tick(agent, blackboard, delta_time_seconds)

#endif // PLENUM_ROBOTICS_BEHAVIOR_TREE_DM
