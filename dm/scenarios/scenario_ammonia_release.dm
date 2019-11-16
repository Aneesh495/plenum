// Scenario: Refrigeration Ammonia Release & Control Room HVAC Shelter-In-Place
//
// Simulates an accidental toxic anhydrous ammonia (NH3) liquid receiver rupture
// in a chemical chiller plant. Models dense aerosol two-phase flashing, downwind
// toxic gas plume dispersion, fence-line toxic detector voting, emergency plant
// isolation, and automated Control Room HVAC damper closure into shelter-in-place mode.

/datum/scenario/ammonia_release
    var/name = "Industrial Ammonia Release & Shelter-In-Place Evacuation"
    var/description = "Liquid receiver flange failure with toxic plume dispersion and HVAC emergency recirculation"
    var/duration_ticks = 300
    var/elapsed_ticks = 0
    var/active = 0

    // Source leak telemetry
    var/receiver_pressure_bar = 12.5
    var/leak_rate_kg_s = 0.0
    var/cumulative_released_kg = 0.0

    // Downwind fence-line detectors (Distance: 150m, 300m, 600m)
    var/sensor_150m_nh3_ppm = 0.0
    var/sensor_300m_nh3_ppm = 0.0
    var/sensor_control_room_ppm = 0.0

    // Protective responses
    var/plant_siren_sounding = 0
    var/hvac_dampers_isolated = 0
    var/water_curtain_active = 0

/datum/scenario/ammonia_release/New()
    ..()

/datum/scenario/ammonia_release/proc/start_scenario()
    active = 1
    elapsed_ticks = 0
    receiver_pressure_bar = 12.5
    leak_rate_kg_s = 0.0
    plant_siren_sounding = 0
    hvac_dampers_isolated = 0

/datum/scenario/ammonia_release/proc/step_scenario(dt_sec)
    if(!active)
        return

    elapsed_ticks++

    if(elapsed_ticks == 10)
        // Flange seal catastrophically blows out on high-pressure liquid line
        leak_rate_kg_s = 18.5 // Flashing liquid jet

    if(leak_rate_kg_s > 0.0)
        cumulative_released_kg += leak_rate_kg_s * dt_sec
        receiver_pressure_bar = max(receiver_pressure_bar - (0.15 * dt_sec), 1.0)

        // Downwind toxic gas plume progression (approximate Gaussian transport at 3.5 m/s wind)
        if(elapsed_ticks > 15)
            sensor_150m_nh3_ppm = min(sensor_150m_nh3_ppm + (12.0 * dt_sec), 480.0) // Highly toxic
        if(elapsed_ticks > 35)
            sensor_300m_nh3_ppm = min(sensor_300m_nh3_ppm + (4.5 * dt_sec), 160.0)
        if(elapsed_ticks > 60)
            if(!hvac_dampers_isolated)
                sensor_control_room_ppm = min(sensor_control_room_ppm + (1.2 * dt_sec), 45.0)

        // Automated safety interlock triggers:
        // Fence-line sensor > 25 ppm: sound alarm, activate water spray absorption curtain
        if(sensor_150m_nh3_ppm >= 25.0)
            plant_siren_sounding = 1
            water_curtain_active = 1
            // Water curtain scrubs ~60% of airborne ammonia vapor
            leak_rate_kg_s = max(leak_rate_kg_s * 0.96, 4.0)

        // Control Room HVAC Protection: Isolate fresh air dampers at 20 ppm
        if(sensor_300m_nh3_ppm >= 20.0 && !hvac_dampers_isolated)
            hvac_dampers_isolated = 1
            // Ingress halts; internal scrubbers clean room air
            sensor_control_room_ppm = max(sensor_control_room_ppm - (0.5 * dt_sec), 0.0)

    if(elapsed_ticks >= duration_ticks)
        active = 0
