// Twelve-Bed Cyclic Pressure Swing Adsorption (PSA) Hydrogen Purification
//
// Implements industrial 12-bed polybed pressure swing adsorption for production
// of fuel-cell grade hydrogen (>99.999% purity) from steam reformer / syngas feed.
// Models cyclic bed staging (Adsorption, Equalizations PE1-PE3, Blowdown, Purge,
// Repressurization), multi-component Langmuir adsorption isotherms on layered
// activated carbon and zeolite 5A molecular sieves, and MTZ breakthrough dynamics.

/datum/model/hydrogen_psa
    var/tag = "PSA-UNIT-12"
    var/num_beds = 12
    var/cycle_time_sec = 720.0 // 12-minute complete cycle
    var/bed_height_m = 9.0
    var/bed_diameter_m = 2.4
    var/adsorbent_mass_per_bed_kg = 24000.0

    // Feed conditions
    var/feed_pressure_bar = 24.0
    var/feed_temp_k = 308.15
    var/feed_flow_nm3_hr = 45000.0

    // Feed composition (molar)
    var/y_h2_in = 0.745
    var/y_co2_in = 0.185
    var/y_ch4_in = 0.045
    var/y_co_in = 0.020
    var/y_n2_in = 0.005

    // Adsorption bed states (1 to 12)
    // States: 1=Adsorption, 2=Equalization 1 Down, 3=Equalization 2 Down, 4=Equalization 3 Down,
    //         5=Blowdown, 6=Purge, 7=Equalization 3 Up, 8=Equalization 2 Up, 9=Equalization 1 Up, 10=Repressurization
    var/list/bed_states = list()
    var/list/bed_pressures_bar = list()
    var/list/bed_loading_co2 = list() // mol/kg
    var/list/bed_loading_ch4 = list()
    var/list/bed_loading_co = list()

    // Product performance
    var/product_purity_h2 = 0.999992
    var/co_slip_ppm = 0.45
    var/h2_recovery_pct = 89.4
    var/tail_gas_calorific_mj_nm3 = 7.8

/datum/model/hydrogen_psa/New()
    ..()
    bed_states = list()
    bed_pressures_bar = list()
    bed_loading_co2 = list()
    bed_loading_ch4 = list()
    bed_loading_co = list()

    for(var/i = 1 to num_beds)
        bed_states.Add((i % 10) + 1)
        bed_pressures_bar.Add(feed_pressure_bar)
        bed_loading_co2.Add(0.5)
        bed_loading_ch4.Add(0.1)
        bed_loading_co.Add(0.05)

// Langmuir Multi-Component Adsorption Isotherm:
// q_i = (q_max_i * b_i * P_i) / (1 + sum(b_j * P_j))
/datum/model/hydrogen_psa/proc/calculate_langmuir_loading(component_name, partial_pressure_bar, total_press_bar)
    // Sorbent affinity parameters (Activated Carbon + Zeolite 5A composite)
    var/q_max = 0.0
    var/b_affinity = 0.0

    switch(component_name)
        if("CO2")
            q_max = 4.25 // mol/kg
            b_affinity = 0.85
        if("CH4")
            q_max = 2.10
            b_affinity = 0.22
        if("CO")
            q_max = 1.65
            b_affinity = 0.45
        if("N2")
            q_max = 0.85
            b_affinity = 0.08
        if("H2")
            q_max = 0.15 // Weakly adsorbed, non-competing
            b_affinity = 0.005

    var/denom = 1.0 + (0.85 * y_co2_in * total_press_bar) + (0.22 * y_ch4_in * total_press_bar) + (0.45 * y_co_in * total_press_bar)
    var/q_equil = (q_max * b_affinity * partial_pressure_bar) / max(denom, 1e-4)
    return q_equil

// Cyclic step for the 12-bed PSA system
/datum/model/hydrogen_psa/proc/step_cycle(dt_sec)
    var/step_fraction = dt_sec / (cycle_time_sec / num_beds)

    for(var/b = 1 to num_beds)
        var/state = bed_states[b]

        switch(state)
            if(1) // Adsorption: High pressure feed, pure H2 product
                bed_pressures_bar[b] = feed_pressure_bar
                var/p_co2 = feed_pressure_bar * y_co2_in
                var/q_target_co2 = calculate_langmuir_loading("CO2", p_co2, feed_pressure_bar)
                bed_loading_co2[b] = bed_loading_co2[b] + (q_target_co2 - bed_loading_co2[b]) * 0.15 * step_fraction

                var/p_co = feed_pressure_bar * y_co_in
                var/q_target_co = calculate_langmuir_loading("CO", p_co, feed_pressure_bar)
                bed_loading_co[b] = bed_loading_co[b] + (q_target_co - bed_loading_co[b]) * 0.15 * step_fraction

                // Breakthrough condition check
                if(bed_loading_co[b] > 1.45)
                    co_slip_ppm = min(co_slip_ppm + 0.2, 5.0)
                    product_purity_h2 = max(product_purity_h2 - 0.00005, 0.9995)
                else
                    co_slip_ppm = max(co_slip_ppm - 0.05, 0.15)
                    product_purity_h2 = min(product_purity_h2 + 0.000002, 0.999995)

            if(2, 3, 4) // Equalization Down: Gas transfers to depressurize bed
                var/target_p = feed_pressure_bar * (1.0 - (state - 1) * 0.22)
                bed_pressures_bar[b] = bed_pressures_bar[b] + (target_p - bed_pressures_bar[b]) * 0.25 * step_fraction

            if(5) // Counter-current Blowdown: Venting tail gas to fuel gas header
                var/blow_p = 1.3 // bar
                bed_pressures_bar[b] = bed_pressures_bar[b] + (blow_p - bed_pressures_bar[b]) * 0.40 * step_fraction
                // Desorption of impurities
                bed_loading_co2[b] = max(bed_loading_co2[b] * 0.85, 0.2)
                bed_loading_co[b] = max(bed_loading_co[b] * 0.80, 0.08)

            if(6) // Low-pressure Purge with product H2 slipstream
                bed_pressures_bar[b] = 1.25
                bed_loading_co2[b] = max(bed_loading_co2[b] * 0.70, 0.05)
                bed_loading_co[b] = max(bed_loading_co[b] * 0.65, 0.02)

            if(7, 8, 9) // Equalization Up: Gas received from depressurizing partner bed
                var/target_p = 1.3 + (state - 6) * 5.5
                bed_pressures_bar[b] = bed_pressures_bar[b] + (target_p - bed_pressures_bar[b]) * 0.25 * step_fraction

            if(10) // Repressurization with pure H2 product
                bed_pressures_bar[b] = bed_pressures_bar[b] + (feed_pressure_bar - bed_pressures_bar[b]) * 0.35 * step_fraction
                if(abs(bed_pressures_bar[b] - feed_pressure_bar) < 0.5)
                    bed_states[b] = 1 // Return to adsorption

// Valve sequence advance to rotate all beds in the cycle
/datum/model/hydrogen_psa/proc/advance_step()
    for(var/b = 1 to num_beds)
        var/s = bed_states[b]
        s = (s % 10) + 1
        bed_states[b] = s
    return 1
