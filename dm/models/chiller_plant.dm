// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Centrifugal Water Chiller & Vapor-Compression Refrigeration
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_CHILLER_PLANT_DM
#define PLENUM_MODELS_CHILLER_PLANT_DM

#include "../core/obj.dm"

/obj/machinery/centrifugal_chiller
    name = "water-cooled centrifugal chiller"
    desc = "High-efficiency magnetic-bearing centrifugal chiller utilizing low-GWP refrigerant."
    var/chiller_id = "CH-01"
    
    // Thermal Capacity
    var/cooling_capacity_tons = 1000.0  // 1000 RT = 3517 kW thermal
    var/chilled_water_flow_lps = 150.0  // 150 L / s
    var/chilled_water_supply_c = 6.7    // 44 F setpoint
    var/chilled_water_return_c = 12.2   // 54 F return
    
    // Efficiency Metrics (AHRI 550/590)
    var/full_load_cop = 6.20            // Coefficient of Performance (kW_th / kW_elec)
    var/compressor_lift_kw_per_ton = 0.567
    var/load_percentage = 80.0          // Part-load ratio
    
    // Condenser Side
    var/condenser_water_inlet_c = 29.5
    var/condenser_water_outlet_c = 35.0

/obj/machinery/centrifugal_chiller/proc/CalculateElectricalPowerDraw(load_ratio)
    load_percentage = max(10.0, min(100.0, load_ratio))
    
    // Thermal Duty: Q_th = Capacity * (load_percent / 100)
    var/q_thermal_kw = (cooling_capacity_tons * 3.51685) * (load_percentage * 0.01)
    
    // Part-load COP degradation curve
    var/plr = load_percentage * 0.01
    var/cop_eff = full_load_cop * (1.2 * plr - 0.2 * (plr ** 2))
    
    // Electrical input: P_elec = Q_thermal / COP
    var/p_elec_kw = q_thermal_kw / max(1.0, cop_eff)
    power_draw_watts = p_elec_kw * 1000.0
    return power_draw_watts

#endif // PLENUM_MODELS_CHILLER_PLANT_DM
