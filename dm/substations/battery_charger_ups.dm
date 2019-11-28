// Dual-Redundant 125V DC Substation Battery Charger & Static Transfer UPS
//
// Implements nuclear/industrial Class 1E 125V DC station auxiliary battery charger
// and uninterruptible power supply (UPS). Formulates 6-pulse silicon-controlled
// rectifier (SCR) phase firing angle alpha modulation, three-stage charging profiles
// (Float 2.25 V/cell, Equalize 2.33 V/cell, Current-Limit Recharge), balanced bridge
// DC ground fault leakage detection (+/- poles), and sub-cycle static bypass transfer.

/datum/substation/battery_charger_ups
    var/tag = "UPS-CHARGER-125VDC"
    var/system_dc_voltage_v = 125.0
    var/num_lead_acid_cells = 60 // 60 cells in series

    // Operating Charging Modes: "FLOAT", "EQUALIZE", "BOOST_CURRENT_LIMIT"
    var/charging_mode = "FLOAT"
    var/float_voltage_per_cell = 2.250   // 135.0 V bus voltage
    var/equalize_voltage_per_cell = 2.330 // 139.8 V bus voltage
    var/max_charging_current_limit_a = 200.0 // Current limit clamp

    // Dynamic electrical states
    var/dc_bus_voltage_v = 135.0
    var/charger_output_current_a = 45.0
    var/battery_terminal_current_a = 5.2 // Float trickle charge
    var/substation_dc_load_current_a = 39.8 // Continuous trip coils / IED loads

    // Ground Fault Detection (+/- pole balance bridge)
    var/positive_pole_to_ground_v = 67.5
    var/negative_pole_to_ground_v = -67.5
    var/ground_fault_alarm = 0

    // Static Bypass Switch
    var/inverter_online = 1
    var/static_switch_on_bypass = 0
    var/ac_mains_voltage_v = 480.0

/datum/substation/battery_charger_ups/New()
    ..()

// Ground Fault Detection Bridge: detects insulation degradation to earth ground
/datum/substation/battery_charger_ups/proc/check_ground_fault(pos_leakage_kohm, neg_leakage_kohm)
    var/total_v = dc_bus_voltage_v
    var/r_pos = max(pos_leakage_kohm, 0.01)
    var/r_neg = max(neg_leakage_kohm, 0.01)

    // Voltage divider to earth
    positive_pole_to_ground_v = total_v * (r_pos / (r_pos + r_neg))
    negative_pole_to_ground_v = -(total_v - positive_pole_to_ground_v)

    // Alarm if unbalance exceeds 25V difference
    var/unbalance = abs(abs(positive_pole_to_ground_v) - abs(negative_pole_to_ground_v))
    if(unbalance > 25.0)
        ground_fault_alarm = 1
        return 1
    else
        ground_fault_alarm = 0
        return 0

// Step battery charger SCR phase firing and DC bus regulation
/datum/substation/battery_charger_ups/proc/step_charger(dt_sec, load_demand_a = 40.0)
    substation_dc_load_current_a = load_demand_a

    // 1. Determine target voltage based on active mode
    var/target_bus_v = 135.0
    if(charging_mode == "EQUALIZE")
        target_bus_v = num_lead_acid_cells * equalize_voltage_per_cell // 139.8 V
    else
        target_bus_v = num_lead_acid_cells * float_voltage_per_cell   // 135.0 V

    // 2. SCR Voltage and Current Feedback Loop:
    // Proportional-integral regulation of SCR firing angle alpha: V_dc = 1.35 * V_ac * cos(alpha)
    var/v_error = target_bus_v - dc_bus_voltage_v
    var/i_demand = substation_dc_load_current_a + (v_error * 25.0)

    // Current limit clamp
    charger_output_current_a = min(max(i_demand, 0.0), max_charging_current_limit_a)

    // Battery gets remainder of current: I_batt = I_charger - I_load
    battery_terminal_current_a = charger_output_current_a - substation_dc_load_current_a

    // DC bus voltage relaxation
    dc_bus_voltage_v = dc_bus_voltage_v + (v_error * 0.40 * dt_sec)

    // 3. Static bypass monitoring: transfer to mains if inverter trips
    if(!inverter_online && !static_switch_on_bypass)
        static_switch_on_bypass = 1 // Sub-cycle static switch transfer (< 4 ms)
    else if(inverter_online && static_switch_on_bypass)
        static_switch_on_bypass = 0

    return dc_bus_voltage_v
