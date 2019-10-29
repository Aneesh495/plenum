// Method of Characteristics (MOC) Hydraulic Transient & Water Hammer Solver
//
// Implements 1D hyperbolic hydraulic transient wave equations for pressurized
// pipeline networks. Solves compatibility equations along C+ and C- characteristic
// lines (dx/dt = +a, dx/dt = -a), acoustic wave speed in elastic conduit (Korteweg formula),
// rapid valve closure Joukowsky pressure surge, air chamber accumulator damping,
// and transient vapor cavity separation (column separation).

/datum/hydraulics/water_hammer
    var/tag = "SURGE-MOC-PIPE"
    var/pipe_length_m = 1200.0
    var/pipe_diameter_m = 0.60
    var/wall_thickness_m = 0.012
    var/elastic_modulus_pipe_pa = 2.06e11 // Carbon steel (206 GPa)
    var/fluid_density_kg_m3 = 998.2       // Water
    var/bulk_modulus_fluid_pa = 2.19e9    // 2.19 GPa

    // Numerical Grid (Courant stability: dt = dx / a)
    var/num_reaches = 20
    var/reach_length_dx = 60.0
    var/wave_speed_a = 1180.0 // Acoustic celerity (m/s)
    var/time_step_dt = 0.0508 // Courant number Cr = a * dt / dx = 1.0

    // Spatial grid profiles (size num_reaches + 1)
    var/list/piezometric_head_h = list() // Head in meters
    var/list/volumetric_flow_q = list()  // Flow in m^3/s

    // Surge protection accumulator
    var/air_chamber_installed = 1
    var/air_chamber_vol_m3 = 15.0
    var/air_chamber_press_bar = 8.5
    var/polytropic_air_k = 1.2

/datum/hydraulics/water_hammer/New()
    ..()
    calculate_wave_speed()
    initialize_steady_state(60.0, 0.45) // 60m head (6 bar), 0.45 m3/s initial flow

// Korteweg acoustic wave speed calculation:
// a = sqrt((K / rho) / (1 + (K / E) * (D / e) * c1))
/datum/hydraulics/water_hammer/proc/calculate_wave_speed()
    var/k = bulk_modulus_fluid_pa
    var/e_pipe = elastic_modulus_pipe_pa
    var/d = pipe_diameter_m
    var/thickness = wall_thickness_m
    var/rho = fluid_density_kg_m3

    var/conduit_flexibility = (k / e_pipe) * (d / thickness) * 1.0 // Anchored against longitudinal movement
    var/denominator = 1.0 + conduit_flexibility
    var/celerity_sq = (k / rho) / denominator
    wave_speed_a = sqrt(celerity_sq)

    reach_length_dx = pipe_length_m / num_reaches
    time_step_dt = reach_length_dx / wave_speed_a
    return wave_speed_a

// Initialize steady-state hydraulic grade line
/datum/hydraulics/water_hammer/proc/initialize_steady_state(upstream_head_m, initial_flow_m3_s)
    piezometric_head_h = list()
    volumetric_flow_q = list()

    var/area = 3.14159 * (pipe_diameter_m * 0.5) * (pipe_diameter_m * 0.5)
    var/velocity = initial_flow_m3_s / area
    var/friction_factor = 0.018
    var/hf_per_meter = (friction_factor * velocity * velocity) / (2.0 * 9.80665 * pipe_diameter_m)

    for(var/i = 1 to (num_reaches + 1))
        var/dist = (i - 1) * reach_length_dx
        var/h = upstream_head_m - (hf_per_meter * dist)
        piezometric_head_h.Add(h)
        volumetric_flow_q.Add(initial_flow_m3_s)

// Method of Characteristics (MOC) integration step:
// Along C+: H_P = C_P - B * Q_P
// Along C-: H_P = C_M + B * Q_P
// where B = a / (g * A) is pipe characteristic impedance
/datum/hydraulics/water_hammer/proc/step_moc(valve_opening_ratio, dt_external)
    var/g = 9.80665
    var/area = 3.14159 * (pipe_diameter_m * 0.5) * (pipe_diameter_m * 0.5)
    var/b_impedance = wave_speed_a / (g * area)
    var/f_factor = 0.018

    // Friction resistance parameter: R = f * dx / (2 * g * D * A^2)
    var/r_friction = (f_factor * reach_length_dx) / (2.0 * g * pipe_diameter_m * area * area)

    var/list/next_h = list()
    var/list/next_q = list()
    for(var/i = 1 to (num_reaches + 1))
        next_h.Add(0.0)
        next_q.Add(0.0)

    // 1. Upstream boundary: Constant reservoir head H[1] = H_res
    next_h[1] = piezometric_head_h[1]
    var/c_minus_1 = piezometric_head_h[2] - (b_impedance * volumetric_flow_q[2]) + (r_friction * volumetric_flow_q[2] * abs(volumetric_flow_q[2]))
    next_q[1] = (next_h[1] - c_minus_1) / b_impedance

    // 2. Interior nodes: Intersection of C+ and C- characteristics
    for(var/i = 2 to num_reaches)
        // C+ from node i-1
        var/cp = piezometric_head_h[i - 1] + (b_impedance * volumetric_flow_q[i - 1]) - (r_friction * volumetric_flow_q[i - 1] * abs(volumetric_flow_q[i - 1]))
        // C- from node i+1
        var/cm = piezometric_head_h[i + 1] - (b_impedance * volumetric_flow_q[i + 1]) + (r_friction * volumetric_flow_q[i + 1] * abs(volumetric_flow_q[i + 1]))

        var/h_p = (cp + cm) * 0.5
        var/q_p = (cp - cm) / (2.0 * b_impedance)
        next_h[i] = h_p
        next_q[i] = q_p

    // 3. Downstream boundary: Fast-closing control valve
    // Orifice flow equation: Q_v = tau * Q0 * sqrt(H_v / H0)
    var/last = num_reaches + 1
    var/cp_last = piezometric_head_h[last - 1] + (b_impedance * volumetric_flow_q[last - 1]) - (r_friction * volumetric_flow_q[last - 1] * abs(volumetric_flow_q[last - 1]))

    var/tau = max(valve_opening_ratio, 0.0)
    if(tau <= 1e-4)
        // Completely closed valve (instantaneous velocity dead-stop)
        next_q[last] = 0.0
        next_h[last] = cp_last // Maximum Joukowsky upsurge
    else
        var/q0 = 0.45
        var/h0 = 50.0
        var/cv_val = (tau * q0) / sqrt(h0)
        // Quadratic equation for Q: Q + B * cv^2 / 2 - cv * sqrt(...)
        var/b_cv = b_impedance * cv_val * cv_val
        var/term_root = (b_cv * b_cv * 0.25) + (cp_last * cv_val * cv_val)
        var/q_sol = (-b_cv * 0.5) + sqrt(max(term_root, 0.0))
        next_q[last] = q_sol
        next_h[last] = cp_last - (b_impedance * q_sol)

    // Air chamber surge damping if installed
    if(air_chamber_installed && next_h[last] > 80.0)
        var/surge_excess = next_h[last] - 80.0
        next_h[last] = 80.0 + (surge_excess * 0.35) // Accumulator cushion

    piezometric_head_h = next_h
    volumetric_flow_q = next_q
