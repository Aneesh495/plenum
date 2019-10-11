// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Battery Power Conversion System (PCS) & Grid-Forming Inverter
// Language: Dream Maker (DM)

#ifndef PLENUM_MODELS_BESS_PCS_DM
#define PLENUM_MODELS_BESS_PCS_DM

#include "../core/obj.dm"
#include "../microgrid/storage.dm"

#define PCS_MODE_GRID_FOLLOWING   1 // Current source PLL
#define PCS_MODE_GRID_FORMING     2 // Voltage source Virtual Synchronous Machine

/obj/machinery/bess_pcs_inverter
    name = "utility-scale 4-quadrant BESS inverter"
    desc = "Silicon carbide (SiC) bidirectional power conversion system with grid-forming capability."
    var/pcs_id = "PCS-01"
    
    // Ratings
    var/rated_power_mva = 5.0
    var/operating_mode = PCS_MODE_GRID_FORMING
    var/synthetic_inertia_h = 4.5       // Virtual inertia emulation
    var/frequency_droop_percent = 2.0   // Fast 2% droop for microgrid stabilization
    
    // Grid Synchronization
    var/pll_frequency_hz = 60.0
    var/voltage_reference_pu = 1.00
    var/current_active_mw = 0.0
    var/current_reactive_mvar = 0.0

/obj/machinery/bess_pcs_inverter/proc/CalculateVirtualSynchronousResponse(grid_freq_hz, delta_time_seconds)
    if(operating_mode != PCS_MODE_GRID_FORMING)
        return current_active_mw

    // Virtual Synchronous Machine (VSM) Power-Frequency Swing Law:
    // Delta_P = 2*H*(df/dt) + (1/Droop)*(f_nom - f_meas)
    var/freq_err = SYSTEM_FREQUENCY_NOMINAL_HZ - grid_freq_hz
    var/droop_p = (rated_power_mva / (frequency_droop_percent * 0.01)) * (freq_err / SYSTEM_FREQUENCY_NOMINAL_HZ)
    
    current_active_mw = max(-rated_power_mva, min(rated_power_mva, droop_p))
    return current_active_mw

#endif // PLENUM_MODELS_BESS_PCS_DM
