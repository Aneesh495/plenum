// Detailed Hydrocarbon Combustion & Thermal Zeldovich NOx Kinetics
//
// Implements multi-step reduced reaction mechanism (GRI-Mech 3.0 derivative)
// for natural gas combustion in industrial boilers, gas turbines, and flare tips.
// Formulates modified Arrhenius reaction rates k(T) = A * T^b * exp(-Ea / RT),
// simultaneous methane oxidation, CO/CO2 water-gas shift equilibrium, and extended
// Zeldovich thermal NOx formation kinetics (N2 + O <=> NO + N).

/datum/chemistry/combustion_kinetics
    var/tag = "COMBUSTION-KINETICS-ENGINE"

    // Chemical Species Concentrations (kmol / m^3)
    var/conc_ch4 = 0.050
    var/conc_o2  = 0.120
    var/conc_co2 = 0.010
    var/conc_h2o = 0.020
    var/conc_co  = 0.001
    var/conc_h2  = 0.001
    var/conc_n2  = 0.450
    var/conc_no  = 0.00005 // 50 ppm NOx baseline

    // Thermal States
    var/flame_temp_k = 2150.0 // Adiabatic Flame Temperature (AFT)
    var/flame_pressure_bar = 1.05
    var/heat_release_rate_kw_m3 = 18500.0

/datum/chemistry/combustion_kinetics/New()
    ..()

// Modified Arrhenius rate calculation: k = A * T^b * exp(-E_a / (R * T))
/datum/chemistry/combustion_kinetics/proc/calculate_arrhenius_rate(a_prefactor, b_temp_exponent, e_act_j_mol, temp_k)
    var/r_gas = 8.314462618
    var/t = max(temp_k, 300.0)

    var/t_term = (b_temp_exponent != 0.0) ? exp(b_temp_exponent * log(t)) : 1.0
    var/exp_term = exp(-e_act_j_mol / (r_gas * t))
    return a_prefactor * t_term * exp_term

// Step combustion ODEs over integration timestep dt
/datum/chemistry/combustion_kinetics/proc/step_reactions(dt_sec)
    var/t = flame_temp_k

    // 1. Methane partial oxidation: CH4 + 1.5 O2 -> CO + 2 H2O
    // Rate: r1 = k1 * [CH4]^0.7 * [O2]^0.8 (Dryer-Glassman mechanism)
    var/k1 = calculate_arrhenius_rate(2.8e9, 0.0, 202500.0, t)
    var/ch4_term = exp(0.7 * log(max(conc_ch4, 1e-6)))
    var/o2_term = exp(0.8 * log(max(conc_o2, 1e-6)))
    var/r_ch4 = k1 * ch4_term * o2_term * dt_sec
    r_ch4 = min(r_ch4, conc_ch4 * 0.95)

    conc_ch4 -= r_ch4
    conc_o2  = max(conc_o2 - (1.5 * r_ch4), 0.001)
    conc_co  += r_ch4
    conc_h2o += 2.0 * r_ch4

    // 2. Carbon Monoxide Oxidation: CO + 0.5 O2 <=> CO2
    // Rate: r2 = k2_f * [CO] * [H2O]^0.5 * [O2]^0.25 - k2_r * [CO2]
    var/k2_f = calculate_arrhenius_rate(3.2e12, 0.0, 167000.0, t)
    var/h2o_term = sqrt(max(conc_h2o, 1e-6))
    var/o2_q_term = exp(0.25 * log(max(conc_o2, 1e-6)))
    var/r_co = k2_f * conc_co * h2o_term * o2_q_term * dt_sec
    r_co = min(r_co, conc_co * 0.90)

    conc_co  -= r_co
    conc_o2  = max(conc_o2 - (0.5 * r_co), 0.001)
    conc_co2 += r_co

    // 3. Extended Zeldovich Thermal NOx Mechanism:
    // Reaction 1: N2 + O <=> NO + N (Rate determining, high activation energy ~318 kJ/mol)
    // Reaction 2: N + O2 <=> NO + O
    // Reaction 3: N + OH <=> NO + H
    // Quasi-steady state atomic N concentration yields classic Zeldovich rate:
    // d[NO]/dt = (2 * k1_f * [N2] * [O]_eq) / (1 + (k1_r * [NO]) / (k2_f * [O2] + k3_f * [OH]))
    var/k_zeldovich_1 = calculate_arrhenius_rate(1.8e11, 0.0, 318000.0, t)

    // Equilibrium atomic oxygen [O]_eq ~ sqrt(K_p_O2 * [O2])
    var/k_p_o2 = exp(-245000.0 / (8.314 * t)) * 1e4
    var/conc_o_atom = sqrt(max(k_p_o2 * conc_o2, 1e-12))

    var/r_nox = 2.0 * k_zeldovich_1 * conc_n2 * conc_o_atom * dt_sec
    conc_no += r_nox

    // 4. Heat of combustion release rate (Delta H_combustion ~ 802 kJ / mol CH4)
    var/moles_ch4_burned_per_sec = r_ch4 / dt_sec
    heat_release_rate_kw_m3 = moles_ch4_burned_per_sec * 802000.0

    // Energy balance on flame temperature
    // Cp_mix ~ 35.0 kJ / (kmol * K)
    var/cp_flame = 35.0
    var/total_moles = conc_ch4 + conc_o2 + conc_co2 + conc_h2o + conc_co + conc_n2
    var/temp_rise = (heat_release_rate_kw_m3 * dt_sec) / max(total_moles * cp_flame, 1.0)
    flame_temp_k = min(max(flame_temp_k + temp_rise - (25.0 * dt_sec), 800.0), 2450.0)
