// Scenario: Cascading Transmission Line Overload Trip & Under-Frequency Load Shedding
//
// Simulates a catastrophic transmission contingency event starting with a 230 kV
// circuit breaker failure, causing power redirection onto parallel circuits,
// thermally induced conductor sag trips (Mho Zone 3 pickup), generation-load
// power imbalance, steep frequency decline (-1.2 Hz/s RoCoF), and four-stage
// automated Under-Frequency Load Shedding (UFLS) scheme execution.

/datum/scenario/cascading_trip
    var/name = "Cascading Transmission Overload & UFLS Action"
    var/description = "230kV substation line trip cascading to microgrid islanding and automatic load shedding"
    var/duration_ticks = 400
    var/elapsed_ticks = 0
    var/active = 0
    var/stage = 0

    // Electrical telemetry
    var/grid_frequency_hz = 60.0
    var/line1_flow_mw = 120.0
    var/line2_flow_mw = 95.0
    var/line3_flow_mw = 80.0
    var/total_load_mw = 295.0
    var/shed_load_mw = 0.0

    // UFLS Thresholds (Stage 1 to 4)
    var/ufls_stage1_hz = 59.3 // Shed 10% load
    var/ufls_stage2_hz = 59.0 // Shed additional 10%
    var/ufls_stage3_hz = 58.7 // Shed additional 15%
    var/ufls_stage4_hz = 58.4 // Islanding / Blackout prevention

/datum/scenario/cascading_trip/New()
    ..()

/datum/scenario/cascading_trip/proc/start_scenario()
    active = 1
    elapsed_ticks = 0
    stage = 1
    grid_frequency_hz = 60.0

/datum/scenario/cascading_trip/proc/step_scenario(dt_sec)
    if(!active)
        return

    elapsed_ticks++

    // Sequence of cascading failure events
    if(elapsed_ticks == 20)
        // Main Intertie Breaker CB-201 trips on bus fault
        line1_flow_mw = 0.0
        // Power redirects to line 2 and line 3
        line2_flow_mw = 165.0 // Exceeds 140 MW thermal rating
        line3_flow_mw = 130.0 // Near limit
        stage = 2

    if(elapsed_ticks == 60)
        // Line 2 thermally trips on Zone 3 distance protection
        line2_flow_mw = 0.0
        // All burden shifts to Line 3
        line3_flow_mw = 250.0 // Massive overload
        stage = 3

    if(elapsed_ticks == 80)
        // Line 3 trips on instantaneous overcurrent
        line3_flow_mw = 0.0
        // Microgrid is suddenly islanded with massive generation deficit (-120 MW)
        stage = 4

    // Dynamic frequency decay if islanded
    if(stage >= 4)
        var/deficit_mw = total_load_mw - shed_load_mw - 140.0 // Local generation is only 140 MW
        if(deficit_mw > 0.0)
            // Swing equation frequency drop: df/dt = -f0 * deficit / (2 * H * S_base)
            var/rocof = -deficit_mw * 0.008
            grid_frequency_hz = max(grid_frequency_hz + (rocof * dt_sec), 57.5)

        // Stage 1 UFLS: 59.3 Hz
        if(grid_frequency_hz <= ufls_stage1_hz && shed_load_mw < 30.0)
            shed_load_mw = 30.0

        // Stage 2 UFLS: 59.0 Hz
        if(grid_frequency_hz <= ufls_stage2_hz && shed_load_mw < 60.0)
            shed_load_mw = 60.0

        // Stage 3 UFLS: 58.7 Hz
        if(grid_frequency_hz <= ufls_stage3_hz && shed_load_mw < 105.0)
            shed_load_mw = 105.0

        // Stabilization if load shed balances local generation
        if(shed_load_mw >= 105.0)
            grid_frequency_hz = min(grid_frequency_hz + (0.15 * dt_sec), 59.8)

    if(elapsed_ticks >= duration_ticks)
        active = 0
