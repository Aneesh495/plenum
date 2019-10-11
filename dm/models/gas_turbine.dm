// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Industrial Gas Turbine Power Plant (Brayton Cycle Thermodynamics)
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_GAS_TURBINE_DM
#define PLENUM_MODELS_GAS_TURBINE_DM

#include "../core/obj.dm"
#include "../physics/gas_mixture.dm"
#include "../microgrid/generator.dm"

/obj/machinery/gas_turbine
    name = "heavy-duty industrial gas turbine"
    desc = "Single-shaft industrial gas turbine with axial compressor, dry low-NOx combustor, and 3-stage power turbine."
    var/turbine_id = "GT-01"
    
    // Design Thermodynamic Ratings
    var/rated_power_mw = 45.0
    var/compressor_pressure_ratio = 16.5
    var/compressor_isentropic_eff = 0.88
    var/turbine_isentropic_eff = 0.91
    var/firing_temperature_tit_c = 1250.0 // Turbine inlet temperature
    
    // Operating States
    var/rpm_shaft = 3600.0
    var/fuel_flow_kg_s = 2.45             // Natural gas / methane fuel mass flow
    var/air_inlet_flow_kg_s = 145.0
    var/exhaust_gas_temperature_egt_c = 540.0
    var/compressor_discharge_temp_c = 410.0
    var/compressor_discharge_pressure_bar = 16.5
    var/surge_margin_percentage = 22.0    // Anti-surge margin
    
    // Electrical Synchronous Generator Coupling
    var/datum/power_generator/synchronous_alternator/coupled_generator = null

/obj/machinery/gas_turbine/New(loc, id = "GT-01")
    ..(loc)
    turbine_id = id
    coupled_generator = new /datum/power_generator/synchronous_alternator(id + "-GEN", null, rated_power_mw)

/obj/machinery/gas_turbine/proc/CalculateBraytonCycleThermodynamics(ambient_temp_k = 293.15, ambient_p_bar = 1.01325)
    var/gamma = AIR_SPECIFIC_HEAT_RATIO
    var/exp_gamma = (gamma - 1.0) / gamma // ~ 0.2857
    var/cp_air = 1005.0 // J / (kg * K)
    var/cp_flue = 1150.0 // J / (kg * K)

    // 1. Axial Compressor Stage:
    // T2_s = T1 * (P2 / P1)^((gamma - 1)/gamma)
    var/t1 = ambient_temp_k
    var/t2_isentropic = t1 * (compressor_pressure_ratio ** exp_gamma)
    var/t2_actual = t1 + ((t2_isentropic - t1) / compressor_isentropic_eff)
    compressor_discharge_temp_c = t2_actual - 273.15
    compressor_discharge_pressure_bar = ambient_p_bar * compressor_pressure_ratio

    // Compressor Work: W_comp = m_air * Cp_air * (T2 - T1)
    var/w_comp_watts = air_inlet_flow_kg_s * cp_air * (t2_actual - t1)

    // 2. Combustor Heat Addition: Q_in = m_fuel * LHV (Methane LHV = 50.0 MJ/kg)
    var/lhv_methane_j_kg = 50000000.0
    var/heat_input_watts = fuel_flow_kg_s * lhv_methane_j_kg
    var/total_mass_flow = air_inlet_flow_kg_s + fuel_flow_kg_s

    // Firing temperature T3
    var/t3 = t2_actual + (heat_input_watts / (total_mass_flow * cp_flue))
    firing_temperature_tit_c = t3 - 273.15

    // 3. Power Turbine Expansion:
    // T4_s = T3 / (P2 / P1)^((gamma - 1)/gamma)
    var/t4_isentropic = t3 / (compressor_pressure_ratio ** exp_gamma)
    var/t4_actual = t3 - (turbine_isentropic_eff * (t3 - t4_isentropic))
    exhaust_gas_temperature_egt_c = t4_actual - 273.15

    // Turbine Gross Work: W_turb = m_total * Cp_flue * (T3 - T4)
    var/w_turb_watts = total_mass_flow * cp_flue * (t3 - t4_actual)

    // Net Output Mechanical Power
    var/w_net_watts = max(0.0, w_turb_watts - w_comp_watts)
    var/net_mw = (w_net_watts * 0.000001) * 0.985 // 98.5% mechanical / gearbox efficiency
    
    if(coupled_generator)
        coupled_generator.current_output_mw = min(rated_power_mw, net_mw)

    return net_mw

/obj/machinery/gas_turbine/ProcessTick(delta_time_seconds)
    ..()
    if(operating_state == 1) // Running
        CalculateBraytonCycleThermodynamics()

#endif // PLENUM_MODELS_GAS_TURBINE_DM
