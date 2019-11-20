// Electrolyte NRTL (e-NRTL) Acid Gas Sweetening & Chemical Absorption
//
// Implements Chen and Song Electrolyte Non-Random Two-Liquid (e-NRTL) thermodynamic
// framework for reactive absorption of sour acid gases (CO2, H2S) into aqueous
// alkanolamine solvents (N-methyldiethanolamine MDEA and monoethanolamine MEA).
// Formulates Pitzer-Debye-Huckel (PDH) long-range electrostatic ion-ion forces,
// ionic strength I, and chemical equilibrium speciation (MDEAH+, HCO3-, HS-, CO3^2-).

/datum/chemistry/electrolyte_nrtl
    var/tag = "ENRTL-AMINE-SWEETENING"
    var/amine_wt_pct = 45.0 // 45 wt% activated MDEA solvent
    var/amine_molecular_weight = 119.16 // MDEA (C5H13NO2)

    // Liquid phase speciation concentrations (mol / kg solvent)
    var/m_mdea_free = 3.25
    var/m_mdeah_plus = 0.85
    var/m_hco3_minus = 0.82
    var/m_hs_minus = 0.03
    var/m_co3_minus2 = 0.01

    // Operating states
    var/absorber_temp_k = 323.15 // 50 C column bottom
    var/absorber_press_bar = 65.0 // 65 bar natural gas treater
    var/ionic_strength_mol_kg = 0.88
    var/co2_loading_alpha = 0.26 // mol CO2 / mol amine
    var/h2s_loading_alpha = 0.01

    // Equilibrium partial pressures
    var/p_co2_equil_kpa = 12.5
    var/p_h2s_equil_kpa = 0.08 // < 4 ppm sweet gas specification

/datum/chemistry/electrolyte_nrtl/New()
    ..()

// Pitzer-Debye-Huckel (PDH) Long-Range Ionic Activity Coefficient:
// ln(gamma_i_PDH) = -A_phi * [ sqrt(I)/(1 + b*sqrt(I)) + (2/b)*ln(1 + b*sqrt(I)) ] * z_i^2
/datum/chemistry/electrolyte_nrtl/proc/calculate_pdh_activity(z_valence, ionic_str, temp_k)
    var/b_param = 1.20 // Universal Pitzer parameter
    var/a_phi = 0.392 * (temp_k / 298.15) // Debye-Huckel osmotic slope parameter

    var/sqrt_i = sqrt(max(ionic_str, 1e-4))
    var/term1 = sqrt_i / (1.0 + (b_param * sqrt_i))
    var/term2 = (2.0 / b_param) * log(1.0 + (b_param * sqrt_i))

    var/ln_gamma = -a_phi * (term1 + term2) * (z_valence * z_valence)
    return exp(min(max(ln_gamma, -4.0), 1.0))

// Chemical equilibrium speciation and vapor partial pressure of CO2 over MDEA:
// K_eq = [MDEAH+] * [HCO3-] / ([MDEA] * [CO2] * [H2O])
// P_CO2 = [CO2] / H_CO2 (Henry's law)
/datum/chemistry/electrolyte_nrtl/proc/calculate_acid_gas_equilibrium(loading_co2, temp_k)
    co2_loading_alpha = loading_co2

    // Ionic strength calculation: I = 0.5 * sum(m_i * z_i^2)
    var/m_total_amine = 4.10
    m_mdeah_plus = m_total_amine * loading_co2
    m_hco3_minus = m_mdeah_plus * 0.98
    m_mdea_free = max(m_total_amine - m_mdeah_plus, 0.05)

    ionic_strength_mol_kg = 0.5 * ((m_mdeah_plus * 1.0) + (m_hco3_minus * 1.0) + (m_co3_minus2 * 4.0))

    // Activity coefficient for bicarbonate ion via PDH
    var/gamma_hco3 = calculate_pdh_activity(1, ionic_strength_mol_kg, temp_k)

    // Temperature dependent equilibrium constant for MDEA carbamate / bicarbonate:
    // ln(K) = -11.9 + (3450 / T)
    var/ln_k = -11.9 + (3450.0 / temp_k)
    var/k_rxn = exp(ln_k)

    // Dissolved molecular CO2 concentration in liquid
    var/m_co2_mol = (m_mdeah_plus * m_hco3_minus * gamma_hco3) / max(m_mdea_free * k_rxn, 1e-6)

    // Henry's Law constant H_CO2 (kPa * kg / mol): ln(H) = 7.85 - (1850 / T)
    var/h_henry = exp(7.85 - (1850.0 / temp_k))
    p_co2_equil_kpa = m_co2_mol * h_henry

    return p_co2_equil_kpa
