// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Battery Energy Storage Systems (BESS) & Electrochemical Models
// Language: Dream Maker (DM)

#ifndef PLENUM_MICROGRID_STORAGE_DM
#define PLENUM_MICROGRID_STORAGE_DM

#include "bus.dm"

/datum/bess_unit
    var/storage_id = "BESS-01"
    var/datum/electrical_bus/connected_bus = null
    
    // Nameplate Capacity
    var/capacity_mwh = 4.0              // Total nominal capacity
    var/max_power_mw = 2.0              // 0.5C 2-hour rating
    var/state_of_charge = 0.50          // SoC in range [0.0, 1.0]
    var/min_soc = 0.10                  // 10% reserve margin to prevent degradation
    var/max_soc = 0.95                  // 95% upper limit to prevent overcharging

    // Electrical & Inverter Efficiencies
    var/coulombic_efficiency = 0.98
    var/inverter_efficiency = 0.96      // Bi-directional 4-quadrant PCS
    var/internal_resistance_ohms = 0.02
    
    // Operating States
    var/active_power_mw = 0.0           // Positive = Discharging to grid, Negative = Charging
    var/reactive_power_mvar = 0.0       // 4-quadrant reactive voltage support
    var/cell_temperature_c = 25.0       // Cell pack temperature
    var/thermal_mass_j_k = 2000000.0    // Pack thermal mass
    var/cooling_power_kw = 50.0

/datum/bess_unit/New(id, datum/electrical_bus/bus, mwh = 4.0, max_mw = 2.0)
    ..()
    storage_id = id
    connected_bus = bus
    capacity_mwh = mwh
    max_power_mw = max_mw
    if(connected_bus)
        connected_bus.connected_generators += src

/datum/bess_unit/proc/CalculateOCV(soc)
    // LiFePO4 open circuit voltage flat plateau with steep knees
    soc = max(0.0, min(1.0, soc))
    if(soc < 0.1)
        return 3.00 + (soc * 2.0) // 3.00V to 3.20V
    else if(soc > 0.9)
        return 3.32 + ((soc - 0.9) * 2.8) // 3.32V to 3.60V
    else
        return 3.20 + ((soc - 0.1) * 0.15) // Stable nominal plateau ~3.25V

/datum/bess_unit/proc/CommandDispatch(target_mw, target_mvar, delta_time_seconds)
    // Clamp to hardware bidirectional inverter power envelope
    active_power_mw = max(-max_power_mw, min(max_power_mw, target_mw))
    reactive_power_mvar = max(-max_power_mw * 0.5, min(max_power_mw * 0.5, target_mvar))

    // Check SoC boundaries
    if(active_power_mw > 0.0 && state_of_charge <= min_soc)
        active_power_mw = 0.0 // Battery depleted
    else if(active_power_mw < 0.0 && state_of_charge >= max_soc)
        active_power_mw = 0.0 // Battery full

    // Integrate SoC: Delta_SoC = - (P * dt) / (Capacity * eta)
    var/dt_hours = delta_time_seconds / 3600.0
    if(active_power_mw > 0.0)
        // Discharging
        var/energy_withdrawn = (active_power_mw * dt_hours) / inverter_efficiency
        state_of_charge = max(0.0, state_of_charge - (energy_withdrawn / capacity_mwh))
    else if(active_power_mw < 0.0)
        // Charging
        var/energy_stored = (-active_power_mw * dt_hours) * inverter_efficiency * coulombic_efficiency
        state_of_charge = min(1.0, state_of_charge + (energy_stored / capacity_mwh))

    // Thermal dissipation: Joule loss P_loss = I^2 * R
    var/i_approx = (abs(active_power_mw) * 1000000.0) / 800.0 // 800V DC bus
    var/p_loss_watts = (i_approx * i_approx) * internal_resistance_ohms
    var/heat_joules = p_loss_watts * delta_time_seconds
    var/delta_t = heat_joules / thermal_mass_j_k
    cell_temperature_c += delta_t

    // Active thermal chiller response
    if(cell_temperature_c > 28.0)
        var/cool_joules = cooling_power_kw * 1000.0 * delta_time_seconds
        cell_temperature_c = max(25.0, cell_temperature_c - (cool_joules / thermal_mass_j_k))

    if(connected_bus)
        connected_bus.p_gen_mw += active_power_mw
        connected_bus.q_gen_mvar += reactive_power_mvar

    return active_power_mw

#endif // PLENUM_MICROGRID_STORAGE_DM
