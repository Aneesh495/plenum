// Modular Multilevel Converter (MMC) HVDC Substation
//
// Implements 1000 MW +/- 320 kV Modular Multilevel Converter (MMC) for
// high-voltage direct current (HVDC) transmission and offshore wind intertie.
// Models 3-phase 6-arm topology with 200 half-bridge sub-modules (SM) per arm,
// Nearest Level Modulation (NLM), sub-module capacitor voltage balancing,
// Circulating Current Suppression Controller (CCSC), and decoupled P-Q / Vdc-Q vectors.

/datum/model/hvdc_converter
    var/tag = "MMC-HVDC-STA-01"
    var/rated_power_mw = 1000.0
    var/dc_voltage_kv = 640.0 // +/- 320 kV pole-to-pole
    var/ac_nominal_kv = 330.0 // 330 kV grid intertie
    var/num_submodules_per_arm = 200
    var/sm_nominal_capacitance_uf = 7500.0
    var/sm_nominal_voltage_v = 3200.0 // 3.2 kV per capacitor
    var/arm_inductance_mh = 50.0
    var/arm_resistance_ohm = 0.85

    // Operating setpoints and measurements
    var/control_mode = "VDC_Q" // "VDC_Q" (slack converter) or "P_Q" (power dispatch)
    var/p_order_mw = 750.0
    var/q_order_mvar = 0.0
    var/vdc_order_kv = 640.0

    var/p_measured_mw = 748.2
    var/q_measured_mvar = -2.1
    var/vdc_measured_kv = 639.8
    var/grid_frequency_hz = 50.0

    // Average sub-module capacitor voltages per arm (6 arms)
    // 1=A_upper, 2=A_lower, 3=B_upper, 4=B_lower, 5=C_upper, 6=C_lower
    var/list/arm_sm_voltages = list()
    var/circulating_current_rms_a = 45.0
    var/converter_efficiency = 0.989

/datum/model/hvdc_converter/New()
    ..()
    arm_sm_voltages = list()
    for(var/i = 1 to 6)
        arm_sm_voltages.Add(sm_nominal_voltage_v)

// Nearest Level Modulation (NLM): calculate number of inserted submodules per arm:
// n_upper = N/2 - round(v_ac_ref / v_sm)
// n_lower = N/2 + round(v_ac_ref / v_sm)
/datum/model/hvdc_converter/proc/calculate_inserted_submodules(phase_ac_voltage_v)
    var/v_sm = sm_nominal_voltage_v
    var/half_n = round(num_submodules_per_arm * 0.5)
    var/steps = round(phase_ac_voltage_v / v_sm)
    var/n_upper = min(max(half_n - steps, 0), num_submodules_per_arm)
    var/n_lower = min(max(half_n + steps, 0), num_submodules_per_arm)
    return list(n_upper, n_lower)

// Circulating Current Suppression Control (CCSC)
// Mitigates double-frequency (100 Hz / 120 Hz) negative-sequence circulating currents in arms
/datum/model/hvdc_converter/proc/step_ccsc(dt_sec)
    // Resonant bandpass filter on arm currents
    var/i_diff_peak = 65.0 // Peak differential arm current
    var/gain_ccsc = 15.0
    var/damping = 0.85
    circulating_current_rms_a = max(circulating_current_rms_a * damping - (gain_ccsc * 0.02 * dt_sec), 8.0)
    return circulating_current_rms_a

// Dynamic converter step with vector current control (d-q frame)
/datum/model/hvdc_converter/proc/step_converter(dt_sec)
    // 1. DC Voltage or Active Power Control Loop
    if(control_mode == "VDC_Q")
        var/v_err = vdc_order_kv - vdc_measured_kv
        var/p_delta = v_err * 85.0 * dt_sec
        p_measured_mw = p_measured_mw + p_delta
        vdc_measured_kv = vdc_measured_kv + (p_delta * 0.015)
    else
        var/p_err = p_order_mw - p_measured_mw
        p_measured_mw = p_measured_mw + (p_err * 8.0 * dt_sec)

    // 2. Reactive Power Control Loop
    var/q_err = q_order_mvar - q_measured_mvar
    q_measured_mvar = q_measured_mvar + (q_err * 12.0 * dt_sec)

    // 3. Submodule Capacitor Voltage Dynamics:
    // dV_cap/dt = (I_arm * n_inserted) / (C_sm * N)
    var/i_dc = (p_measured_mw * 1000.0) / max(vdc_measured_kv, 1.0)
    var/i_arm_dc = i_dc / 3.0 // 3 phases

    for(var/a = 1 to 6)
        var/c_total_f = sm_nominal_capacitance_uf * 1e-6
        var/delta_v = (i_arm_dc * 0.5 * dt_sec) / (c_total_f * num_submodules_per_arm * 10.0)
        // Alternating ripple
        var/ripple = (a % 2 == 1) ? delta_v : -delta_v
        arm_sm_voltages[a] = min(max(arm_sm_voltages[a] + ripple, 2800.0), 3600.0)

    // 4. Circulating current suppression
    step_ccsc(dt_sec)
