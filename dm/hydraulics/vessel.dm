// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Pressurized Vessels, Cryogenic Dewars & ASME Hoop Stress
// Language: Dream Maker (DM)

#ifndef PLENUM_HYDRAULICS_VESSEL_DM
#define PLENUM_HYDRAULICS_VESSEL_DM

#include "../core/obj.dm"
#include "../physics/gas_mixture.dm"

/obj/machinery/process_vessel
    name = "pressurized buffer vessel"
    desc = "ASME Section VIII Div 1 certified cylindrical pressure vessel with dished heads."
    var/vessel_id = "V-301"
    
    // Geometry & Volume
    var/vessel_height_meters = 4.0
    var/vessel_radius_meters = 1.0
    var/wall_thickness_meters = 0.025   // 25 mm high-tensile carbon steel
    var/max_allowable_working_pressure_pa = 2000000.0 // 20 bar MAWP
    var/yield_strength_pa = 250000000.0 // 250 MPa ASTM A516 Gr 70
    
    // Fluid Inventory
    var/liquid_level_meters = 2.0       // 50% level
    var/liquid_density_kg_m3 = WATER_DENSITY_STP
    var/datum/gas_mixture/ullage_gas = null // Vapor space mixture above liquid

    // Level Instrumentation & Trip Contacts
    var/level_percent = 50.0
    var/level_switch_high_high = FALSE  // LSHH trip threshold at 90%
    var/level_switch_low_low = FALSE    // LSLL trip threshold at 10%
    
    // Cryogenic Boil-Off Parameters
    var/is_cryogenic_dewar = FALSE
    var/vacuum_jacket_heat_leak_watts = 35.0

/obj/machinery/process_vessel/New(loc, id, h = 4.0, r = 1.0)
    ..(loc)
    vessel_id = id
    vessel_height_meters = h
    vessel_radius_meters = r
    
    // Compute total geometric volume: V = pi * r^2 * h
    var/total_vol_m3 = 3.14159265 * vessel_radius_meters * vessel_radius_meters * vessel_height_meters
    var/ullage_vol_liters = (total_vol_m3 * 0.5) * 1000.0
    ullage_gas = new /datum/gas_mixture(ullage_vol_liters)
    ullage_gas.SetCompositionSTP(101.325, 293.15, 0.05, 0.95) // Nitrogen blanket pad

/obj/machinery/process_vessel/proc/CalculateHoopStressPascals()
    // ASME Boiler and Pressure Vessel Code: sigma = (P * r) / t
    var/p_internal = ullage_gas.CalculatePressurePascals()
    var/sigma = (p_internal * vessel_radius_meters) / wall_thickness_meters
    return sigma

/obj/machinery/process_vessel/proc/GetBottomHydrostaticPressurePa()
    var/p_ullage = ullage_gas.CalculatePressurePascals()
    var/p_hydrostatic = liquid_density_kg_m3 * STANDARD_GRAVITY_ACCEL * liquid_level_meters
    return p_ullage + p_hydrostatic

/obj/machinery/process_vessel/proc/UpdateLevelMeters(inflow_m3_s, outflow_m3_s, delta_time_seconds)
    var/cross_section_m2 = 3.14159265 * vessel_radius_meters * vessel_radius_meters
    var/net_inflow_m3 = (inflow_m3_s - outflow_m3_s) * delta_time_seconds
    var/delta_h = net_inflow_m3 / cross_section_m2

    liquid_level_meters = max(0.0, min(vessel_height_meters, liquid_level_meters + delta_h))
    level_percent = (liquid_level_meters / vessel_height_meters) * 100.0

    // Evaluate Safety Interlock Limit Switches
    level_switch_high_high = (level_percent >= 90.0)
    level_switch_low_low = (level_percent <= 10.0)

    // Dynamic Ullage Volume Adjustment
    var/liquid_vol_m3 = cross_section_m2 * liquid_level_meters
    var/total_vol_m3 = cross_section_m2 * vessel_height_meters
    var/ullage_vol_m3 = max(0.1, total_vol_m3 - liquid_vol_m3)
    ullage_gas.volume_liters = ullage_vol_m3 * 1000.0

    // Check ASME Hoop Stress Yield Limit
    var/current_stress = CalculateHoopStressPascals()
    if(current_stress >= yield_strength_pa)
        // Vessel rupture!
        operating_state = 2
        if(event_hub)
            event_hub.SendSignal(SIG_CONTAINMENT_BREACH, list("vessel" = vessel_id, "stress" = current_stress))

    return level_percent

#endif // PLENUM_HYDRAULICS_VESSEL_DM
