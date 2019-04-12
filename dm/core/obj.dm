// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Machinery and Physical Structures
// Language: Dream Maker (DM)

#ifndef PLENUM_CORE_OBJ_DM
#define PLENUM_CORE_OBJ_DM

#include "atom.dm"

/obj/plenum_obj
    name = "facility object"
    var/power_draw_watts = 0.0          // Active electrical load in Watts
    var/reactive_power_vars = 0.0       // Reactive electrical load in VARs
    var/power_factor = 0.95             // Operating power factor (lagging/leading)
    var/power_bus_id = "BUS-MAIN"       // Connected electrical bus node
    var/is_powered = TRUE               // Active power availability state
    var/heat_output_watts = 0.0         // Thermal dissipation to local turf atmosphere
    var/operating_state = 1             // 0=Off, 1=Nominal, 2=Fault/Degraded
    var/vibration_rms_velocity_mms = 0.5 // Mechanical vibration health metric (ISO 10816)
    var/wear_index = 0.0                // Cumulative wear [0.0 = New, 1.0 = Failed]
    var/mtbf_hours = 50000.0            // Mean Time Between Failures in operating hours
    var/is_loto_locked = FALSE          // Lockout/Tagout (LOTO) maintenance isolation state
    var/loto_tag = ""

/obj/plenum_obj/proc/ProcessTick(delta_time_seconds)
    if(is_loto_locked || operating_state == 0)
        return
    
    // Dissipate heat to the turf if located inside one
    if(heat_output_watts > 0.0 && isturf(loc))
        var/turf/plenum_turf/T = loc
        if(T.air)
            T.air.AddThermalEnergy(heat_output_watts * delta_time_seconds)

    // Accumulate mechanical wear
    if(mtbf_hours > 0.0)
        var/wear_delta = (delta_time_seconds / 3600.0) / mtbf_hours
        wear_index += wear_delta
        if(wear_index >= 1.0)
            operating_state = 2
            if(event_hub)
                event_hub.SendSignal(SIG_OBJECT_DESTROYED, list("uid" = uid, "reason" = "wear_exhaustion"))

/obj/plenum_obj/proc/ApplyLOTO(technician_id, tag_reason)
    is_loto_locked = TRUE
    operating_state = 0
    loto_tag = "[technician_id]: [tag_reason]"

/obj/plenum_obj/proc/RemoveLOTO()
    is_loto_locked = FALSE
    loto_tag = ""
    operating_state = 1

// ----------------------------------------------------------------------------
// Active Machinery Subtypes
// ----------------------------------------------------------------------------

/obj/machinery
    name = "industrial machinery"
    density = TRUE
    var/is_critical_path = FALSE

/obj/machinery/damper
    name = "motorized ventilation damper"
    desc = "High-speed fail-safe pneumatic HVAC isolation damper with position telemetry."
    density = FALSE
    var/position_percent = 100.0        // 0.0 = Closed, 100.0 = Fully Open
    var/actuation_speed_per_sec = 25.0  // Percentage stroke per second
    var/target_position = 100.0
    var/fail_safe_position = 0.0        // Default position on power loss (0=Closed)

/obj/machinery/damper/proc/OpenDamper()
    target_position = 100.0

/obj/machinery/damper/proc/CloseDamper()
    target_position = 0.0

/obj/machinery/damper/ProcessTick(delta_time_seconds)
    ..()
    if(!is_powered)
        target_position = fail_safe_position
    
    if(position_percent != target_position)
        var/step = actuation_speed_per_sec * delta_time_seconds
        if(position_percent < target_position)
            position_percent = min(position_percent + step, target_position)
        else
            position_percent = max(position_percent - step, target_position)
        
        // Update turf permeability based on aperture
        if(isturf(loc))
            var/turf/plenum_turf/T = loc
            if(position_percent < 5.0)
                T.permeability_flags = T.permeability_flags & ~PASS_GAS
            else
                T.permeability_flags = T.permeability_flags | PASS_GAS

// ----------------------------------------------------------------------------
// Industrial Sensor Transducers
// ----------------------------------------------------------------------------

/obj/machinery/sensor
    name = "instrumentation transmitter"
    density = FALSE
    power_draw_watts = 15.0
    var/sensor_tag = "PIT-101"
    var/measured_value = 0.0
    var/calibrated_range_min = 0.0
    var/calibrated_range_max = 1000.0
    var/output_current_ma = 4.0          // 4-20 mA analog standard loop
    var/calibration_drift_bias = 0.0    // Fault injection bias
    var/measurement_noise_sigma = 0.01   // Gaussian noise std dev

/obj/machinery/sensor/proc/SampleProcessValue(raw_physical_value)
    measured_value = raw_physical_value + calibration_drift_bias
    
    // Scale to 4-20 mA signal loop: I = 4 + 16 * ((PV - min) / (max - min))
    var/span = calibrated_range_max - calibrated_range_min
    if(span > 0.0001)
        var/fraction = (measured_value - calibrated_range_min) / span
        fraction = max(0.0, min(1.0, fraction))
        output_current_ma = 4.0 + (16.0 * fraction)
    else
        output_current_ma = 4.0
    
    return measured_value

#endif // PLENUM_CORE_OBJ_DM
