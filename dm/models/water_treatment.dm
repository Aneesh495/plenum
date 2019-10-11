// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Reverse Osmosis (RO) Demineralization & Osmotic Pressure Flux
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_WATER_TREATMENT_DM
#define PLENUM_MODELS_WATER_TREATMENT_DM

#include "../core/obj.dm"

/obj/machinery/ro_demineralizer
    name = "two-pass reverse osmosis skid"
    desc = "High-pressure spiral-wound polyamide composite membrane demineralizer for ultra-pure boiler feed."
    var/skid_id = "RO-SKID-01"
    
    // Membrane Hydraulic Parameters
    var/membrane_area_m2 = 3500.0
    var/water_permeability_coeff_a = 1.2e-11 // m / (s * Pa)
    var/salt_permeability_coeff_b = 3.5e-8   // m / s
    
    // Operating Pressures & Concentrations
    var/feed_pressure_bar = 55.0         // 55 bar operating pressure
    var/permeate_pressure_bar = 1.5
    var/feed_tds_ppm = 2500.0            // Feed Total Dissolved Solids
    var/permeate_tds_ppm = 12.0          // Permeate high purity
    var/recovery_ratio = 0.75            // 75% permeate yield
    
    // Flow Rates
    var/feed_flow_m3_h = 100.0
    var/permeate_flow_m3_h = 75.0
    var/concentrate_flow_m3_h = 25.0

/obj/machinery/ro_demineralizer/proc/CalculateOsmoticPressurePa(tds_ppm, temp_k = 293.15)
    // Van 't Hoff Equation for NaCl equivalent: Pi = 1.12 * (T + 273.15) * sum(m_j)
    // Rule of thumb: ~ 0.07 bar per 1000 ppm TDS at 25 C
    var/pi_bar = (tds_ppm / 1000.0) * 0.075 * (temp_k / 298.15)
    return pi_bar * 100000.0

/obj/machinery/ro_demineralizer/proc/CalculatePermeateFlux(temp_k = 293.15)
    // Water Flux: J_w = A * (Delta_P - Delta_Pi)
    var/delta_p_pa = (feed_pressure_bar - permeate_pressure_bar) * 100000.0
    var/avg_feed_tds = feed_tds_ppm * 1.5 // Concentration polarization across membrane
    var/osmotic_p_pa = CalculateOsmoticPressurePa(avg_feed_tds, temp_k)
    var/net_driving_pressure = max(0.0, delta_p_pa - osmotic_p_pa)

    var/flux_m_s = water_permeability_coeff_a * net_driving_pressure
    var/vol_m3_s = flux_m_s * membrane_area_m2
    permeate_flow_m3_h = vol_m3_s * 3600.0
    return permeate_flow_m3_h

#endif // PLENUM_MODELS_WATER_TREATMENT_DM
