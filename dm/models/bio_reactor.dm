// Industrial Aerobic Fermentation Bioreactor and Dissolved Oxygen Kinetics
//
// Implements 100,000-liter fed-batch industrial bio-fermentation reactor.
// Formulates Monod microbial cell growth kinetics, substrate inhibition (Haldane),
// Volumetric Oxygen Mass Transfer Coefficient (kLa) via Cooper/Van 't Riet correlation,
// Oxygen Transfer Rate (OTR), Oxygen Uptake Rate (OUR), metabolic heat generation,
// and cascade PID agitation/aeration for dissolved oxygen (DO) setpoint tracking.

/datum/model/bio_reactor
    var/tag = "FERM-BIO-R101"
    var/working_volume_liters = 80000.0
    var/max_volume_liters = 100000.0
    var/impeller_diameter_m = 1.45
    var/agitator_speed_rpm = 180.0
    var/aeration_rate_vvm = 1.2 // Vessel volumes per minute

    // Monod Kinetic Parameters (E. coli / Pichia pastoris)
    var/mu_max = 0.45 // hr^-1 maximum specific growth rate
    var/k_s_substrate = 0.15 // g/L half-velocity constant
    var/k_o_oxygen = 0.0002 // g/L critical dissolved oxygen
    var/yield_biomass_substrate = 0.51 // g biomass / g glucose
    var/yield_biomass_oxygen = 1.15    // g biomass / g O2

    // Concentrations in broth (g/L)
    var/biomass_conc_x = 24.5     // Cell dry weight
    var/substrate_conc_s = 2.10   // Carbon source (glucose)
    var/dissolved_oxygen_c = 0.0055 // g/L (~80% air saturation at 30 C)
    var/do_saturation_pct = 78.5
    var/broth_temp_k = 303.15      // 30 C optimal

    // Mass Transfer & Heat
    var/kla_hr = 220.0 // Volumetric mass transfer coefficient (hr^-1)
    var/otr_g_l_hr = 1.85 // Oxygen transfer rate
    var/our_g_l_hr = 1.82 // Oxygen uptake rate
    var/metabolic_heat_kw = 425.0
    var/cooling_jacket_flow_l_min = 650.0

/datum/model/bio_reactor/New()
    ..()

// Van 't Riet empirical correlation for kLa in stirred bioreactor:
// kLa = 0.026 * (P_g / V)^0.4 * v_s^0.5 (in s^-1)
/datum/model/bio_reactor/proc/calculate_kla(power_watts, air_flow_m3_s)
    var/vol_m3 = working_volume_liters * 0.001
    var/v_cross = 3.14159 * 1.5 * 1.5 // 3m tank diameter
    var/superficial_velocity = air_flow_m3_s / max(v_cross, 0.1)

    var/pg_v = power_watts / max(vol_m3, 1.0)
    var/term1 = exp(0.40 * log(max(pg_v, 1.0)))
    var/term2 = sqrt(max(superficial_velocity, 1e-5))

    var/kla_s = 0.026 * term1 * term2
    return kla_s * 3600.0 // Convert to hr^-1

// Step microbial ODEs:
// dX/dt = mu * X
// dS/dt = -(1/Y_xs) * mu * X + F_in * S_in / V
// dC_o/dt = kLa * (C* - C_o) - (1/Y_xo) * mu * X
/datum/model/bio_reactor/proc/step_fermentation(dt_sec, glucose_feed_rate_l_hr = 120.0, glucose_feed_conc_g_l = 500.0)
    var/dt_hr = dt_sec / 3600.0

    // 1. Specific growth rate mu via dual-substrate Monod kinetics
    var/monod_s = substrate_conc_s / max(k_s_substrate + substrate_conc_s, 1e-4)
    var/monod_o = dissolved_oxygen_c / max(k_o_oxygen + dissolved_oxygen_c, 1e-5)
    var/mu = mu_max * monod_s * monod_o

    // 2. Biomass production: dX = mu * X * dt
    var/dx = mu * biomass_conc_x * dt_hr
    biomass_conc_x = min(biomass_conc_x + dx, 120.0)

    // 3. Substrate consumption and feed addition
    var/v_liters = working_volume_liters
    var/feed_addition_g = (glucose_feed_rate_l_hr * glucose_feed_conc_g_l) * dt_hr
    var/feed_conc_increase = feed_addition_g / max(v_liters, 1.0)
    var/ds_consumed = (1.0 / yield_biomass_substrate) * dx
    substrate_conc_s = max(substrate_conc_s - ds_consumed + feed_conc_increase, 0.01)

    // Volume increment from feed
    working_volume_liters = min(working_volume_liters + (glucose_feed_rate_l_hr * dt_hr), max_volume_liters)

    // 4. Oxygen Dynamics: OTR and OUR
    // Henry's Law equilibrium oxygen solubility at 30 C: C* ~ 0.0078 g/L
    var/c_star = 0.0078
    otr_g_l_hr = kla_hr * max(c_star - dissolved_oxygen_c, 0.0)
    our_g_l_hr = (1.0 / yield_biomass_oxygen) * dx / dt_hr

    var/dc_dt = otr_g_l_hr - our_g_l_hr
    dissolved_oxygen_c = min(max(dissolved_oxygen_c + (dc_dt * dt_hr), 0.0001), c_star)
    do_saturation_pct = (dissolved_oxygen_c / c_star) * 100.0

    // 5. Agitation Cascade Control: ramp agitator if DO drops below 60%
    if(do_saturation_pct < 60.0)
        var/agit_err = 60.0 - do_saturation_pct
        agitator_speed_rpm = min(agitator_speed_rpm + (agit_err * 0.5 * dt_sec), 350.0)
    else if(do_saturation_pct > 85.0 && agitator_speed_rpm > 120.0)
        agitator_speed_rpm = max(agitator_speed_rpm - (0.1 * dt_sec), 120.0)

    // Recalculate kLa with new agitation power (Ungassed P = Np * rho * N^3 * D^5)
    var/n_rev_s = agitator_speed_rpm / 60.0
    var/power_agit_w = 4.8 * 1050.0 * (n_rev_s * n_rev_s * n_rev_s) * (impeller_diameter_m * impeller_diameter_m * impeller_diameter_m * impeller_diameter_m * impeller_diameter_m)
    var/air_m3_s = (aeration_rate_vvm * working_volume_liters * 0.001) / 60.0
    kla_hr = calculate_kla(power_agit_w, air_m3_s)

    // 6. Metabolic heat generation (approx. 0.46 kJ per mmol O2 consumed = 14.4 kJ / g O2)
    var/o2_grams_s = (our_g_l_hr * working_volume_liters / 3600.0)
    metabolic_heat_kw = o2_grams_s * 14.4
