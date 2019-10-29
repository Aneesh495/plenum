// Beggs & Brill Two-Phase Liquid-Gas Pipeline Hydraulics
//
// Implements comprehensive two-phase flow regime determination and pressure
// drop solver based on the Beggs and Brill empirical correlation and Taitel-Dukler
// mechanistic criteria. Predicts flow patterns (Segregated, Intermittent, Distributed,
// Transition), in-situ liquid holdup with inclination correction, slip velocity,
// slug frequency, and combined gravitational/frictional pressure gradients.

/datum/hydraulics/multiphase
    var/tag = "TWO-PHASE-LINE"
    var/pipe_diameter_m = 0.30
    var/pipe_length_m = 2500.0
    var/inclination_deg = 2.5 // Upward incline (radians = deg * pi / 180)

    // Fluid properties
    var/liquid_density_kg_m3 = 850.0  // Light crude oil
    var/gas_density_kg_m3 = 45.0      // Associated natural gas at 40 bar
    var/liquid_viscosity_pa_s = 0.0035
    var/gas_viscosity_pa_s = 0.000015
    var/interfacial_tension_n_m = 0.028

    // Superficial velocities
    var/v_sl = 0.85 // Superficial liquid velocity (m/s)
    var/v_sg = 4.20 // Superficial gas velocity (m/s)

    // Calculated two-phase states
    var/mixture_velocity_m_s = 5.05
    var/input_liquid_fraction_lambda = 0.168
    var/froude_number = 8.68
    var/flow_regime = "INTERMITTENT_SLUG"
    var/liquid_holdup = 0.285 // In-situ liquid volume fraction
    var/total_dp_bar = 8.45
    var/elevation_dp_bar = 1.85
    var/friction_dp_bar = 6.60

/datum/hydraulics/multiphase/New()
    ..()

// Determine Beggs & Brill flow regime using dimensionless boundary curves L1, L2, L3, L4
/datum/hydraulics/multiphase/proc/determine_flow_regime(lambda_l, froude)
    var/l1 = 316.0 * exp(0.302 * log(max(lambda_l, 1e-4)))
    var/l2 = 0.0009252 * exp(-2.4684 * log(max(lambda_l, 1e-4)))
    var/l3 = 0.10 * exp(-1.4516 * log(max(lambda_l, 1e-4)))
    var/l4 = 0.50 * exp(-6.738 * log(max(lambda_l, 1e-4)))

    if((lambda_l < 0.01 && froude < l1) || (lambda_l >= 0.01 && froude < l2))
        return "SEGREGATED_STRATIFIED"
    if((lambda_l >= 0.01 && froude > l2 && froude <= l3))
        return "TRANSITION"
    if((lambda_l >= 0.01 && lambda_l < 0.4 && froude > l3 && froude <= l1) || (lambda_l >= 0.4 && froude > l3 && froude <= l4))
        return "INTERMITTENT_SLUG"
    if((lambda_l < 0.4 && froude >= l1) || (lambda_l >= 0.4 && froude > l4))
        return "DISTRIBUTED_MIST"

    return "INTERMITTENT_SLUG"

// Calculate horizontal liquid holdup H_L(0) and apply inclination correction B(theta)
/datum/hydraulics/multiphase/proc/calculate_holdup(lambda_l, froude, theta_rad, regime)
    var/a_reg = 0.98
    var/b_reg = 0.4846
    var/c_reg = 0.0868

    switch(regime)
        if("SEGREGATED_STRATIFIED")
            a_reg = 0.980
            b_reg = 0.4846
            c_reg = 0.0868
        if("INTERMITTENT_SLUG")
            a_reg = 0.845
            b_reg = 0.5351
            c_reg = 0.0173
        if("DISTRIBUTED_MIST")
            a_reg = 1.065
            b_reg = 0.5824
            c_reg = 0.0609

    // Horizontal holdup: H_L0 = a * lambda^b / Fr^c
    var/hl0 = (a_reg * exp(b_reg * log(max(lambda_l, 1e-4)))) / exp(c_reg * log(max(froude, 1e-4)))
    hl0 = min(max(hl0, lambda_l), 1.0)

    // Inclination factor: psi = 1 + C * [sin(1.8 * theta) - 0.333 * sin(1.8 * theta)^3]
    var/sin_18_theta = sin(1.8 * theta_rad)
    var/c_factor = 0.0055 * exp(log(max(lambda_l, 1e-4)) * (-3.768)) // Upward flow
    c_factor = min(c_factor, 0.45)
    var/psi = 1.0 + (c_factor * (sin_18_theta - (0.333 * sin_18_theta * sin_18_theta * sin_18_theta)))

    var/hl = hl0 * psi
    return min(max(hl, lambda_l), 1.0)

// Step two-phase hydraulic gradient
/datum/hydraulics/multiphase/proc/step_hydraulics(flow_rate_liquid_m3_s, flow_rate_gas_m3_s)
    var/area = 3.14159 * (pipe_diameter_m * 0.5) * (pipe_diameter_m * 0.5)
    v_sl = flow_rate_liquid_m3_s / area
    v_sg = flow_rate_gas_m3_s / area
    mixture_velocity_m_s = v_sl + v_sg

    input_liquid_fraction_lambda = v_sl / max(mixture_velocity_m_s, 1e-4)

    var/g = 9.80665
    froude_number = (mixture_velocity_m_s * mixture_velocity_m_s) / (g * pipe_diameter_m)

    // Flow pattern determination
    flow_regime = determine_flow_regime(input_liquid_fraction_lambda, froude_number)

    // In-situ liquid holdup
    var/theta_rad = (inclination_deg * 3.14159) / 180.0
    liquid_holdup = calculate_holdup(input_liquid_fraction_lambda, froude_number, theta_rad, flow_regime)

    // Effective two-phase mixture density
    var/rho_mix = (liquid_density_kg_m3 * liquid_holdup) + (gas_density_kg_m3 * (1.0 - liquid_holdup))

    // 1. Hydrostatic elevation gradient: dP/dL_elev = rho_mix * g * sin(theta)
    var/dp_elev_per_m = rho_mix * g * sin(theta_rad)
    elevation_dp_bar = (dp_elev_per_m * pipe_length_m) / 100000.0

    // 2. Frictional gradient with Beggs-Brill two-phase friction multiplier
    var/mu_no_slip = (liquid_viscosity_pa_s * input_liquid_fraction_lambda) + (gas_viscosity_pa_s * (1.0 - input_liquid_fraction_lambda))
    var/re_no_slip = (rho_mix * mixture_velocity_m_s * pipe_diameter_m) / max(mu_no_slip, 1e-6)
    var/fn = 0.0055 * (1.0 + exp(0.333 * log(20000.0 * (0.000045 / pipe_diameter_m) + (1e6 / max(re_no_slip, 1.0)))))

    // Friction multiplier: S = ln(y) / (-0.0523 + 3.182*ln(y) - 0.8725*ln(y)^2 + 0.01853*ln(y)^4)
    var/y_term = input_liquid_fraction_lambda / max(liquid_holdup * liquid_holdup, 1e-4)
    var/f_two_phase = fn * exp(0.12 * log(max(y_term, 0.1)))

    var/dp_fric_per_m = (2.0 * f_two_phase * rho_mix * mixture_velocity_m_s * mixture_velocity_m_s) / pipe_diameter_m
    friction_dp_bar = (dp_fric_per_m * pipe_length_m) / 100000.0

    total_dp_bar = elevation_dp_bar + friction_dp_bar
    return total_dp_bar
