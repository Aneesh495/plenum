// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Autonomous Robotics & Kinematics Verification Tests
// Language: Dream Maker (DM)

#ifndef PLENUM_TESTS_ROBOTICS_DM
#define PLENUM_TESTS_ROBOTICS_DM

#include "test_runner.dm"
#include "../core/spatial_grid.dm"
#include "../robotics/pathfinding.dm"
#include "../robotics/kinematics.dm"
#include "../robotics/behavior_tree.dm"

/datum/test_suite_robotics

/datum/test_suite_robotics/proc/RunTests(datum/test_runner/runner)
    runner.StartSuite("Autonomous Robotics & JPS Pathfinding")

    // Test 1: Spatial Grid & Jump Point Search (JPS)
    var/datum/spatial_grid/grid = new /datum/spatial_grid(10, 10, 1)
    for(var/x = 1 to 10)
        for(var/y = 1 to 10)
            var/turf/plenum_turf/floor/flr = new /turf/plenum_turf/floor()
            flr.x = x
            flr.y = y
            flr.z = 1
            flr.permeability_flags = PASS_ALL
            flr.density = FALSE
            grid.SetTurf(x, y, 1, flr)

    // Add an obstacle wall at (5, 5)
    var/turf/plenum_turf/wall/w = new /turf/plenum_turf/wall()
    w.x = 5
    w.y = 5
    w.z = 1
    w.density = TRUE
    w.permeability_flags = PASS_NONE
    grid.SetTurf(5, 5, 1, w)

    var/datum/jps_pathfinder/jps = new /datum/jps_pathfinder(grid)
    var/list/path = jps.FindPath(1, 1, 8, 8, 1)
    runner.AssertTrue(path != null && path.len > 0, "JPS Successfully Finds Path Around Spatial Obstacle")
    var/list/start_pt = path[1]
    var/list/end_pt = path[path.len]
    runner.AssertEqual(start_pt[1], 1, 0, "JPS Path Origin X Matches Start")
    runner.AssertEqual(end_pt[1], 8, 0, "JPS Path Destination X Matches Target")

    // Test 2: Differential Drive Forward & Inverse Kinematics
    var/datum/differential_kinematics/diff = new /datum/differential_kinematics()
    diff.wheel_radius_meters = 0.10
    diff.track_width_meters = 0.50

    // Equal wheel speeds (10 rad/s each) -> pure forward translation: v = 0.10 * 10 = 1.0 m/s, omega = 0
    var/list/vw = diff.ForwardKinematics(10.0, 10.0)
    runner.AssertEqual(vw[1], 1.0, 0.0001, "Differential Drive Forward Linear Velocity (v = 1.0 m/s)")
    runner.AssertEqual(vw[2], 0.0, 0.0001, "Differential Drive Zero Yaw Angular Velocity on Symmetric Drive")

    // Test 3: Runge-Kutta Midpoint Odometry Integration
    diff.pos_x_meters = 0.0
    diff.pos_y_meters = 0.0
    diff.heading_radians = 0.0 // Facing East (x-direction)
    diff.linear_velocity_mps = 2.0
    diff.angular_velocity_rad_s = 0.0
    diff.IntegrateOdometryMidpoint(1.0) // 1 second step
    runner.AssertEqual(diff.pos_x_meters, 2.0, 0.001, "Dead-Reckoning Odometry Translates Exactly 2.0m Forward")
    runner.AssertEqual(diff.pos_y_meters, 0.0, 0.001, "Dead-Reckoning Zero Lateral Drift")

    // Test 4: Autonomous Behavior Tree Execution
    var/datum/behavior_tree/bt = new /datum/behavior_tree()
    var/datum/bt_node/selector/root_sel = new /datum/bt_node/selector()
    root_sel.children += new /datum/bt_node/condition/battery_low()
    bt.root_node = root_sel

    var/mob/plenum_mob/robot = new /mob/plenum_mob()
    robot.max_energy_joules = 500000.0
    robot.energy_storage_joules = 50000.0 // 10% battery (Low)
    var/status = bt.Evaluate(robot, 0.1)
    runner.AssertEqual(status, BT_STATUS_SUCCESS, 0, "Behavior Tree Asserts SUCCESS on Low Battery Condition")

    qdel(grid)
    qdel(jps)
    qdel(diff)
    qdel(bt)
    qdel(robot)

#endif // PLENUM_TESTS_ROBOTICS_DM
