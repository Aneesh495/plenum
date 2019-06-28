// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Hydraulic Pipe Networks, Head Loss & Joukowsky Water Hammer
// Language: Dream Maker (DM)

#ifndef PLENUM_HYDRAULICS_PIPE_NETWORK_DM
#define PLENUM_HYDRAULICS_PIPE_NETWORK_DM

#include "../defines.dm"
#include "../core/datum.dm"
#include "../physics/fluid_dynamics.dm"

/datum/pipe_segment
    var/pipe_id = "PIPE-101"
    var/length_meters = 15.0
    var/diameter_meters = 0.15          // 6-inch industrial pipe
    var/wall_roughness_meters = 0.000045 // Commercial drawn carbon steel (0.045 mm)
    var/fluid_density_kg_m3 = WATER_DENSITY_STP
    var/fluid_viscosity_pa_s = 0.001002 // Water dynamic viscosity at 20 C
    var/flow_rate_m3_s = 0.05           // Volumetric throughput (50 L/s)
    var/upstream_pressure_pa = 500000.0 // 5 bar
    var/downstream_pressure_pa = 450000.0
    var/list/minor_loss_coefficients = list() // Sum of K factors (bends, reducers)
    var/is_ruptured = FALSE

/datum/pipe_segment/New(id, len_m = 15.0, diam_m = 0.15)
    ..()
    pipe_id = id
    length_meters = len_m
    diameter_meters = diam_m

/datum/pipe_segment/proc/CalculateCrossSectionArea()
    var/radius = diameter_meters * 0.5
    return 3.14159265 * radius * radius

/datum/pipe_segment/proc/CalculateVelocity()
    var/area = CalculateCrossSectionArea()
    if(area <= 0.00001) return 0.0
    return flow_rate_m3_s / area

/datum/pipe_segment/proc/CalculateHeadLossMeters()
    // Darcy-Weisbach Equation: h_f = f * (L / D) * (v^2 / (2 * g))
    var/v = CalculateVelocity()
    if(abs(v) <= 0.0001)
        return 0.0

    var/datum/fluid_dynamics_solver/cfd = new /datum/fluid_dynamics_solver()
    var/re = cfd.CalculateReynoldsNumber(fluid_density_kg_m3, abs(v), diameter_meters, fluid_viscosity_pa_s)
    var/f = cfd.CalculateDarcyWeisbachFriction(re, wall_roughness_meters, diameter_meters)
    qdel(cfd)

    var/friction_head = f * (length_meters / diameter_meters) * ((v * v) / (2.0 * STANDARD_GRAVITY_ACCEL))
    
    // Minor losses: sum(K) * (v^2 / 2g)
    var/k_sum = 0.0
    for(var/k_val in minor_loss_coefficients)
        k_sum += k_val
    var/minor_head = k_sum * ((v * v) / (2.0 * STANDARD_GRAVITY_ACCEL))

    return friction_head + minor_head

/datum/pipe_segment/proc/CalculateJoukowskyShockPressure(delta_v_mps)
    // Joukowsky Equation for Water Hammer pressure surge:
    // Delta_P = rho * a * Delta_v
    // Wave speed in steel pipe filled with water: a ~ 1200 m / s
    var/wave_speed_mps = 1200.0
    var/surge_pascals = fluid_density_kg_m3 * wave_speed_mps * abs(delta_v_mps)
    return surge_pascals

/datum/pipe_segment/proc/UpdatePressureDrop(p_inlet)
    upstream_pressure_pa = p_inlet
    var/head_loss_m = CalculateHeadLossMeters()
    var/delta_p_loss = head_loss_m * fluid_density_kg_m3 * STANDARD_GRAVITY_ACCEL
    downstream_pressure_pa = max(0.0, upstream_pressure_pa - delta_p_loss)
    return downstream_pressure_pa

#endif // PLENUM_HYDRAULICS_PIPE_NETWORK_DM
