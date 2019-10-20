// Lithium-Ion Battery Electrochemistry and Thermal Runaway Kinetics
//
// Implements 2nd-order dual-RC Thevenin Equivalent Circuit Model (ECM)
// for utility-scale battery energy storage cells (LiFePO4 / NMC).
// Formulates open-circuit voltage OCV(SoC), ohmic overpotential,
// electrochemical charge-transfer polarization (R1-C1), mass-diffusion
// concentration polarization (R2-C2), SEI layer aging capacity fade,
// and Arrhenius thermal runaway self-heating combustion kinetics.

/datum/model/bess_cell
    var/tag = "BESS-CELL-LFP-280AH"
    var/nominal_capacity_ah = 280.0
    var/current_capacity_ah = 278.5
    var/state_of_charge = 0.85 // 0.0 to 1.0
    var/state_of_health = 0.995

    // Thevenin ECM Parameters
    var/r0_ohmic_ohm = 0.00018 // 0.18 mOhm
    var/r1_activation_ohm = 0.00012
    var/c1_activation_farad = 45000.0
    var/r2_diffusion_ohm = 0.00015
    var/c2_diffusion_farad = 120000.0

    // Dynamic states
    var/terminal_voltage_v = 3.32
    var/ocv_v = 3.34
    var/v_rc1 = 0.0
    var/v_rc2 = 0.0
    var/current_amperes = 140.0 // Positive = discharge, negative = charge

    // Thermal States
    var/cell_temp_k = 298.15 // 25 C
    var/cell_mass_kg = 5.45
    var/specific_heat_cp = 1100.0 // J / (kg * K)
    var/cooling_htc_w_k = 4.5
    var/thermal_runaway_active = 0
    var/sei_layer_thickness_nm = 18.5

/datum/model/bess_cell/New()
    ..()

// Non-linear Open Circuit Voltage (OCV) vs SoC curve for LFP cell (flat plateau at 3.28-3.34 V)
/datum/model/bess_cell/proc/calculate_ocv(soc)
    var/s = min(max(soc, 0.001), 0.999)
    // Modified Nernst-Redlich-Kister equation
    var/e0 = 3.20
    var/nernst = 0.025 * log(s / (1.0 - s))
    var/plateau = 0.11 * tanh(18.0 * (s - 0.5)) + 0.05 * s
    var/knee_low = -0.35 * exp(-35.0 * s)
    var/knee_high = 0.25 * exp(45.0 * (s - 1.0))
    return e0 + nernst + plateau + knee_low + knee_high

// Step 2nd-order Thevenin ECM and thermal dynamics
/datum/model/bess_cell/proc/step_cell(dt_sec, current_a)
    current_amperes = current_a

    // 1. Coulomb counting for SoC: dSoC/dt = -I / (Q_nom * 3600)
    var/coulomb_eff = (current_a < 0.0) ? 0.995 : 1.0 // Faradaic charging efficiency
    var/delta_soc = (-current_a * coulomb_eff * dt_sec) / (current_capacity_ah * 3600.0)
    state_of_charge = min(max(state_of_charge + delta_soc, 0.0), 1.0)

    // 2. Open Circuit Voltage
    ocv_v = calculate_ocv(state_of_charge)

    // 3. Dual-RC Overpotentials:
    // dV1/dt = -V1/(R1*C1) + I/C1
    // dV2/dt = -V2/(R2*C2) + I/C2
    var/tau1 = r1_activation_ohm * c1_activation_farad
    var/tau2 = r2_diffusion_ohm * c2_diffusion_farad

    var/dv1 = ((-v_rc1 / max(tau1, 0.001)) + (current_a / c1_activation_farad)) * dt_sec
    var/dv2 = ((-v_rc2 / max(tau2, 0.001)) + (current_a / c2_diffusion_farad)) * dt_sec
    v_rc1 += dv1
    v_rc2 += dv2

    // 4. Terminal Voltage: V_t = OCV - I*R0 - V_rc1 - V_rc2
    // Temperature effect on R0: Arrhenius R0(T) = R0_ref * exp(E_a/R * (1/T - 1/T_ref))
    var/arrhenius_r = exp(2200.0 * ((1.0 / cell_temp_k) - (1.0 / 298.15)))
    var/r0_actual = r0_ohmic_ohm * arrhenius_r

    terminal_voltage_v = ocv_v - (current_a * r0_actual) - v_rc1 - v_rc2

    // 5. Heat Generation Rate: Q_dot = I^2 * R0 + I * (V_rc1 + V_rc2) + T * I * (dOCV/dT)
    var/q_joule = (current_a * current_a * r0_actual) + (abs(current_a) * (abs(v_rc1) + abs(v_rc2)))
    var/q_entropic = cell_temp_k * current_a * (-0.000045) // Reversible entropic heat
    var/q_gen_watts = q_joule + q_entropic

    // 6. Chemical Exothermic Reaction (Thermal Runaway above 393 K / 120 C)
    // SEI decomposition and cathode oxygen release: Arrhenius kinetics
    var/q_chem_watts = 0.0
    if(cell_temp_k > 393.15)
        var/r_gas = 8.314462618
        var/k_runaway = 1.6e15 * exp(-140000.0 / (r_gas * cell_temp_k))
        q_chem_watts = k_runaway * cell_mass_kg * 450.0 // High heat release
        thermal_runaway_active = 1

    // 7. Thermal balance: m * cp * dT/dt = Q_gen + Q_chem - h_cool * (T - T_ambient)
    var/q_cooling = cooling_htc_w_k * (cell_temp_k - 295.15)
    var/dT_dt = (q_gen_watts + q_chem_watts - q_cooling) / (cell_mass_kg * specific_heat_cp)
    cell_temp_k = cell_temp_k + (dT_dt * dt_sec)

    // 8. Solid Electrolyte Interphase (SEI) growth aging
    // dL_sei / dt ~ k_sei * exp(-E_sei / (R * T)) / L_sei
    var/k_sei = 1.2e-13 * exp(-38000.0 / (8.314 * cell_temp_k))
    sei_layer_thickness_nm += (k_sei / max(sei_layer_thickness_nm, 1.0)) * dt_sec * 1e9
    state_of_health = max(1.0 - (sei_layer_thickness_nm - 18.5) * 0.004, 0.60)
    current_capacity_ah = nominal_capacity_ah * state_of_health
