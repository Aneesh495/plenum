// Electro-Hydraulic Governor (EHG) & Multi-Cylinder Steam Turbine
//
// Implements utility-scale reheat steam turbine governing system (HP-IP-LP).
// Models Main Stop Valves (MSV), Control Valves (CV1-4) with non-linear lift cam
// flow characteristics, Intercept Valves (IV), IEEEG1 governor transfer functions,
// speed droop regulation (4%), load limiters, and mechanical overspeed bolt trip (110%).

/datum/turbomachinery/steam_turbine_governor
    var/tag = "STG-EHG-GOVERNOR"
    var/rated_power_mw = 180.0
    var/rated_speed_rpm = 3600.0
    var/current_speed_rpm = 3600.0
    var/speed_droop_pct = 4.0 // 4% droop regulation

    // Steam Valve Servomotors (0.0 to 1.0 position)
    var/msv_position = 1.0 // Main stop valves (1.0 = fully open)
    var/cv1_position = 0.85 // High pressure control valve 1
    var/cv2_position = 0.85
    var/cv3_position = 0.60
    var/cv4_position = 0.00 // Sequential partial arc admission
    var/iv_position  = 1.0  // Intercept valve

    // Steam Conditions
    var/main_steam_press_bar = 125.0
    var/main_steam_temp_k = 838.15 // 565 C
    var/reheat_steam_press_bar = 30.0
    var/reheat_steam_temp_k = 838.15
    var/condenser_vacuum_bar = 0.065 // 65 mbar absolute

    // Mechanical states
    var/electrical_power_mw = 145.0
    var/turbine_rotor_torque_nm = 385000.0
    var/emergency_trip_active = 0
    var/trip_reason = "NONE"

/datum/turbomachinery/steam_turbine_governor/New()
    ..()

// IEEEG1 Speed Droop Governing:
// Delta_P_order = (Speed_ref - Speed_actual) / (Droop * Speed_rated)
/datum/turbomachinery/steam_turbine_governor/proc/calculate_governor_demand(speed_rpm, speed_ref_rpm, load_setpoint_mw)
    var/speed_error = speed_ref_rpm - speed_rpm
    var/droop_pu = speed_droop_pct * 0.01
    var/delta_p_droop = (speed_error / (droop_pu * rated_speed_rpm)) * rated_power_mw

    var/total_demand_mw = load_setpoint_mw + delta_p_droop
    return min(max(total_demand_mw, 0.0), rated_power_mw)

// Non-linear valve cam flow curve: converts linear servo position to steam flow fraction
/datum/turbomachinery/steam_turbine_governor/proc/valve_flow_fraction(pos)
    // S-curve characteristic to linearize mass flow vs valve lift
    var/p = min(max(pos, 0.0), 1.0)
    return (p * p * (3.0 - (2.0 * p)))

// Step steam turbine governor and rotor dynamics
/datum/turbomachinery/steam_turbine_governor/proc/step_governor(dt_sec, grid_frequency_hz, generator_electrical_load_mw)
    // 1. Convert grid frequency to turbine speed
    var/target_speed = (grid_frequency_hz / 60.0) * rated_speed_rpm

    // 2. Check emergency overspeed trip (> 110% = 3960 RPM)
    if(current_speed_rpm >= (rated_speed_rpm * 1.10) && !emergency_trip_active)
        emergency_trip_active = 1
        trip_reason = "MECHANICAL_OVERSPEED_110_PCT"
        msv_position = 0.0
        cv1_position = 0.0
        cv2_position = 0.0
        cv3_position = 0.0
        cv4_position = 0.0
        iv_position = 0.0

    // 3. Loss of condenser vacuum trip (> 0.25 bar)
    if(condenser_vacuum_bar > 0.250 && !emergency_trip_active)
        emergency_trip_active = 1
        trip_reason = "LOSS_OF_CONDENSER_VACUUM"
        msv_position = 0.0

    if(emergency_trip_active)
        electrical_power_mw = 0.0
        current_speed_rpm = max(current_speed_rpm - (35.0 * dt_sec), 0.0) // Coastdown
        return 0

    // 4. EHG Modulation
    var/power_demand = calculate_governor_demand(current_speed_rpm, 3600.0, generator_electrical_load_mw)
    var/demand_fraction = power_demand / rated_power_mw

    // Sequence control valves
    cv1_position = min(demand_fraction * 1.25, 1.0)
    cv2_position = min(demand_fraction * 1.25, 1.0)
    cv3_position = min(max((demand_fraction - 0.5) * 2.0, 0.0), 1.0)
    cv4_position = min(max((demand_fraction - 0.8) * 5.0, 0.0), 1.0)

    var/total_flow_fraction = (valve_flow_fraction(cv1_position) + valve_flow_fraction(cv2_position) + valve_flow_fraction(cv3_position) + valve_flow_fraction(cv4_position)) * 0.25

    // 5. Rotor mechanical torque and acceleration (Swing equation)
    var/mech_power = rated_power_mw * total_flow_fraction * (main_steam_press_bar / 125.0)
    electrical_power_mw = mech_power

    var/omega = (current_speed_rpm * 2.0 * 3.14159) / 60.0
    turbine_rotor_torque_nm = (mech_power * 1e6) / max(omega, 10.0)

    var/j_inertia = 25000.0 // kg * m^2
    var/d_omega_dt = ((mech_power - generator_electrical_load_mw) * 1e6) / (j_inertia * max(omega, 10.0))
    var/d_rpm_dt = (d_omega_dt * 60.0) / (2.0 * 3.14159)

    current_speed_rpm = min(max(current_speed_rpm + (d_rpm_dt * dt_sec), 3000.0), 4000.0)
    return electrical_power_mw
