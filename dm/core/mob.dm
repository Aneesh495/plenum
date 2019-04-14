// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Mobile Autonomous Agents and Plant Operators
// Language: Dream Maker (DM)

#ifndef PLENUM_CORE_MOB_DM
#define PLENUM_CORE_MOB_DM

#include "atom.dm"

/mob/plenum_mob
    name = "autonomous mobile agent"
    density = TRUE
    var/energy_storage_joules = 500000.0  // Battery or chemical energy capacity
    var/max_energy_joules = 500000.0
    var/idle_power_draw_watts = 25.0
    var/motion_power_draw_watts = 250.0
    var/heading_degrees = 0.0             // Orientation [0, 360)
    var/velocity_linear_mps = 0.0         // Forward speed in meters/second
    var/max_speed_mps = 2.5
    var/list/payload_items = list()
    var/hazard_exposure_dose = 0.0        // Cumulative toxic/radiological exposure
    var/is_autonomous = TRUE
    var/agent_status = ROBOT_STATE_IDLE
    var/datum/behavior_tree/ai_brain = null

/mob/plenum_mob/proc/StepTowardsTarget(turf/target_turf, delta_time_seconds)
    if(!target_turf || energy_storage_joules <= 0.0)
        return FALSE
    
    var/dir_to = get_dir(src, target_turf)
    var/turf/next_step = get_step(src, dir_to)
    
    if(next_step && next_step.CanPass(src, loc, PASS_ROBOTIC))
        Move(next_step)
        var/consumed = motion_power_draw_watts * delta_time_seconds
        energy_storage_joules = max(0.0, energy_storage_joules - consumed)
        return TRUE
    return FALSE

/mob/plenum_mob/proc/ProcessTick(delta_time_seconds)
    if(energy_storage_joules <= 0.0)
        agent_status = ROBOT_STATE_ESTOP
        return
    
    // Idle consumption
    var/idle_joules = idle_power_draw_watts * delta_time_seconds
    energy_storage_joules = max(0.0, energy_storage_joules - idle_joules)

    // Sample atmospheric hazards from current turf
    if(isturf(loc))
        var/turf/plenum_turf/T = loc
        if(T.air)
            var/co_moles = T.air.GetMoles(GAS_CO)
            var/sf6_moles = T.air.GetMoles(GAS_SF6)
            if(co_moles > 0.01 || sf6_moles > 0.05)
                hazard_exposure_dose += (co_moles * 10.0 + sf6_moles * 2.0) * delta_time_seconds

// ----------------------------------------------------------------------------
// Human Operator Entity
// ----------------------------------------------------------------------------

/mob/plenum_mob/human_operator
    name = "Licensed Process Operator"
    desc = "Control board operator with hazardous material PPE certification."
    is_autonomous = FALSE
    var/operator_badge_id = "OP-495"
    var/heart_rate_bpm = 72.0
    var/oxygen_blood_saturation = 99.0
    var/ppe_respiratory_rating = 0.95     // 95% particulate & organic vapor filtration efficiency

/mob/plenum_mob/human_operator/ProcessTick(delta_time_seconds)
    ..()
    // Human respiration mechanics: consume O2, produce CO2
    if(isturf(loc))
        var/turf/plenum_turf/T = loc
        if(T.air && T.air.total_moles > 0.0)
            var/o2_fraction = T.air.GetMolarFraction(GAS_O2)
            if(o2_fraction < 0.16)
                oxygen_blood_saturation = max(60.0, oxygen_blood_saturation - 1.5 * delta_time_seconds)
                heart_rate_bpm = min(170.0, heart_rate_bpm + 2.0 * delta_time_seconds)
            else
                oxygen_blood_saturation = min(99.0, oxygen_blood_saturation + 0.5 * delta_time_seconds)
                heart_rate_bpm = max(70.0, heart_rate_bpm - 0.5 * delta_time_seconds)

            // Respiration: ~0.005 mol/s O2 -> CO2
            var/respire_moles = 0.005 * delta_time_seconds
            if(T.air.GetMoles(GAS_O2) >= respire_moles)
                T.air.AdjustMoles(GAS_O2, -respire_moles)
                T.air.AdjustMoles(GAS_CO2, respire_moles)

#endif // PLENUM_CORE_MOB_DM
