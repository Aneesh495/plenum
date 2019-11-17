// Test Suite: Advanced Fluid Dynamics and Hydraulics Verification
//
// Meticulously tests acoustic celerity Korteweg formula, MOC transient integration,
// Beggs and Brill two-phase flow regimes, Fanno sonic choking, and pump cavitation.

/datum/unit_test/test_advanced_hydraulics
    var/tests_passed = 0
    var/tests_failed = 0

/datum/unit_test/test_advanced_hydraulics/proc/run_all_tests()
    world.log << "--- RUNNING ADVANCED HYDRAULICS UNIT TESTS ---"
    test_water_hammer_celerity()
    test_water_hammer_moc_step()
    test_multiphase_flow_regimes()
    test_compressible_fanno_choking()
    test_pump_cavitation_margin()
    world.log << "--- ADVANCED HYDRAULICS RESULTS: [tests_passed] PASSED, [tests_failed] FAILED ---"
    return (tests_failed == 0)

/datum/unit_test/test_advanced_hydraulics/proc/assert_true(condition, test_name)
    if(condition)
        tests_passed++
        world.log << "  [test_name]: PASS"
    else
        tests_failed++
        world.log << "  [test_name]: FAIL"

/datum/unit_test/test_advanced_hydraulics/proc/test_water_hammer_celerity()
    var/datum/hydraulics/water_hammer/wh = new()
    var/a = wh.calculate_wave_speed()
    assert_true(a > 1000.0 && a < 1400.0, "Korteweg acoustic wave speed in steel pipe ~ 1180 m/s")

/datum/unit_test/test_advanced_hydraulics/proc/test_water_hammer_moc_step()
    var/datum/hydraulics/water_hammer/wh = new()
    wh.step_moc(0.5, 0.05) // 50% valve closure
    assert_true(wh.piezometric_head_h.len == 21, "MOC spatial grid maintains 21 nodes")
    assert_true(wh.volumetric_flow_q.len == 21, "MOC flow grid maintains 21 nodes")

/datum/unit_test/test_advanced_hydraulics/proc/test_multiphase_flow_regimes()
    var/datum/hydraulics/multiphase/mp = new()
    var/regime_low = mp.determine_flow_regime(0.005, 1.0)
    assert_true(regime_low == "SEGREGATED_STRATIFIED", "Low holdup low Froude identifies as stratified")

    var/regime_high = mp.determine_flow_regime(0.5, 50.0)
    assert_true(regime_high == "DISTRIBUTED_MIST", "High velocity identifies as distributed mist")

/datum/unit_test/test_advanced_hydraulics/proc/test_compressible_fanno_choking()
    var/datum/hydraulics/compressible_duct/cd = new()
    cd.duct_length_m = 500.0 // Long duct guaranteed to choke
    cd.step_fanno(45.0)
    assert_true(cd.choked == 1, "Long duct sonically chokes at exit")
    assert_true(abs(cd.outlet_mach - 1.0) < 0.05, "Choked outlet Mach reaches unity")

/datum/unit_test/test_advanced_hydraulics/proc/test_pump_cavitation_margin()
    var/datum/hydraulics/cavitation/cav = new()
    var/npsha = cav.calculate_npsha(200000.0, 31180.0, 2.0)
    assert_true(npsha > 15.0, "High suction pressure provides safe NPSHA > 15m")

    cav.suction_static_press_pa = 35000.0 // Near vapor pressure 31180 Pa
    cav.step_cavitation(0.1, 450.0)
    assert_true(cav.cavitation_active == 1, "Low suction margin activates cavitation alarm")
