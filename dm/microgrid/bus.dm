// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Electrical Bus Nodes & Complex Nodal Admittance
// Language: Dream Maker (DM)

#ifndef PLENUM_MICROGRID_BUS_DM
#define PLENUM_MICROGRID_BUS_DM

#include "../defines.dm"
#include "../core/datum.dm"

/datum/electrical_bus
    var/bus_id = "BUS-01"
    var/bus_type = BUS_TYPE_PQ           // 1=PQ (Load), 2=PV (Generator), 3=Slack (Swing)
    var/base_kv = 13.8                   // Nominal line-to-line RMS kV
    var/base_mva = 10.0                  // Per-unit base apparent power
    var/voltage_magnitude_pu = 1.00      // Per-unit voltage magnitude
    var/voltage_angle_rad = 0.0          // Voltage phase angle in radians
    
    // Nodal Power Injections (Net: Gen - Load)
    var/p_gen_mw = 0.0                   // Active power generation
    var/q_gen_mvar = 0.0                 // Reactive power generation
    var/p_load_mw = 0.0                  // Active power load
    var/q_load_mvar = 0.0                // Reactive power load

    // Shunt admittance (Y_shunt = G + jB)
    var/shunt_conductance_g_pu = 0.0     // Shunt conductance per-unit
    var/shunt_susceptance_b_pu = 0.0     // Shunt susceptance per-unit (capacitor banks/reactors)

    // Generator voltage limits for PV buses
    var/q_min_mvar = -5.0
    var/q_max_mvar = 10.0
    var/target_voltage_pu = 1.00

    // Dynamic frequency state
    var/frequency_hz = SYSTEM_FREQUENCY_NOMINAL_HZ
    var/frequency_rocof_hz_s = 0.0       // Rate of Change of Frequency (RoCoF)

    // Network topology associations
    var/list/connected_lines = list()
    var/list/connected_loads = list()
    var/list/connected_generators = list()
    var/list/connected_breakers = list()

/datum/electrical_bus/New(id, type = BUS_TYPE_PQ, kv = 13.8)
    ..()
    bus_id = id
    bus_type = type
    base_kv = kv
    voltage_magnitude_pu = 1.00
    voltage_angle_rad = 0.0

/datum/electrical_bus/proc/GetNetRealPowerPU()
    // Net real power injected into network in per-unit: (P_gen - P_load) / S_base
    return (p_gen_mw - p_load_mw) / base_mva

/datum/electrical_bus/proc/GetNetReactivePowerPU()
    // Net reactive power injected in per-unit: (Q_gen - Q_load) / S_base
    return (q_gen_mvar - q_load_mvar) / base_mva

/datum/electrical_bus/proc/GetActualVoltageKV()
    return voltage_magnitude_pu * base_kv

/datum/electrical_bus/proc/UpdateFrequencyDroop(delta_p_pu, droop_percentage = 4.0, inertia_constant_h = 4.0, delta_time_seconds = 0.01)
    // Governor frequency droop & swing equation:
    // 2 * H * (df / dt) = delta_P_mech - delta_P_elec - D * delta_f
    var/damping_d = 1.5
    var/delta_f = (frequency_hz - SYSTEM_FREQUENCY_NOMINAL_HZ) / SYSTEM_FREQUENCY_NOMINAL_HZ
    
    // Power imbalance acceleration
    var/accel_power = delta_p_pu - (damping_d * delta_f)
    frequency_rocof_hz_s = (accel_power / (2.0 * inertia_constant_h)) * SYSTEM_FREQUENCY_NOMINAL_HZ
    frequency_hz += frequency_rocof_hz_s * delta_time_seconds
    return frequency_hz

/datum/electrical_bus/proc/CheckVoltageThresholds()
    // ANSI C84.1 Range A (0.95 to 1.05 pu) and Range B (0.90 to 1.06 pu)
    if(voltage_magnitude_pu < 0.90)
        return "CRITICAL_UNDERVOLTAGE"
    else if(voltage_magnitude_pu < 0.95)
        return "WARNING_UNDERVOLTAGE"
    else if(voltage_magnitude_pu > 1.05)
        return "WARNING_OVERVOLTAGE"
    return "NORMAL"

#endif // PLENUM_MICROGRID_BUS_DM
