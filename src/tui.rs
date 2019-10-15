//! Terminal UI (TUI) Dashboard for Plenum Digital Twin
//!
//! Renders real-time ANSI/ASCII industrial telemetry, microgrid status,
//! atmospheric zone chemistry, robot telemetry, and alarm annunciator grids.

use crate::simulator::SimulationEngine;
use crate::automation::AlarmState;

pub struct Dashboard;

impl Dashboard {
    pub fn render(engine: &SimulationEngine) -> String {
        let metrics = engine.metrics();
        let mut out = String::with_capacity(4096);

        out.push_str("\x1b[2J\x1b[H"); // Clear screen and home cursor
        out.push_str("========================================================================================\n");
        out.push_str(&format!(
            " PLENUM CYBER-PHYSICAL DIGITAL TWIN v{} | SIM: {:07.2}s | TICK: {:06}\n",
            crate::VERSION, metrics.sim_time, engine.tick
        ));
        out.push_str("========================================================================================\n");

        // Section 1: Process Gauges
        out.push_str("--- PROCESS TELEMETRY & THREE-ELEMENT CONTROL ------------------------------------------\n");
        let p_bar = Self::format_bar(metrics.boiler_pressure_bar, 0.0, 100.0, 24);
        out.push_str(&format!(" Steam Pressure : [{}] {:5.1} bar (SP: 65.0 bar)\n", p_bar, metrics.boiler_pressure_bar));

        let t_bar = Self::format_bar(engine.pid_temp.pv, 250.0, 600.0, 24);
        out.push_str(&format!(" Superheat Temp : [{}] {:5.1} K   (SP: 480.0 K)\n", t_bar, engine.pid_temp.pv));

        let l_bar = Self::format_bar(engine.pid_level.pv, 0.0, 100.0, 24);
        out.push_str(&format!(" Drum Level     : [{}] {:5.1} %   (SP:  50.0 %)\n", l_bar, engine.pid_level.pv));

        let b_bar = Self::format_bar(metrics.bess_soc_percent, 0.0, 100.0, 24);
        out.push_str(&format!(" BESS Charge    : [{}] {:5.1} %   (Net: {:+.1} MW)\n", b_bar, metrics.bess_soc_percent, engine.power_flow.buses[3].p_gen_mw));

        // Section 2: Microgrid Substation Status
        out.push_str("\n--- MICROGRID SUBSTATION (13.8 kV / 4.16 kV INTERTIE) ---------------------------------\n");
        out.push_str(&format!(
            " Bus 1 [GRID SLACK] : {:6.3} pu | {:5.1} kV | {:5.2} Hz\n",
            engine.power_flow.buses[0].voltage_magnitude_pu,
            engine.power_flow.buses[0].voltage_magnitude_pu * engine.power_flow.buses[0].base_kv,
            engine.power_flow.buses[0].frequency_hz
        ));
        out.push_str(&format!(
            " Bus 2 [TURBINE PV] : {:6.3} pu | {:5.1} MW Gen | Angle: {:+5.2} deg\n",
            engine.power_flow.buses[1].voltage_magnitude_pu,
            engine.power_flow.buses[1].p_gen_mw,
            engine.power_flow.buses[1].voltage_angle_rad.to_degrees()
        ));
        out.push_str(&format!(
            " Bus 3 [PLANT LOAD] : {:6.3} pu | {:5.1} MW Load | {:4.1} MVAR\n",
            engine.power_flow.buses[2].voltage_magnitude_pu,
            engine.power_flow.buses[2].p_load_mw,
            engine.power_flow.buses[2].q_load_mvar
        ));
        out.push_str(&format!(
            " Bus 4 [BESS / RES] : {:6.3} pu | {:5.1} MW Aux | Status: DISPATCH\n",
            engine.power_flow.buses[3].voltage_magnitude_pu,
            engine.power_flow.buses[3].p_gen_mw
        ));

        // Section 3: Atmospheric Zones
        out.push_str("\n--- MULTI-ZONE ATMOSPHERIC THERMODYNAMICS ----------------------------------------------\n");
        for (i, zone) in engine.zones.iter().enumerate() {
            let p_kpa = zone.calculate_pressure_ideal() / 1000.0;
            out.push_str(&format!(
                " [{}] {:<16} : {:5.1} K | {:6.2} kPa | {:7.1} mol | Vol: {:6.0} L\n",
                i + 1, engine.zone_names[i], zone.temperature_k, p_kpa, zone.total_moles(), zone.volume_liters
            ));
        }

        // Section 4: Autonomous Robotic Inspection
        out.push_str("\n--- ROBOTIC INSPECTION & SPATIAL FLEET -------------------------------------------------\n");
        out.push_str(&format!(
            " AGV Unit-1 Pos: ({:2}, {:2}) -> Target: ({:2}, {:2}) | Route Remaining: {} waypoints\n",
            engine.robot_pos.0, engine.robot_pos.1, engine.robot_target.0, engine.robot_target.1, engine.robot_path.len()
        ));

        // Section 5: ISA-18.2 Alarm Annunciator & Event Log
        out.push_str("\n--- ALARM ANNUNCIATOR & EVENT JOURNAL --------------------------------------------------\n");
        for alarm in &engine.alarms {
            let state_str = match alarm.state {
                AlarmState::Normal => "[ NORMAL ]",
                AlarmState::ActiveUnacknowledged => "\x1b[31;1m[ UNACK  ]\x1b[0m",
                AlarmState::ActiveAcknowledged => "\x1b[33m[  ACK   ]\x1b[0m",
                AlarmState::ClearedUnacknowledged => "\x1b[36m[ CLR_UA ]\x1b[0m",
            };
            out.push_str(&format!(" {:<8} {:<32} {}\n", alarm.tag, alarm.description, state_str));
        }

        out.push_str("\nRecent Plant Events:\n");
        let start_idx = engine.event_log.len().saturating_sub(4);
        for entry in &engine.event_log[start_idx..] {
            out.push_str(&format!("   {}\n", entry));
        }

        out.push_str("========================================================================================\n");
        out
    }

    fn format_bar(val: f64, min_v: f64, max_v: f64, width: usize) -> String {
        let clamped = val.clamp(min_v, max_v);
        let ratio = if (max_v - min_v).abs() < 1e-6 { 0.0 } else { (clamped - min_v) / (max_v - min_v) };
        let filled = ((ratio * width as f64).round() as usize).min(width);
        let empty = width.saturating_sub(filled);

        let mut s = String::with_capacity(width);
        for _ in 0..filled {
            s.push('=');
        }
        for _ in 0..empty {
            s.push(' ');
        }
        s
    }
}
