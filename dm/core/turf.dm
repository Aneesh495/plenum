// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Simulated Turf Grid and Spatial Cells
// Language: Dream Maker (DM)

#ifndef PLENUM_CORE_TURF_DM
#define PLENUM_CORE_TURF_DM

#include "atom.dm"

/turf/plenum_turf
    name = "facility floor"
    desc = "Reinforced ceramic composite industrial flooring."
    var/cell_volume_liters = 2500.0     // Volume of turf atmosphere (e.g. 2.5 m^3)
    var/datum/gas_mixture/air = null    // Local atmospheric gas mixture
    var/datum/area/plenum_area/zone = null // Zone association
    var/list/cardinal_neighbors = null  // Fast cache for 4-way adjacent turfs
    var/list/diagonal_neighbors = null  // Fast cache for 8-way adjacent turfs
    var/fluid_depth_meters = 0.0        // Surface pooled liquid level
    var/fluid_viscosity = 1.0           // Relative viscosity
    var/max_differential_pressure = 500000.0 // Rupture limit in Pascals (5 bar)

/turf/plenum_turf/New()
    ..()
    thermal_mass = 5000.0
    temperature = STANDARD_TEMPERATURE_KELVIN
    permeability_flags = PASS_ALL

/turf/plenum_turf/proc/InitializeAtmosphere(pressure_kpa = 101.325, temp_k = 293.15, o2_ratio = 0.21, n2_ratio = 0.79)
    if(!air)
        air = new /datum/gas_mixture(cell_volume_liters)
    air.SetCompositionSTP(pressure_kpa, temp_k, o2_ratio, n2_ratio)

/turf/plenum_turf/proc/CacheNeighbors()
    if(!cardinal_neighbors)
        cardinal_neighbors = list()
    else
        cardinal_neighbors.Cut()
    
    if(!diagonal_neighbors)
        diagonal_neighbors = list()
    else
        diagonal_neighbors.Cut()

    var/turf/T_north = locate(x, y + 1, z)
    var/turf/T_south = locate(x, y - 1, z)
    var/turf/T_east  = locate(x + 1, y, z)
    var/turf/T_west  = locate(x - 1, y, z)

    if(T_north) cardinal_neighbors += T_north
    if(T_south) cardinal_neighbors += T_south
    if(T_east)  cardinal_neighbors += T_east
    if(T_west)  cardinal_neighbors += T_west

    var/turf/T_ne = locate(x + 1, y + 1, z)
    var/turf/T_nw = locate(x - 1, y + 1, z)
    var/turf/T_se = locate(x + 1, y - 1, z)
    var/turf/T_sw = locate(x - 1, y - 1, z)

    if(T_ne) diagonal_neighbors += T_ne
    if(T_nw) diagonal_neighbors += T_nw
    if(T_se) diagonal_neighbors += T_se
    if(T_sw) diagonal_neighbors += T_sw

/turf/plenum_turf/proc/GetAtmosphericPressure()
    if(!air)
        return 0.0
    return air.CalculatePressurePascals()

/turf/plenum_turf/proc/EqualizeAtmosphereWith(turf/plenum_turf/neighbor, transfer_coefficient = 0.25)
    if(!neighbor || !air || !neighbor.air)
        return 0.0
    if(!(permeability_flags & PASS_GAS) || !(neighbor.permeability_flags & PASS_GAS))
        return 0.0

    var/p_self = air.CalculatePressurePascals()
    var/p_target = neighbor.air.CalculatePressurePascals()
    var/delta_p = p_self - p_target

    if(abs(delta_p) < 0.1)
        return 0.0

    var/moles_to_move = (delta_p * cell_volume_liters * 0.001) / (R_IDEAL_GAS_CONSTANT * air.temperature) * transfer_coefficient
    if(moles_to_move > 0.0)
        var/datum/gas_mixture/packet = air.RemoveMolesFraction(moles_to_move / (air.total_moles + 0.000001))
        if(packet)
            neighbor.air.MergeMixture(packet)
            qdel(packet)
    else if(moles_to_move < 0.0)
        var/moles_in = -moles_to_move
        var/datum/gas_mixture/packet = neighbor.air.RemoveMolesFraction(moles_in / (neighbor.air.total_moles + 0.000001))
        if(packet)
            air.MergeMixture(packet)
            qdel(packet)

    return delta_p

// ----------------------------------------------------------------------------
// Specialized Turf Subtypes
// ----------------------------------------------------------------------------

/turf/plenum_turf/floor
    name = "industrial floor"
    density = FALSE
    opacity = FALSE
    permeability_flags = PASS_ALL

/turf/plenum_turf/wall
    name = "reinforced blast wall"
    desc = "High-tensile steel and concrete load-bearing structural barrier."
    density = TRUE
    opacity = TRUE
    permeability_flags = PASS_NONE
    thermal_mass = 50000.0
    thermal_conductivity = 0.05
    structural_integrity = 50000.0
    max_integrity = 50000.0

/turf/plenum_turf/wall/containment
    name = "hermetic containment bulkhead"
    desc = "Multi-layer vacuum-jacketed seal for toxic, cryogenic, or explosive process zones."
    density = TRUE
    opacity = TRUE
    permeability_flags = PASS_NONE
    is_hermetic = TRUE
    thermal_mass = 120000.0
    thermal_conductivity = 0.01
    structural_integrity = 200000.0
    max_integrity = 200000.0
    acoustic_damping_db = 45.0

/turf/plenum_turf/conduit
    name = "utility conduit channel"
    desc = "Protected floor chase with cable racks and pneumatic distribution runners."
    density = FALSE
    opacity = FALSE
    permeability_flags = PASS_GAS | PASS_ELECTRICAL | PASS_PNEUMATIC

/turf/plenum_turf/vacuum
    name = "vacuum boundary"
    desc = "Outer space or deep exhaust plenum vent."
    density = FALSE
    opacity = FALSE
    permeability_flags = PASS_ALL

/turf/plenum_turf/vacuum/New()
    ..()
    air = new /datum/gas_mixture(cell_volume_liters)
    // Vacuum has 0 moles and 0 pressure
    air.total_moles = 0.0
    air.temperature = 2.73 // Cosmic background / cryogenic sink

#endif // PLENUM_CORE_TURF_DM
