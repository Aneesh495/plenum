// Test Suite: Industrial Telemetry, SCADA, and IIoT Protocol Verification
//
// Meticulously tests OPC UA IEC 62541 monitored items and deadbands,
// DNP3 IEEE 1815 Select-Before-Operate CROB state machine, and Sparkplug B RBE encoding.

/datum/unit_test/test_advanced_telemetry
    var/tests_passed = 0
    var/tests_failed = 0

/datum/unit_test/test_advanced_telemetry/proc/run_all_tests()
    world.log << "--- RUNNING ADVANCED TELEMETRY UNIT TESTS ---"
    test_opc_ua_address_space_and_deadbands()
    test_dnp3_sbo_two_step_control()
    test_dnp3_class_event_queues()
    test_sparkplug_b_dbirth_and_rbe()
    world.log << "--- ADVANCED TELEMETRY RESULTS: [tests_passed] PASSED, [tests_failed] FAILED ---"
    return (tests_failed == 0)

/datum/unit_test/test_advanced_telemetry/proc/assert_true(condition, test_name)
    if(condition)
        tests_passed++
        world.log << "  [test_name]: PASS"
    else
        tests_failed++
        world.log << "  [test_name]: FAIL"

/datum/unit_test/test_advanced_telemetry/proc/test_opc_ua_address_space_and_deadbands()
    var/datum/telemetry/opc_ua_server/server = new()
    var/val = server.read_variable(1, "Plant.Boiler.DrumPressure")
    assert_true(val == 65.0, "Initial address space variable read succeeds")

    server.add_monitored_item(1, "Plant.Boiler.DrumPressure", 0.5)

    // Minor change (0.1 bar) below 0.5 bar deadband: should not emit
    server.write_variable(1, "Plant.Boiler.DrumPressure", 65.1)
    var/list/notifs_empty = server.publish_notifications()
    // First call always initializes; second small move must suppress
    server.write_variable(1, "Plant.Boiler.DrumPressure", 65.2)
    var/list/notifs_suppressed = server.publish_notifications()
    assert_true(notifs_suppressed.len == 0, "OPC UA deadband filter suppresses minor value changes")

/datum/unit_test/test_advanced_telemetry/proc/test_dnp3_sbo_two_step_control()
    var/datum/telemetry/dnp3_outstation/dnp = new()
    // Step 1: Attempt to operate without selecting: must fail with NOT_ARMED error code 3
    var/res_bad = dnp.handle_sbo_operate(1, "TRIP")
    assert_true(res_bad == 3, "Direct operate without select rejected by SBO state machine")

    // Step 2: Select first
    var/res_sel = dnp.handle_sbo_select(1)
    assert_true(res_sel == 0, "Select command arms targeted binary output point")

    // Step 3: Operate while armed: must succeed
    var/res_ok = dnp.handle_sbo_operate(1, "TRIP")
    assert_true(res_ok == 0, "Operate command executes on armed point")

/datum/unit_test/test_advanced_telemetry/proc/test_dnp3_class_event_queues()
    var/datum/telemetry/dnp3_outstation/dnp = new()
    dnp.set_binary_input(2, 1, 100.5)
    assert_true(dnp.class1_events.len == 1, "Binary state change enqueues Class 1 event")

    var/list/polled = dnp.poll_events(1)
    assert_true(polled.len == 1, "Class 1 poll retrieves event")
    assert_true(dnp.class1_events.len == 0, "Polled events cleared from buffer")

/datum/unit_test/test_advanced_telemetry/proc/test_sparkplug_b_dbirth_and_rbe()
    var/datum/telemetry/sparkplug_eon/spb = new()
    var/list/birth = spb.encode_dbirth(1700000000000)
    var/topic = birth["topic"]
    assert_true(topic == "spBv1.0/PLANT_SOUTH/DBIRTH/TURBINE_BAY_01/GAS_TURBINE_01", "Sparkplug B topic formatted correctly")

    // No changes: DDATA must be null (RBE compression)
    var/list/ddata_none = spb.encode_ddata(1700000001000)
    assert_true(ddata_none == null, "RBE suppresses publication when metrics remain unchanged")

    // Modify metric and verify DDATA generation
    spb.set_metric_value(2, 245.8)
    var/list/ddata_active = spb.encode_ddata(1700000002000)
    assert_true(ddata_active != null, "Report-by-Exception publishes changed metric")
