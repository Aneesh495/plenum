// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Cryogenic Air Separation Unit (ASU) & Liquefaction Cycle
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_AIR_SEPARATION_DM
#define PLENUM_MODELS_AIR_SEPARATION_DM

#include "../core/obj.dm"
#include "../physics/gas_mixture.dm"

/obj/machinery/air_separation_unit
    name = "cryogenic air separation unit"
    desc = "Double-column cryogenic fractional distillation plant with vacuum perlite cold box."
    var/asu_id = "ASU-01"
    
    // Operating Cryogenic Temperatures
    var/hp_column_temp_k = 96.0         // High-pressure column at 6 bar
    var/lp_column_temp_k = 80.0         // Low-pressure column at 1.3 bar
    var/hp_column_pressure_bar = 6.0
    var/lp_column_pressure_bar = 1.3
    
    // Production Rates
    var/liquid_oxygen_production_tpd = 150.0  // Tons per day LOX (99.6% purity)
    var/liquid_nitrogen_production_tpd = 450.0 // Tons per day LIN (99.999% purity)
    var/argon_production_tpd = 12.0
    
    // Turbo-Expander Cryogenic Refrigeration
    var/turbo_expander_rpm = 45000.0
    var/refrigeration_duty_kw = 1250.0
    var/feed_air_compressor_power_mw = 8.5

/obj/machinery/air_separation_unit/proc/EvaluateDistillationRecovery(air_feed_nm3_h = 50000.0)
    // Separation efficiency: Atmospheric air composition ~ 78.08% N2, 20.95% O2, 0.93% Ar
    var/o2_recovery_efficiency = 0.985
    var/n2_recovery_efficiency = 0.990
    
    // LOX output (Nm^3 / h)
    var/o2_inflow = air_feed_nm3_h * 0.2095
    var/lox_nm3_h = o2_inflow * o2_recovery_efficiency
    
    // LIN output (Nm^3 / h)
    var/n2_inflow = air_feed_nm3_h * 0.7808
    var/lin_nm3_h = n2_inflow * n2_recovery_efficiency

    // 1 Nm^3 O2 = 1.429 kg -> Convert to metric tons/day
    liquid_oxygen_production_tpd = (lox_nm3_h * 1.429 * 24.0) / 1000.0
    liquid_nitrogen_production_tpd = (lin_nm3_h * 1.250 * 24.0) / 1000.0

    power_draw_watts = feed_air_compressor_power_mw * 1000000.0
    return liquid_oxygen_production_tpd

#endif // PLENUM_MODELS_AIR_SEPARATION_DM
