// Triple-Pressure Reheat Heat Recovery Steam Generator (HRSG)
//
// Implements multi-circuit gas-turbine exhaust waste heat recovery.
// Models High Pressure (HP: 130 bar, 565 C), Intermediate Pressure with
// Reheat (IP/RH: 32 bar, 565 C), and Low Pressure (LP: 5.5 bar, 230 C) steam
// generation loops. Solves Logarithmic Mean Temperature Difference (LMTD),
// pinch-point / approach-point thermodynamics, and HP superheater attemperator
// spray water injection for tight turbine admission temperature control.

/datum/model/hrsg_reheat
    var/tag = "HRSG-TRIPLE-01"

    // Gas Turbine Exhaust (Flue Gas) Feed
    var/gas_inlet_temp_k = 883.15 // 610 C
    var/gas_mass_flow_kg_s = 650.0
    var/gas_cp = 1.15 // kJ / (kg * K)
    var/gas_stack_temp_k = 368.15 // 95 C (acid dew point limit)

    // HP Circuit (130 bar)
    var/hp_pressure_bar = 130.0
    var/hp_steam_temp_k = 838.15 // 565 C
    var/hp_steam_flow_kg_s = 78.5
    var/hp_pinch_point_k = 9.2
    var/hp_approach_point_k = 5.5
    var/hp_attemperator_spray_kg_s = 2.4

    // IP / Reheat Circuit (32 bar)
    var/ip_pressure_bar = 32.0
    var/rh_steam_temp_k = 838.15 // 565 C reheat
    var/ip_steam_flow_kg_s = 18.2
    var/cold_reheat_temp_k = 618.15 // 345 C from HP turbine exhaust

    // LP Circuit (5.5 bar)
    var/lp_pressure_bar = 5.5
    var/lp_steam_temp_k = 503.15 // 230 C
    var/lp_steam_flow_kg_s = 12.8

    // Heat Exchanger Surface Areas (m^2)
    var/area_hp_superheater = 4500.0
    var/area_hp_evaporator = 12000.0
    var/area_hp_economizer = 8500.0
    var/overall_u_evap = 0.065 // kW / (m^2 * K)
    var/overall_u_sh = 0.045

/datum/model/hrsg_reheat/New()
    ..()

// Logarithmic Mean Temperature Difference (LMTD)
// LMTD = (dT1 - dT2) / ln(dT1 / dT2)
/datum/model/hrsg_reheat/proc/calculate_lmtd(dt1, dt2)
    var/t1 = max(dt1, 0.1)
    var/t2 = max(dt2, 0.1)

    if(abs(t1 - t2) < 0.01)
        return (t1 + t2) * 0.5

    var/ratio = t1 / t2
    var/ln_val = (ratio > 0.0) ? log(ratio) : 1.0
    return (t1 - t2) / max(ln_val, 1e-4)

// Attemperator spray control to maintain HP steam setpoint at 838.15 K (565 C)
/datum/model/hrsg_reheat/proc/modulate_attemperator_spray(uncooled_temp_k, target_temp_k = 838.15)
    var/error = uncooled_temp_k - target_temp_k
    if(error <= 0.0)
        hp_attemperator_spray_kg_s = 0.0
        hp_steam_temp_k = uncooled_temp_k
        return hp_steam_temp_k

    // Energy balance: m_steam * h_sh + m_spray * h_spray = (m_steam + m_spray) * h_target
    // Enthalpy difference approximation: delta_m_spray ~ m_steam * cp_steam * error / h_fg
    var/delta_spray = (hp_steam_flow_kg_s * 2.1 * error) / 2200.0
    hp_attemperator_spray_kg_s = min(max(hp_attemperator_spray_kg_s + delta_spray, 0.0), 15.0)
    hp_steam_temp_k = target_temp_k
    return hp_steam_temp_k

// Step HRSG thermal profile along gas path
/datum/model/hrsg_reheat/proc/step_hrsg(dt_sec)
    // 1. Total available thermal duty from gas turbine exhaust
    // Q_dot = m_gas * cp_gas * (T_in - T_stack)
    var/q_total_kw = gas_mass_flow_kg_s * gas_cp * (gas_inlet_temp_k - gas_stack_temp_k)

    // 2. High Pressure Superheater and Reheater Zone
    var/gas_temp = gas_inlet_temp_k
    var/q_sh_rh = (hp_steam_flow_kg_s * 2.1 * 120.0) + (ip_steam_flow_kg_s * 2.0 * 220.0)
    gas_temp = gas_temp - (q_sh_rh / (gas_mass_flow_kg_s * gas_cp))

    // 3. HP Evaporator Zone (Pinch Point)
    // T_sat at 130 bar is ~ 604.2 K (331 C)
    var/t_sat_hp = 604.2
    var/q_hp_evap = hp_steam_flow_kg_s * 1350.0 // Latent heat at 130 bar
    gas_temp = gas_temp - (q_hp_evap / (gas_mass_flow_kg_s * gas_cp))
    hp_pinch_point_k = max(gas_temp - t_sat_hp, 3.0)

    // 4. IP and LP Generation Zones
    var/q_ip_lp = (ip_steam_flow_kg_s * 1800.0) + (lp_steam_flow_kg_s * 2100.0)
    gas_temp = gas_temp - (q_ip_lp / (gas_mass_flow_kg_s * gas_cp))

    // 5. Economizer and Stack Exhaust
    var/q_econ = hp_steam_flow_kg_s * 4.2 * 110.0
    gas_temp = max(gas_temp - (q_econ / (gas_mass_flow_kg_s * gas_cp)), 368.15)
    gas_stack_temp_k = gas_temp

    // Thermal inertia on steam temperatures
    var/uncooled_hp = 835.0 + (gas_inlet_temp_k - 883.15) * 0.4
    modulate_attemperator_spray(uncooled_hp)
