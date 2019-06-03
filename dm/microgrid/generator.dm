// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Distributed Energy Generation (Synchronous, Solar PV, PEM Fuel Cell)
// Language: Dream Maker (DM)

#ifndef PLENUM_MICROGRID_GENERATOR_DM
#define PLENUM_MICROGRID_GENERATOR_DM

#include "bus.dm"

/datum/power_generator
    var/generator_id = "GEN-01"
    var/datum/electrical_bus/connected_bus = null
    var/rated_capacity_mw = 10.0
    var/current_output_mw = 0.0
    var/current_output_mvar = 0.0
    var/power_factor = 0.95
    var/is_online = TRUE
    var/ramp_rate_mw_per_min = 2.0
    var/minimum_stable_mw = 1.0

/datum/power_generator/New(id, datum/electrical_bus/bus, mw = 10.0)
    ..()
    generator_id = id
    connected_bus = bus
    rated_capacity_mw = mw
    if(connected_bus)
        connected_bus.connected_generators += src

// ----------------------------------------------------------------------------
// Synchronous Turbo-Alternator with IEEE DC1A Exciter & Droop Governor
// ----------------------------------------------------------------------------

/datum/power_generator/synchronous_alternator
    var/inertia_constant_h = 3.5         // Seconds (MW*s / MVA)
    var/governor_droop_percent = 4.0     // 4% standard droop
    var/excitation_voltage_pu = 1.05
    var/armature_current_limit_pu = 1.10
    var/field_thermal_limit_pu = 1.25

/datum/power_generator/synchronous_alternator/proc/UpdateGovernor(target_mw, grid_freq_hz, delta_time_seconds)
    if(!is_online)
        current_output_mw = 0.0
        current_output_mvar = 0.0
        return 0.0

    // Droop response: Delta_P = -(1 / Droop) * (Delta_f / f_nom)
    var/freq_err_pu = (grid_freq_hz - SYSTEM_FREQUENCY_NOMINAL_HZ) / SYSTEM_FREQUENCY_NOMINAL_HZ
    var/droop_delta_mw = -(rated_capacity_mw / (governor_droop_percent * 0.01)) * freq_err_pu
    var/desired_mw = max(minimum_stable_mw, min(rated_capacity_mw, target_mw + droop_delta_mw))

    // Ramp rate limiter
    var/max_ramp_step = (ramp_rate_mw_per_min / 60.0) * delta_time_seconds
    if(desired_mw > current_output_mw)
        current_output_mw = min(current_output_mw + max_ramp_step, desired_mw)
    else
        current_output_mw = max(current_output_mw - max_ramp_step, desired_mw)

    if(connected_bus)
        connected_bus.p_gen_mw = current_output_mw
        connected_bus.q_gen_mvar = current_output_mvar

    return current_output_mw

// ----------------------------------------------------------------------------
// Solar Photovoltaic (PV) with Perturb & Observe MPPT
// ----------------------------------------------------------------------------

/datum/power_generator/solar_pv
    var/array_area_m2 = 5000.0           // Commercial rooftop / ground mount
    var/module_efficiency = 0.215        // 21.5% high-efficiency monocrystalline
    var/temp_coefficient_pmax = -0.0035  // -0.35% / K power loss above 25 C
    var/irradiance_w_m2 = 800.0          // Direct normal + diffuse solar flux
    var/cell_temperature_c = 45.0
    var/mppt_voltage_v = 600.0           // DC link voltage
    var/last_power_w = 0.0
    var/perturb_step_v = 2.0

/datum/power_generator/solar_pv/proc/CalculatePVPowerWatts()
    // Standard PV output equation: P = G * A * eta * (1 + gamma*(T_cell - 25))
    var/temp_derate = 1.0 + (temp_coefficient_pmax * (cell_temperature_c - 25.0))
    temp_derate = max(0.5, min(1.2, temp_derate))
    var/raw_dc_watts = irradiance_w_m2 * array_area_m2 * module_efficiency * temp_derate
    
    // Inverter clipping at rated capacity
    var/max_inverter_watts = rated_capacity_mw * 1000000.0
    var/ac_watts = min(raw_dc_watts * 0.97, max_inverter_watts) // 97% inverter efficiency
    current_output_mw = ac_watts * 0.000001
    
    if(connected_bus)
        connected_bus.p_gen_mw = current_output_mw
    return current_output_mw

// ----------------------------------------------------------------------------
// PEM Fuel Cell System
// ----------------------------------------------------------------------------

/datum/power_generator/fuel_cell
    var/cell_count = 500
    var/cell_active_area_cm2 = 300.0
    var/operating_temperature_k = 353.15 // 80 C
    var/h2_consumption_rate_g_s = 0.0
    var/o2_consumption_rate_g_s = 0.0

/datum/power_generator/fuel_cell/proc/CalculateCellVoltage(current_density_a_cm2)
    // Nernst reversible open-circuit potential E_nernst ~ 1.229 V at STP, ~1.18 V at 80 C
    var/e_nernst = 1.18
    
    // Tafel activation overpotential: eta_act = a + b * ln(i)
    var/eta_act = 0.06 + (0.04 * log(max(0.001, current_density_a_cm2)))
    
    // Ohmic resistive loss: eta_ohm = i * R_internal
    var/r_membrane = 0.15 // Ohm * cm^2
    var/eta_ohm = current_density_a_cm2 * r_membrane
    
    // Concentration mass-transport loss: eta_conc = -B * ln(1 - i / i_limit)
    var/i_limit = 2.0 // A / cm^2
    var/ratio = current_density_a_cm2 / i_limit
    var/eta_conc = -0.05 * log(max(0.001, 1.0 - ratio))

    var/v_cell = e_nernst - eta_act - eta_ohm - eta_conc
    return max(0.2, v_cell)

#endif // PLENUM_MICROGRID_GENERATOR_DM
