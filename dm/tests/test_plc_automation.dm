// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: PLC Automation, Ladder Logic & PID Verification Tests
// Language: Dream Maker (DM)

#ifndef PLENUM_TESTS_PLC_AUTOMATION_DM
#define PLENUM_TESTS_PLC_AUTOMATION_DM

#include "test_runner.dm"
#include "../automation/plc.dm"
#include "../automation/ladder_logic.dm"
#include "../automation/function_blocks.dm"
#include "../automation/pid_controller.dm"
#include "../automation/modbus.dm"

/datum/test_suite_plc_automation

/datum/test_suite_plc_automation/proc/RunTests(datum/test_runner/runner)
    runner.StartSuite("PLC Automation & Closed-Loop Control")

    // Test 1: PLC Cyclic Scan with Ladder Logic Rung
    var/datum/plc_controller/plc = new /datum/plc_controller("PLC-TEST")
    var/datum/ladder_rung/rung1 = new /datum/ladder_rung()
    rung1.series_contacts += new /datum/ladder_contact(CONTACT_NORMALLY_OPEN, "IX", 1)
    rung1.output_coils += new /datum/ladder_coil(COIL_NORMAL, "QX", 1)
    plc.ladder_rungs += rung1

    plc.SetDiscreteInput(1, TRUE)
    plc.ExecuteCyclicScan(0.01)
    runner.AssertEqual(plc.GetDiscreteOutput(1), TRUE, 0, "Ladder Logic Rung NO Contact Energizes Output Coil")

    plc.SetDiscreteInput(1, FALSE)
    plc.ExecuteCyclicScan(0.01)
    runner.AssertEqual(plc.GetDiscreteOutput(1), FALSE, 0, "Ladder Logic Rung De-energizes on Contact Open")

    // Test 2: IEC 61131-3 TON Timer On-Delay
    var/datum/iec_function_block/timer_on_delay/ton = new /datum/iec_function_block/timer_on_delay()
    ton.preset_time_s = 2.0
    ton.input_in = TRUE
    ton.ExecuteBlock(plc, 1.0)
    runner.AssertEqual(ton.output_q, FALSE, 0, "TON Timer Output Remains FALSE Before Preset Time (1.0s < 2.0s)")
    ton.ExecuteBlock(plc, 1.5)
    runner.AssertEqual(ton.output_q, TRUE, 0, "TON Timer Output Asserts TRUE After Preset Exceeded (2.5s >= 2.0s)")

    // Test 3: PID Controller Anti-Reset Windup Clamping
    var/datum/pid_controller/pid = new /datum/pid_controller("PID-TEST", 2.0, 5.0, 0.0)
    pid.output_min = 0.0
    pid.output_max = 100.0
    pid.setpoint_sp = 100.0
    pid.process_variable_pv = 10.0 // Large persistent error
    for(var/step = 1 to 20)
        pid.ComputeStep(1.0)
    runner.AssertEqual(pid.control_output_cv, 100.0, 0.0001, "PID Output Clamped at 100% Upper Saturation Limit")
    runner.AssertTrue(pid.integral_accumulator <= 120.0, "PID Anti-Reset Windup Restricts Accumulator Growth")

    // Test 4: Modbus TCP FC 03 & FC 06 Register Transactions
    var/datum/modbus_server/mb_srv = new /datum/modbus_server(1, plc)
    var/datum/modbus_frame/write_req = new /datum/modbus_frame()
    write_req.function_code = MODBUS_FC_WRITE_SINGLE_REG
    write_req.start_address = 10
    write_req.data_payload += 4285
    var/datum/modbus_frame/write_resp = mb_srv.HandleRequest(write_req)
    runner.AssertEqual(plc.holding_registers[11], 4285, 0, "Modbus FC 06 Successfully Writes Holding Register")

    var/datum/modbus_frame/read_req = new /datum/modbus_frame()
    read_req.function_code = MODBUS_FC_READ_HOLDING_REGS
    read_req.start_address = 10
    read_req.quantity = 1
    var/datum/modbus_frame/read_resp = mb_srv.HandleRequest(read_req)
    runner.AssertEqual(read_resp.data_payload[1], 4285, 0, "Modbus FC 03 Successfully Reads Back Register Value")

    qdel(plc)
    qdel(ton)
    qdel(pid)
    qdel(mb_srv)
    qdel(write_req)
    qdel(write_resp)
    qdel(read_req)
    qdel(read_resp)

#endif // PLENUM_TESTS_PLC_AUTOMATION_DM
