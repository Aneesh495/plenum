// Atmospheric Toxic & Flammable Gas Dispersion (Gaussian Plume)
//
// Implements EPA / Turner Gaussian plume atmospheric dispersion equations
// for accidental chemical releases (H2S, NH3, Cl2, CH4). Formulates Pasquill-Gifford
// atmospheric stability classes (A through F), Briggs downwind dispersion coefficients
// (sigma_y, sigma_z), ground reflection, crosswind concentration profiles, and
// emergency response planning guidelines (ERPG-1, ERPG-2, ERPG-3, IDLH hazard zones).

/datum/safety/toxic_dispersion
    var/tag = "PLUME-DISPERSION-MODEL"
    var/chemical_name = "H2S" // Hydrogen Sulfide
    var/molecular_weight = 34.08
    var/release_rate_kg_s = 2.50 // Continuous release rate Q
    var/effective_release_height_m = 12.0 // Stack / leak height H

    // Meteorology
    var/wind_speed_m_s = 3.5 // Wind at 10m elevation
    var/wind_direction_deg = 225.0 // Blowing from Southwest
    var/stability_class = "D" // Pasquill Class: A=Very Unstable, D=Neutral, F=Stable
    var/ambient_temp_k = 293.15
    var/ambient_press_kpa = 101.325

    // Toxic Threshold Criteria (ppm) for H2S
    var/erpg1_ppm = 0.1   // Mild odor perception
    var/erpg2_ppm = 30.0  // Irreversible adverse health effects threshold
    var/erpg3_ppm = 100.0 // Life-threatening threshold
    var/idlh_ppm = 100.0  // Immediately Dangerous to Life or Health

/datum/safety/toxic_dispersion/New()
    ..()

// Briggs rural downwind dispersion coefficients: sigma_y(x) and sigma_z(x) in meters
/datum/safety/toxic_dispersion/proc/calculate_dispersion_sigmas(downwind_distance_x_m)
    var/x = max(downwind_distance_x_m, 10.0)
    var/sigma_y = 0.0
    var/sigma_z = 0.0

    switch(stability_class)
        if("A") // Extremely unstable
            sigma_y = 0.22 * x * sqrt(1.0 + 0.0001 * x)
            sigma_z = 0.20 * x
        if("B") // Moderately unstable
            sigma_y = 0.16 * x * sqrt(1.0 + 0.0001 * x)
            sigma_z = 0.12 * x
        if("C") // Slightly unstable
            sigma_y = 0.11 * x * sqrt(1.0 + 0.0001 * x)
            sigma_z = 0.08 * x * sqrt(1.0 + 0.0002 * x)
        if("D") // Neutral (overcast / high wind)
            sigma_y = 0.08 * x * sqrt(1.0 + 0.0001 * x)
            sigma_z = 0.06 * x * sqrt(1.0 + 0.0015 * x)
        if("E") // Slightly stable
            sigma_y = 0.06 * x * sqrt(1.0 + 0.0001 * x)
            sigma_z = 0.03 * x * (1.0 + 0.0003 * x)
        if("F") // Moderately stable (nighttime light wind)
            sigma_y = 0.04 * x * sqrt(1.0 + 0.0001 * x)
            sigma_z = 0.016 * x * (1.0 + 0.0003 * x)

    return list("sy" = max(sigma_y, 1.0), "sz" = max(sigma_z, 0.5))

// Gaussian Plume Ground-Level Concentration:
// C(x, y, 0) = (Q / (pi * u * sy * sz)) * exp(-y^2 / (2 * sy^2)) * exp(-H^2 / (2 * sz^2))
// Returns concentration in mg/m^3
/datum/safety/toxic_dispersion/proc/calculate_concentration_mg_m3(downwind_x, crosswind_y)
    var/list/sigmas = calculate_dispersion_sigmas(downwind_x)
    var/sy = sigmas["sy"]
    var/sz = sigmas["sz"]

    var/u = max(wind_speed_m_s, 0.5)
    var/q = release_rate_kg_s * 1e6 // Convert kg/s to mg/s

    var/pi_val = 3.141592653589793
    var/prefactor = q / (pi_val * u * sy * sz)

    var/exp_y = exp(-(crosswind_y * crosswind_y) / (2.0 * sy * sy))
    var/exp_z = exp(-(effective_release_height_m * effective_release_height_m) / (2.0 * sz * sz))

    var/c_mg_m3 = prefactor * exp_y * exp_z
    return c_mg_m3

// Convert mass concentration (mg/m^3) to volume mixing ratio (ppm):
// ppm = (C_mg_m3 * 24.45 / MW) * (T / 298.15) * (101.325 / P)
/datum/safety/toxic_dispersion/proc/convert_mg_m3_to_ppm(c_mg_m3)
    var/molar_vol = 24.45 // L/mol at STP
    var/ppm = (c_mg_m3 * molar_vol / molecular_weight) * (ambient_temp_k / 298.15) * (101.325 / ambient_press_kpa)
    return max(ppm, 0.0)

// Find downwind hazard footprint distance for a target threshold in ppm
/datum/safety/toxic_dispersion/proc/find_hazard_boundary_distance(target_ppm)
    var/x_low = 10.0
    var/x_high = 10000.0 // 10 km max search
    var/target_mg_m3 = (target_ppm * molecular_weight / 24.45)

    for(var/iter = 1 to 20)
        var/x_mid = (x_low + x_high) * 0.5
        var/c_mid = calculate_concentration_mg_m3(x_mid, 0.0) // Centerline y=0

        if(c_mid > target_mg_m3)
            x_low = x_mid // Plume is still higher than threshold: look further downwind
        else
            x_high = x_mid

    return (x_low + x_high) * 0.5
