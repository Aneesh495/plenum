// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Tracked Service Robot & 6-DOF Manipulator Tooling
// Language: Dream Maker (DM)

#ifndef PLENUM_ROBOTICS_SERVICE_ROBOT_DM
#define PLENUM_ROBOTICS_SERVICE_ROBOT_DM

#include "../core/mob.dm"
#include "../hydraulics/valve.dm"
#include "../microgrid/switchgear.dm"

/mob/plenum_mob/robot/service_robot
    name = "heavy maintenance manipulator robot"
    desc = "Tracked hazmat intervention robot equipped with 6-DOF robotic arm and tool turret."
    density = TRUE
    var/robot_id = "ROBOT-SRV-01"
    
    // Arm Kinematics & Payload
    var/arm_reach_meters = 1.8
    var/arm_payload_capacity_kg = 45.0
    var/current_tool = "TORQUE_WRENCH"   // "TORQUE_WRENCH", "FOAM_NOZZLE", "BREAKER_ACTUATOR"
    var/co2_extinguisher_reserve_kg = 20.0
    var/is_manipulating = FALSE
    var/action_progress_percent = 0.0

/mob/plenum_mob/robot/service_robot/New(loc, id = "ROBOT-SRV-01")
    ..(loc)
    robot_id = id
    max_energy_joules = 800000.0
    energy_storage_joules = 800000.0
    motion_power_draw_watts = 400.0

/mob/plenum_mob/robot/service_robot/proc/ActuateManualValve(obj/machinery/control_valve/valve, target_stroke)
    if(!valve || get_dist(src, valve) > 1)
        return FALSE // Must be adjacent
    
    current_tool = "TORQUE_WRENCH"
    is_manipulating = TRUE
    valve.target_position = max(0.0, min(1.0, target_stroke))
    is_manipulating = FALSE
    return TRUE

/mob/plenum_mob/robot/service_robot/proc/ResetTrippedBreaker(obj/machinery/circuit_breaker/breaker)
    if(!breaker || get_dist(src, breaker) > 1)
        return FALSE
    
    current_tool = "BREAKER_ACTUATOR"
    is_manipulating = TRUE
    var/success = breaker.CloseBreaker()
    is_manipulating = FALSE
    return success

/mob/plenum_mob/robot/service_robot/proc/DeployFireExtinguisher(turf/plenum_turf/target_turf, discharge_kg = 5.0)
    if(!target_turf || co2_extinguisher_reserve_kg <= 0.0 || get_dist(src, target_turf) > 3)
        return FALSE
    
    current_tool = "FOAM_NOZZLE"
    var/used_kg = min(discharge_kg, co2_extinguisher_reserve_kg)
    co2_extinguisher_reserve_kg -= used_kg
    
    // Inject CO2 into target turf atmosphere to smother flame: 1 mol CO2 = 0.044 kg
    if(target_turf.air)
        var/moles_co2 = used_kg / MOLAR_MASS_CO2
        target_turf.air.AdjustMoles(GAS_CO2, moles_co2)
        // Evaporative dry-ice cooling effect
        target_turf.air.AddThermalEnergy(-moles_co2 * 20000.0) // 20 kJ / mol sublimation cooling

    return TRUE

#endif // PLENUM_ROBOTICS_SERVICE_ROBOT_DM
