// Test Suite: Advanced Process Automation and Modern Control Verification
//
// Meticulously tests Extended Kalman Filter (EKF), Dynamic Matrix Control (DMC),
// Smith Predictor dead-time compensation, Fuzzy Logic FIS, and HART telemetry.

/datum/unit_test/test_advanced_automation
    var/tests_passed = 0
    var/tests_failed = 0

/datum/unit_test/test_advanced_automation/proc/run_all_tests()
    world.log << "--- RUNNING ADVANCED AUTOMATION UNIT TESTS ---"
    test_kalman_filter_state_update()
    test_dmc_predictive_moves()
    test_smith_predictor_deadtime()
    test_fuzzy_logic_defuzzification()
    test_hart_protocol_framing()
    world.log << "--- ADVANCED AUTOMATION RESULTS: [tests_passed] PASSED, [tests_failed] FAILED ---"
    return (tests_failed == 0)

/datum/unit_test/test_advanced_automation/proc/assert_true(condition, test_name)
    if(condition)
        tests_passed++
        world.log << "  [test_name]: PASS"
    else
        tests_failed++
        world.log << "  [test_name]: FAIL"

/datum/unit_test/test_advanced_automation/proc/test_kalman_filter_state_update()
    var/datum/automation/kalman_filter/ekf = new()
    ekf.predict(list(50.0, 50.0), 0.1)
    var/list/z = list(355.0, 46.0, 51.0)
    var/list/x_corr = ekf.update(z)
    assert_true(x_corr.len == 3, "EKF updates all 3 process state variables")
    assert_true(x_corr[1] > 348.0 && x_corr[1] < 360.0, "Temperature state estimate converges toward measurement")

/datum/unit_test/test_advanced_automation/proc/test_dmc_predictive_moves()
    var/datum/automation/dmc_controller/dmc = new()
    var/u_move = dmc.compute_control_move(45.0, 50.0) // Error = +5.0
    assert_true(u_move > 50.0, "DMC increases actuator position to eliminate positive error")
    assert_true(u_move <= 55.0, "DMC move respects delta_u maximum slew rate clamp")

/datum/unit_test/test_advanced_automation/proc/test_smith_predictor_deadtime()
    var/datum/automation/smith_predictor/sp = new()
    var/u = sp.step_predictor(48.0, 50.0, 1.0)
    assert_true(u >= 0.0 && u <= 100.0, "Smith predictor output bounded between 0% and 100%")

/datum/unit_test/test_advanced_automation/proc/test_fuzzy_logic_defuzzification()
    var/datum/automation/fuzzy_controller/fis = new()
    var/out_zero = fis.evaluate_fuzzy(0.0, 0.0)
    assert_true(abs(out_zero) < 1.0, "Zero error and zero derivative produces zero control move")

    var/out_pos = fis.evaluate_fuzzy(15.0, 2.0)
    assert_true(out_pos > 10.0, "Positive error produces positive corrective control action")

/datum/unit_test/test_advanced_automation/proc/test_hart_protocol_framing()
    var/datum/automation/hart_device/hart = new()
    var/ma = hart.calculate_analog_current(50.0)
    assert_true(abs(ma - 12.0) < 0.1, "50% PV produces exact 12.0 mA analog loop current")

    var/list/resp = hart.process_hart_command(1, list())
    assert_true(resp.len >= 2, "HART Command 1 responds with engineering units and PV")
