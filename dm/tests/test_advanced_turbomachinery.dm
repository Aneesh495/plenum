// Test Suite: Turbomachinery, Aerodynamics, and Hydroelectric Governors Verification
//
// Meticulously tests F-class gas turbine aerothermal cycle, steam turbine EHG cam curves,
// hydro turbine penstock water inertia non-minimum phase response, and 8MW wind BEM.

/datum/unit_test/test_advanced_turbomachinery
    var/tests_passed = 0
    var/tests_failed = 0

/datum/unit_test/test_advanced_turbomachinery/proc/run_all_tests()
    world.log << "--- RUNNING ADVANCED TURBOMACHINERY UNIT TESTS ---"
    test_gas_turbine_aerothermo()
    test_steam_turbine_governor_ehg()
    test_hydro_turbine_penstock_inertia()
    test_wind_turbine_bem_mppt()
    world.log << "--- ADVANCED TURBOMACHINERY RESULTS: [tests_passed] PASSED, [tests_failed] FAILED ---"
    return (tests_failed == 0)

/datum/unit_test/test_advanced_turbomachinery/proc/assert_true(condition, test_name)
    if(condition)
        tests_passed++
        world.log << "  [test_name]: PASS"
    else
        tests_failed++
        world.log << "  [test_name]: FAIL"

/datum/unit_test/test_advanced_turbomachinery/proc/test_gas_turbine_aerothermo()
    var/datum/turbomachinery/gas_turbine_aero/gt = new()
    var/flow = gt.calculate_air_flow(15.0, 288.15, 1.01325)
    assert_true(flow > 600.0 && flow < 850.0, "Compressor airflow scales with VIGV opening")

    gt.step_cycle(240.0, 1.0)
    assert_true(gt.turbine_inlet_temp_tit_k > 1400.0, "TIT firing temperature reflects combustor heat release")
    assert_true(gt.shaft_gross_power_mw > 200.0, "Gross power output meets F-class baseload range")

/datum/unit_test/test_advanced_turbomachinery/proc/test_steam_turbine_governor_ehg()
    var/datum/turbomachinery/steam_turbine_governor/stg = new()
    var/flow_frac = stg.valve_flow_fraction(0.5)
    // S-curve: 0.5^2 * (3 - 2*0.5) = 0.25 * 2 = 0.50
    assert_true(abs(flow_frac - 0.50) < 0.01, "Valve cam curve produces symmetric S-characteristic")

    stg.current_speed_rpm = 4000.0 // Exceeds 3960 RPM overspeed limit
    stg.step_governor(0.1, 60.0, 150.0)
    assert_true(stg.emergency_trip_active == 1, "Overspeed bolt trips stop valves at 110% rated speed")

/datum/unit_test/test_advanced_turbomachinery/proc/test_hydro_turbine_penstock_inertia()
    var/datum/turbomachinery/hydro_turbine/hydro = new()
    var/initial_head = hydro.net_head_m
    // Rapidly open wicket gates from 0.5 to 0.9: water inertia causes initial head depression
    hydro.step_hydraulic_head(0.9, 0.5)
    assert_true(hydro.net_head_m < initial_head, "Water starting time Tw produces non-minimum phase head dip")

/datum/unit_test/test_advanced_turbomachinery/proc/test_wind_turbine_bem_mppt()
    var/datum/turbomachinery/wind_turbine_aero/wind = new()
    var/cp_opt = wind.calculate_power_coefficient(8.1, 0.0)
    assert_true(cp_opt > 0.40 && cp_opt < 0.593, "Optimal TSR yields high Cp below Betz limit")

    wind.step_turbine(1.0, 15.0) // Region 3 high wind (15 m/s)
    assert_true(wind.control_region == "REGION_3_PITCH", "High wind triggers Region 3 pitch control")
    assert_true(wind.blade_pitch_angle_deg > 0.0, "Blades pitch toward feather to limit rated power")
