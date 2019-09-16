// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Material Handling, Roller Conveyors & Diverter Gates
// Language: Dream Maker (DM)

#ifndef PLENUM_ROBOTICS_CONVEYOR_DM
#define PLENUM_ROBOTICS_CONVEYOR_DM

#include "../core/obj.dm"

/obj/machinery/conveyor_belt
    name = "motorized roller conveyor segment"
    desc = "Heavy-duty modular roller conveyor with variable speed induction drive."
    density = FALSE
    var/conveyor_id = "CVY-101"
    var/speed_mps = 1.2                  // Linear belt speed in meters/second
    var/conveyor_direction = DIR_EAST    // Conveyance direction vector
    var/is_running = TRUE
    var/optical_sensor_blocked = FALSE   // Photoelectric eye sensor
    var/jam_detected = FALSE
    var/jam_timer_s = 0.0

/obj/machinery/conveyor_belt/ProcessTick(delta_time_seconds)
    ..()
    if(!is_running || operating_state == 0)
        return

    // Move any resting items on this turf
    if(isturf(loc))
        var/turf/current_turf = loc
        optical_sensor_blocked = FALSE

        for(var/atom/movable/M in current_turf.contents)
            if(M == src || !M.density)
                continue

            optical_sensor_blocked = TRUE
            var/turf/next_turf = get_step(src, conveyor_direction)
            if(next_turf && next_turf.CanPass(M, current_turf, PASS_ALL))
                M.Move(next_turf)

        // Jam supervision: sensor blocked continuously for > 8s indicates line jam
        if(optical_sensor_blocked)
            jam_timer_s += delta_time_seconds
            if(jam_timer_s >= 8.0)
                jam_detected = TRUE
                operating_state = 2 // Fault
                if(event_hub)
                    event_hub.SendSignal(SIG_ALARM_STATE_CHANGED, list("conveyor" = conveyor_id, "alarm" = "CONVEYOR_JAM"))
        else
            jam_timer_s = 0.0
            jam_detected = FALSE

/obj/machinery/conveyor_diverter
    name = "pneumatic sorting diverter"
    desc = "High-speed pop-up transfer diverter arm for routing parcels across conveyor spurs."
    var/diverter_id = "DIV-01"
    var/is_diverting = FALSE
    var/divert_direction = DIR_NORTH

/obj/machinery/conveyor_diverter/proc/ActuateDivert(divert_state)
    is_diverting = divert_state ? TRUE : FALSE

#endif // PLENUM_ROBOTICS_CONVEYOR_DM
