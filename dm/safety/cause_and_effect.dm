// Cause and Effect (C&E) Matrix Safety Shutdown Logic Engine
//
// Implements deterministic 2D Boolean Cause and Effect logic matrix for process plant
// Emergency Shutdown (ESD) and Depressuring (EDP) systems per API RP 14C / IEC 61511.
// Maps initiating sensor causes (PSHH, LSLL, TSHH, Flameout, Toxic Gas GDX, Manual ESD)
// to final protective effect elements (Emergency Shutdown Valves ESDVs, High-Pressure
// Blowdown Valves BDVs, Pump Trips, and Deluge Foam Actuation) with latched resets.

/datum/safety/cause_and_effect
    var/tag = "SIS-CE-MATRIX"
    var/num_causes = 8
    var/num_effects = 8

    var/list/cause_tags = list(
        "PSHH-101-DRUM",   // High-High Drum Pressure
        "LSLL-102-DRUM",   // Low-Low Drum Level
        "TSHH-201-FURNACE",// High-High Furnace Tube Skin Temp
        "FLAME-301-FAIL",  // Burner Flameout Scanner
        "GDX-401-CH4-GAS", // Combustible Gas LEL > 40%
        "TDX-402-TOXIC-H2S",// Toxic Gas H2S > 10 ppm
        "ESD-PB-MCR",      // Main Control Room Manual Pushbutton
        "GRID-BLACKOUT"    // Complete 13.8 kV Bus Voltage Collapse
    )

    var/list/effect_tags = list(
        "ESDV-01-FUEL-GAS", // Fuel Gas Header Isolation Valve (Fail Closed)
        "ESDV-02-FEEDWATER",// Boiler Feedwater Block Valve
        "BDV-03-FLARE-DEP", // Emergency Blowdown to Flare (Fail Open)
        "TRIP-PUMP-P101",   // Main Feedwater Pump Motor Breaker Trip
        "TRIP-TURBINE-STG", // Steam Turbine Trip Stop Valve
        "FOV-01-DELUGE",    // Fire Water Foam Deluge Valve
        "HVAC-ISOLATION",   // Control Room HVAC Damper Isolation
        "SIREN-ALARM-FAC"   // Facility-Wide Audible / Visual Horn
    )

    // Flat 8x8 matrix (size 64): 1 = Trigger action, 0 = No action
    var/list/ce_matrix = list()
    var/list/cause_active = list()
    var/list/effect_tripped = list()
    var/list/effect_latched = list()

/datum/safety/cause_and_effect/New()
    ..()
    cause_active = list()
    effect_tripped = list()
    effect_latched = list()

    for(var/i = 1 to num_causes)
        cause_active.Add(0)

    for(var/j = 1 to num_effects)
        effect_tripped.Add(0)
        effect_latched.Add(0)

    // Initialize 8x8 matrix
    ce_matrix = list(
        // Effect: ESDV1, ESDV2, BDV3, PUMP, TURB, FOV, HVAC, SIREN
        1, 0, 1, 0, 1, 0, 0, 1, // Cause 1: PSHH Drum (Fuel cut, Blowdown, Turbine trip)
        1, 1, 0, 1, 1, 0, 0, 1, // Cause 2: LSLL Drum (Fuel cut, Feed cut, Pump trip, Turbine trip)
        1, 0, 0, 0, 1, 0, 0, 1, // Cause 3: TSHH Tube (Fuel cut, Turbine trip)
        1, 0, 0, 0, 1, 0, 0, 1, // Cause 4: Flameout (Fuel cut, Turbine trip)
        1, 0, 1, 1, 1, 1, 1, 1, // Cause 5: Combustible Gas (Complete plant isolation, Deluge)
        1, 0, 0, 0, 0, 0, 1, 1, // Cause 6: Toxic Gas (HVAC isolation, Siren)
        1, 1, 1, 1, 1, 0, 1, 1, // Cause 7: Manual MCR ESD (Total plant shutdown)
        0, 0, 0, 1, 1, 0, 0, 1  // Cause 8: Grid blackout (Pump trip, Turbine trip)
    )

// Set status of a specific initiating cause (0 = Normal, 1 = Tripped)
/datum/safety/cause_and_effect/proc/set_cause(cause_idx, is_tripped)
    if(cause_idx >= 1 && cause_idx <= num_causes)
        cause_active[cause_idx] = is_tripped

// Scan C&E logic matrix and latch outputs
/datum/safety/cause_and_effect/proc/evaluate_matrix()
    var/num_active_effects = 0

    for(var/eff = 1 to num_effects)
        var/demand = 0

        for(var/cau = 1 to num_causes)
            if(cause_active[cau])
                var/matrix_idx = (cau - 1) * num_effects + eff
                if(ce_matrix[matrix_idx] == 1)
                    demand = 1
                    break

        effect_tripped[eff] = demand
        if(demand)
            effect_latched[eff] = 1 // Safety latch requires authorized operator reset
            num_active_effects++

    return num_active_effects

// Reset latched safety elements (permissive check: all causes must be clear)
/datum/safety/cause_and_effect/proc/reset_latches()
    for(var/cau = 1 to num_causes)
        if(cause_active[cau])
            return 0 // Reset rejected: Initiating cause is still active

    for(var/eff = 1 to num_effects)
        effect_latched[eff] = 0
        effect_tripped[eff] = 0

    return 1
