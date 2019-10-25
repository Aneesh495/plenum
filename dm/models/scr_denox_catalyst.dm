// Selective Catalytic Reduction (SCR) DeNOx Reactor & Ammonia Slip Control
//
// Implements industrial post-combustion SCR flue gas denitrogenation system.
// Models monolithic honeycomb Vanadium-Tungsten-Titania (V2O5-WO3/TiO2) catalyst,
// Eley-Rideal surface reaction kinetics, ammonia-to-NOx stoichiometric molar ratio,
// temperature window bounds (310 C to 400 C), catalyst deactivation (SO2 oxidation
// and alkali poisoning), and tight ammonia slip regulation to prevent air preheater
// ammonium bisulfate (ABS) fouling.

/datum/model/scr_denox
    var/tag = "SCR-REACTOR-UNIT"
    var/catalyst_volume_m3 = 185.0
    var/specific_surface_area_m2_m3 = 850.0 // Honeycomb pitch ~ 7.4 mm
    var/area_velocity_av_m_hr = 14.5        // AV = Q_flue / A_cat
    var/catalyst_activity_k_m_hr = 48.0     // Intrinsic rate constant

    // Flue Gas Inlet Conditions
    var/flue_gas_flow_nm3_hr = 420000.0
    var/inlet_temp_k = 623.15 // 350 C (optimal catalytic window)
    var/inlet_nox_ppm = 280.0
    var/inlet_o2_percent = 3.8
    var/inlet_so2_ppm = 120.0

    // Ammonia Injection Grid (AIG)
    var/nh3_injection_kg_hr = 95.5
    var/ammonia_nox_molar_ratio = 0.92 // NSR (Normalized Stoichiometric Ratio)

    // Outlet Stack Emissions
    var/outlet_nox_ppm = 22.4 // >90% reduction efficiency
    var/ammonia_slip_ppm = 1.45 // Strict environmental limit < 2.0 ppm
    var/denox_efficiency_pct = 92.0
    var/abs_formation_risk = 0 // 1 if ammonium bisulfate condensation temperature reached

/datum/model/scr_denox/New()
    ..()

// Ammonium Bisulfate (ABS) deposition temperature calculation:
// T_abs = 604.5 - 28.5 * ln(P_NH3 * P_SO3)
/datum/model/scr_denox/proc/calculate_abs_deposition_temp_k(nh3_ppm, so2_ppm)
    var/so3_ppm = so2_ppm * 0.012 // ~1.2% SO2 to SO3 oxidation over V2O5 catalyst
    var/p_prod = max(nh3_ppm * so3_ppm, 0.001)
    var/t_abs_c = 185.0 + (12.5 * log(p_prod))
    return t_abs_c + 273.15

// Eley-Rideal Catalytic Reduction Efficiency:
// DeNOx = 1 - exp(-k * A_v) where k is corrected for temperature and O2
/datum/model/scr_denox/proc/calculate_reduction_efficiency(temp_k, o2_pct)
    // Arrhenius temperature correction on catalyst rate constant k
    var/r_gas = 8.314462618
    var/e_act = 55000.0 // 55 kJ/mol
    var/temp_factor = exp((-e_act / r_gas) * ((1.0 / temp_k) - (1.0 / 623.15)))

    // Oxygen order dependence ~ 0.5
    var/o2_factor = sqrt(max(o2_pct / 3.0, 0.1))

    var/k_actual = catalyst_activity_k_m_hr * temp_factor * o2_factor
    var/ratio = k_actual / max(area_velocity_av_m_hr, 1.0)
    var/eff_ideal = 1.0 - exp(-ratio)
    return min(max(eff_ideal, 0.1), 0.985)

// Step SCR reaction and Ammonia Injection Grid (AIG) controller
/datum/model/scr_denox/proc/step_scr(dt_sec, target_outlet_nox_ppm = 25.0)
    // 1. Stoichiometric ammonia mass requirement
    // 1 mol NH3 reacts with 1 mol NO (MW NH3 = 17.03, MW NO = 30.01)
    var/flue_nm3_s = flue_gas_flow_nm3_hr / 3600.0
    var/moles_nox_s = (flue_nm3_s / 0.022414) * (inlet_nox_ppm * 1e-6)

    // Feedforward + Feedback control on AIG valve
    var/nox_error = outlet_nox_ppm - target_outlet_nox_ppm
    var/delta_nsr = (nox_error / target_outlet_nox_ppm) * 0.05 * dt_sec
    ammonia_nox_molar_ratio = min(max(ammonia_nox_molar_ratio + delta_nsr, 0.5), 1.05)

    var/target_nh3_mol_s = moles_nox_s * ammonia_nox_molar_ratio
    nh3_injection_kg_hr = target_nh3_mol_s * 0.017031 * 3600.0

    // 2. Catalytic reaction kinetics
    var/eff_kinetic = calculate_reduction_efficiency(inlet_temp_k, inlet_o2_percent)

    // Actual DeNOx is constrained by both kinetics and ammonia availability
    denox_efficiency_pct = min(eff_kinetic, ammonia_nox_molar_ratio) * 100.0
    outlet_nox_ppm = inlet_nox_ppm * (1.0 - (denox_efficiency_pct / 100.0))

    // 3. Ammonia Slip Calculation: Unreacted NH3 exiting the reactor
    var/unreacted_nh3_fraction = max(ammonia_nox_molar_ratio - (denox_efficiency_pct / 100.0), 0.0)
    ammonia_slip_ppm = (inlet_nox_ppm * unreacted_nh3_fraction) + 0.15 // Baseline background

    // 4. Ammonium Bisulfate (ABS) salt deposition alert
    var/t_abs = calculate_abs_deposition_temp_k(ammonia_slip_ppm, inlet_so2_ppm)
    if(inlet_temp_k < t_abs)
        abs_formation_risk = 1
    else
        abs_formation_risk = 0
