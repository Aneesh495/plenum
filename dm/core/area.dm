// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Logical Area Sectors and Environmental Zones
// Language: Dream Maker (DM)

#ifndef PLENUM_CORE_AREA_DM
#define PLENUM_CORE_AREA_DM

#include "atom.dm"

/area/plenum_area
    name = "generic facility sector"
    var/zone_id = "ZONE-00"
    var/list/turfs = list()
    var/target_temperature_k = 293.15    // 20 degrees C
    var/target_pressure_kpa = 101.325    // Standard 1 atm
    var/target_o2_percentage = 21.0      // 21% O2
    var/positive_pressure_bias_pa = 0.0  // Differential HVAC overpressure for cleanrooms
    var/power_bus_id = "BUS-MAIN"        // Associated electrical power feeder
    var/power_available = TRUE           // Grid power status for area services
    var/hvac_active = TRUE               // Active climate regulation status
    var/fire_lockdown = FALSE            // Hermetic damper seal status
    var/esd_lockdown = FALSE             // Facility emergency trip status
    var/total_zone_volume_liters = 0.0   // Summed volumetric capacity
    var/aggregate_temperature_k = 293.15 // Bulk weighted temperature
    var/aggregate_pressure_kpa = 101.325 // Bulk weighted pressure

/area/plenum_area/proc/RegisterTurf(turf/plenum_turf/T)
    if(!T || (T in turfs))
        return
    turfs += T
    total_zone_volume_liters += T.cell_volume_liters

/area/plenum_area/proc/UnregisterTurf(turf/plenum_turf/T)
    if(!T || !(T in turfs))
        return
    turfs -= T
    total_zone_volume_liters -= T.cell_volume_liters

/area/plenum_area/proc/UpdateAggregateThermodynamics()
    if(turfs.len == 0)
        return
    
    var/sum_temp_weighted = 0.0
    var/sum_pressure_weighted = 0.0
    var/total_vol = 0.0

    for(var/turf/plenum_turf/T in turfs)
        if(!T.air)
            continue
        var/vol = T.cell_volume_liters
        total_vol += vol
        sum_temp_weighted += T.air.temperature * vol
        sum_pressure_weighted += T.air.CalculatePressurePascals() * vol

    if(total_vol > 0.0)
        aggregate_temperature_k = sum_temp_weighted / total_vol
        aggregate_pressure_kpa = (sum_pressure_weighted / total_vol) * 0.001

/area/plenum_area/proc/TriggerFireLockdown()
    fire_lockdown = TRUE
    hvac_active = FALSE
    for(var/turf/plenum_turf/T in turfs)
        for(var/obj/machinery/damper/D in T.contents)
            D.CloseDamper()

/area/plenum_area/proc/ResetLockdown()
    fire_lockdown = FALSE
    esd_lockdown = FALSE
    hvac_active = TRUE
    for(var/turf/plenum_turf/T in turfs)
        for(var/obj/machinery/damper/D in T.contents)
            D.OpenDamper()

// ----------------------------------------------------------------------------
// Specialized Facility Zones
// ----------------------------------------------------------------------------

/area/plenum_area/reactor_containment
    name = "Reactor Containment Cell"
    zone_id = "ZONE-REACTOR-01"
    target_temperature_k = 288.15
    positive_pressure_bias_pa = -50.0 // Negative pressure to prevent hazardous leaks outwards

/area/plenum_area/switchgear_room
    name = "Medium-Voltage Switchgear Room"
    zone_id = "ZONE-ELEC-SWG"
    target_temperature_k = 291.15
    positive_pressure_bias_pa = 25.0  // Positive pressure to keep dust and conductive debris out

/area/plenum_area/process_manifold_hall
    name = "Fluid Manifold & Pumping Gallery"
    zone_id = "ZONE-FLUID-MAN"
    target_temperature_k = 293.15

/area/plenum_area/control_room
    name = "Central Operations Control Center"
    zone_id = "ZONE-OPS-CTRL"
    target_temperature_k = 295.15
    positive_pressure_bias_pa = 50.0  // High positive pressure for habitability and life support

/area/plenum_area/cryogenic_storage
    name = "Cryogenic Liquid Storage Vault"
    zone_id = "ZONE-CRYO-VAULT"
    target_temperature_k = 90.15     // Cryogenic storage atmosphere
    positive_pressure_bias_pa = 10.0

#endif // PLENUM_CORE_AREA_DM
