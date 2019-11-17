// Test Suite: Functional Safety, SIL Verification, and Environmental Dispersion
//
// Meticulously tests IEC 61508 SIL PFDavg voting architectures, Cause and Effect
// shutdown matrix latching, and Gaussian plume toxic gas concentration footprints.

/datum/unit_test/test_advanced_safety
    var/tests_passed = 0
    var/tests_failed = 0

/datum/unit_test/test_advanced_safety/proc/run_all_tests()
    world.log << "--- RUNNING ADVANCED SAFETY UNIT TESTS ---"
    test_sil_voting_architectures()
    test_cause_and_effect_latching()
    test_cause_and_effect_reset_permissive()
    test_toxic_dispersion_gaussian_decay()
    world.log << "--- ADVANCED SAFETY RESULTS: [tests_passed] PASSED, [tests_failed] FAILED ---"
    return (tests_failed == 0)

/datum/unit_test/test_advanced_safety/proc/assert_true(condition, test_name)
    if(condition)
        tests_passed++
        world.log << "  [test_name]: PASS"
    else
        tests_failed++
        world.log << "  [test_name]: FAIL"

/datum/unit_test/test_advanced_safety/proc/test_sil_voting_architectures()
    var/datum/safety/sil_verifier/sil = new()

    sil.evaluate_pfd_avg("1oo1")
    var/pfd_1oo1 = sil.calculated_pfd_avg

    sil.evaluate_pfd_avg("1oo2")
    var/pfd_1oo2 = sil.calculated_pfd_avg

    sil.evaluate_pfd_avg("2oo3")
    var/pfd_2oo3 = sil.calculated_pfd_avg

    assert_true(pfd_1oo2 < pfd_1oo1, "Redundant 1oo2 architecture exhibits lower PFD than single 1oo1")
    assert_true(sil.achieved_sil >= 2, "2oo3 architecture achieves SIL 2 or higher rating")

/datum/unit_test/test_advanced_safety/proc/test_cause_and_effect_latching()
    var/datum/safety/cause_and_effect/ce = new()
    // Trigger Cause 1: PSHH High-High Drum Pressure
    ce.set_cause(1, 1)
    var/active_effects = ce.evaluate_matrix()
    assert_true(active_effects > 0, "Active causes trigger protective effect elements")
    assert_true(ce.effect_latched[1] == 1, "Fuel gas block valve ESDV-01 latches in shutdown position")

/datum/unit_test/test_advanced_safety/proc/test_cause_and_effect_reset_permissive()
    var/datum/safety/cause_and_effect/ce = new()
    ce.set_cause(1, 1)
    ce.evaluate_matrix()

    // Attempt reset while cause is still active
    var/reset_ok = ce.reset_latches()
    assert_true(reset_ok == 0, "Safety interlock prevents reset while initiating fault persists")

    // Clear cause and retry reset
    ce.set_cause(1, 0)
    reset_ok = ce.reset_latches()
    assert_true(reset_ok == 1, "Safety system successfully resets after initiating cause clears")

/datum/unit_test/test_advanced_safety/proc/test_toxic_dispersion_gaussian_decay()
    var/datum/safety/toxic_dispersion/disp = new()
    var/c_100m = disp.calculate_concentration_mg_m3(100.0, 0.0)
    var/c_500m = disp.calculate_concentration_mg_m3(500.0, 0.0)
    assert_true(c_500m < c_100m, "Atmospheric dispersion concentration decays with downwind distance")
    assert_true(c_100m > 0.0, "Downwind concentration is strictly positive")
