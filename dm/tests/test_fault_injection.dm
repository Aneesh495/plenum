// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Fault Injection & Rollback Checkpoint Verification Tests
// Language: Dream Maker (DM)

#ifndef PLENUM_TESTS_FAULT_INJECTION_DM
#define PLENUM_TESTS_FAULT_INJECTION_DM

#include "test_runner.dm"
#include "../scheduler/fault_injector.dm"
#include "../scheduler/rollback_engine.dm"
#include "../core/obj.dm"

/datum/test_suite_fault_injection

/datum/test_suite_fault_injection/proc/RunTests(datum/test_runner/runner)
    runner.StartSuite("Fault Injection & State Checkpoint Rollback")

    // Test 1: Sensor Calibration Drift Injection
    var/datum/fault_injection_engine/f_eng = new /datum/fault_injection_engine()
    var/obj/machinery/sensor/pit = new /obj/machinery/sensor()
    pit.calibrated_range_min = 0.0
    pit.calibrated_range_max = 100.0
    pit.calibration_drift_bias = 0.0

    f_eng.InjectSensorDrift(pit, 0.5, 10.0) // 0.5 unit/s drift for 10s
    f_eng.ProcessFaultsTick(2.0)
    runner.AssertEqual(pit.calibration_drift_bias, 1.0, 0.001, "Sensor Calibration Drift Progresses Deterministically (0.5 * 2s = 1.0)")

    // Test 2: Pipe Rupture Fault Injection
    var/datum/pipe_segment/pipe = new /datum/pipe_segment("P-CRIT", 20.0, 0.15)
    runner.AssertEqual(pipe.is_ruptured, FALSE, 0, "Pipe Initially Intact")
    f_eng.InjectPipeRupture(pipe, 0.5)
    runner.AssertEqual(pipe.is_ruptured, TRUE, 0, "Fault Injector Asserts Pipe Rupture Flag")

    // Test 3: State Rollback Checkpointing & Checksum Hashing
    var/datum/rollback_engine/rb = new /datum/rollback_engine()
    var/list/state_tick_100 = list(101.3, 293.15, 50.0, 1.0)
    var/chk_100 = rb.SaveCheckpoint(100, state_tick_100)
    runner.AssertTrue(chk_100 > 0, "FNV-1a Hash Generates Valid Non-Zero 32-bit Checksum")

    var/list/state_tick_101 = list(104.5, 298.20, 52.0, 1.0)
    rb.SaveCheckpoint(101, state_tick_101)

    // Rollback to tick 100
    var/list/restored_state = rb.RollbackToTick(100)
    runner.AssertEqual(restored_state[1], 101.3, 0.0001, "Rollback Engine Accurately Restores Checkpointed State at Tick 100")
    runner.AssertEqual(restored_state[2], 293.15, 0.0001, "Rollback Engine Restores Thermal Vector")

    qdel(f_eng)
    qdel(pit)
    qdel(pipe)
    qdel(rb)

#endif // PLENUM_TESTS_FAULT_INJECTION_DM
