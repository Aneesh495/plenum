// Catalytic Naphtha Reforming and Hydroprocessing Reactor Model
//
// Implements multi-tube fixed-bed radial flow catalytic reforming of heavy naphtha
// to high-octane reformate and pure hydrogen. Models simultaneous endothermic
// dehydrogenation of naphthenes to aromatics, dehydrocyclization of paraffins,
// isomerization of normal paraffins to isoparaffins, hydrocracking to light ends (C1-C4),
// Ergun equation catalyst bed pressure drop, and deactivating coke deposition kinetics.

/datum/model/catalytic_reformer
    var/tag = "CRU-100"
    var/bed_diameter_m = 2.8
    var/bed_length_m = 6.5
    var/catalyst_mass_kg = 18500.0 // Platinum-Rhenium on chlorinated alumina (Pt-Re/Al2O3)
    var/pellet_diameter_m = 0.0016
    var/bed_voidage = 0.38

    // Operating states
    var/inlet_temp_k = 783.15 // 510 C
    var/inlet_press_bar = 28.5
    var/recycle_ratio_h2_hc = 4.5 // Molar H2 to hydrocarbon ratio

    // Feed composition (mole fractions)
    var/paraffins = 0.52
    var/naphthenes = 0.38
    var/aromatics = 0.10

    // Outlet yields
    var/reformate_ron = 101.5 // Research Octane Number
    var/h2_yield_wt_pct = 3.4
    var/c5_plus_yield_wt_pct = 87.2
    var/coke_deposition_rate_kg_hr = 0.045
    var/cumulative_coke_wt_pct = 1.25

/datum/model/catalytic_reformer/New()
    ..()

// Reaction kinetics step using Arrhenius rate constants
/datum/model/catalytic_reformer/proc/step_kinetics(dt_sec, feed_rate_bpd = 25000.0)
    var/r_gas = 8.314462618
    var/t = inlet_temp_k

    // 1. Dehydrogenation of Naphthenes to Aromatics (Endothermic: Delta H ~ +210 kJ/mol)
    // Rate: r_deh = k_deh * (P_N - P_A * P_H2^3 / K_eq)
    var/k_deh = 1.45e6 * exp(-138000.0 / (r_gas * t))
    var/delta_n = k_deh * naphthenes * 0.05 * dt_sec
    delta_n = min(delta_n, naphthenes * 0.95)
    naphthenes -= delta_n
    aromatics += delta_n

    // Endothermic temperature drop along bed
    var/delta_t_endotherm = (delta_n * 210000.0) / (catalyst_mass_kg * 0.92)
    inlet_temp_k = max(inlet_temp_k - (delta_t_endotherm * 0.1), 740.0)

    // 2. Isomerization of n-Paraffins to iso-Paraffins (Slightly Exothermic: Delta H ~ -8 kJ/mol)
    var/k_iso = 3.2e4 * exp(-85000.0 / (r_gas * t))
    var/iso_rate = k_iso * paraffins * 0.02 * dt_sec

    // 3. Hydrocracking to C1-C4 gases (Exothermic: Delta H ~ -55 kJ/mol)
    var/k_hyd = 8.8e5 * exp(-145000.0 / (r_gas * t))
    var/crack_rate = k_hyd * paraffins * (1.0 / max(recycle_ratio_h2_hc, 1.0)) * 0.01 * dt_sec
    paraffins = max(paraffins - crack_rate, 0.05)

    // 4. Coke deposition on Pt-Re acid and metal sites
    // Deactivation rate increases at low H2 partial pressure and elevated temperature
    var/coke_fac = exp(12.0 * (t - 773.15) / 773.15) / max(recycle_ratio_h2_hc, 0.5)
    var/delta_coke = (coke_fac * 0.0001) * dt_sec
    cumulative_coke_wt_pct += delta_coke

    // Catalyst activity decay factor: a = exp(-alpha * C_coke)
    var/activity = exp(-0.45 * cumulative_coke_wt_pct)

    // Research Octane Number calculation based on aromatic content and branching
    reformate_ron = min(85.0 + (aromatics * 32.0) + (iso_rate * 5.0) * activity, 106.0)
    h2_yield_wt_pct = 2.0 + (aromatics * 3.5) * activity
    c5_plus_yield_wt_pct = max(94.0 - (crack_rate * 150.0), 75.0)

// Pressure drop calculation across packed bed via Ergun equation:
// dP/L = 150 * mu * (1 - eps)^2 * v / (eps^3 * d_p^2) + 1.75 * rho * (1 - eps) * v^2 / (eps^3 * d_p)
/datum/model/catalytic_reformer/proc/calculate_ergun_pressure_drop(gas_velocity_m_s, gas_density_kg_m3, gas_viscosity_pa_s)
    var/eps = bed_voidage
    var/dp = pellet_diameter_m
    var/v = gas_velocity_m_s
    var/rho = gas_density_kg_m3
    var/mu = gas_viscosity_pa_s

    var/eps3 = eps * eps * eps
    var/one_minus_eps = 1.0 - eps

    var/viscous_term = (150.0 * mu * (one_minus_eps * one_minus_eps) * v) / (eps3 * dp * dp)
    var/inertial_term = (1.75 * rho * one_minus_eps * v * v) / (eps3 * dp)

    var/dp_per_meter = viscous_term + inertial_term
    var/total_dp_pa = dp_per_meter * bed_length_m
    return total_dp_pa / 100000.0 // Return in bar

// Regeneration purge cycle: burn off coke deposit with diluted 0.8% O2 in N2
/datum/model/catalytic_reformer/proc/regenerate_catalyst(purge_hours = 24.0)
    var/burn_fraction = min(purge_hours / 24.0, 1.0)
    cumulative_coke_wt_pct = cumulative_coke_wt_pct * (1.0 - (burn_fraction * 0.92))
    return cumulative_coke_wt_pct
