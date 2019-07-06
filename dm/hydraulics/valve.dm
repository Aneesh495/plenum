// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Control Valves, Pressure Safety Relief & Equal Percentage Trims
// Language: Dream Maker (DM)

#ifndef PLENUM_HYDRAULICS_VALVE_DM
#define PLENUM_HYDRAULICS_VALVE_DM

#include "pipe_network.dm"
#include "../core/obj.dm"

#define VALVE_TRIM_LINEAR          1
#define VALVE_TRIM_EQUAL_PERCENT   2
#define VALVE_TRIM_QUICK_OPENING   3

/obj/machinery/control_valve
    name = "pneumatic diaphragm control valve"
    desc = "Globe pattern modulating control valve with digital electro-pneumatic positioner."
    var/valve_id = "FCV-201"
    
    // Valve Sizing Parameters
    var/cv_max = 120.0                  // Maximum Flow Coefficient (US GPM / psi^0.5)
    var/trim_characteristic = VALVE_TRIM_EQUAL_PERCENT
    var/rangeability = 50.0             // R = 50 for equal percentage trim
    
    // Position Feedback & Servo Actuation
    var/stem_position = 0.50            // Stroke [0.0 = Closed, 1.0 = Full Open]
    var/target_position = 0.50          // Setpoint from PLC / DCS analog output
    var/stroking_speed_per_sec = 0.20   // Full stroke in 5 seconds
    var/air_supply_pressure_psi = 60.0  // Instrument air pressure
    var/fail_safe_mode = "FAIL_CLOSED"  // Air-to-Open (Fail-Closed) or Air-to-Close

/obj/machinery/control_valve/proc/CalculateEffectiveCv()
    var/pos = max(0.001, min(1.0, stem_position))
    var/cv_eff = 0.0

    switch(trim_characteristic)
        if(VALVE_TRIM_LINEAR)
            cv_eff = cv_max * pos
        if(VALVE_TRIM_EQUAL_PERCENT)
            // Equal percentage: Cv = Cv_max * R^(pos - 1)
            cv_eff = cv_max * (rangeability ** (pos - 1.0))
        if(VALVE_TRIM_QUICK_OPENING)
            cv_eff = cv_max * sqrt(pos)

    return max(0.0, cv_eff)

/obj/machinery/control_valve/proc/CalculateFlowRateM3S(upstream_p_pa, downstream_p_pa, specific_gravity = 1.0)
    var/delta_p_pa = max(0.0, upstream_p_pa - downstream_p_pa)
    var/delta_p_psi = delta_p_pa * 0.000145038 // Convert Pa to psi
    var/cv = CalculateEffectiveCv()

    // Q_gpm = Cv * sqrt(delta_p_psi / SG)
    var/q_gpm = cv * sqrt(delta_p_psi / max(0.01, specific_gravity))
    // Convert US GPM to m^3 / s: 1 GPM = 0.0000630902 m^3 / s
    return q_gpm * 0.0000630902

/obj/machinery/control_valve/ProcessTick(delta_time_seconds)
    ..()
    // Actuator servo motion
    if(stem_position != target_position)
        var/max_step = stroking_speed_per_sec * delta_time_seconds
        if(stem_position < target_position)
            stem_position = min(stem_position + max_step, target_position)
        else
            stem_position = max(stem_position - max_step, target_position)

// ----------------------------------------------------------------------------
// Pressure Safety Relief Valve (PSV / PRV per ASME Section VIII)
// ----------------------------------------------------------------------------

/obj/machinery/safety_relief_valve
    name = "direct spring-loaded pressure relief valve"
    desc = "ASME Section VIII certified emergency overpressure safety relief valve."
    var/set_pressure_pa = 1000000.0     // 10 bar setpoint
    var/overpressure_accumulation = 0.10 // 10% overpressure for full lift
    var/blowdown_percentage = 0.07      // 7% reseat pressure drop below setpoint
    var/is_lifting = FALSE
    var/total_lifted_events = 0

/obj/machinery/safety_relief_valve/proc/EvaluateRelief(current_vessel_p_pa)
    var/full_lift_p = set_pressure_pa * (1.0 + overpressure_accumulation)
    var/reseat_p = set_pressure_pa * (1.0 - blowdown_percentage)

    if(!is_lifting)
        if(current_vessel_p_pa >= set_pressure_pa)
            is_lifting = TRUE
            total_lifted_events++
            if(event_hub)
                event_hub.SendSignal(SIG_ALARM_STATE_CHANGED, list("psv" = name, "status" = "LIFTED"))
    else
        // Hysteresis: stays open until pressure drops below blowdown reseat threshold
        if(current_vessel_p_pa < reseat_p)
            is_lifting = FALSE

    return is_lifting

#endif // PLENUM_HYDRAULICS_VALVE_DM
