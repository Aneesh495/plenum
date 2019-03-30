// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Spatial Atom Base Class
// Language: Dream Maker (DM)

#ifndef PLENUM_CORE_ATOM_DM
#define PLENUM_CORE_ATOM_DM

#include "datum.dm"

/atom/plenum_atom
    var/uid = 0
    var/thermal_mass = 1000.0           // Heat capacity in Joules / Kelvin
    var/temperature = 293.15            // Surface/internal temperature in Kelvin
    var/thermal_conductivity = 0.5      // W / (m * K) Fourier conduction coefficient
    var/emissivity = 0.90               // Radiative emissivity factor [0.0, 1.0]
    var/structural_integrity = 1000.0   // Current structural health in Pascals / Joules
    var/max_integrity = 1000.0          // Maximum structural threshold before rupture
    var/permeability_flags = PASS_ALL   // Bitmask of allowed media flows
    var/acoustic_damping_db = 3.0       // Sound absorption loss in decibels
    var/is_hermetic = FALSE             // Impermeable to micro-molecular gas leaks
    var/datum/plenum_datum/event_hub = null

/atom/plenum_atom/New(loc)
    ..(loc)
    uid = ++plenum_datum_uid_counter
    event_hub = new /datum/plenum_datum()

/atom/plenum_atom/proc/Destroy()
    if(event_hub)
        event_hub.Destroy()
        event_hub = null
    return ..()

/atom/plenum_atom/proc/CanPass(atom/movable/mover, turf/target_turf, pass_flags)
    // Validate whether the specified mover or flow can pass through this boundary
    if((permeability_flags & pass_flags) != pass_flags)
        return FALSE
    if(density && mover && mover.density)
        return FALSE
    return TRUE

/atom/plenum_atom/proc/ApplyThermalEnergy(delta_joules)
    if(thermal_mass <= 0.0)
        return temperature
    var/delta_t = delta_joules / thermal_mass
    temperature += delta_t
    if(temperature < ABSOLUTE_ZERO_KELVIN)
        temperature = ABSOLUTE_ZERO_KELVIN
    return temperature

/atom/plenum_atom/proc/ConductHeat(atom/plenum_atom/target, delta_time_seconds, contact_area_m2 = 1.0, distance_m = 1.0)
    if(!target || distance_m <= 0.0)
        return 0.0
    
    // Effective harmonic mean of conductivities
    var/k_eff = (2.0 * thermal_conductivity * target.thermal_conductivity) / (thermal_conductivity + target.thermal_conductivity + 0.000001)
    var/delta_t = target.temperature - temperature
    
    // Fourier's Law of Thermal Conduction: Q = k * A * (dT / dx) * dt
    var/heat_flux_watts = k_eff * contact_area_m2 * (delta_t / distance_m)
    var/energy_transferred = heat_flux_watts * delta_time_seconds
    
    ApplyThermalEnergy(energy_transferred)
    target.ApplyThermalEnergy(-energy_transferred)
    return energy_transferred

/atom/plenum_atom/proc/ApplyMechanicalStress(applied_stress_pascals)
    if(applied_stress_pascals <= 0.0)
        return structural_integrity
    
    structural_integrity -= applied_stress_pascals
    if(structural_integrity <= 0.0)
        structural_integrity = 0.0
        OnStructuralFailure()
    return structural_integrity

/atom/plenum_atom/proc/OnStructuralFailure()
    // Default response: lose integrity and become completely permeable to rupture flows
    permeability_flags = PASS_ALL
    if(event_hub)
        event_hub.SendSignal(SIG_CONTAINMENT_BREACH, list("uid" = uid, "loc" = loc))

/atom/plenum_atom/proc/SerializeAtom()
    return list(
        "uid" = uid,
        "name" = name,
        "x" = x,
        "y" = y,
        "z" = z,
        "temperature" = temperature,
        "integrity" = structural_integrity,
        "permeability" = permeability_flags
    )

#endif // PLENUM_CORE_ATOM_DM
