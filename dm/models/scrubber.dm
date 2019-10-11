// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Packed-Bed Acid Gas Chemical Scrubber & pH Control
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_SCRUBBER_DM
#define PLENUM_MODELS_SCRUBBER_DM

#include "../core/obj.dm"
#include "../physics/gas_mixture.dm"

/obj/machinery/wet_scrubber
    name = "caustic packed-bed gas scrubber"
    desc = "Vertical counter-current wet scrubber with polypropylene random packing and caustic dosing loop."
    var/scrubber_id = "SCB-01"
    
    // Physical Packing Dimensions
    var/column_diameter_meters = 2.4
    var/packing_height_meters = 6.0
    var/specific_surface_area_m2_m3 = 145.0 // Packing surface area
    
    // Chemistry & pH Dosing
    var/recirculating_ph = 8.5           // Target pH [8.0, 9.5]
    var/naoh_dosing_rate_lph = 25.0      // Liters per hour of 20% NaOH
    var/neutralization_efficiency = 0.992 // 99.2% acid gas removal
    
    // Operating Flow
    var/gas_inflow_rate_m3_h = 15000.0
    var/liquid_recirculation_rate_m3_h = 120.0
    var/bed_pressure_drop_mbar = 8.5

/obj/machinery/wet_scrubber/proc/TreatGasMixture(datum/gas_mixture/flue_gas, delta_time_seconds)
    if(!flue_gas || flue_gas.total_moles <= EPSILON_MOLES)
        return
    
    // Neutralize acidic species: CO2 absorption by caustic:
    // CO2 + 2 NaOH -> Na2CO3 + H2O
    var/co2_moles = flue_gas.GetMoles(GAS_CO2)
    if(co2_moles > 0.0)
        var/scrubbed_moles = co2_moles * neutralization_efficiency * 0.15 * delta_time_seconds
        scrubbed_moles = min(scrubbed_moles, co2_moles)
        flue_gas.AdjustMoles(GAS_CO2, -scrubbed_moles)
        
        // Caustic consumption drops pH
        var/ph_drop = (scrubbed_moles * 0.0005)
        recirculating_ph = max(4.0, recirculating_ph - ph_drop)

    // Automated pH dosing pump feedback
    if(recirculating_ph < 8.2)
        naoh_dosing_rate_lph = 50.0 // Double dosing
        recirculating_ph = min(9.5, recirculating_ph + (0.05 * delta_time_seconds))
    else if(recirculating_ph > 9.0)
        naoh_dosing_rate_lph = 10.0 // Throttle dosing

    return recirculating_ph

#endif // PLENUM_MODELS_SCRUBBER_DM
