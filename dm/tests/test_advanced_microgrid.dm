// Test Suite: Advanced Microgrid, Relays, and Power Electronics Verification
//
// Meticulously tests IEC 60255 IDMT curves, Distance 21 Mho circles, 87T differential,
// optimal economic dispatch lambda iteration, IEEE 519 THD, and Grid-Forming VSM.

/datum/unit_test/test_advanced_microgrid
    var/tests_passed = 0
    var/tests_failed = 0

/datum/unit_test/test_advanced_microgrid/proc/run_all_tests()
    world.log << "--- RUNNING ADVANCED MICROGRID UNIT TESTS ---"
    test_iec60255_idmt_curves()
    test_distance_mho_reach()
    test_differential_87t_inrush_restraint()
    test_economic_dispatch_lambda()
    test_harmonic_thd_calculation()
    test_gfm_vsm_swing_equation()
    world.log << "--- ADVANCED MICROGRID RESULTS: [tests_passed] PASSED, [tests_failed] FAILED ---"
    return (tests_failed == 0)

/datum/unit_test/test_advanced_microgrid/proc/assert_true(condition, test_name)
    if(condition)
        tests_passed++
        world.log << "  [test_name]: PASS"
    else
        tests_failed++
        world.log << "  [test_name]: FAIL"

/datum/unit_test/test_advanced_microgrid/proc/test_iec60255_idmt_curves()
    var/datum/microgrid/relay/r = new()
    r.pickup_current_a = 100.0
    r.time_dial_multiplier = 0.5
    r.curve_type = "IEC_STANDARD"

    var/t_2x = r.calculate_idmt_trip_time(200.0) // 2x pickup
    var/t_5x = r.calculate_idmt_trip_time(500.0) // 5x pickup
    assert_true(t_5x < t_2x, "Higher fault current trips in strictly shorter operating time")
    assert_true(t_2x > 1.0 && t_2x < 10.0, "Standard inverse trip time within expected bounds")

/datum/unit_test/test_advanced_microgrid/proc/test_distance_mho_reach()
    var/datum/microgrid/relay/r = new()
    r.zone1_reach_ohm = 5.0
    // Close fault inside Zone 1
    var/tripped = r.evaluate_distance_mho(1.0, 2.0, 0.05)
    assert_true(tripped == 1, "Close-in fault triggers instantaneous Zone 1 trip")

/datum/unit_test/test_advanced_microgrid/proc/test_differential_87t_inrush_restraint()
    var/datum/microgrid/relay/r = new()
    // High differential current but 25% 2nd harmonic (transformer energization inrush)
    var/tripped = r.evaluate_differential_87t(5.0, 0.0, 0.25)
    assert_true(tripped == 0, "87T differential trip successfully blocked by 2nd harmonic inrush")

/datum/unit_test/test_advanced_microgrid/proc/test_economic_dispatch_lambda()
    var/datum/microgrid/economic_dispatch/ed = new()
    var/lambda = ed.solve_dispatch(180.0)
    assert_true(lambda > 15.0 && lambda < 80.0, "System marginal price lambda converges in reasonable range")
    var/sum_p = 0.0
    for(var/p in ed.p_dispatch_mw)
        sum_p += p
    assert_true(abs(sum_p - 180.0) < 0.5, "Dispatched generator fleet matches total system demand")

/datum/unit_test/test_advanced_microgrid/proc/test_harmonic_thd_calculation()
    var/datum/microgrid/harmonics/h = new()
    var/thd = h.calculate_thd_voltage()
    assert_true(thd > 0.0 && thd < 10.0, "Voltage THD computes to physical percentage")

/datum/unit_test/test_advanced_microgrid/proc/test_gfm_vsm_swing_equation()
    var/datum/microgrid/inverter_gfm/inv = new()
    inv.virtual_rotor_freq_hz = 60.0
    inv.step_swing_equation(0.01, 59.8) // Grid frequency sag
    assert_true(inv.virtual_rotor_freq_hz > 59.8, "VSM virtual inertia resists sudden grid frequency collapse")
