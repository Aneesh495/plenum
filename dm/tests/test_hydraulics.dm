// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Hydraulics, Pumps & Valve Verification Tests
// Language: Dream Maker (DM)

#ifndef PLENUM_TESTS_HYDRAULICS_DM
#define PLENUM_TESTS_HYDRAULICS_DM

#include "test_runner.dm"
#include "../hydraulics/pipe_network.dm"
#include "../hydraulics/pump.dm"
#include "../hydraulics/valve.dm"
#include "../hydraulics/vessel.dm"

/datum/test_suite_hydraulics

/datum/test_suite_hydraulics/proc/RunTests(datum/test_runner/runner)
    runner.StartSuite("Hydraulics, Pumps & Process Vessels")

    // Test 1: Darcy-Weisbach Head Loss
    var/datum/pipe_segment/pipe = new /datum/pipe_segment("P-TEST", 100.0, 0.20) // 100m, 20cm diam
    pipe.flow_rate_m3_s = 0.08 // 80 L/s
    var/head_loss = pipe.CalculateHeadLossMeters()
    runner.AssertTrue(head_loss > 0.5 && head_loss < 10.0, "Darcy-Weisbach Realistic Hydraulic Friction Head Loss")

    // Test 2: Joukowsky Water Hammer Surge Pressure
    // Delta_P = rho * a * Delta_v (For rho=1000, a=1200, Delta_v=2 m/s -> Delta_P = 2.4 MPa / 24 bar)
    var/surge_pa = pipe.CalculateJoukowskyShockPressure(2.0)
    runner.AssertEqual(surge_pa, 2400000.0, 1000.0, "Joukowsky Surge Pressure Calculation (Delta_P = 2.4 MPa)")

    // Test 3: Pump Affinity Law Speed Scaling
    var/obj/machinery/centrifugal_pump/pmp = new /obj/machinery/centrifugal_pump()
    pmp.shutoff_head_meters = 80.0
    pmp.vfd_speed_ratio = 1.0
    var/head_100 = pmp.CalculatePumpHead(0.0)
    runner.AssertEqual(head_100, 80.0, 0.01, "Centrifugal Pump Shutoff Head at 100% Speed")

    pmp.vfd_speed_ratio = 0.5 // 50% speed -> Head should scale as (0.5)^2 = 0.25 -> 20.0m
    var/head_50 = pmp.CalculatePumpHead(0.0)
    runner.AssertEqual(head_50, 20.0, 0.01, "Pump Affinity Law Head Scaling: H2 = H1 * (N2/N1)^2")

    // Test 4: Equal Percentage Control Valve Cv Characteristics
    var/obj/machinery/control_valve/vlv = new /obj/machinery/control_valve()
    vlv.cv_max = 100.0
    vlv.trim_characteristic = VALVE_TRIM_EQUAL_PERCENT
    vlv.rangeability = 50.0
    vlv.stem_position = 1.0 // 100% stroke -> Cv = Cv_max = 100
    runner.AssertEqual(vlv.CalculateEffectiveCv(), 100.0, 0.01, "Equal Percentage Valve Cv at 100% Stroke")
    vlv.stem_position = 0.5 // 50% stroke -> Cv = 100 * 50^(-0.5) = 14.14
    runner.AssertEqual(vlv.CalculateEffectiveCv(), 14.142, 0.01, "Equal Percentage Valve Cv at 50% Stroke")

    // Test 5: Pressure Vessel ASME Hoop Stress
    var/obj/machinery/process_vessel/ves = new /obj/machinery/process_vessel(null, "VES-TEST", 5.0, 1.2)
    ves.wall_thickness_meters = 0.025
    ves.ullage_gas.SetCompositionSTP(1000.0, 293.15, 0.0, 1.0) // 10 bar (1 MPa)
    var/sigma = ves.CalculateHoopStressPascals()
    // sigma = (1e6 * 1.2) / 0.025 = 48 MPa
    runner.AssertEqual(sigma, 48000000.0, 100000.0, "ASME Boiler Code Hoop Stress Calculation (sigma = P*r/t = 48 MPa)")

    qdel(pipe)
    qdel(pmp)
    qdel(vlv)
    qdel(ves)

#endif // PLENUM_TESTS_HYDRAULICS_DM
