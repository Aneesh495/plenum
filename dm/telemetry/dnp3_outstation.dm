// Distributed Network Protocol (DNP3 / IEEE 1815) Outstation Stack
//
// Implements electric utility and water SCADA telemetry protocol (IEEE 1815-2012).
// Models Object Groups: Group 1 (Binary Inputs), Group 12 (Control Relay Output Block
// CROB with Select-Before-Operate SBO handshake), Group 30 (32-bit Analog Inputs),
// Class 0/1/2/3 polling classification, and unsolicted response event buffering.

/datum/telemetry/dnp3_outstation
    var/tag = "DNP3-OUTSTATION-RTU"
    var/outstation_address = 10
    var/master_address = 1

    // Data Points
    var/list/binary_inputs = list(1, 0, 0, 1, 0, 0, 1, 0) // Group 1
    var/list/analog_inputs = list(65.4, 50.2, 45.1, 60.02, 13.82) // Group 30 (Bar, %, MW, Hz, kV)
    var/list/analog_deadbands = list(0.5, 1.0, 0.5, 0.05, 0.1)

    // Event Buffers (Class 1, 2, 3)
    var/list/class1_events = list() // Urgent alarms & trips
    var/list/class2_events = list() // Analog threshold changes
    var/list/class3_events = list() // Diagnostic logs

    // Select-Before-Operate (SBO) State Machine
    var/sbo_armed_point = -1
    var/sbo_arm_timeout_sec = 10.0
    var/sbo_timer_sec = 0.0

/datum/telemetry/dnp3_outstation/New()
    ..()
    class1_events = list()
    class2_events = list()
    class3_events = list()

// Update binary input state and generate Class 1 event upon change
/datum/telemetry/dnp3_outstation/proc/set_binary_input(point_index, new_state, timestamp_sec = 0.0)
    if(point_index >= 1 && point_index <= binary_inputs.len)
        if(binary_inputs[point_index] != new_state)
            binary_inputs[point_index] = new_state
            // Enqueue Class 1 Binary Event (Group 2 Variation 2)
            class1_events.Add(list(
                "group" = 2,
                "point" = point_index,
                "state" = new_state,
                "time"  = timestamp_sec
            ))
            return 1
    return 0

// Update analog input and evaluate deadband for Class 2 event generation
/datum/telemetry/dnp3_outstation/proc/update_analog_input(point_index, new_val, timestamp_sec = 0.0)
    if(point_index >= 1 && point_index <= analog_inputs.len)
        var/prev_val = analog_inputs[point_index]
        var/db = analog_deadbands[point_index]
        analog_inputs[point_index] = new_val

        if(abs(new_val - prev_val) >= db)
            // Enqueue Class 2 Analog Event (Group 32 Variation 5: Float with time)
            class2_events.Add(list(
                "group" = 32,
                "point" = point_index,
                "value" = new_val,
                "time"  = timestamp_sec
            ))
            return 1
    return 0

// Select-Before-Operate (SBO) Step 1: Select / Arm command (CROB Group 12)
/datum/telemetry/dnp3_outstation/proc/handle_sbo_select(point_index)
    if(point_index >= 1 && point_index <= binary_inputs.len)
        sbo_armed_point = point_index
        sbo_timer_sec = sbo_arm_timeout_sec
        return 0 // SUCCESS status code in DNP3
    return 4 // OUT_OF_RANGE error

// Select-Before-Operate (SBO) Step 2: Operate / Execute command
/datum/telemetry/dnp3_outstation/proc/handle_sbo_operate(point_index, control_code = "TRIP")
    if(sbo_armed_point == point_index && sbo_timer_sec > 0.0)
        // Command validated and executed
        sbo_armed_point = -1
        sbo_timer_sec = 0.0

        if(control_code == "TRIP")
            set_binary_input(point_index, 0)
        else
            set_binary_input(point_index, 1)

        return 0 // SUCCESS
    return 3 // NOT_ARMED / TIMEOUT error

// Class 0 Poll: Master requests all current static data points
/datum/telemetry/dnp3_outstation/proc/process_class0_poll()
    var/list/response_data = list(
        "binary_inputs" = binary_inputs,
        "analog_inputs" = analog_inputs
    )
    return response_data

// Class 1/2/3 Event Poll: Read and acknowledge events
/datum/telemetry/dnp3_outstation/proc/poll_events(class_mask)
    var/list/polled = list()
    if(class_mask & 1) // Class 1
        for(var/ev in class1_events) polled.Add(ev)
        class1_events.Cut()

    if(class_mask & 2) // Class 2
        for(var/ev in class2_events) polled.Add(ev)
        class2_events.Cut()

    return polled
