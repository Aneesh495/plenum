// Transformer IEEE C57.91 Dynamic Thermal Loading & Insulation Aging
//
// Implements IEEE C57.91 thermal loading guide for oil-immersed power transformers.
// Formulates top-oil temperature differential rise (Delta Theta_TO) with thermal inertia
// time constant tau_TO, winding hot-spot temperature rise (Delta Theta_H) with time
// constant tau_W, non-linear load ratio K = I / I_rated, Arrhenius thermal aging
// acceleration factor F_AA, and cumulative insulation Loss of Life (LOL) tracking.

/datum/substation/transformer_thermal
    var/tag = "XFMR-100MVA-THERMAL"
    var/mva_rating = 100.0
    var/cooling_class = "ONAF" // ONAN (Natural), ONAF (Forced Air), OFAF (Forced Oil)

    // Nameplate Design Thermal Parameters (IEEE C57.91)
    var/rated_top_oil_rise_k = 45.0
    var/rated_hot_spot_rise_k = 25.0
    var/loss_ratio_r = 5.2 // Ratio of load loss to no-load core loss at rated MVA
    var/oil_time_constant_tau_to_min = 180.0 // 3 hours oil thermal inertia
    var/winding_time_constant_tau_w_min = 7.0 // 7 minutes winding copper inertia

    // Exponents for cooling mode
    var/oil_exponent_n = 0.8
    var/winding_exponent_m = 0.8

    // Dynamic Temperatures (Celsius)
    var/ambient_temp_c = 30.0
    var/top_oil_temp_c = 68.5
    var/hot_spot_temp_c = 94.2 // Must remain below 120 C normal, 140 C emergency
    var/delta_top_oil_rise = 38.5
    var/delta_hot_spot_rise = 25.7

    // Aging & Life Consumption
    var/load_ratio_k = 0.92 // Current load / rated load
    var/aging_acceleration_factor_faa = 0.28 // F_AA = 1.0 at reference 110 C
    var/equivalent_aging_hours = 0.0
    var/percent_loss_of_life = 0.045 // Total insulation life ~ 180,000 hours

/datum/substation/transformer_thermal/New()
    ..()

// Arrhenius Aging Acceleration Factor (FAA) per IEEE C57.91:
// F_AA = exp[ (15000 / 383.15) - (15000 / (Theta_H + 273.15)) ]
// Evaluates rate of cellulose paper insulation degradation relative to reference 110 C
/datum/substation/transformer_thermal/proc/calculate_faa(hot_spot_c)
    var/theta_k = hot_spot_c + 273.15
    var/exponent = (15000.0 / 383.15) - (15000.0 / max(theta_k, 273.15))
    var/faa = exp(min(max(exponent, -15.0), 15.0))
    return faa

// Step transformer thermal ODEs and insulation aging
/datum/substation/transformer_thermal/proc/step_thermal(dt_minutes, load_mva, ambient_c)
    ambient_temp_c = ambient_c
    load_ratio_k = load_mva / max(mva_rating, 1.0)
    var/k = load_ratio_k

    // 1. Ultimate Top-Oil Temperature Rise:
    // Delta_Theta_TO_u = Delta_Theta_TO_rated * [ (K^2 * R + 1) / (R + 1) ]^n
    var/load_factor = ((k * k * loss_ratio_r) + 1.0) / (loss_ratio_r + 1.0)
    var/delta_to_u = rated_top_oil_rise_k * exp(oil_exponent_n * log(max(load_factor, 0.01)))

    // Top-oil dynamic response: d(Delta_TO)/dt = (Delta_TO_u - Delta_TO) / tau_TO
    var/d_to_dt = (delta_to_u - delta_top_oil_rise) / max(oil_time_constant_tau_to_min, 1.0)
    delta_top_oil_rise += d_to_dt * dt_minutes
    top_oil_temp_c = ambient_temp_c + delta_top_oil_rise

    // 2. Ultimate Hot-Spot Temperature Rise over Top-Oil:
    // Delta_Theta_H_u = Delta_Theta_H_rated * K^(2*m)
    var/delta_h_u = rated_hot_spot_rise_k * exp((2.0 * winding_exponent_m) * log(max(k, 0.01)))

    // Winding hot-spot dynamic response: d(Delta_H)/dt = (Delta_H_u - Delta_H) / tau_W
    var/d_h_dt = (delta_h_u - delta_hot_spot_rise) / max(winding_time_constant_tau_w_min, 0.1)
    delta_hot_spot_rise += d_h_dt * dt_minutes
    hot_spot_temp_c = top_oil_temp_c + delta_hot_spot_rise

    // 3. Insulation Aging & Loss of Life (LOL):
    aging_acceleration_factor_faa = calculate_faa(hot_spot_temp_c)
    var/aging_increment_hours = (dt_minutes / 60.0) * aging_acceleration_factor_faa
    equivalent_aging_hours += aging_increment_hours

    // IEEE normal insulation life expectation: 180,000 hours (20.55 years)
    percent_loss_of_life = (equivalent_aging_hours / 180000.0) * 100.0
    return hot_spot_temp_c
