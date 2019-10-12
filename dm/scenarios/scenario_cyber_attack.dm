// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Scenario: Cyber-Physical Fieldbus Packet Tampering & SIS Defense
// Language: Dream Maker (DM)

#ifndef PLENUM_SCENARIOS_CYBER_ATTACK_DM
#define PLENUM_SCENARIOS_CYBER_ATTACK_DM

#include "../core/datum.dm"
#include "../automation/plc.dm"
#include "../automation/modbus.dm"
#include "../safety/sis_interlocks.dm"

/datum/scenario_cyber_attack
    var/scenario_name = "Industrial Fieldbus Register Tampering & SIS Interlock Defense"
    var/attack_thwarted = FALSE

/datum/scenario_cyber_attack/proc/ExecuteScenarioStep(datum/plc_controller/plc, datum/modbus_server/server, datum/sif_voting_block/sis)
    // Adversary injects malicious Modbus FC 06 packet to overwrite pressure setpoint
    var/datum/modbus_frame/malicious_req = new /datum/modbus_frame()
    malicious_req.function_code = MODBUS_FC_WRITE_SINGLE_REG
    malicious_req.start_address = 5
    malicious_req.data_payload += 9999 // Dangerous override

    server.HandleRequest(malicious_req)

    // Independent Safety Instrumented System (SIS) hardwired voting logic
    // monitors physical pressure transmitters independently of SCADA network
    sis.UpdateSensors(TRUE, TRUE, FALSE)
    var/trip = sis.EvaluateVotingLogic(0.01)

    // Even if PLC registers are tampered, SIS overrides and protects facility
    if(trip)
        attack_thwarted = TRUE

    qdel(malicious_req)
    return attack_thwarted

#endif // PLENUM_SCENARIOS_CYBER_ATTACK_DM
