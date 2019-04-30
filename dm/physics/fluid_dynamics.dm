// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Discrete Navier-Stokes Approximation & Compressible Orifice Flow
// Language: Dream Maker (DM)

#ifndef PLENUM_PHYSICS_FLUID_DYNAMICS_DM
#define PLENUM_PHYSICS_FLUID_DYNAMICS_DM

#include "gas_mixture.dm"

/datum/fluid_dynamics_solver
    var/gauss_seidel_iterations = 4
    var/kinematic_viscosity_air = 1.5e-5  // m^2 / s at STP
    var/drag_damping_coefficient = 0.05

/datum/fluid_dynamics_solver/proc/CalculateMassFlowOrifice(p_upstream, p_downstream, t_upstream, discharge_coeff = 0.62, orifice_area_m2 = 0.05, molar_mass = 0.02897, gamma = 1.4)
    // Compressible gas flow through a nozzle or pipe puncture orifice
    if(p_upstream <= p_downstream || p_upstream <= 0.0 || t_upstream <= 0.0)
        return 0.0

    var/pressure_ratio = p_downstream / p_upstream
    // Critical pressure ratio for sonic choking:
    var/critical_ratio = (2.0 / (gamma + 1.0)) ** (gamma / (gamma - 1.0))

    var/mass_flow_kg_per_sec = 0.0

    if(pressure_ratio <= critical_ratio)
        // Choked (Sonic) Flow: Velocity at throat reaches Mach 1
        var/term1 = discharge_coeff * orifice_area_m2 * p_upstream
        var/term2 = sqrt((gamma * molar_mass) / (R_IDEAL_GAS_CONSTANT * t_upstream))
        var/term3 = (2.0 / (gamma + 1.0)) ** ((gamma + 1.0) / (2.0 * (gamma - 1.0)))
        mass_flow_kg_per_sec = term1 * term2 * term3
    else
        // Subsonic Flow: St. Venant-Wantzel equation
        var/term1 = discharge_coeff * orifice_area_m2 * p_upstream
        var/term2 = sqrt((2.0 * molar_mass / (R_IDEAL_GAS_CONSTANT * t_upstream)) * (gamma / (gamma - 1.0)))
        var/term3 = sqrt((pressure_ratio ** (2.0 / gamma)) - (pressure_ratio ** ((gamma + 1.0) / gamma)))
        mass_flow_kg_per_sec = term1 * term2 * term3

    return mass_flow_kg_per_sec

/datum/fluid_dynamics_solver/proc/SolvePressureVelocityStep(list/turf_list, delta_time_seconds)
    // Discrete pressure-gradient momentum update over spatial turf array
    for(var/turf/plenum_turf/T in turf_list)
        if(!T.air || !T.cardinal_neighbors)
            continue
        
        var/p_center = T.air.CalculatePressurePascals()
        var/vol_m3 = T.cell_volume_liters * 0.001

        for(var/turf/plenum_turf/neighbor in T.cardinal_neighbors)
            if(!neighbor.air || !(neighbor.permeability_flags & PASS_GAS))
                continue
            
            var/p_neighbor = neighbor.air.CalculatePressurePascals()
            var/grad_p = (p_center - p_neighbor) / 2.5 // 2.5 meter grid cell spacing
            
            // Momentum exchange: delta_v = -(1/rho) * grad(P) * dt
            var/density_center = (T.air.total_moles * 0.029) / vol_m3
            if(density_center > 0.001)
                var/accel = -grad_p / density_center
                // Velocity transport across face
                var/flux_velocity = accel * delta_time_seconds
                // Apply spatial drag damping
                flux_velocity *= (1.0 - drag_damping_coefficient)
                
                // Moles advected across cell interface
                if(abs(flux_velocity) > 0.01)
                    var/contact_area = 2.5 * 3.0 // 7.5 m^2 face area
                    var/vol_flux_m3 = flux_velocity * contact_area * delta_time_seconds
                    if(vol_flux_m3 > 0.0)
                        var/moles_to_move = (p_center * vol_flux_m3) / (R_IDEAL_GAS_CONSTANT * T.air.temperature)
                        moles_to_move = min(moles_to_move, T.air.total_moles * 0.5)
                        if(moles_to_move > 0.0)
                            var/fraction = moles_to_move / (T.air.total_moles + 0.000001)
                            var/datum/gas_mixture/packet = T.air.RemoveMolesFraction(fraction)
                            if(packet)
                                neighbor.air.MergeMixture(packet)
                                qdel(packet)

/datum/fluid_dynamics_solver/proc/CalculateReynoldsNumber(density_kg_m3, velocity_mps, diameter_m, dynamic_viscosity_pa_s)
    if(dynamic_viscosity_pa_s <= 0.0)
        return 0.0
    return (density_kg_m3 * velocity_mps * diameter_m) / dynamic_viscosity_pa_s

/datum/fluid_dynamics_solver/proc/CalculateDarcyWeisbachFriction(reynolds, pipe_roughness_m, diameter_m)
    // Swamee-Jain explicit equation for Darcy-Weisbach friction factor f
    if(reynolds < 2300.0)
        // Laminar regime: f = 64 / Re
        if(reynolds <= 0.0) return 0.064
        return 64.0 / reynolds
    
    // Turbulent regime (Swamee-Jain approximation of Colebrook-White)
    var/epsilon_d = pipe_roughness_m / diameter_m
    var/term1 = epsilon_d / 3.7
    var/term2 = 5.74 / (reynolds ** 0.9)
    var/log_val = log(term1 + term2)
    var/f = 0.25 / ((log_val) ** 2)
    return f

#endif // PLENUM_PHYSICS_FLUID_DYNAMICS_DM
