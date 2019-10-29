// Pump Net Positive Suction Head (NPSH) & Rayleigh-Plesset Cavitation
//
// Implements centrifugal pump cavitation diagnostics and bubble dynamics.
// Evaluates Net Positive Suction Head Available (NPSHA), NPSH 3% head drop
// requirement (NPSHR), Suction Specific Speed (Nss), cavitation margin ratio,
// and single-bubble Rayleigh-Plesset spherical growth and violent collapse
// microjet erosion pressure pulses on pump impeller blades.

/datum/hydraulics/cavitation
    var/tag = "PUMP-CAVITATION-MONITOR"
    var/pump_speed_rpm = 2950.0
    var/rated_flow_m3_hr = 450.0
    var/impeller_eye_diameter_m = 0.22

    // Suction conditions
    var/suction_static_press_pa = 135000.0 // 1.35 bar absolute
    var/suction_pipe_diameter_m = 0.25
    var/suction_velocity_m_s = 2.55
    var/fluid_temp_k = 343.15 // 70 C hot water
    var/fluid_density_kg_m3 = 977.8
    var/fluid_vapor_press_pa = 31180.0 // 0.31 bar vapor pressure at 70 C

    // NPSH States (in meters of liquid column)
    var/npsh_available_m = 10.9
    var/npsh_required_m = 5.2
    var/cavitation_margin_ratio = 2.10 // Recommended > 1.3 to 1.5
    var/suction_specific_speed_nss = 11200.0 // US units

    // Rayleigh-Plesset Bubble Dynamics
    var/bubble_radius_microns = 25.0
    var/bubble_collapse_velocity_m_s = 0.0
    var/microjet_impact_press_mpa = 0.0 // Shockwave peak on collapse
    var/cavitation_active = 0
    var/impeller_erosion_rate_mm_year = 0.02

/datum/hydraulics/cavitation/New()
    ..()

// Net Positive Suction Head Available:
// NPSHA = (P_suction_static - P_vapor) / (rho * g) + v_suction^2 / (2 * g)
/datum/hydraulics/cavitation/proc/calculate_npsha(static_press_pa, vapor_press_pa, velocity_m_s)
    var/g = 9.80665
    var/head_press = (static_press_pa - vapor_press_pa) / (fluid_density_kg_m3 * g)
    var/head_vel = (velocity_m_s * velocity_m_s) / (2.0 * g)
    return max(head_press + head_vel, 0.0)

// NPSHR scaling with flow rate via affinity quadratic curve:
// NPSHR(Q) = NPSHR_bep * (0.8 + 0.2 * (Q / Q_bep)^2)
/datum/hydraulics/cavitation/proc/calculate_npshr(flow_m3_hr)
    var/flow_ratio = flow_m3_hr / max(rated_flow_m3_hr, 1.0)
    var/npshr_bep = 5.2
    return npshr_bep * (0.8 + (0.2 * flow_ratio * flow_ratio))

// Rayleigh-Plesset 2nd-order ODE integration for bubble collapse:
// R * R_ddot + 1.5 * R_dot^2 = (1 / rho) * [P_vap - P_inf - 2*sigma/R - 4*mu*R_dot/R]
/datum/hydraulics/cavitation/proc/step_rayleigh_plesset(ambient_press_pa, dt_microsec = 0.5)
    var/dt = dt_microsec * 1e-6
    var/r_m = bubble_radius_microns * 1e-6
    var/rho = fluid_density_kg_m3
    var/sigma = 0.0628 // Surface tension N/m
    var/mu = 0.000404  // Dynamic viscosity Pa*s

    var/pressure_driving = fluid_vapor_press_pa - ambient_press_pa - ((2.0 * sigma) / max(r_m, 1e-8)) - ((4.0 * mu * bubble_collapse_velocity_m_s) / max(r_m, 1e-8))
    var/r_ddot = (pressure_driving / rho - (1.5 * bubble_collapse_velocity_m_s * bubble_collapse_velocity_m_s)) / max(r_m, 1e-8)

    bubble_collapse_velocity_m_s += r_ddot * dt
    r_m += bubble_collapse_velocity_m_s * dt

    if(r_m <= 1e-6)
        // Violent collapse singularity: generate water-hammer microjet shockwave
        // P_shock = rho * c_acoustic * v_jet (v_jet can exceed 1000 m/s)
        var/v_jet = min(abs(bubble_collapse_velocity_m_s) * 4.0, 1500.0)
        microjet_impact_press_mpa = (rho * 1480.0 * v_jet) * 1e-6 // Up to 2000 MPa
        bubble_radius_microns = 25.0 // Rebound / new nucleation site
        bubble_collapse_velocity_m_s = 0.0
    else
        bubble_radius_microns = r_m * 1e6
        microjet_impact_press_mpa = max(microjet_impact_press_mpa * 0.95, 0.0)

// Step pump cavitation diagnostics
/datum/hydraulics/cavitation/proc/step_cavitation(dt_sec, flow_m3_hr = 450.0)
    npsh_available_m = calculate_npsha(suction_static_press_pa, fluid_vapor_press_pa, suction_velocity_m_s)
    npsh_required_m = calculate_npshr(flow_m3_hr)

    cavitation_margin_ratio = npsh_available_m / max(npsh_required_m, 0.1)

    if(cavitation_margin_ratio < 1.05)
        cavitation_active = 1
        // Run Rayleigh-Plesset bubble collapse steps
        for(var/i = 1 to 10)
            step_rayleigh_plesset(suction_static_press_pa * 1.5, 0.5)
        impeller_erosion_rate_mm_year = min(impeller_erosion_rate_mm_year + (0.01 * dt_sec), 5.0)
    else
        cavitation_active = 0
        impeller_erosion_rate_mm_year = max(impeller_erosion_rate_mm_year - (0.001 * dt_sec), 0.01)
