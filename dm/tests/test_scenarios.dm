// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: End-to-End Plant Blackout & Autonomous Recovery Integration Scenario
// Language: Dream Maker (DM)

#ifndef PLENUM_TESTS_SCENARIOS_DM
#define PLENUM_TESTS_SCENARIOS_DM

#include "test_runner.dm"
#include "../core/spatial_grid.dm"
#include "../core/area.dm"
#include "../microgrid/bus.dm"
#include "../microgrid/line.dm"
#include "../microgrid/storage.dm"
#include "../microgrid/switchgear.dm"
#include "../hydraulics/vessel.dm"
#include "../safety/emergency_shutdown.dm"
#include "../robotics/pathfinding.dm"
#include "../robotics/service_robot.dm"

/datum/test_suite_scenarios

/datum/test_suite_scenarios/proc/RunTests(datum/test_runner/runner)
    runner.StartSuite("End-to-End Facility Blackout & Autonomous Recovery Scenario")

    // Phase 1: Construct Digital Twin Plant Substrates
    var/datum/electrical_bus/grid_bus = new /datum/electrical_bus("BUS-GRID", BUS_TYPE_SLACK, 13.8)
    var/datum/electrical_bus/plant_bus = new /datum/electrical_bus("BUS-PLANT", BUS_TYPE_PQ, 13.8)
    var/datum/bess_unit/bess = new /datum/bess_unit("BESS-EMERGENCY", plant_bus, 5.0, 2.5)
    bess.state_of_charge = 0.85 // 85% charged

    var/obj/machinery/circuit_breaker/main_incomer = new /obj/machinery/circuit_breaker(null, "VCB-MAIN-INCOMER", grid_bus, plant_bus)
    var/obj/machinery/process_vessel/reactor_vessel = new /obj/machinery/process_vessel(null, "RX-VESSEL-01", 6.0, 1.5)
    
    // Phase 2: Incur Grid Loss of Mains / External Fault
    world.log << "  [Scenario Event]: External Utility Grid Blackout Incurred"
    main_incomer.TripBreaker("Grid Undervoltage Loss of Mains")
    runner.AssertEqual(main_incomer.breaker_state, BREAKER_STATE_TRIPPED, 0, "Main Incoming Breaker Trips on Grid Loss")

    // Phase 3: Microgrid Islanding & BESS Fast Inverter Injection
    world.log << "  [Scenario Event]: Microgrid Seamless Islanding & BESS Power Dispatch"
    bess.CommandDispatch(2.0, 0.5, 1.0) // Dispatch 2 MW emergency power
    runner.AssertEqual(bess.active_power_mw, 2.0, 0.001, "BESS Dispatches 2.0 MW Emergency Islanded Power")
    runner.AssertTrue(bess.state_of_charge > 0.84, "BESS SoC Maintained Within Operational Envelope")

    // Phase 4: Autonomous Robotic Intervention
    world.log << "  [Scenario Event]: Deploying Autonomous Hazmat Service Robot"
    var/datum/spatial_grid/plant_map = new /datum/spatial_grid(16, 16, 1)
    for(var/x = 1 to 16)
        for(var/y = 1 to 16)
            var/turf/plenum_turf/floor/flr = new /turf/plenum_turf/floor()
            flr.x = x
            flr.y = y
            flr.z = 1
            flr.density = FALSE
            flr.permeability_flags = PASS_ALL
            plant_map.SetTurf(x, y, 1, flr)

    var/datum/jps_pathfinder/pathfinder = new /datum/jps_pathfinder(plant_map)
    var/list/nav_path = pathfinder.FindPath(1, 1, 12, 12, 1)
    runner.AssertTrue(nav_path != null && nav_path.len > 0, "Autonomous Robot Computes JPS Navigation Path to Switchgear Room")

    var/mob/plenum_mob/robot/service_robot/bot = new /mob/plenum_mob/robot/service_robot()
    var/obj/machinery/circuit_breaker/backup_breaker = new /obj/machinery/circuit_breaker(null, "VCB-AUX-01", plant_bus, null)
    backup_breaker.breaker_state = BREAKER_STATE_TRIPPED
    bot.loc = locate(12, 12, 1) // Robot arrives at switchgear panel
    
    // Robot resets auxiliary breaker
    var/reset_ok = bot.ResetTrippedBreaker(backup_breaker)
    runner.AssertTrue(reset_ok, "Autonomous Robot Successfully Re-closes Tripped Auxiliary Breaker")
    runner.AssertEqual(backup_breaker.breaker_state, BREAKER_STATE_CLOSED, 0, "Auxiliary Breaker Verified Closed")

    qdel(grid_bus)
    qdel(plant_bus)
    qdel(bess)
    qdel(main_incomer)
    qdel(reactor_vessel)
    qdel(plant_map)
    qdel(pathfinder)
    qdel(bot)
    qdel(backup_breaker)

#endif // PLENUM_TESTS_SCENARIOS_DM
