// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Safety Instrumented Systems (SIS) & ESD Verification Tests
// Language: Dream Maker (DM)

#ifndef PLENUM_TESTS_SIS_SAFETY_DM
#define PLENUM_TESTS_SIS_SAFETY_DM

#include "test_runner.dm"
#include "../safety/sis_interlocks.dm"
#include "../safety/emergency_shutdown.dm"
#include "../safety/containment.dm"
#include "../microgrid/switchgear.dm"

/datum/test_suite_sis_safety

/datum/test_suite_sis_safety/proc/RunTests(datum/test_runner/runner)
    runner.StartSuite("Safety Instrumented Systems & ESD")

    // Test 1: 2oo3 Triple Modular Redundancy Voting Logic
    var/datum/sif_voting_block/sif = new /datum/sif_voting_block("SIF-TEST", SIS_ARCH_2OO3, SIL_RATING_3)
    
    // Case 1: 0 channels tripped -> No trip
    sif.UpdateSensors(FALSE, FALSE, FALSE)
    runner.AssertEqual(sif.EvaluateVotingLogic(0.1), FALSE, 0, "2oo3 Voting: 0/3 Demands -> No Trip")

    // Case 2: 1 channel tripped (spurious glitch or single sensor failure) -> No trip
    sif.UpdateSensors(TRUE, FALSE, FALSE)
    runner.AssertEqual(sif.EvaluateVotingLogic(0.1), FALSE, 0, "2oo3 Voting: 1/3 Demands -> Immunity to Spurious Trip")

    // Case 3: 2 channels tripped -> Immediate Voted Trip
    sif.UpdateSensors(TRUE, TRUE, FALSE)
    runner.AssertEqual(sif.EvaluateVotingLogic(0.1), TRUE, 0, "2oo3 Voting: 2/3 Demands -> Majority Trip Asserts TRUE")

    // Case 4: 3 channels tripped -> Voted Trip
    sif.UpdateSensors(TRUE, TRUE, TRUE)
    runner.AssertEqual(sif.EvaluateVotingLogic(0.1), TRUE, 0, "2oo3 Voting: 3/3 Demands -> Full Trip Asserts TRUE")

    // Test 2: ESD Level 3 Facility Blackout Sequencing
    var/datum/esd_sequencer/esd = new /datum/esd_sequencer()
    var/obj/machinery/circuit_breaker/bkr1 = new /obj/machinery/circuit_breaker(null, "BKR-MAIN-1", null, null)
    var/obj/machinery/circuit_breaker/bkr2 = new /obj/machinery/circuit_breaker(null, "BKR-MAIN-2", null, null)
    esd.main_power_breakers += bkr1
    esd.main_power_breakers += bkr2

    esd.TriggerESD(ESD_STAGE_FACILITY_BLACK)
    runner.AssertEqual(bkr1.breaker_state, BREAKER_STATE_TRIPPED, 0, "ESD-3 Trips Main Circuit Breaker 1")
    runner.AssertEqual(bkr2.breaker_state, BREAKER_STATE_TRIPPED, 0, "ESD-3 Trips Main Circuit Breaker 2")
    runner.AssertTrue(esd.blowdown_active, "ESD-3 Initiates Active Emergency Flare Depressurization")

    // Test 3: Airlock Hermetic Interlock
    var/datum/airlock_controller/airlock = new /datum/airlock_controller()
    var/obj/machinery/containment_door/door_in = new /obj/machinery/containment_door()
    var/obj/machinery/containment_door/door_out = new /obj/machinery/containment_door()
    door_in.door_state = 3 // Sealed
    door_out.door_state = 3 // Sealed
    airlock.door_inner = door_in
    airlock.door_outer = door_out

    var/entry_granted = airlock.RequestEntry()
    runner.AssertTrue(entry_granted, "Airlock Ingress Allowed When Opposing Door is Verified Sealed")
    runner.AssertEqual(door_out.door_state, 4, 0, "Outer Door Begins Opening on Valid Entry Request")

    qdel(sif)
    qdel(esd)
    qdel(bkr1)
    qdel(bkr2)
    qdel(airlock)
    qdel(door_in)
    qdel(door_out)

#endif // PLENUM_TESTS_SIS_SAFETY_DM
