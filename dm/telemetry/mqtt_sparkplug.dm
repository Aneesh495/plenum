// MQTT Sparkplug B Edge-of-Network (EoN) Node & Metric Payload Encoder
//
// Implements Eclipse Sparkplug B industrial IoT (IIoT) payload specification.
// Formulates topic namespaces: spBv1.0/group_id/message_type/edge_node_id/device_id,
// standard message types (NBIRTH, NDATA, DBIRTH, DDATA, NDEATH with Last Will and
// Testament LWT), metric aliases, sequence numbers (0 to 255 wrapping), and
// Report-by-Exception (RBE) data compression over lightweight MQTT brokers.

/datum/telemetry/sparkplug_eon
    var/tag = "SPARKPLUG-EON-NODE"
    var/group_id = "PLANT_SOUTH"
    var/edge_node_id = "TURBINE_BAY_01"
    var/device_id = "GAS_TURBINE_01"

    // Sparkplug Sequence Number: 0 to 255 wrapping integer
    var/seq_counter = 0

    // Metric Registry: map of metric_name -> value
    var/list/metric_names = list(
        "Combustor/TIT",
        "Turbine/PowerMW",
        "Compressor/DischargePress",
        "Vibration/Bearing1RMS",
        "Breaker/Status"
    )
    var/list/metric_types = list("FLOAT", "FLOAT", "FLOAT", "FLOAT", "BOOLEAN")
    var/list/current_metric_values = list(1693.2, 241.5, 18.75, 1.45, 1)
    var/list/last_published_values = list(-999.0, -999.0, -999.0, -999.0, -1)

/datum/telemetry/sparkplug_eon/New()
    ..()
    seq_counter = 0

// Increment and wrap 8-bit Sparkplug sequence number
/datum/telemetry/sparkplug_eon/proc/next_seq()
    var/s = seq_counter
    seq_counter = (seq_counter + 1) % 256
    return s

// Build MQTT topic string for Sparkplug B message:
// spBv1.0 / group_id / message_type / edge_node_id [/ device_id]
/datum/telemetry/sparkplug_eon/proc/build_topic(message_type, is_device_msg = 1)
    if(is_device_msg)
        return "spBv1.0/[group_id]/[message_type]/[edge_node_id]/[device_id]"
    else
        return "spBv1.0/[group_id]/[message_type]/[edge_node_id]"

// Generate DBIRTH (Device Birth) Payload: publishes all metrics and initializes aliases
/datum/telemetry/sparkplug_eon/proc/encode_dbirth(timestamp_ms)
    var/list/metrics_payload = list()

    for(var/i = 1 to metric_names.len)
        var/list/metric_obj = list(
            "name" = metric_names[i],
            "alias" = i,
            "datatype" = metric_types[i],
            "value" = current_metric_values[i],
            "timestamp" = timestamp_ms
        )
        metrics_payload.Add(metric_obj)
        last_published_values[i] = current_metric_values[i]

    var/list/payload = list(
        "timestamp" = timestamp_ms,
        "seq" = next_seq(),
        "metrics" = metrics_payload
    )
    return list("topic" = build_topic("DBIRTH", 1), "payload" = payload)

// Generate DDATA (Device Data) Payload: Report-by-Exception (RBE)
// Publishes only metrics that have changed since previous publication
/datum/telemetry/sparkplug_eon/proc/encode_ddata(timestamp_ms)
    var/list/changed_metrics = list()

    for(var/i = 1 to metric_names.len)
        var/curr_v = current_metric_values[i]
        var/last_v = last_published_values[i]

        var/has_changed = 0
        if(metric_types[i] == "BOOLEAN")
            has_changed = (curr_v != last_v)
        else
            // Analog deadband ~ 0.2%
            has_changed = (abs(curr_v - last_v) > 0.05)

        if(has_changed)
            changed_metrics.Add(list(
                "alias" = i, // Use compact numeric alias in DDATA
                "value" = curr_v,
                "timestamp" = timestamp_ms
            ))
            last_published_values[i] = curr_v

    if(changed_metrics.len == 0)
        return null // No changes: suppress publication (RBE compression)

    var/list/payload = list(
        "timestamp" = timestamp_ms,
        "seq" = next_seq(),
        "metrics" = changed_metrics
    )
    return list("topic" = build_topic("DDATA", 1), "payload" = payload)

// Update metric value in registry
/datum/telemetry/sparkplug_eon/proc/set_metric_value(metric_idx, new_val)
    if(metric_idx >= 1 && metric_idx <= current_metric_values.len)
        current_metric_values[metric_idx] = new_val
