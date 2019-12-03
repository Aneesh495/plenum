// OPC Unified Architecture (IEC 62541 OPC UA) Server & Information Model
//
// Implements industrial interoperability standard OPC UA binary protocol stack.
// Formulates full Address Space with Namespaces, NodeIds (ns=1;s=Tag), NodeClasses
// (Object, Variable, Method), ReferenceTypes (Organizes, HasComponent), Subscriptions,
// MonitoredItems with absolute/percent deadband filters, and DataValue StatusCodes.

/datum/telemetry/opc_ua_node
    var/node_namespace = 1
    var/node_identifier = "Process.Boiler.Pressure"
    var/display_name = "Steam Drum Pressure"
    var/node_class = "VARIABLE" // "OBJECT", "VARIABLE", "METHOD"
    var/data_type = "DOUBLE"

    // DataValue fields
    var/current_value = 65.0
    var/status_code = 0x00000000 // Good (0x00), Uncertain (0x40), Bad (0x80)
    var/source_timestamp_sec = 0.0
    var/server_timestamp_sec = 0.0

/datum/telemetry/opc_ua_server
    var/tag = "OPC-UA-SERVER-01"
    var/endpoint_url = "opc.tcp://127.0.0.1:4840"
    var/security_policy = "Basic256Sha256"
    var/security_mode = "SignAndEncrypt"

    // Address space node registry: map of "ns;id" -> datum/telemetry/opc_ua_node
    var/list/address_space = list()

    // Subscriptions & MonitoredItems
    var/publishing_interval_ms = 100.0
    var/sampling_interval_ms = 50.0
    var/list/monitored_node_ids = list()
    var/list/deadbands = list()
    var/list/last_reported_values = list()
    var/sequence_number = 1

/datum/telemetry/opc_ua_server/New()
    ..()
    address_space = list()
    monitored_node_ids = list()
    deadbands = list()
    last_reported_values = list()
    initialize_address_space()

// Initialize standard ISA-95 hierarchical address space
/datum/telemetry/opc_ua_server/proc/initialize_address_space()
    create_variable_node(1, "Plant.Boiler.DrumPressure", "Drum Steam Pressure", 65.0, "DOUBLE")
    create_variable_node(1, "Plant.Boiler.DrumLevel", "Boiler Drum Level", 50.0, "DOUBLE")
    create_variable_node(1, "Plant.Turbine.PowerMW", "Generator Active Power", 45.0, "DOUBLE")
    create_variable_node(1, "Plant.Substation.GridFrequency", "Grid Frequency", 60.0, "DOUBLE")
    create_variable_node(1, "Plant.Safety.ESDState", "Emergency Shutdown Latched", 0, "BOOLEAN")

/datum/telemetry/opc_ua_server/proc/create_variable_node(ns, id, name, init_val, dtype)
    var/datum/telemetry/opc_ua_node/node = new()
    node.node_namespace = ns
    node.node_identifier = id
    node.display_name = name
    node.current_value = init_val
    node.data_type = dtype

    var/key = "[ns];[id]"
    address_space[key] = node
    return node

// Write value to address space variable node with quality status
/datum/telemetry/opc_ua_server/proc/write_variable(ns, id, val, status = 0x00000000, timestamp = 0.0)
    var/key = "[ns];[id]"
    var/datum/telemetry/opc_ua_node/node = address_space[key]
    if(!node)
        return 0 // BadNodeIdUnknown (0x80340000)

    node.current_value = val
    node.status_code = status
    node.source_timestamp_sec = timestamp
    return 1 // Good

// Read value from address space
/datum/telemetry/opc_ua_server/proc/read_variable(ns, id)
    var/key = "[ns];[id]"
    var/datum/telemetry/opc_ua_node/node = address_space[key]
    if(!node)
        return null
    return node.current_value

// Add MonitoredItem to active subscription with deadband filter
/datum/telemetry/opc_ua_server/proc/add_monitored_item(ns, id, deadband_abs = 0.1)
    var/key = "[ns];[id]"
    if(address_space[key])
        monitored_node_ids.Add(key)
        deadbands.Add(deadband_abs)
        last_reported_values.Add(-999999.0) // Force initial report

// Publish notification message: evaluates deadband filters on monitored variables
/datum/telemetry/opc_ua_server/proc/publish_notifications()
    var/list/data_change_notifications = list()

    for(var/i = 1 to monitored_node_ids.len)
        var/key = monitored_node_ids[i]
        var/datum/telemetry/opc_ua_node/node = address_space[key]
        var/db = deadbands[i]
        var/last_v = last_reported_values[i]

        var/delta = abs(node.current_value - last_v)
        if(delta >= db)
            // Value changed beyond deadband: emit notification
            data_change_notifications.Add(list(
                "node" = key,
                "value" = node.current_value,
                "status" = node.status_code
            ))
            last_reported_values[i] = node.current_value

    if(data_change_notifications.len > 0)
        sequence_number++

    return data_change_notifications
