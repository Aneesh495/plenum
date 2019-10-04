// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Electrical Microgrid & Power Flow Verification Tests
// Language: Dream Maker (DM)

#ifndef PLENUM_TESTS_MICROGRID_DM
#define PLENUM_TESTS_MICROGRID_DM

#include "test_runner.dm"
#include "../microgrid/bus.dm"
#include "../microgrid/line.dm"
#include "../microgrid/transformer.dm"
#include "../microgrid/power_flow.dm"
#include "../microgrid/protection.dm"

/datum/test_suite_microgrid

/datum/test_suite_microgrid/proc/RunTests(datum/test_runner/runner)
    runner.StartSuite("Electrical Microgrid & Protection")

    // Test 1: Bus Real & Reactive Power Per-Unit Calculations
    var/datum/electrical_bus/bus1 = new /datum/electrical_bus("BUS-SLACK", BUS_TYPE_SLACK, 13.8)
    bus1.base_mva = 10.0
    bus1.p_gen_mw = 5.0
    bus1.p_load_mw = 2.0
    runner.AssertEqual(bus1.GetNetRealPowerPU(), 0.30, 0.0001, "Bus Net Real Power PU ( (5-2)/10 = 0.30 )")

    // Test 2: Transmission Line Series Admittance
    var/datum/electrical_bus/bus2 = new /datum/electrical_bus("BUS-LOAD", BUS_TYPE_PQ, 13.8)
    bus2.base_mva = 10.0
    bus2.p_load_mw = 3.0
    var/datum/transmission_line/line12 = new /datum/transmission_line("LINE-1-2", bus1, bus2, 0.02, 0.08, 0.01, 15.0)
    
    // G = R / (R^2 + X^2) = 0.02 / (0.0004 + 0.0064) = 0.02 / 0.0068 = 2.9412
    var/g_expected = 0.02 / ((0.02 * 0.02) + (0.08 * 0.08))
    runner.AssertEqual(line12.GetSeriesAdmittanceG(), g_expected, 0.001, "Line Conductance G_ij Formulation")

    // Test 3: Power Flow Solver Convergence
    var/list/b_list = list(bus1, bus2)
    var/list/l_list = list(line12)
    var/datum/power_flow_solver/pf = new /datum/power_flow_solver(b_list, l_list)
    var/converged = pf.SolveNewtonRaphson()
    runner.AssertTrue(converged, "Newton-Raphson 2-Bus Power Flow Convergence")
    runner.AssertTrue(bus2.voltage_magnitude_pu > 0.90 && bus2.voltage_magnitude_pu < 1.10, "Bus 2 Voltage Magnitude within Operational Envelope")

    // Test 4: IEC 60255 Inverse Time Overcurrent Relay Trip Timing
    var/datum/protective_relay/relay51 = new /datum/protective_relay("RELAY-51", 51, 500.0, 0.10)
    // At I = 1000A (M = 2.0x pickup), operating time should be ~ 1.0s with TMS = 0.1
    var/t_op = relay51.CalculateOperatingTimeSeconds(1000.0)
    runner.AssertTrue(t_op > 0.5 && t_op < 1.5, "IEC Standard Inverse Trip Time Calculation (t ~ 1.0s)")

    // Test 5: Transformer OLTC Tap Regulation
    var/datum/electrical_bus/bus_sec = new /datum/electrical_bus("BUS-SEC", BUS_TYPE_PQ, 4.16)
    bus_sec.voltage_magnitude_pu = 0.96 // Low voltage condition
    var/datum/power_transformer/xfmr = new /datum/power_transformer("XFMR-01", bus1, bus_sec, 20.0, 13.8, 4.16)
    xfmr.target_secondary_pu = 1.00
    xfmr.EvaluateOLTCServo()
    runner.AssertTrue(xfmr.tap_position > 0, "Transformer OLTC Steps Up Tap Position on Low Secondary Voltage")

    qdel(bus1)
    qdel(bus2)
    qdel(bus_sec)
    qdel(line12)
    qdel(pf)
    qdel(relay51)
    qdel(xfmr)

#endif // PLENUM_TESTS_MICROGRID_DM
