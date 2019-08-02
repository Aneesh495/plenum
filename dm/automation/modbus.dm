// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Modbus TCP/RTU Protocol Engine & Register Map
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_MODBUS_DM
#define PLENUM_AUTOMATION_MODBUS_DM

#include "plc.dm"

// Modbus Exception Codes
#define MODBUS_EX_ILLEGAL_FUNCTION         1
#define MODBUS_EX_ILLEGAL_DATA_ADDRESS     2
#define MODBUS_EX_ILLEGAL_DATA_VALUE       3
#define MODBUS_EX_SLAVE_DEVICE_FAILURE     4

/datum/modbus_frame
    var/transaction_id = 0
    var/protocol_id = 0                  // 0 = Modbus TCP
    var/unit_id = 1
    var/function_code = 3
    var/start_address = 0
    var/quantity = 1
    var/list/data_payload = list()
    var/exception_code = 0

/datum/modbus_server
    var/server_unit_id = 1
    var/datum/plc_controller/bound_plc = null

/datum/modbus_server/New(unit = 1, datum/plc_controller/plc)
    ..()
    server_unit_id = unit
    bound_plc = plc

/datum/modbus_server/proc/CalculateCRC16(list/byte_array)
    // Standard Modbus CRC-16 (Polynomial 0xA001, Initial value 0xFFFF)
    var/crc = 65535
    for(var/b in byte_array)
        crc = crc ^ b
        for(var/bit = 1 to 8)
            if(crc & 1)
                crc = (crc >> 1) ^ 40961 // 0xA001
            else
                crc = crc >> 1
    return crc & 65535

/datum/modbus_server/proc/HandleRequest(datum/modbus_frame/req)
    var/datum/modbus_frame/resp = new /datum/modbus_frame()
    resp.transaction_id = req.transaction_id
    resp.protocol_id = req.protocol_id
    resp.unit_id = req.unit_id
    resp.function_code = req.function_code

    if(!bound_plc)
        resp.function_code = req.function_code | 128 // Exception flag
        resp.exception_code = MODBUS_EX_SLAVE_DEVICE_FAILURE
        return resp

    switch(req.function_code)
        if(MODBUS_FC_READ_HOLDING_REGS)
            // FC 03: Read Holding Registers (%MW)
            var/start = req.start_address + 1
            var/count = req.quantity
            if(start < 1 || start + count - 1 > bound_plc.holding_registers.len)
                resp.function_code = req.function_code | 128
                resp.exception_code = MODBUS_EX_ILLEGAL_DATA_ADDRESS
                return resp

            for(var/i = start to (start + count - 1))
                resp.data_payload += bound_plc.holding_registers[i]

        if(MODBUS_FC_WRITE_SINGLE_REG)
            // FC 06: Write Single Register
            var/addr = req.start_address + 1
            if(addr < 1 || addr > bound_plc.holding_registers.len)
                resp.function_code = req.function_code | 128
                resp.exception_code = MODBUS_EX_ILLEGAL_DATA_ADDRESS
                return resp

            if(req.data_payload.len > 0)
                bound_plc.holding_registers[addr] = req.data_payload[1]
                resp.data_payload += req.data_payload[1]

        if(MODBUS_FC_READ_DISCRETE_INPUTS)
            // FC 02: Read Discrete Inputs (%IX)
            var/start = req.start_address + 1
            var/count = req.quantity
            if(start < 1 || start + count - 1 > bound_plc.discrete_inputs.len)
                resp.function_code = req.function_code | 128
                resp.exception_code = MODBUS_EX_ILLEGAL_DATA_ADDRESS
                return resp

            for(var/i = start to (start + count - 1))
                resp.data_payload += bound_plc.discrete_inputs[i]

        if(MODBUS_FC_WRITE_SINGLE_COIL)
            // FC 05: Write Single Coil (%QX)
            var/addr = req.start_address + 1
            if(addr < 1 || addr > bound_plc.discrete_outputs.len)
                resp.function_code = req.function_code | 128
                resp.exception_code = MODBUS_EX_ILLEGAL_DATA_ADDRESS
                return resp

            if(req.data_payload.len > 0)
                bound_plc.discrete_outputs[addr] = req.data_payload[1] ? TRUE : FALSE
                resp.data_payload += req.data_payload[1]

        else
            resp.function_code = req.function_code | 128
            resp.exception_code = MODBUS_EX_ILLEGAL_FUNCTION

    return resp

#endif // PLENUM_AUTOMATION_MODBUS_DM
