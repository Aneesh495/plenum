// Hydro-Electric Turbine Governor & Penstock Water Column Dynamics
//
// Implements hydro-electric generation units (Francis and Pelton turbines).
// Formulates penstock hydraulic inertia (water starting time T_w), non-minimum
// phase inverse power response characteristic ((1 - T_w * s) / (1 + 0.5 * T_w * s)),
// wicket gate servomotor rate limits, draft tube vortex rope pressure pulsations
// at part load, and surge tank water level oscillation damping.

/datum/turbomachinery/hydro_turbine
    var/tag = "HYDRO-FRANCIS-150MW"
    var/rated_power_mw = 150.0
    var/rated_head_m = 185.0
    var/rated_flow_m3_s = 92.5
    var/rated_speed_rpm = 300.0 // 24-pole generator at 60 Hz
    var/current_speed_rpm = 300.0

    // Water Column Inertia
    var/penstock_length_m = 480.0
    var/penstock_area_m2 = 18.8
    var/water_starting_time_tw_sec = 1.45 // T_w = (L * v0) / (g * H0)
    var/mechanical_starting_time_tm_sec = 6.20 // 2 * H inertia constant

    // Wicket Gate Actuator States (0.0 to 1.0)
    var/gate_position = 0.82
    var/gate_rate_limit_per_sec = 0.15 // Closing speed clamped to prevent penstock burst
    var/pilot_valve_demand = 0.82

    // Hydraulic Telemetry
    var/net_head_m = 182.4
    var/flow_rate_m3_s = 88.5
    var/turbine_efficiency = 0.935
    var/mechanical_power_mw = 148.2
    var/draft_tube_vortex_pulsation_pct = 1.8 // Pressure fluctuation at runner exit

    // Surge Tank
    var/surge_tank_water_level_m = 42.5
    var/surge_tank_area_m2 = 85.0

/datum/turbomachinery/hydro_turbine/New()
    ..()

// Classical Hydraulic Turbine Non-Linear Transfer Function:
// Q = G * sqrt(H / H0)
// H = H_gross - H_friction - (T_w / dt) * (Q - Q_prev)
/datum/turbomachinery/hydro_turbine/proc/step_hydraulic_head(gate_pos, dt_sec, gross_head_m = 185.0)
    var/g0 = min(max(gate_pos, 0.01), 1.0)
    var/h_ratio = max(net_head_m / rated_head_m, 0.1)

    // Flow follows gate opening and square root of net head
    var/q_target = rated_flow_m3_s * g0 * sqrt(h_ratio)
    var/delta_q = q_target - flow_rate_m3_s

    // Penstock water inertia pressure surge: Delta_H = -T_w * (dH0 / dt)
    var/delta_h_inertia = -(water_starting_time_tw_sec * (delta_q / dt_sec)) * (rated_head_m / rated_flow_m3_s)
    delta_h_inertia = min(max(delta_h_inertia, -45.0), 65.0) // Clamped by relief

    // Penstock head loss from Darcy-Weisbach friction
    var/v_penstock = q_target / penstock_area_m2
    var/h_friction = 0.016 * (penstock_length_m / 4.8) * (v_penstock * v_penstock) / (2.0 * 9.80665)

    net_head_m = gross_head_m - h_friction + delta_h_inertia
    flow_rate_m3_s = q_target
    return net_head_m

// Step hydro governor and Francis turbine power generation
/datum/turbomachinery/hydro_turbine/proc/step_governor(dt_sec, grid_frequency_hz, power_setpoint_mw)
    // 1. Permanent Droop (b_p ~ 4%) and Temporary Droop (b_t ~ 25%) with dashpot filter
    var/freq_error_pu = (60.0 - grid_frequency_hz) / 60.0
    var/droop_gain = 1.0 / 0.04
    var/gate_demand = (power_setpoint_mw / rated_power_mw) + (freq_error_pu * droop_gain * 0.1)
    gate_demand = min(max(gate_demand, 0.0), 1.0)

    // 2. Servomotor rate limit: clamp dG/dt
    var/gate_error = gate_demand - gate_position
    var/max_move = gate_rate_limit_per_sec * dt_sec
    var/clamped_move = min(max(gate_error, -max_move), max_move)
    gate_position += clamped_move

    // 3. Penstock fluid dynamics step
    step_hydraulic_head(gate_position, dt_sec)

    // 4. Turbine Hill Chart Efficiency:
    // Efficiency peaks at 85% gate and nominal head, drops off at low flow
    var/q_pu = flow_rate_m3_s / rated_flow_m3_s
    var/eff_peak = 0.942
    var/eff_drop = 0.25 * (q_pu - 0.85) * (q_pu - 0.85)
    turbine_efficiency = max(eff_peak - eff_drop, 0.70)

    // 5. Shaft Mechanical Power: P = rho * g * Q * H * eta
    var/rho = 998.0
    var/g = 9.80665
    var/power_watts = rho * g * flow_rate_m3_s * net_head_m * turbine_efficiency
    mechanical_power_mw = power_watts * 1e-6

    // 6. Draft Tube Vortex Rope Pulsation at part load (40% to 70% flow)
    if(q_pu > 0.40 && q_pu < 0.75)
        var/part_load_factor = (q_pu - 0.40) * (0.75 - q_pu) * 16.0
        draft_tube_vortex_pulsation_pct = 1.5 + (part_load_factor * 8.5)
    else
        draft_tube_vortex_pulsation_pct = 1.2

    // 7. Rotor Speed Dynamics (Swing Equation)
    var/speed_error = (grid_frequency_hz / 60.0) * rated_speed_rpm - current_speed_rpm
    current_speed_rpm += speed_error * 0.15 * dt_sec

    return mechanical_power_mw
