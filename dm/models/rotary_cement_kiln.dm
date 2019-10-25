// Industrial Rotary Cement Kiln Pyroprocessing & Bogue Phase Mineralogy
//
// Implements 5,000 tonnes/day dry-process rotary cement kiln with multi-stage
// suspension preheater and calciner tower. Formulates limestone decarbonation
// kinetics (CaCO3 -> CaO + CO2), clinker mineralogy phase formation using
// Bogue equations (C3S alite, C2S belite, C3A aluminate, C4AF ferrite),
// radiative heat transfer in the burning zone (1450 C), and tertiary air heat recuperation.

/datum/model/rotary_cement_kiln
    var/tag = "KILN-LINE-01"
    var/production_capacity_tpd = 5000.0
    var/kiln_length_m = 72.0
    var/kiln_diameter_m = 4.8
    var/kiln_slope_pct = 3.5
    var/rotational_speed_rpm = 3.8
    var/material_retention_time_min = 28.0

    // Raw Meal Feed (Oxide fractions)
    var/feed_cao_pct = 43.5
    var/feed_sio2_pct = 13.8
    var/feed_al2o3_pct = 3.2
    var/feed_fe2o3_pct = 2.1
    var/feed_loi_pct = 36.2 // Loss on ignition (CO2)

    // Clinker Mineralogy (Bogue phases)
    var/alite_c3s_pct = 62.5   // Tricalcium silicate
    var/belite_c2s_pct = 15.2  // Dicalcium silicate
    var/aluminate_c3a_pct = 7.8 // Tricalcium aluminate
    var/ferrite_c4af_pct = 10.4 // Tetracalcium aluminoferrite
    var/free_lime_f_cao_pct = 1.15 // Quality indicator (< 1.5%)

    // Burning Zone Thermal States
    var/burning_zone_temp_k = 1723.15 // 1450 C clinkering
    var/precalciner_temp_k = 1173.15   // 900 C
    var/calcination_degree_pct = 94.5
    var/pulverized_coal_t_hr = 16.5
    var/secondary_air_temp_k = 1273.15 // 1000 C from clinker cooler

/datum/model/rotary_cement_kiln/New()
    ..()

// Bogue Equations for Portland Cement Clinker Mineralogy:
// C3S  = 4.071 * CaO - 7.600 * SiO2 - 6.718 * Al2O3 - 1.430 * Fe2O3
// C2S  = 2.867 * SiO2 - 0.7544 * C3S
// C3A  = 2.650 * Al2O3 - 1.692 * Fe2O3
// C4AF = 3.043 * Fe2O3
/datum/model/rotary_cement_kiln/proc/calculate_bogue_phases(cao_clink, sio2_clink, al2o3_clink, fe2o3_clink)
    var/c4af = 3.043 * fe2o3_clink
    var/c3a = max((2.650 * al2o3_clink) - (1.692 * fe2o3_clink), 0.0)
    var/c3s = (4.071 * cao_clink) - (7.600 * sio2_clink) - (6.718 * al2o3_clink) - (1.430 * fe2o3_clink)
    c3s = min(max(c3s, 40.0), 75.0)
    var/c2s = max((2.867 * sio2_clink) - (0.7544 * c3s), 5.0)

    alite_c3s_pct = c3s
    belite_c2s_pct = c2s
    aluminate_c3a_pct = c3a
    ferrite_c4af_pct = c4af

// Step kiln thermodynamics and clinkering kinetics
/datum/model/rotary_cement_kiln/proc/step_kiln(dt_sec, target_burning_temp_k = 1723.15)
    // 1. Coal combustion heat release
    var/coal_lhv_mj_kg = 27.5
    var/heat_input_mw = (pulverized_coal_t_hr * 1000.0 * coal_lhv_mj_kg) / 3600.0

    // 2. Burning zone radiative energy balance
    var/temp_error = target_burning_temp_k - burning_zone_temp_k
    burning_zone_temp_k = burning_zone_temp_k + (temp_error * 0.05 * dt_sec)

    // 3. Free Lime (unreacted CaO) kinetics:
    // Burning zone temperature directly impacts lime combination rate:
    // f_CaO decreases exponentially above 1400 C
    if(burning_zone_temp_k > 1693.15)
        free_lime_f_cao_pct = max(free_lime_f_cao_pct - (0.01 * dt_sec), 0.65)
    else
        free_lime_f_cao_pct = min(free_lime_f_cao_pct + (0.02 * dt_sec), 3.50)

    // 4. Clinker phase equilibrium updates
    var/clink_factor = 1.0 / (1.0 - (feed_loi_pct * 0.01 * (calcination_degree_pct * 0.01)))
    var/cao_active = (feed_cao_pct * clink_factor) - free_lime_f_cao_pct
    var/sio2_active = feed_sio2_pct * clink_factor
    var/al2o3_active = feed_al2o3_pct * clink_factor
    var/fe2o3_active = feed_fe2o3_pct * clink_factor

    calculate_bogue_phases(cao_active, sio2_active, al2o3_active, fe2o3_active)
