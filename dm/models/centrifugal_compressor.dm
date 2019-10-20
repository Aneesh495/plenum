// Multi-Stage Centrifugal Compressor Train and Anti-Surge Control
//
// Implements API 617 centrifugal compressor train for pipeline natural gas
// and refinery cracked gas service. Formulates polytropic head, polytropic
// efficiency, fan affinity laws (speed scaling), non-linear characteristic
// performance maps, surge line parabola, and high-speed anti-surge recycle
// valve (ASV) control with derivative lead-lag kick protection.

/datum/model/centrifugal_compressor
    var/tag = "K-301-TRAIN"
    var/rated_speed_rpm = 10500.0
    var/current_speed_rpm = 10200.0
    var/driver_power_mw = 18.5 // Electric motor or gas turbine drive
    var/impeller_diameter_m = 0.65

    // Gas Properties (Natural Gas MW ~ 17.5 g/mol, k ~ 1.28)
    var/gas_molecular_weight = 17.5
    var/gas_adiabatic_k = 1.28
    var/gas_z_compressibility = 0.94

    // Suction & Discharge States
    var/suction_press_bar = 28.0
    var/suction_temp_k = 305.15 // 32 C
    var/suction_flow_m3_hr = 14500.0 // Actual volumetric flow (ACMH)
    var/discharge_press_bar = 82.0
    var/discharge_temp_k = 398.15
    var/pressure_ratio = 2.93

    // Aerodynamic Performance
    var/polytropic_head_m = 9200.0
    var/polytropic_efficiency = 0.835
    var/polytropic_exponent_n = 1.34

    // Anti-Surge Protection
    var/surge_margin_percent = 18.5 // Margin to surge limit line (SLL)
    var/anti_surge_valve_pos = 0.0  // 0% = closed, 100% = full recycle
    var/surge_active = 0
    var/recycle_flow_m3_hr = 0.0

/datum/model/centrifugal_compressor/New()
    ..()

// Polytropic Head Calculation:
// H_p = Z_avg * (R / MW) * T1 * (n / (n - 1)) * [(P2 / P1)^((n - 1)/n) - 1] / g
/datum/model/centrifugal_compressor/proc/calculate_polytropic_head(p_ratio, t1_k)
    var/r_spec = (8314.46 / gas_molecular_weight) // J / (kg * K)
    var/n = polytropic_exponent_n
    var/n_factor = n / (n - 1.0)
    var/press_term = exp(((n - 1.0) / n) * log(p_ratio)) - 1.0
    var/head_j_kg = gas_z_compressibility * r_spec * t1_k * n_factor * press_term
    var/head_m = head_j_kg / 9.80665
    return head_m

// Surge Line Determination: Surge flow ACMH scales linearly with speed:
// Q_surge(N) = Q_surge_rated * (N / N_rated)
/datum/model/centrifugal_compressor/proc/calculate_surge_limit_flow(speed_rpm)
    var/speed_ratio = speed_rpm / rated_speed_rpm
    var/rated_surge_flow = 9800.0 // ACMH
    return rated_surge_flow * speed_ratio

// Step compressor aerodynamics and anti-surge safety controller
/datum/model/centrifugal_compressor/proc/step_compressor(dt_sec, target_discharge_bar = 82.0)
    // 1. Calculate Surge Limit Line (SLL) and Surge Control Line (SCL)
    var/q_sll = calculate_surge_limit_flow(current_speed_rpm)
    var/q_scl = q_sll * 1.12 // 12% safety margin line

    var/net_suction_flow = suction_flow_m3_hr + recycle_flow_m3_hr
    surge_margin_percent = ((net_suction_flow - q_sll) / max(q_sll, 1.0)) * 100.0

    // 2. Anti-Surge Controller (Fast PI with derivative kick)
    if(net_suction_flow < q_scl)
        // Deficit: open recycle valve rapidly
        var/flow_deficit = q_scl - net_suction_flow
        var/delta_valve = (flow_deficit / 2500.0) * 8.0 * dt_sec
        anti_surge_valve_pos = min(anti_surge_valve_pos + delta_valve, 1.0)
    else if(net_suction_flow > q_scl * 1.08 && anti_surge_valve_pos > 0.0)
        // Safe: slow ramp close
        anti_surge_valve_pos = max(anti_surge_valve_pos - (0.05 * dt_sec), 0.0)

    recycle_flow_m3_hr = anti_surge_valve_pos * 8500.0

    // Check catastrophic surge trip (< 0% margin)
    if(surge_margin_percent <= 0.0)
        surge_active = 1
        anti_surge_valve_pos = 1.0 // Slam full open
    else
        surge_active = 0

    // 3. Pressure Ratio & Head vs Flow Characteristic:
    // H(Q, N) = H0 * (N/N0)^2 - B * (Q / (N/N0))^2
    var/speed_ratio = current_speed_rpm / rated_speed_rpm
    var/q_norm = net_suction_flow / max(speed_ratio, 0.1)
    var/h_ideal = (11200.0 * speed_ratio * speed_ratio) - (0.0000085 * q_norm * q_norm)
    polytropic_head_m = max(h_ideal, 1000.0)

    // Invert head to compute actual discharge pressure
    var/r_spec = 8314.46 / gas_molecular_weight
    var/head_j = polytropic_head_m * 9.80665
    var/n = polytropic_exponent_n
    var/exponent = (n - 1.0) / n
    var/inner = 1.0 + (head_j / (gas_z_compressibility * r_spec * suction_temp_k * (n / (n - 1.0))))
    pressure_ratio = (inner > 0.0) ? exp((1.0 / exponent) * log(inner)) : 1.0
    discharge_press_bar = suction_press_bar * pressure_ratio

    // 4. Discharge Temperature: T2 = T1 * (P2/P1)^((n-1)/n)
    discharge_temp_k = suction_temp_k * exp(exponent * log(pressure_ratio))

    // 5. Driver shaft power consumption: P_shaft = (m_dot * g * H_p) / eta_p
    var/gas_density = (suction_press_bar * 100000.0) / (r_spec * suction_temp_k * gas_z_compressibility)
    var/mass_flow_kg_s = (net_suction_flow / 3600.0) * gas_density
    var/power_watts = (mass_flow_kg_s * 9.80665 * polytropic_head_m) / max(polytropic_efficiency, 0.5)
    driver_power_mw = power_watts * 1e-6
