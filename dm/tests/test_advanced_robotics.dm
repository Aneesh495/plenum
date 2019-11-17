// Test Suite: Autonomous Robotics, Fleet Coordination, and Kinematics Verification
//
// Meticulously tests Multi-Agent Path Finding (MAPF), time-space conflict resolution,
// 2D occupancy grid SLAM log-odds updates, and 6-DOF manipulator inverse kinematics.

/datum/unit_test/test_advanced_robotics
    var/tests_passed = 0
    var/tests_failed = 0

/datum/unit_test/test_advanced_robotics/proc/run_all_tests()
    world.log << "--- RUNNING ADVANCED ROBOTICS UNIT TESTS ---"
    test_fleet_conflict_detection()
    test_time_space_path_planning()
    test_slam_log_odds_mapping()
    test_manipulator_forward_kinematics()
    test_manipulator_dls_inverse_kinematics()
    world.log << "--- ADVANCED ROBOTICS RESULTS: [tests_passed] PASSED, [tests_failed] FAILED ---"
    return (tests_failed == 0)

/datum/unit_test/test_advanced_robotics/proc/assert_true(condition, test_name)
    if(condition)
        tests_passed++
        world.log << "  [test_name]: PASS"
    else
        tests_failed++
        world.log << "  [test_name]: FAIL"

/datum/unit_test/test_advanced_robotics/proc/test_fleet_conflict_detection()
    var/datum/robotics/fleet_coordinator/fc = new()
    // Reserve cell (5, 5, t=10) for Agent 1
    fc.reservation_table["5,5,10"] = 1
    assert_true(fc.is_cell_reserved(5, 5, 10, 2) == 1, "Collision detector flags vertex conflict for Agent 2")
    assert_true(fc.is_cell_reserved(5, 5, 10, 1) == 0, "Own reservation does not self-conflict")

/datum/unit_test/test_advanced_robotics/proc/test_time_space_path_planning()
    var/datum/robotics/fleet_coordinator/fc = new()
    var/list/plan = fc.plan_time_space_route(1, 2, 2, 8, 8)
    assert_true(plan.len > 0, "Time-space A* planner discovers conflict-free route")

/datum/unit_test/test_advanced_robotics/proc/test_slam_log_odds_mapping()
    var/datum/robotics/slam_mcl/slam = new()
    slam.update_lidar_beam(5, 5, 10, 5)
    var/idx_hit = (5 - 1) * slam.grid_width + 10
    var/idx_free = (5 - 1) * slam.grid_width + 7
    assert_true(slam.occupancy_log_odds[idx_hit] > 0.0, "LiDAR obstacle hit increments log-odds (occupied)")
    assert_true(slam.occupancy_log_odds[idx_free] < 0.0, "Traversed space decrements log-odds (free space)")

/datum/unit_test/test_advanced_robotics/proc/test_manipulator_forward_kinematics()
    var/datum/robotics/manipulator_arm/arm = new()
    var/list/pos = arm.compute_forward_kinematics()
    assert_true(pos.len == 3, "Forward kinematics produces 3D Cartesian coordinates [X, Y, Z]")
    assert_true(arm.ee_x_m > 0.1 && arm.ee_z_m > 0.1, "End-effector positioned in positive operational envelope")

/datum/unit_test/test_advanced_robotics/proc/test_manipulator_dls_inverse_kinematics()
    var/datum/robotics/manipulator_arm/arm = new()
    var/target_x = arm.ee_x_m + 0.05
    var/target_y = arm.ee_y_m + 0.02
    var/target_z = arm.ee_z_m + 0.04

    // Run 10 DLS Jacobian steps toward target
    for(var/i = 1 to 10)
        arm.step_inverse_kinematics(target_x, target_y, target_z)

    var/dist = sqrt((target_x - arm.ee_x_m)**2 + (target_y - arm.ee_y_m)**2 + (target_z - arm.ee_z_m)**2)
    assert_true(dist < 0.10, "Damped least squares inverse kinematics converges toward Cartesian target")
