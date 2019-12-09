// Test Suite: Chemical Thermodynamics and Reaction Kinetics Verification
//
// Meticulously tests Peng-Robinson EOS Cardano cubic roots, fugacity departures,
// GRI-Mech thermal NOx, Rachford-Rice flash solver, UNIQUAC, and e-NRTL speciation.

/datum/unit_test/test_advanced_chemistry
    var/tests_passed = 0
    var/tests_failed = 0

/datum/unit_test/test_advanced_chemistry/proc/run_all_tests()
    world.log << "--- RUNNING ADVANCED CHEMISTRY UNIT TESTS ---"
    test_peng_robinson_z_factor()
    test_peng_robinson_fugacity()
    test_combustion_zeldovich_nox()
    test_rachford_rice_vle_flash()
    test_uniquac_activity_coefficients()
    test_electrolyte_nrtl_pdh_activity()
    world.log << "--- ADVANCED CHEMISTRY RESULTS: [tests_passed] PASSED, [tests_failed] FAILED ---"
    return (tests_failed == 0)

/datum/unit_test/test_advanced_chemistry/proc/assert_true(condition, test_name)
    if(condition)
        tests_passed++
        world.log << "  [test_name]: PASS"
    else
        tests_failed++
        world.log << "  [test_name]: FAIL"

/datum/unit_test/test_advanced_chemistry/proc/test_peng_robinson_z_factor()
    var/datum/chemistry/peng_robinson/pr = new()
    var/z_gas = pr.solve_z_factor(50.0, 300.0, "VAPOR")
    assert_true(z_gas > 0.70 && z_gas < 1.05, "Natural gas Z-factor at 50 bar 300 K within physical bounds")

/datum/unit_test/test_advanced_chemistry/proc/test_peng_robinson_fugacity()
    var/datum/chemistry/peng_robinson/pr = new()
    pr.solve_z_factor(30.0, 310.0, "VAPOR")
    var/list/phis = pr.calculate_fugacity_coefficients()
    assert_true(phis.len == 5, "Fugacity coefficients computed for all 5 components")
    assert_true(phis[1] > 0.80 && phis[1] < 1.05, "Methane fugacity coefficient reflects non-ideal gas departure")

/datum/unit_test/test_advanced_chemistry/proc/test_combustion_zeldovich_nox()
    var/datum/chemistry/combustion_kinetics/ck = new()
    ck.flame_temp_k = 2100.0
    ck.step_reactions(0.01)
    assert_true(ck.conc_no > 0.00005, "High temperature flame generates thermal Zeldovich NOx")

/datum/unit_test/test_advanced_chemistry/proc/test_rachford_rice_vle_flash()
    var/datum/chemistry/flash_solver/flash = new()
    flash.calculate_wilson_k_values(10.0, 340.0)
    var/beta = flash.solve_rachford_rice()
    assert_true(beta >= 0.0 && beta <= 1.0, "Rachford-Rice vapor fraction beta bounded in [0, 1]")
    var/sum_x = 0.0
    var/sum_y = 0.0
    for(var/i = 1 to flash.num_components)
        sum_x += flash.liquid_x[i]
        sum_y += flash.vapor_y[i]
    assert_true(abs(sum_x - 1.0) < 0.001, "Liquid mole fractions sum to unity")
    assert_true(abs(sum_y - 1.0) < 0.001, "Vapor mole fractions sum to unity")

/datum/unit_test/test_advanced_chemistry/proc/test_uniquac_activity_coefficients()
    var/datum/chemistry/uniquac/uq = new()
    var/list/gammas = uq.calculate_activity_coefficients(0.40, 333.15)
    assert_true(gammas[1] > 1.0, "Ethanol in water exhibits positive deviation from Raoult's law (gamma > 1)")
    assert_true(gammas[2] > 1.0, "Water in ethanol exhibits positive activity coefficient")

/datum/unit_test/test_advanced_chemistry/proc/test_electrolyte_nrtl_pdh_activity()
    var/datum/chemistry/electrolyte_nrtl/enrtl = new()
    var/gamma_ion = enrtl.calculate_pdh_activity(1, 0.88, 323.15)
    assert_true(gamma_ion > 0.20 && gamma_ion < 1.0, "Pitzer-Debye-Huckel screens ionic activity below 1.0")
