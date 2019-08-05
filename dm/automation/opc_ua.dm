// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: OPC UA Address Space Information Model & Subscriptions
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_OPC_UA_DM
#define PLENUM_AUTOMATION_OPC_UA_DM

#include "plc.dm"

#define OPCUA_STATUS_GOOD           0x00000000
#define OPCUA_STATUS_UNCERTAIN      0x40000000
#define OPCUA_STATUS_BAD            0x80000000

/datum/opcua_node
    var/node_namespace = 1
    var/node_identifier = "Plant.Unit1.Pressure"
    var/display_name = "Chamber Pressure"
    var/node_class = "Variable"         // "Variable", "Object", "Method"
    var/current_value = 0.0
    var/status_code = OPCUA_STATUS_GOOD
    var/source_timestamp = 0
    var/list/references = list()        // Forward/inverse relationship links

/datum/opcua_node/New(ns = 1, id = "", name = "", cls = "Variable")
    ..()
    node_namespace = ns
    node_identifier = id
    display_name = name
    node_class = cls
    source_timestamp = world.time

/datum/opcua_node/proc/WriteValue(new_val)
    current_value = new_val
    status_code = OPCUA_STATUS_GOOD
    source_timestamp = world.time

/datum/opcua_monitored_item
    var/item_id = 1
    var/datum/opcua_node/target_node = null
    var/sampling_interval_ms = 100.0
    var/deadband_absolute = 0.05
    var/last_notified_value = 0.0
    var/has_pending_notification = FALSE

/datum/opcua_monitored_item/New(id, datum/opcua_node/node, interval = 100.0, deadband = 0.05)
    ..()
    item_id = id
    target_node = node
    sampling_interval_ms = interval
    deadband_absolute = deadband
    if(target_node)
        last_notified_value = target_node.current_value

/datum/opcua_monitored_item/proc/CheckDataChange()
    if(!target_node)
        return FALSE
    
    var/diff = abs(target_node.current_value - last_notified_value)
    if(diff >= deadband_absolute)
        has_pending_notification = TRUE
        last_notified_value = target_node.current_value
        return TRUE
    return FALSE

/datum/opcua_server
    var/server_uri = "opc.tcp://plenum.internal:4840"
    var/list/address_space = list()     // NodeId string -> /datum/opcua_node
    var/list/monitored_items = list()

/datum/opcua_server/proc/RegisterNode(datum/opcua_node/node)
    if(!node) return
    var/key = "ns=[node.node_namespace];s=[node.node_identifier]"
    address_space[key] = node

/datum/opcua_server/proc/FindNode(ns, id)
    var/key = "ns=[ns];s=[id]"
    return address_space[key]

/datum/opcua_server/proc/PublishCycle()
    var/list/notifications = list()
    for(var/datum/opcua_monitored_item/item in monitored_items)
        if(item.CheckDataChange())
            notifications += list(
                "item_id" = item.item_id,
                "node" = item.target_node.node_identifier,
                "val" = item.target_node.current_value,
                "status" = item.target_node.status_code,
                "time" = item.target_node.source_timestamp
            )
            item.has_pending_notification = FALSE
    return notifications

#endif // PLENUM_AUTOMATION_OPC_UA_DM
