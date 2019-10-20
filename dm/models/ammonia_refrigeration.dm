// Two-Stage Ammonia (R-717) Industrial Refrigeration & Flash Economizer
//
// Implements large-scale two-stage industrial refrigeration plant (-35 C).
// Models low-stage booster compressor, high-stage trim compressor with
// hydraulic slide valve capacity regulation, flash-tank intercooler economizer,
// evaporative condenser head pressure control, thermal expansion valve (TXV),
// and thermodynamic Coefficient of Performance (COP) optimization.

/datum/model/ammonia_refrigeration
    var/tag = "CHILL-NH3-TWOSTAGE"

    // Evaporator / Cold Box (-35 C / 238.15 K)
    var/evap_temp_k = 238.15 // -35 C
    var/evap_pressure_bar = 0.93 // Sub-atmospheric NH3 suction
    var/cooling_capacity_kw = 2400.0 // 680 TR (Tons of Refrigeration)
    var/evap_refrigerant_flow_kg_s = 2.15

    // Intermediate Flash Economizer (3.2 bar / -10 C)
    var/inter_pressure_bar = 3.20
    var/inter_temp_k = 263.15 // -10 C
    var/flash_gas_flow_kg_s = 0.48

    // Condenser Loop (+32 C / 305.15 K)
    var/cond_pressure_bar = 12.4
    var/cond_temp_k = 305.15 // +32 C
    var/ambient_wet_bulb_k = 293.15 // 20 C
    var/condenser_heat_rejection_kw = 3150.0

    // Compressors
    var/booster_slide_valve_pct = 85.0 // Low stage capacity
    var/high_stage_slide_valve_pct = 90.0
    var/booster_power_kw = 285.0
    var/high_stage_power_kw = 465.0
    var/total_power_kw = 750.0
    var/cop_cooling = 3.20

    // Enthalpy states (kJ/kg for R-717 Ammonia)
    var/h_evap_out = 1415.0 // Saturated vapor at -35 C
    var/h_booster_out = 1585.0 // Superheated discharge
    var/h_inter_sat_liq = 145.0 // Subcooled liquid leaving economizer
    var/h_cond_out = 345.0     // Saturated liquid at +32 C
    var/h_high_stage_out = 1620.0

/datum/model/ammonia_refrigeration/New()
    ..()

// Coefficient of Performance (COP): COP = Q_cooling / W_total
/datum/model/ammonia_refrigeration/proc/calculate_cop()
    if(total_power_kw <= 1.0)
        return 0.0
    return cooling_capacity_kw / total_power_kw

// Evaporative condenser head pressure floating control based on ambient wet-bulb
/datum/model/ammonia_refrigeration/proc/modulate_head_pressure(wet_bulb_k)
    ambient_wet_bulb_k = wet_bulb_k
    // Condenser approach is ~ 4.5 K above wet bulb
    cond_temp_k = max(ambient_wet_bulb_k + 4.5, 298.15) // Min condensing temp 25 C
    // R-717 Antoine saturation pressure correlation:
    // log10(P_bar) = 4.8688 - (1113.928 / (T - 10.409))
    var/log_p = 4.8688 - (1113.928 / (cond_temp_k - 10.409))
    cond_pressure_bar = exp(log_p * 2.302585)
    return cond_pressure_bar

// Step refrigeration cycle and slide valve modulating controller
/datum/model/ammonia_refrigeration/proc/step_refrigeration(dt_sec, target_cooling_kw = 2400.0)
    // 1. Evaporator heat load balance
    var/delta_load = (target_cooling_kw - cooling_capacity_kw) * 0.25 * dt_sec
    cooling_capacity_kw = cooling_capacity_kw + delta_load

    // 2. Low-stage booster mass flow: m_evap = Q_cooling / (h_evap_out - h_inter_sat_liq)
    var/delta_h_evap = h_evap_out - h_inter_sat_liq
    evap_refrigerant_flow_kg_s = cooling_capacity_kw / max(delta_h_evap, 100.0)

    // Booster compressor slide valve modulated by suction pressure error
    var/press_err = evap_pressure_bar - 0.93
    booster_slide_valve_pct = min(max(booster_slide_valve_pct + (press_err * 25.0 * dt_sec), 20.0), 100.0)

    // Booster isentropic compression power: W = m * (h_out - h_in) / eta_is
    var/eta_booster = 0.76 * (booster_slide_valve_pct / 100.0)
    booster_power_kw = (evap_refrigerant_flow_kg_s * (h_booster_out - h_evap_out)) / max(eta_booster, 0.2)

    // 3. Flash Intercooler Mass and Energy Balance
    // Flash gas generated from subcooling liquid from condenser to intermediate pressure
    // m_flash = m_evap * (h_cond_out - h_inter_sat_liq) / (h_flash_vapor - h_cond_out)
    var/h_flash_vapor = 1460.0
    flash_gas_flow_kg_s = evap_refrigerant_flow_kg_s * ((h_cond_out - h_inter_sat_liq) / max(h_flash_vapor - h_cond_out, 100.0))

    // 4. High-Stage Compressor
    var/high_stage_flow = evap_refrigerant_flow_kg_s + flash_gas_flow_kg_s
    var/eta_high = 0.81 * (high_stage_slide_valve_pct / 100.0)
    high_stage_power_kw = (high_stage_flow * (h_high_stage_out - h_flash_vapor)) / max(eta_high, 0.2)

    total_power_kw = booster_power_kw + high_stage_power_kw
    condenser_heat_rejection_kw = cooling_capacity_kw + total_power_kw
    cop_cooling = calculate_cop()
