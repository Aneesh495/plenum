// Blast Furnace Lower Zone & Raceway Adiabatic Flame Temperature (RAFT)
//
// Implements 4,000 m3 ironmaking blast furnace lower zone (tuyere, raceway,
// dripping zone, and hearth). Models Raceway Adiabatic Flame Temperature (RAFT),
// hot blast oxygen enrichment, moisture blast blast injection, Pulverized Coal
// Injection (PCI), Boudouard gas equilibrium (C + CO2 <=> 2CO), iron ore
// reduction kinetics (Fe2O3 -> Fe3O4 -> FeO -> Fe), and hot metal chemistry.

/datum/model/blast_furnace_tuyere
    var/tag = "BF-TUYERE-ZONE"
    var/hot_metal_production_tpd = 8500.0 // Tonnes of hot metal per day
    var/num_tuyeres = 32
    var/hearth_diameter_m = 13.5

    // Hot Blast Conditions
    var/blast_temp_k = 1473.15 // 1200 C from hot stoves
    var/blast_pressure_bar = 4.2
    var/blast_volume_nm3_min = 6800.0
    var/oxygen_enrichment_pct = 5.5 // Total 26.5% O2
    var/blast_moisture_g_nm3 = 25.0

    // Pulverized Coal Injection (PCI)
    var/pci_rate_kg_thm = 195.0 // kg per tonne hot metal
    var/pci_replacement_ratio = 0.85 // kg coke replaced per kg coal

    // Raceway Performance Indicators
    var/raft_temp_k = 2423.15 // 2150 C optimal raceway temperature
    var/bosh_gas_volume_nm3_min = 9200.0
    var/bosh_gas_co_pct = 38.5
    var/bosh_gas_h2_pct = 8.2
    var/bosh_gas_n2_pct = 53.3

    // Hot Metal (Pig Iron) Quality
    var/hot_metal_temp_k = 1773.15 // 1500 C tapping
    var/carbon_pct = 4.45
    var/silicon_pct = 0.42
    var/sulfur_pct = 0.025
    var/slag_basicity_b2 = 1.18 // CaO / SiO2

/datum/model/blast_furnace_tuyere/New()
    ..()

// Raceway Adiabatic Flame Temperature (RAFT) Calculation:
// RAFT is governed by heat of combustion of carbon to CO, blast sensible heat,
// PCI heat deficit, oxygen enrichment (+40 K per 1% O2), and moisture blast (-7 K per g/Nm3)
/datum/model/blast_furnace_tuyere/proc/calculate_raft(blast_t_k, o2_enrich, moisture_g, pci_kg)
    var/base_raft = 2320.0 // Kelvin baseline at 1150 C blast
    var/delta_blast_t = (blast_t_k - 1423.15) * 0.75
    var/delta_o2 = o2_enrich * 42.0
    var/delta_moist = -moisture_g * 6.8
    var/delta_pci = -(pci_kg - 150.0) * 1.85 // Endothermic volatile devolatilization
    return base_raft + delta_blast_t + delta_o2 + delta_moist + delta_pci

// Boudouard Reaction Equilibrium: C + CO2 <=> 2CO (Endothermic)
// Equilibrium constant K_p = P_CO^2 / P_CO2
/datum/model/blast_furnace_tuyere/proc/calculate_boudouard_equilibrium(temp_k)
    var/r_gas = 8.314462618
    var/delta_h = 172500.0 // J / mol
    var/delta_s = 176.5    // J / (mol * K)
    var/delta_g = delta_h - (temp_k * delta_s)
    var/log_kp = -delta_g / (r_gas * temp_k)
    return exp(min(max(log_kp, -20.0), 20.0))

// Step tuyere raceway thermodynamics and hot metal quality
/datum/model/blast_furnace_tuyere/proc/step_tuyere(dt_sec)
    // 1. Calculate actual RAFT
    raft_temp_k = calculate_raft(blast_temp_k, oxygen_enrichment_pct, blast_moisture_g_nm3, pci_rate_kg_thm)

    // 2. Adjust moisture to maintain RAFT in safe refractory window (2373 K to 2473 K)
    if(raft_temp_k > 2450.0)
        blast_moisture_g_nm3 = min(blast_moisture_g_nm3 + (1.2 * dt_sec), 45.0)
    else if(raft_temp_k < 2390.0 && blast_moisture_g_nm3 > 15.0)
        blast_moisture_g_nm3 = max(blast_moisture_g_nm3 - (1.0 * dt_sec), 15.0)

    // 3. Silicon partitioning in hot metal:
    // SiO2 + 2C -> Si + 2CO increases with high hearth thermal state
    var/si_target = 0.35 + ((raft_temp_k - 2400.0) * 0.002)
    silicon_pct = silicon_pct + (si_target - silicon_pct) * 0.08 * dt_sec

    // 4. Sulfur transfer to slag: governed by optical basicity and hearth temperature
    // Desulfurization capacity is enhanced at higher slag basicity B2 > 1.15
    var/s_partition = 45.0 * slag_basicity_b2
    sulfur_pct = min(max(0.95 / s_partition, 0.012), 0.050)
