// Scenario: Hydrocracker Furnace Tube Rupture & High-Pressure Emergency Depressuring
//
// Simulates high-pressure (140 bar, 450 C) hydroprocessing furnace coil rupture
// caused by hydrogen embrittlement and localized hot spots. Triggers rapid acoustic
// pressure collapse, supersonic hydrogen jet release, optical UV/IR flame detection,
// emergency blowdown valve (BDV) opening to cold flare header, and nitrogen snuffing.

/datum/scenario/reformer_rupture
    var/name = "Hydrocracker Furnace Coil Rupture & Flare Blowdown"
    var/description = "Catastrophic tube rupture with hydrogen jet release and rapid 15-minute emergency depressurization"
    var/duration_ticks = 300
    var/elapsed_ticks = 0
    var/active = 0

    // Process parameters
    var/reactor_pressure_bar = 142.0
    var/tube_skin_temp_k = 765.0 // 492 C
    var/flare_header_pressure_bar = 1.8
    var/h2_release_rate_kg_s = 0.0
    var/bdv_valve_open = 0
    var/fuel_gas_esdv_closed = 0
    var/fire_deluge_active = 0

/datum/scenario/reformer_rupture/New()
    ..()

/datum/scenario/reformer_rupture/proc/start_scenario()
    active = 1
    elapsed_ticks = 0
    reactor_pressure_bar = 142.0
    h2_release_rate_kg_s = 0.0
    bdv_valve_open = 0
    fuel_gas_esdv_closed = 0

/datum/scenario/reformer_rupture/proc/step_scenario(dt_sec)
    if(!active)
        return

    elapsed_ticks++

    // Sequence of incident progression
    if(elapsed_ticks == 15)
        // Tube skin overheats to 820 C and ruptures
        tube_skin_temp_k = 1093.15
        h2_release_rate_kg_s = 45.0 // High-pressure choked sonic jet release

    if(elapsed_ticks == 20)
        // Optical flame scanners detect infrared flare in firebox
        // SIS Trip Level 1: Cut fuel gas
        fuel_gas_esdv_closed = 1

    if(elapsed_ticks == 25)
        // Emergency Depressuring System (EDP / API 521): Open BDV to flare
        bdv_valve_open = 1
        fire_deluge_active = 1

    // Pressure blowdown curve: P(t) = P0 * exp(-t / tau_depressure)
    if(bdv_valve_open)
        var/tau_dep = 65.0 // Depressurize to <7 bar in under 15 minutes per API 521
        var/dp = (reactor_pressure_bar - flare_header_pressure_bar) * (dt_sec / tau_dep)
        reactor_pressure_bar = max(reactor_pressure_bar - dp, flare_header_pressure_bar)
        h2_release_rate_kg_s = max(h2_release_rate_kg_s - (0.4 * dt_sec), 0.5)

    if(elapsed_ticks >= duration_ticks)
        active = 0
