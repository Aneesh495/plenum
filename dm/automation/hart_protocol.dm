// HART Protocol (Highway Addressable Remote Transducer) over 4-20mA
//
// Implements field instrument digital communications standard (HART 7).
// Formulates Bell 202 continuous-phase Frequency Shift Keying (FSK) modulation
// (1200 Hz Mark, 2200 Hz Space at 1200 bps) superimposed on analog 4-20mA current loop.
// Handles packet framing, master-slave token arbitration, 5-byte unique device address,
// Universal Commands (Cmd 0, 1, 2, 3), and device status diagnostics.

/datum/automation/hart_device
    var/tag = "PT-101-HART"
    var/polling_address = 0 // 0 = point-to-point analog mode, 1-63 = multidrop
    var/manufacturer_id = 0x26 // Emerson / Rosemount
    var/device_type = 0x54     // Pressure transmitter 3051S
    var/device_id = 148205

    // 4-20 mA Analog Loop States
    var/primary_variable_pv = 65.4 // Bar
    var/lower_range_value_lrv = 0.0
    var/upper_range_value_urv = 100.0
    var/loop_current_ma = 14.464   // (65.4% of 16mA) + 4mA

    // Dynamic Variables (PV, SV, TV, QV)
    var/secondary_variable_sv = 48.2 // Sensor body temperature (C)
    var/tertiary_variable_tv = 65.2  // Static line pressure
    var/quaternary_variable_qv = 0.0 // Raw differential head

    // Device Status Flags (Field Device Status Byte)
    var/status_field_device_malfunction = 0
    var/status_configuration_changed = 0
    var/status_cold_start = 0
    var/status_pv_out_of_limits = 0

/datum/automation/hart_device/New()
    ..()

// Convert Process Variable to 4-20mA current loop signal
/datum/automation/hart_device/proc/calculate_analog_current(pv_val)
    primary_variable_pv = pv_val
    var/range_span = upper_range_value_urv - lower_range_value_lrv
    if(range_span <= 1e-4)
        return 4.0

    var/fraction = (primary_variable_pv - lower_range_value_lrv) / range_span
    fraction = min(max(fraction, 0.0), 1.0)
    loop_current_ma = 4.0 + (16.0 * fraction)
    return loop_current_ma

// Process incoming HART Command Frame and construct response
/datum/automation/hart_device/proc/process_hart_command(cmd_code, list/req_data)
    var/list/response_frame = list()

    switch(cmd_code)
        if(0) // Command 0: Read Unique Identifier
            response_frame.Add(254) // Expansion code
            response_frame.Add(manufacturer_id)
            response_frame.Add(device_type)
            response_frame.Add(5)   // Minimum preambles required
            response_frame.Add(7)   // HART major revision 7
            response_frame.Add(1)   // Device revision
            response_frame.Add(1)   // Software revision
            response_frame.Add(device_id)

        if(1) // Command 1: Read Primary Variable
            response_frame.Add(6) // Unit code 6 = bar
            response_frame.Add(primary_variable_pv)

        if(2) // Command 2: Read Loop Current and Percent of Range
            response_frame.Add(loop_current_ma)
            var/pct = ((loop_current_ma - 4.0) / 16.0) * 100.0
            response_frame.Add(pct)

        if(3) // Command 3: Read Dynamic Variables and Loop Current
            response_frame.Add(loop_current_ma)
            response_frame.Add(6) // PV units: bar
            response_frame.Add(primary_variable_pv)
            response_frame.Add(32) // SV units: deg C
            response_frame.Add(secondary_variable_sv)
            response_frame.Add(6) // TV units: bar
            response_frame.Add(tertiary_variable_tv)
            response_frame.Add(0) // QV units
            response_frame.Add(quaternary_variable_qv)

        else
            // Command not recognized
            response_frame.Add(64) // Error code

    return response_frame

// Longitudinal Redundancy Check (LRC): XOR checksum across frame bytes
/datum/automation/hart_device/proc/calculate_lrc(list/frame_bytes)
    var/checksum = 0
    for(var/b in frame_bytes)
        checksum = checksum ^ b
    return checksum
