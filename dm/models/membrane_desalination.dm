// Seawater Reverse Osmosis (SWRO) Membrane Desalination & Energy Recovery
//
// Implements large-scale seawater desalination facility (50,000 m3/day).
// Formulates Solution-Diffusion membrane transport (water flux J_w and salt flux J_s),
// concentration polarization modulus (CP), Van 't Hoff / Pitzer osmotic pressure,
// membrane compaction and biological fouling decay, and isobaric Pressure Exchanger (PX)
// Energy Recovery Device (ERD) with 96% hydraulic energy transfer efficiency.

/datum/model/membrane_desalination
    var/tag = "SWRO-TRAIN-A"
    var/num_pressure_vessels = 180
    var/elements_per_vessel = 7 // 8-inch spiral-wound polyamide elements
    var/membrane_area_total_m2 = 47880.0

    // Membrane Transport Properties (polyamide thin-film composite)
    var/pure_water_permeability_a = 1.15e-11 // m / (s * Pa)
    var/salt_permeability_b = 2.45e-8        // m / s
    var/fouling_factor = 0.92

    // Feed Seawater Conditions
    var/feed_flow_m3_hr = 4166.0
    var/feed_pressure_bar = 68.0
    var/feed_temp_k = 295.15
    var/feed_salinity_tds_ppm = 38000.0 // 38 g/L (Red Sea / Arabian Gulf baseline)

    // Product Permeate & Reject Brine
    var/permeate_flow_m3_hr = 1875.0 // ~45% recovery
    var/permeate_tds_ppm = 245.0     // Drinking water standard < 500 ppm
    var/brine_flow_m3_hr = 2291.0
    var/brine_salinity_tds_ppm = 69090.0
    var/recovery_ratio = 0.45

    // Energy Recovery Device (Isobaric Pressure Exchanger PX)
    var/erd_efficiency = 0.965
    var/erd_booster_pump_kw = 420.0
    var/specific_energy_kwh_m3 = 2.85 // Specific energy consumption

/datum/model/membrane_desalination/New()
    ..()

// Van 't Hoff osmotic pressure calculation for saline water:
// Pi = i * M * R * T (approx. 0.0805 * TDS_g_L * (T / 298.15) bar)
/datum/model/membrane_desalination/proc/calculate_osmotic_pressure_bar(salinity_ppm, temp_k)
    var/tds_g_l = salinity_ppm * 0.001
    var/temp_ratio = temp_k / 298.15
    var/pi_bar = 0.0805 * tds_g_l * temp_ratio
    return pi_bar

// Solution-Diffusion Model:
// Water flux: J_w = A * (Delta_P - Delta_Pi)
// Salt flux:  J_s = B * (C_feed_membrane - C_permeate)
/datum/model/membrane_desalination/proc/step_transport(dt_sec)
    // 1. Osmotic pressures
    var/pi_feed = calculate_osmotic_pressure_bar(feed_salinity_tds_ppm, feed_temp_k)
    var/pi_brine = calculate_osmotic_pressure_bar(brine_salinity_tds_ppm, feed_temp_k)
    var/pi_avg = (pi_feed + pi_brine) * 0.5
    var/pi_permeate = calculate_osmotic_pressure_bar(permeate_tds_ppm, feed_temp_k)

    // 2. Net Driving Pressure (NDP)
    var/delta_p = feed_pressure_bar - 1.0 // Permeate at atmospheric 1 bar
    var/delta_pi = pi_avg - pi_permeate
    var/ndp_bar = max(delta_p - delta_pi, 0.5)
    var/ndp_pa = ndp_bar * 100000.0

    // 3. Water Flux J_w (m/s) with fouling and temperature correction (TCF)
    // TCF = exp(0.027 * (T - 298.15))
    var/tcf = exp(0.027 * (feed_temp_k - 295.15))
    var/jw = pure_water_permeability_a * ndp_pa * fouling_factor * tcf
    jw = max(jw, 1e-9)

    // 4. Volumetric permeate production
    var/permeate_m3_s = jw * membrane_area_total_m2
    permeate_flow_m3_hr = permeate_m3_s * 3600.0
    recovery_ratio = min(max(permeate_flow_m3_hr / max(feed_flow_m3_hr, 1.0), 0.1), 0.60)
    brine_flow_m3_hr = max(feed_flow_m3_hr - permeate_flow_m3_hr, 100.0)

    // 5. Concentration Polarization Modulus (CP): CP = exp(J_w / k_mass_transfer)
    var/k_mt = 4.5e-5 // Mass transfer coefficient in spacer feed channel
    var/cp_modulus = exp(min(jw / k_mt, 1.5)) // Clamped to prevent mathematical overflow

    // 6. Salt passage and permeate salinity
    var/c_membrane = (feed_salinity_tds_ppm + brine_salinity_tds_ppm) * 0.5 * cp_modulus
    var/js = salt_permeability_b * (c_membrane - permeate_tds_ppm)
    var/c_perm = (js / max(jw, 1e-8))
    permeate_tds_ppm = min(max(c_perm, 80.0), 800.0)

    // Mass balance on reject brine salinity:
    // C_brine = (Feed_flow * C_feed - Perm_flow * C_perm) / Brine_flow
    var/salt_in = feed_flow_m3_hr * feed_salinity_tds_ppm
    var/salt_perm = permeate_flow_m3_hr * permeate_tds_ppm
    brine_salinity_tds_ppm = max((salt_in - salt_perm) / max(brine_flow_m3_hr, 1.0), feed_salinity_tds_ppm)

    // 7. Energy Consumption Calculation
    // High pressure pump power (with PX ERD recycling 55% of hydraulic flow)
    var/hp_pump_flow = feed_flow_m3_hr - (brine_flow_m3_hr * erd_efficiency)
    var/pump_head_m = (feed_pressure_bar * 100000.0) / (1025.0 * 9.80665)
    var/pump_power_kw = (hp_pump_flow * 1025.0 * 9.80665 * pump_head_m) / (3600.0 * 1000.0 * 0.88)
    specific_energy_kwh_m3 = (pump_power_kw + erd_booster_pump_kw) / max(permeate_flow_m3_hr, 1.0)
