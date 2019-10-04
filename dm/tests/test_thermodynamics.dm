// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Thermodynamics & Chemical Kinetics Verification Tests
// Language: Dream Maker (DM)

#ifndef PLENUM_TESTS_THERMODYNAMICS_DM
#define PLENUM_TESTS_THERMODYNAMICS_DM

#include "test_runner.dm"
#include "../physics/gas_mixture.dm"
#include "../physics/thermodynamics.dm"
#include "../physics/combustion.dm"
#include "../physics/phase_change.dm"

/datum/test_suite_thermodynamics

/datum/test_suite_thermodynamics/proc/RunTests(datum/test_runner/runner)
    runner.StartSuite("Thermodynamics & Combustion")

    // Test 1: Ideal Gas Equation of State at STP
    var/datum/gas_mixture/mix1 = new /datum/gas_mixture(2500.0) // 2.5 m^3
    mix1.SetCompositionSTP(101.325, 293.15, 0.21, 0.79)
    var/p_calc = mix1.CalculatePressureIdeal()
    runner.AssertEqual(p_calc, 101325.0, 100.0, "Ideal Gas Law at STP (P = 101325 Pa)")

    // Test 2: First Law of Thermodynamics Thermal Mixing
    // Mix 1: 100 mol at 300K, Mix 2: 100 mol at 400K -> Expected T_final = 350K for identical Cv
    var/datum/gas_mixture/box_a = new /datum/gas_mixture(1000.0)
    var/datum/gas_mixture/box_b = new /datum/gas_mixture(1000.0)
    box_a.temperature = 300.0
    box_a.SetMoles(GAS_N2, 100.0)
    box_b.temperature = 400.0
    box_b.SetMoles(GAS_N2, 100.0)
    box_a.MergeMixture(box_b)
    runner.AssertEqual(box_a.temperature, 350.0, 0.01, "First Law Isothermal Thermal Mixing Energy Conservation")

    // Test 3: Peng-Robinson High Pressure Real Gas Deviation
    // At high density (e.g. 50 bar), real gas volume should show higher repulsive pressure than ideal gas
    var/datum/gas_mixture/co2_high_p = new /datum/gas_mixture(100.0)
    co2_high_p.temperature = 310.0
    co2_high_p.SetMoles(GAS_CO2, 250.0)
    var/p_pr = co2_high_p.CalculatePressurePengRobinson()
    runner.AssertTrue(p_pr > 5000000.0, "Peng-Robinson EOS Supercritical Real Gas Behavior")

    // Test 4: Arrhenius Methane Combustion Stoichiometry
    var/datum/gas_mixture/comb_chamber = new /datum/gas_mixture(1000.0)
    comb_chamber.temperature = 900.0 // Above auto-ignition temp
    comb_chamber.SetMoles(GAS_CH4, 10.0)
    comb_chamber.SetMoles(GAS_O2, 20.0)
    var/datum/combustion_engine/eng = new /datum/combustion_engine()
    var/heat_released = eng.EvaluateReactionTick(comb_chamber, 1.0, FALSE)
    runner.AssertTrue(heat_released > 0.0, "Methane Combustion Exothermic Heat Release")
    runner.AssertTrue(comb_chamber.GetMoles(GAS_CO2) > 0.0, "CO2 Production from Hydrocarbon Oxidation")
    runner.AssertTrue(comb_chamber.GetMoles(GAS_H2O) > 0.0, "H2O Vapor Production from Hydrocarbon Oxidation")

    // Test 5: Antoine Vapor Pressure of Water at 100 C (373.15 K)
    var/datum/phase_change_solver/pcs = new /datum/phase_change_solver()
    var/p_sat_boil = pcs.CalculateSaturationPressureWaterPa(373.15)
    runner.AssertEqual(p_sat_boil, 101325.0, 3000.0, "Antoine Equation Saturation Vapor Pressure at 100 C")

    qdel(mix1)
    qdel(box_a)
    qdel(box_b)
    qdel(co2_high_p)
    qdel(comb_chamber)
    qdel(eng)
    qdel(pcs)

#endif // PLENUM_TESTS_THERMODYNAMICS_DM
