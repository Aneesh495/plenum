// Scenario: Nuclear Station Blackout (SBO) & Passive Natural Circulation
//
// Simulates total loss of all off-site AC power (LOOP) coupled with common-cause
// failure of both Emergency Diesel Generators (EDGs) at an integral SMR facility.
// Models instantaneous reactor scram, primary coolant pump coastdown, transition
// to natural circulation buoyancy-driven decay heat removal (Passive Containment
// Cooling System PCCS), Class 1E 125V DC battery depletion, and fuel cladding limits.

/datum/scenario/station_blackout
    var/name = "Nuclear SMR Station Blackout (SBO) & Passive Decay Heat Removal"
    var/description = "Total AC power collapse with passive safety natural circulation buoyancy transition"
    var/duration_ticks = 350
    var/elapsed_ticks = 0
    var/active = 0

    // Plant states
    var/reactor_power_mw = 160.0
    var/cladding_temp_k = 620.0 // Cladding limit 1477 K (1204 C per 10 CFR 50.46)
    var/primary_mass_flow_kg_s = 850.0
    var/dc_battery_voltage_v = 126.5
    var/natural_circulation_active = 0
    var/core_scrammed = 0

/datum/scenario/station_blackout/New()
    ..()

/datum/scenario/station_blackout/proc/start_scenario()
    active = 1
    elapsed_ticks = 0
    reactor_power_mw = 160.0
    primary_mass_flow_kg_s = 850.0
    dc_battery_voltage_v = 126.5

/datum/scenario/station_blackout/proc/step_scenario(dt_sec)
    if(!active)
        return

    elapsed_ticks++

    if(elapsed_ticks == 10)
        // Loss of offsite power: control rods unlatch via fail-safe gravity drop
        core_scrammed = 1
        reactor_power_mw = 10.5 // Immediate prompt drop to ~6.5% decay heat
        primary_mass_flow_kg_s = 400.0 // Pump coastdown

    if(elapsed_ticks == 30)
        // Primary pumps fully stop: natural circulation head takes over
        // Buoyancy driving head: Delta_P = rho * beta * g * Delta_T * Delta_Z
        natural_circulation_active = 1
        primary_mass_flow_kg_s = 85.0 // Steady natural circulation flow rate

    // Decay heat decay curve: Wigner-Way P(t) ~ P0 * 0.066 * t^(-0.2)
    if(core_scrammed)
        var/t_hours = max((elapsed_ticks * dt_sec) / 3600.0, 0.001)
        reactor_power_mw = max(160.0 * 0.066 * exp(-0.2 * log(t_hours * 3600.0)), 2.5)

    // Cladding heat balance with passive natural circulation
    if(natural_circulation_active)
        var/target_clad = 580.0 + (reactor_power_mw * 4.5)
        cladding_temp_k = cladding_temp_k + (target_clad - cladding_temp_k) * 0.08 * dt_sec

    // DC battery discharge (72-hour coping time)
    dc_battery_voltage_v = max(dc_battery_voltage_v - (0.01 * dt_sec), 105.0)

    if(elapsed_ticks >= duration_ticks)
        active = 0
