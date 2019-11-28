// IEC 61850 Substation Automation, GOOSE Messaging & Sampled Values
//
// Implements digital substation architecture per IEC 61850 standards.
// Models Process Bus Sampled Values (SV 9-2LE at 4800 Hz / 80 samples/cycle),
// Station Bus Generic Object Oriented Substation Events (GOOSE 8-1) with
// exponential heartbeat retransmission, and standard Logical Nodes:
// XCBR (Circuit Breaker), CSWI (Switch Controller), PTOC (Overcurrent Protection),
// and MMXU (Three-Phase AC Electrical Measurement Unit).

/datum/substation/iec61850_ied
    var/tag = "IED-BAY-01-SEL421"
    var/ied_name = "BAY01"

    // Logical Node XCBR1: Circuit Breaker
    // Pos: 1 = Closed (01), 2 = Open (10), 3 = In-transit (00), 4 = Bad State (11)
    var/xcbr_pos = 1
    var/xcbr_operation_counter = 142
    var/xcbr_trip_coil_supervision_ok = 1

    // Logical Node PTOC1: Time Overcurrent Protection
    var/ptoc_str = 0 // Start / pickup indicator
    var/ptoc_op = 0  // Operate / trip output

    // Logical Node MMXU1: AC Measurements
    var/mmxu_tot_w_mw = 45.2
    var/mmxu_tot_var_mvar = 12.8
    var/mmxu_ppv_phsa_kv = 13.82
    var/mmxu_a_phsa_a = 1890.0
    var/mmxu_hz_freq = 60.01

    // GOOSE Publisher State Machine (IEC 61850-8-1)
    var/goose_app_id = 0x0001
    var/goose_state_num_stnum = 1
    var/goose_sq_num_sqnum = 0
    var/goose_time_allowed_to_live_ms = 1000
    var/goose_min_time_ms = 4
    var/goose_max_time_ms = 1000
    var/goose_retransmit_timer_ms = 4

    // SV 9-2LE Streamer (80 samples / cycle)
    var/sv_sample_count = 0
    var/sv_sync_locked = 1 // PTP IEEE 1588 time synchronization

/datum/substation/iec61850_ied/New()
    ..()

// Publish high-speed GOOSE message upon event state change:
// StNum increments, SqNum resets to 0, immediate transmission with min_time = 4ms
/datum/substation/iec61850_ied/proc/trigger_goose_event(new_trip_state)
    if(ptoc_op != new_trip_state)
        ptoc_op = new_trip_state
        goose_state_num_stnum++
        goose_sq_num_sqnum = 0
        goose_retransmit_timer_ms = goose_min_time_ms
        return 1
    return 0

// Step GOOSE retransmission heartbeat timer:
// Interval doubles on each transmission (4ms, 8ms, 16ms, 32ms, 64ms... up to 1000ms heartbeat)
/datum/substation/iec61850_ied/proc/step_goose_heartbeat(dt_ms)
    goose_retransmit_timer_ms -= dt_ms
    if(goose_retransmit_timer_ms <= 0)
        goose_sq_num_sqnum++
        // Double retransmission interval until max_time
        var/next_interval = goose_retransmit_timer_ms * 2.0
        if(next_interval < 0) next_interval = 8.0
        goose_retransmit_timer_ms = min(next_interval, goose_max_time_ms)
        return 1 // Packet transmitted onto Station Bus Ethernet
    return 0

// Execute breaker trip command via Logical Node XCBR
/datum/substation/iec61850_ied/proc/trip_circuit_breaker()
    if(xcbr_pos == 1) // Closed
        xcbr_pos = 3  // In-transit
        xcbr_operation_counter++
        xcbr_pos = 2  // Open
        trigger_goose_event(1)
        return 1
    return 0

// Execute breaker close command with synchrocheck permissive (25)
/datum/substation/iec61850_ied/proc/close_circuit_breaker(synchrocheck_ok = 1)
    if(!synchrocheck_ok)
        return 0 // Interlocked: voltage phase angle or frequency mismatch

    if(xcbr_pos == 2) // Open
        xcbr_pos = 3  // In-transit
        xcbr_pos = 1  // Closed
        trigger_goose_event(0)
        return 1
    return 0

// Ingest SV 9-2LE Sampled Values stream (80 samples per cycle)
/datum/substation/iec61850_ied/proc/process_sampled_values(v_sample, i_sample)
    sv_sample_count = (sv_sample_count + 1) % 80
    // Protection threshold check on instantaneous Sampled Values
    if(abs(i_sample) > 3500.0) // Pickup threshold exceeded
        ptoc_str = 1
        trip_circuit_breaker()
    else if(ptoc_str && abs(i_sample) < 1500.0)
        ptoc_str = 0
