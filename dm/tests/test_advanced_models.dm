// Test Suite: Advanced Industrial Equipment Models Verification
//
// Meticulously tests physical conservation laws, numerical stability,
// and boundary conditions for Catalytic Reformer, 12-Bed PSA, SMR Neutronics,
// HRSG Reheat, SWRO Desalination, BESS Cell ECM, and MMC HVDC Converter.

/datum/unit_test/test_advanced_models
    var/tests_passed = 0
    var/tests_failed = 0

/datum/unit_test/test_advanced_models/proc/run_all_tests()
    world.log << "--- RUNNING ADVANCED PROCESS MODELS UNIT TESTS ---"
    test_catalytic_reformer_kinetics()
    test_hydrogen_psa_adsorption()
    test_nuclear_smr_kinetics()
    test_hrsg_lmtd_thermodynamics()
    test_membrane_desalination_flux()
    test_bess_cell_ecm_voltage()
    test_hvdc_converter_balancing()
    world.log << "--- ADVANCED PROCESS MODELS RESULTS: [tests_passed] PASSED, [tests_failed] FAILED ---"
    return (tests_failed == 0)

/datum/unit_test/test_advanced_models/proc/assert_true(condition, test_name)
    if(condition)
        tests_passed++
        world.log << "  [test_name]: PASS"
    else
        tests_failed++
        world.log << "  [test_name]: FAIL"

/datum/unit_test/test_advanced_models/proc/test_catalytic_reformer_kinetics()
    var/datum/model/catalytic_reformer/cru = new()
    cru.inlet_temp_k = 783.15
    cru.naphthenes = 0.40
    cru.aromatics = 0.10

    cru.step_kinetics(1.0) // 1 second step
    assert_true(cru.aromatics > 0.10, "Reformer dehydrogenation produces aromatics")
    assert_true(cru.reformate_ron >= 85.0 && cru.reformate_ron <= 106.0, "Reformate octane within physical bounds")

/datum/unit_test/test_advanced_models/proc/test_hydrogen_psa_adsorption()
    var/datum/model/hydrogen_psa/psa = new()
    var/loading_co2 = psa.calculate_langmuir_loading("CO2", 4.4, 24.0)
    assert_true(loading_co2 > 1.0 && loading_co2 < 4.25, "Langmuir CO2 loading within sorbent capacity")

    psa.step_cycle(1.0)
    assert_true(psa.product_purity_h2 >= 0.999, "PSA hydrogen purity exceeds 99.9%")

/datum/unit_test/test_advanced_models/proc/test_nuclear_smr_kinetics()
    var/datum/model/nuclear_smr/smr = new()
    smr.step_core(0.1)
    assert_true(smr.thermal_power_mw > 150.0 && smr.thermal_power_mw < 170.0, "SMR power stable at nominal rating")

    smr.trigger_scram()
    smr.step_core(0.5)
    assert_true(smr.scram_tripped == 1, "SCRAM tripped flag latched")
    assert_true(smr.control_rod_insertion_pct > 25.0, "Control rods rapidly insert on trip")

/datum/unit_test/test_advanced_models/proc/test_hrsg_lmtd_thermodynamics()
    var/datum/model/hrsg_reheat/hrsg = new()
    var/lmtd = hrsg.calculate_lmtd(50.0, 20.0)
    // Theoretical LMTD = (50 - 20) / ln(50/20) = 30 / 0.91629 ~ 32.74
    assert_true(abs(lmtd - 32.74) < 0.5, "LMTD logarithmic calculation within 0.5 K tolerance")

/datum/unit_test/test_advanced_models/proc/test_membrane_desalination_flux()
    var/datum/model/membrane_desalination/ro = new()
    ro.step_transport(1.0)
    assert_true(ro.permeate_flow_m3_hr > 1000.0, "RO permeate production active")
    assert_true(ro.permeate_tds_ppm < 500.0, "Drinking water salinity meets WHO standard < 500 ppm")

/datum/unit_test/test_advanced_models/proc/test_bess_cell_ecm_voltage()
    var/datum/model/bess_cell/cell = new()
    cell.state_of_charge = 0.80
    var/ocv = cell.calculate_ocv(0.80)
    assert_true(ocv > 3.25 && ocv < 3.45, "LFP cell OCV within 3.25V-3.45V nominal plateau")

    cell.step_cell(1.0, 140.0) // 140A discharge
    assert_true(cell.terminal_voltage_v < ocv, "Discharge terminal voltage exhibits ohmic drop")

/datum/unit_test/test_advanced_models/proc/test_hvdc_converter_balancing()
    var/datum/model/hvdc_converter/hvdc = new()
    var/list/submodules = hvdc.calculate_inserted_submodules(150000.0)
    assert_true(submodules[1] + submodules[2] == hvdc.num_submodules_per_arm, "MMC arm submodules sum to total count N")
