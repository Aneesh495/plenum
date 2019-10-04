// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: In-Engine Test Harness & Assertion Framework
// Language: Dream Maker (DM)

#ifndef PLENUM_TESTS_TEST_RUNNER_DM
#define PLENUM_TESTS_TEST_RUNNER_DM

#include "../core/datum.dm"

/datum/test_runner
    var/total_assertions = 0
    var/passed_assertions = 0
    var/failed_assertions = 0
    var/list/failure_messages = list()
    var/current_suite_name = "Global"

/datum/test_runner/proc/StartSuite(suite_name)
    current_suite_name = suite_name
    world.log << "------------------------------------------------------------"
    world.log << "Running Test Suite: [suite_name]"
    world.log << "------------------------------------------------------------"

/datum/test_runner/proc/AssertTrue(condition, test_name)
    total_assertions++
    if(condition)
        passed_assertions++
        world.log << "  [test_name]: PASS"
        return TRUE
    else
        failed_assertions++
        var/msg = "FAIL in [current_suite_name] -> [test_name]: Expected TRUE, got FALSE"
        failure_messages += msg
        world.log << "  [msg]"
        return FALSE

/datum/test_runner/proc/AssertFalse(condition, test_name)
    return AssertTrue(!condition, test_name)

/datum/test_runner/proc/AssertEqual(actual, expected, tolerance = 0.0001, test_name = "Equality Test")
    total_assertions++
    var/is_equal = FALSE
    if(isnum(actual) && isnum(expected))
        is_equal = abs(actual - expected) <= tolerance
    else
        is_equal = (actual == expected)

    if(is_equal)
        passed_assertions++
        world.log << "  [test_name]: PASS ([actual])"
        return TRUE
    else
        failed_assertions++
        var/msg = "FAIL in [current_suite_name] -> [test_name]: Expected [expected], got [actual] (diff: [abs(actual - expected)])"
        failure_messages += msg
        world.log << "  [msg]"
        return FALSE

/datum/test_runner/proc/PrintSummary()
    world.log << "============================================================"
    world.log << "PLENUM TEST EXECUTION SUMMARY"
    world.log << "============================================================"
    world.log << "Total Assertions : [total_assertions]"
    world.log << "Passed           : [passed_assertions]"
    world.log << "Failed           : [failed_assertions]"
    if(failed_assertions == 0)
        world.log << "ALL SUITES PASSED VERIFICATION WITH ZERO FAILURES."
    else
        world.log << "FAILURES DETECTED:"
        for(var/f in failure_messages)
            world.log << "  - [f]"
    world.log << "============================================================"
    return (failed_assertions == 0)

#endif // PLENUM_TESTS_TEST_RUNNER_DM
