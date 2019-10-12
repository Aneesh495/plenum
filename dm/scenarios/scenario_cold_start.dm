// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Scenario: Cold Plant Startup to Steady-State Base Load
// Language: Dream Maker (DM)

#ifndef PLENUM_SCENARIOS_COLD_START_DM
#define PLENUM_SCENARIOS_COLD_START_DM

#include "../core/datum.dm"
#include "../models/diesel_genset.dm"
#include "../models/compressed_air.dm"
#include "../models/cooling_tower.dm"
#include "../models/boiler.dm"
#include "../models/gas_turbine.dm"

/datum/scenario_cold_start
    var/scenario_name = "Full Plant Cold Startup to Base Load Equilibrium"
    var/startup_phase = 1
    var/is_at_base_load = FALSE

/datum/scenario_cold_start/proc/ExecuteSequenceStep(obj/machinery/diesel_genset/edg, obj/machinery/instrument_air_compressor/iac, obj/machinery/cooling_tower/ct, obj/machinery/steam_boiler/blr, obj/machinery/gas_turbine/gt, delta_time_s)
    switch(startup_phase)
        if(1)
            // Phase 1: Start emergency diesel generator for cranking power
            edg.InitiateAutoStart()
            edg.is_running_rated = TRUE
            startup_phase = 2

        if(2)
            // Phase 2: Pressurize instrument air header
            iac.operating_state = 1
            iac.receiver_pressure_bar = 7.0
            startup_phase = 3

        if(3)
            // Phase 3: Start cooling tower water circulation
            ct.operating_state = 1
            ct.fan_speed_ratio = 1.0
            ct.CalculateBasinTemperature(20.0)
            startup_phase = 4

        if(4)
            // Phase 4: Fire steam boiler and establish drum water level
            blr.operating_state = 1
            blr.drum_level_mm = 0.0
            startup_phase = 5

        if(5)
            // Phase 5: Gas turbine ignition, synchronization, and ramp to 45 MW base load
            gt.operating_state = 1
            gt.fuel_flow_kg_s = 2.45
            var/net_mw = gt.CalculateBraytonCycleThermodynamics()
            if(net_mw >= 40.0)
                is_at_base_load = TRUE

    return is_at_base_load

#endif // PLENUM_SCENARIOS_COLD_START_DM
