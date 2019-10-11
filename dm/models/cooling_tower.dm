// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Mechanical Draft Cooling Tower & Psychrometric Evaporation
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_COOLING_TOWER_DM
#define PLENUM_MODELS_COOLING_TOWER_DM

#include "../core/obj.dm"

/obj/machinery/cooling_tower
    name = "induced draft counter-flow cooling tower"
    desc = "Multi-cell industrial cooling tower with film fill packing, drift eliminators, and variable speed axial fans."
    var/tower_id = "CT-01"
    
    // Design Thermal Rating
    var/cooling_capacity_mw = 35.0
    var/circulating_water_flow_m3_h = 3000.0 // 3000 m^3 / hr (833 L/s)
    
    // Temperatures
    var/hot_water_inlet_temp_c = 38.0
    var/cold_water_basin_temp_c = 28.0
    var/ambient_wet_bulb_temp_c = 22.0
    var/approach_temperature_c = 6.0     // T_cold - T_wetbulb
    var/cooling_range_c = 10.0           // T_hot - T_cold

    // Fan Aerodynamics & Electrical Power
    var/fan_cell_count = 4
    var/fan_speed_ratio = 1.00           // VFD speed [0.0, 1.0]
    var/rated_fan_power_kw_per_cell = 75.0 // 300 kW total fan array

    // Water Losses & Chemistry
    var/evaporation_loss_m3_h = 45.0
    var/drift_loss_percentage = 0.005    // 0.005% of circulating flow
    var/cycles_of_concentration = 4.5    // TDS concentration ratio

/obj/machinery/cooling_tower/proc/CalculateBasinTemperature(wet_bulb_c)
    ambient_wet_bulb_temp_c = wet_bulb_c
    
    // Approach varies inversely with airflow velocity: Approach ~ Approach_rated * (1 / fan_ratio^0.6)
    var/effective_fan_ratio = max(0.2, fan_speed_ratio)
    var/approach = 6.0 * (1.0 / (effective_fan_ratio ** 0.6))
    approach_temperature_c = max(3.0, approach)

    // Cold basin water equilibrium temperature
    cold_water_basin_temp_c = ambient_wet_bulb_temp_c + approach_temperature_c
    cooling_range_c = max(1.0, hot_water_inlet_temp_c - cold_water_basin_temp_c)

    // Electrical Power of Fan Array
    power_draw_watts = fan_cell_count * rated_fan_power_kw_per_cell * 1000.0 * (effective_fan_ratio ** 3)
    return cold_water_basin_temp_c

#endif // PLENUM_MODELS_COOLING_TOWER_DM
