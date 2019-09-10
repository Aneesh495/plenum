// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Autonomous Aerial Inspection Drone with Radiometric Thermal IR
// Language: Dream Maker (DM)

#ifndef PLENUM_ROBOTICS_INSPECTION_DRONE_DM
#define PLENUM_ROBOTICS_INSPECTION_DRONE_DM

#include "../core/mob.dm"
#include "behavior_tree.dm"

/mob/plenum_mob/robot/inspection_drone
    name = "autonomous aerial inspection drone"
    desc = "Coaxial octocopter with radiometric thermal camera and ultrasonic gas sniffer."
    density = FALSE
    var/drone_id = "UAV-SCAN-01"
    var/altitude_meters = 2.5
    var/rotor_thrust_newtons = 45.0
    
    // Sensor Instrumentation Payloads
    var/thermal_camera_fov_degrees = 60.0
    var/max_detected_surface_temp_c = 25.0
    var/ultrasonic_leak_detected_db = 0.0
    var/hydrocarbon_ppm = 0.0
    
    // Inspection Mission Patrol
    var/list/patrol_waypoints = list()
    var/current_waypoint_index = 1
    var/hover_dwell_timer_s = 0.0

/mob/plenum_mob/robot/inspection_drone/New(loc, id = "UAV-SCAN-01")
    ..(loc)
    drone_id = id
    max_energy_joules = 350000.0
    energy_storage_joules = 350000.0
    motion_power_draw_watts = 350.0

/mob/plenum_mob/robot/inspection_drone/proc/PerformThermalRadiometryScan(list/visible_atoms)
    max_detected_surface_temp_c = 0.0
    var/atom/hottest_atom = null

    for(var/atom/plenum_atom/A in visible_atoms)
        var/temp_c = A.temperature - 273.15
        if(temp_c > max_detected_surface_temp_c)
            max_detected_surface_temp_c = temp_c
            hottest_atom = A

    // Electrical switchgear thermal threshold per IEEE standards: > 75 C indicates severe hot spot
    if(max_detected_surface_temp_c >= 75.0 && hottest_atom)
        if(event_hub)
            event_hub.SendSignal(SIG_ALARM_STATE_CHANGED, list(
                "sensor" = drone_id,
                "alarm" = "THERMAL_HOTSPOT_DETECTED",
                "temp_c" = max_detected_surface_temp_c,
                "target" = hottest_atom.name
            ))

    return max_detected_surface_temp_c

/mob/plenum_mob/robot/inspection_drone/proc/SampleAtmosphericSniffer()
    if(!isturf(loc))
        return 0.0
    var/turf/plenum_turf/T = loc
    if(!T.air)
        return 0.0

    // Measure toxic carbon monoxide and combustible methane
    var/ch4_moles = T.air.GetMoles(GAS_CH4)
    var/co_moles = T.air.GetMoles(GAS_CO)
    var/total_m = max(0.001, T.air.total_moles)
    
    hydrocarbon_ppm = ((ch4_moles + co_moles) / total_m) * 1000000.0
    if(hydrocarbon_ppm >= 500.0) // 500 ppm warning threshold
        if(event_hub)
            event_hub.SendSignal(SIG_ALARM_STATE_CHANGED, list(
                "sensor" = drone_id,
                "alarm" = "GAS_PLUME_DETECTED",
                "ppm" = hydrocarbon_ppm
            ))

    return hydrocarbon_ppm

#endif // PLENUM_ROBOTICS_INSPECTION_DRONE_DM
