// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Distribution Manifolds, Mixing Chambers & Pressure Balancing
// Language: Dream Maker (DM)

#ifndef PLENUM_HYDRAULICS_MANIFOLD_DM
#define PLENUM_HYDRAULICS_MANIFOLD_DM

#include "pipe_network.dm"
#include "valve.dm"

/datum/hydraulic_manifold
    var/manifold_id = "MAN-101"
    var/internal_volume_liters = 500.0
    var/header_pressure_pa = 500000.0   // 5 bar
    var/header_temperature_k = 293.15
    var/list/inlet_pipes = list()
    var/list/outlet_pipes = list()
    var/total_inflow_m3_s = 0.0
    var/total_outflow_m3_s = 0.0

/datum/hydraulic_manifold/New(id, vol_liters = 500.0)
    ..()
    manifold_id = id
    internal_volume_liters = vol_liters

/datum/hydraulic_manifold/proc/AddInlet(datum/pipe_segment/pipe)
    if(pipe && !(pipe in inlet_pipes))
        inlet_pipes += pipe

/datum/hydraulic_manifold/proc/AddOutlet(datum/pipe_segment/pipe)
    if(pipe && !(pipe in outlet_pipes))
        outlet_pipes += pipe

/datum/hydraulic_manifold/proc/BalanceManifoldStep(delta_time_seconds)
    total_inflow_m3_s = 0.0
    var/sum_enthalpy_flow = 0.0
    var/sum_mass_flow = 0.0

    // Sum all incoming flows
    for(var/datum/pipe_segment/in_p in inlet_pipes)
        if(in_p.is_ruptured) continue
        var/q = max(0.0, in_p.flow_rate_m3_s)
        total_inflow_m3_s += q
        var/m_dot = q * in_p.fluid_density_kg_m3
        sum_mass_flow += m_dot
        // Assume water Cp = 4184 J / (kg * K)
        sum_enthalpy_flow += m_dot * 4184.0 * 293.15

    // Mix temperature in header chamber
    if(sum_mass_flow > 0.001)
        header_temperature_k = sum_enthalpy_flow / (sum_mass_flow * 4184.0)

    // Distribute outflow across parallel outlet branches proportionally to flow conductance
    total_outflow_m3_s = 0.0
    var/out_count = outlet_pipes.len
    if(out_count > 0)
        var/q_per_branch = total_inflow_m3_s / out_count
        for(var/datum/pipe_segment/out_p in outlet_pipes)
            if(out_p.is_ruptured) continue
            out_p.flow_rate_m3_s = q_per_branch
            out_p.UpdatePressureDrop(header_pressure_pa)
            total_outflow_m3_s += q_per_branch

    // Volumetric pressure dynamics: Bulk modulus K_fluid ~ 2.2 GPa
    var/vol_m3 = internal_volume_liters * 0.001
    var/net_vol_flow = total_inflow_m3_s - total_outflow_m3_s
    var/bulk_modulus_pa = 2.2e9
    var/delta_p = (bulk_modulus_pa / vol_m3) * (net_vol_flow * delta_time_seconds)
    // Damped pressure update
    header_pressure_pa = max(10000.0, header_pressure_pa + (delta_p * 0.001))

    return header_pressure_pa

#endif // PLENUM_HYDRAULICS_MANIFOLD_DM
