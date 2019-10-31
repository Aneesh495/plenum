// Grid-Forming (GFM) Inverter & Virtual Synchronous Machine (VSM)
//
// Implements advanced power conversion system (PCS) controls for battery storage
// and solar microgrids. Formulates Virtual Synchronous Machine (VSM) swing
// equation inertia emulation (J * domega/dt = P_ref - P_e - D_p * delta_omega),
// active power frequency droop (P-f), reactive power voltage droop (Q-V),
// Rate-of-Change-of-Frequency (RoCoF) damping, and seamless islanding transition.

/datum/microgrid/inverter_gfm
    var/tag = "PCS-GFM-INV-01"
    var/rated_power_mva = 10.0
    var/control_mode = "GRID_FORMING_VSM" // "GRID_FORMING_VSM" or "GRID_FOLLOWING_PQ"

    // VSM Virtual Inertia & Damping Parameters
    var/virtual_inertia_h_sec = 4.5  // H = 4.5 seconds
    var/damping_factor_dp = 20.0     // D_p damping factor (pu/pu)
    var/voltage_droop_dq = 0.03      // 3% Q-V droop

    // Frequency and Power States
    var/virtual_rotor_freq_hz = 60.0
    var/grid_nominal_freq_hz = 60.0
    var/virtual_rotor_angle_rad = 0.0
    var/p_order_pu = 0.50
    var/p_electric_pu = 0.498
    var/q_order_pu = 0.0
    var/q_electric_pu = 0.012

    // Voltage and Islanding States
    var/internal_voltage_mag_pu = 1.01
    var/terminal_voltage_pu = 1.002
    var/rocof_hz_s = 0.0
    var/is_islanded = 0

/datum/microgrid/inverter_gfm/New()
    ..()

// VSM Swing Equation Integration:
// 2*H * d(omega_pu)/dt = P_ref - P_e - D_p * (omega_pu - 1.0)
/datum/microgrid/inverter_gfm/proc/step_swing_equation(dt_sec, grid_frequency_hz)
    var/omega_base = 2.0 * 3.14159 * grid_nominal_freq_hz
    var/omega_pu = virtual_rotor_freq_hz / grid_nominal_freq_hz
    var/grid_omega_pu = grid_frequency_hz / grid_nominal_freq_hz

    // Power imbalance: P_accel = P_order - P_e - Damping
    var/p_damping = damping_factor_dp * (omega_pu - grid_omega_pu)
    var/p_accel = p_order_pu - p_electric_pu - p_damping

    // Angular acceleration: d_omega_dt = P_accel / (2 * H)
    var/d_omega_dt = p_accel / (2.0 * max(virtual_inertia_h_sec, 0.1))
    rocof_hz_s = d_omega_dt * grid_nominal_freq_hz

    // Update virtual speed and angle
    var/new_omega_pu = omega_pu + (d_omega_dt * dt_sec)
    virtual_rotor_freq_hz = new_omega_pu * grid_nominal_freq_hz
    virtual_rotor_angle_rad += (virtual_rotor_freq_hz * 2.0 * 3.14159 - omega_base) * dt_sec

// Q-V Voltage Droop:
// E_ref = V_nominal - D_q * (Q_e - Q_ref)
/datum/microgrid/inverter_gfm/proc/step_voltage_droop(terminal_v_pu, dt_sec)
    terminal_voltage_pu = terminal_v_pu
    var/v_target = 1.0 - (voltage_droop_dq * (q_electric_pu - q_order_pu))
    internal_voltage_mag_pu = internal_voltage_mag_pu + (v_target - internal_voltage_mag_pu) * 15.0 * dt_sec
    return internal_voltage_mag_pu

// Step inverter dispatch and autonomous grid support
/datum/microgrid/inverter_gfm/proc/step_inverter(dt_sec, grid_freq_hz, grid_v_pu)
    // 1. Evaluate Islanding status
    if(grid_freq_hz < 57.0 || grid_freq_hz > 63.0 || grid_v_pu < 0.70)
        is_islanded = 1
    else
        is_islanded = 0

    // 2. Solve VSM swing equation
    step_swing_equation(dt_sec, grid_freq_hz)

    // 3. Solve Q-V voltage droop
    step_voltage_droop(grid_v_pu, dt_sec)

    // 4. Electric power delivery to virtual grid coupling inductor (X_vsm ~ 0.15 pu)
    var/x_vsm = 0.15
    var/delta_angle = virtual_rotor_angle_rad
    p_electric_pu = (internal_voltage_mag_pu * grid_v_pu * sin(delta_angle)) / x_vsm
    q_electric_pu = (internal_voltage_mag_pu * (internal_voltage_mag_pu - grid_v_pu * cos(delta_angle))) / x_vsm
