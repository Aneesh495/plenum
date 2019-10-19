// Generation-IV Small Modular Reactor (SMR) Neutronics & Thermal-Hydraulics
//
// Implements integral pressurized water SMR core (160 MWth / 50 MWe).
// Formulates 6-delayed-neutron group point reactor kinetics (PRKE),
// prompt neutron generation lifetime, negative Doppler fuel temperature
// reactivity feedback, moderator density feedback, Iodine-135 / Xenon-135
// fission product poisoning dynamics, control rod drive mechanism (CRDM),
// and primary loop buoyancy-driven natural circulation.

/datum/model/nuclear_smr
    var/tag = "SMR-CORE-01"
    var/thermal_power_mw = 160.0
    var/rated_power_mw = 160.0
    var/neutron_flux_norm = 1.0 // Normalized to 1.0 at 100% full power

    // PRKE Kinetic Parameters
    var/prompt_lifetime_sec = 0.000025 // Lambda = 2.5e-5 seconds
    var/total_delayed_beta = 0.00650   // Beta_eff = 650 pcm

    // 6-group delayed neutron precursor fractions (beta_i) and decay constants (lambda_i, s^-1)
    var/list/beta_groups = list(0.000215, 0.001424, 0.001274, 0.002568, 0.000748, 0.000271)
    var/list/lambda_groups = list(0.0124, 0.0305, 0.111, 0.301, 1.14, 3.01)
    var/list/precursor_concentrations = list()

    // Reactivity components (in delta k / k)
    var/reactivity_total = 0.0
    var/reactivity_control_rods = 0.0 // Negative insertion
    var/control_rod_insertion_pct = 25.0 // 0% = fully withdrawn, 100% = scram
    var/rod_worth_total = -0.055 // -5500 pcm total shutdown margin

    // Thermal feedbacks
    var/fuel_temp_k = 850.0
    var/moderator_temp_k = 573.15 // 300 C
    var/coeff_doppler_fuel = -0.000028 // -2.8 pcm / K
    var/coeff_moderator = -0.000150   // -15.0 pcm / K

    // Xenon-135 / Iodine-135 poisoning
    var/iodine_conc = 1.0 // Normalized
    var/xenon_conc = 1.0
    var/lambda_iodine = 0.0000287 // 6.57 hr half-life
    var/lambda_xenon = 0.0000209  // 9.14 hr half-life
    var/sigma_xenon_barns = 2600000.0 // Microscopic absorption cross section
    var/xenon_worth = -0.028 // -2800 pcm at equilibrium

    // Primary Loop Thermal-Hydraulics
    var/primary_pressure_bar = 155.0 // 15.5 MPa
    var/core_inlet_temp_k = 565.0
    var/core_outlet_temp_k = 595.0
    var/coolant_mass_flow_kg_s = 850.0
    var/scram_tripped = 0

/datum/model/nuclear_smr/New()
    ..()
    precursor_concentrations = list()
    for(var/i = 1 to 6)
        // Equilibrium concentration: C_i0 = (beta_i / (lambda_i * prompt_lifetime)) * n0
        var/eq_c = beta_groups[i] / (lambda_groups[i] * prompt_lifetime_sec)
        precursor_concentrations.Add(eq_c)

// SCADA manual or automatic reactor trip (SCRAM)
/datum/model/nuclear_smr/proc/trigger_scram()
    scram_tripped = 1
    control_rod_insertion_pct = 100.0
    reactivity_control_rods = rod_worth_total

// Step PRKE kinetics and thermal feedbacks
/datum/model/nuclear_smr/proc/step_core(dt_sec)
    // 1. Control rod insertion position to reactivity
    if(scram_tripped)
        control_rod_insertion_pct = min(control_rod_insertion_pct + (40.0 * dt_sec), 100.0)
    var/rod_frac = control_rod_insertion_pct / 100.0
    reactivity_control_rods = rod_worth_total * rod_frac

    // 2. Feedback reactivities
    var/delta_rho_fuel = coeff_doppler_fuel * (fuel_temp_k - 850.0)
    var/delta_rho_mod = coeff_moderator * (moderator_temp_k - 573.15)
    var/delta_rho_xe = (xenon_conc - 1.0) * xenon_worth

    reactivity_total = reactivity_control_rods + delta_rho_fuel + delta_rho_mod + delta_rho_xe

    // 3. Point Kinetics ODE Step:
    // dn/dt = ((rho - beta)/Lambda) * n + sum(lambda_i * C_i)
    // dC_i/dt = (beta_i / Lambda) * n - lambda_i * C_i
    var/sum_delayed = 0.0
    for(var/i = 1 to 6)
        sum_delayed += lambda_groups[i] * precursor_concentrations[i]

    var/dn_dt = (((reactivity_total - total_delayed_beta) / prompt_lifetime_sec) * neutron_flux_norm) + sum_delayed
    neutron_flux_norm = max(neutron_flux_norm + (dn_dt * dt_sec), 1e-6)
    thermal_power_mw = rated_power_mw * neutron_flux_norm

    // Update precursors
    for(var/i = 1 to 6)
        var/dc_dt = ((beta_groups[i] / prompt_lifetime_sec) * neutron_flux_norm) - (lambda_groups[i] * precursor_concentrations[i])
        precursor_concentrations[i] = max(precursor_concentrations[i] + (dc_dt * dt_sec), 0.0)

    // 4. Iodine-135 and Xenon-135 ODEs
    // dI/dt = gamma_I * Sigma_f * phi - lambda_I * I
    // dXe/dt = gamma_Xe * Sigma_f * phi + lambda_I * I - lambda_Xe * Xe - sigma_a_Xe * phi * Xe
    var/di_dt = (0.061 * neutron_flux_norm) - (lambda_iodine * iodine_conc)
    var/dxe_dt = (0.002 * neutron_flux_norm) + (lambda_iodine * iodine_conc) - (lambda_xenon * xenon_conc) - (0.05 * neutron_flux_norm * xenon_conc)
    iodine_conc = max(iodine_conc + (di_dt * dt_sec * 3600.0), 0.0)
    xenon_conc = max(xenon_conc + (dxe_dt * dt_sec * 3600.0), 0.0)

    // 5. Thermal-Hydraulics Core Heat Balance
    // Q = m_dot * cp * (T_out - T_in)
    var/cp_coolant = 5.2 // kJ / (kg * K) compressed water at 15.5 MPa
    var/delta_t_coolant = (thermal_power_mw * 1000.0) / max(coolant_mass_flow_kg_s * cp_coolant, 10.0)
    core_outlet_temp_k = core_inlet_temp_k + delta_t_coolant
    moderator_temp_k = (core_inlet_temp_k + core_outlet_temp_k) * 0.5

    // Fuel temperature dynamics (thermal capacitance)
    var/target_fuel_t = moderator_temp_k + (thermal_power_mw * 1.75)
    fuel_temp_k = fuel_temp_k + (target_fuel_t - fuel_temp_k) * 0.20 * dt_sec

    // Passive decay heat if tripped: Wigner-Way formula P_decay ~ 0.066 * P0 * t^(-0.2)
    if(scram_tripped && thermal_power_mw < 10.0)
        thermal_power_mw = max(thermal_power_mw, rated_power_mw * 0.045)
