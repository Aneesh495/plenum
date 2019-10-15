//! Digital Twin Simulation Engine
//!
//! Orchestrates multi-rate physical processes, thermodynamic zones,
//! power flow networks, PLC logic scans, and autonomous inspection robotics.

use crate::thermo::{GasMixture, GAS_O2, GAS_CH4};
use crate::microgrid::{ElectricalBus, TransmissionLine, PowerFlowSolver, BUS_SLACK, BUS_PV, BUS_PQ};
use crate::automation::{PlcState, PidController, AlarmState, AlarmRecord, ALARM_PRIO_HIGH, ALARM_PRIO_CRITICAL};
use crate::robotics::SpatialGrid;

pub struct PlantMetrics {
    pub sim_time: f64,
    pub boiler_pressure_bar: f64,
    pub turbine_power_mw: f64,
    pub grid_frequency_hz: f64,
    pub zone1_temp_k: f64,
    pub zone1_o2_percent: f64,
    pub bess_soc_percent: f64,
    pub active_alarms_count: usize,
}

pub struct SimulationEngine {
    pub tick: u64,
    pub sim_time_sec: f64,
    pub dt: f64,
    pub zones: Vec<GasMixture>,
    pub zone_names: Vec<String>,
    pub power_flow: PowerFlowSolver,
    pub plc: PlcState,
    pub pid_pressure: PidController,
    pub pid_temp: PidController,
    pub pid_level: PidController,
    pub alarms: Vec<AlarmRecord>,
    pub grid: SpatialGrid,
    pub robot_pos: (i32, i32),
    pub robot_target: (i32, i32),
    pub robot_path: Vec<(i32, i32)>,
    pub event_log: Vec<String>,
    pub bess_soc: f64,
    pub fault_active: bool,
}

impl SimulationEngine {
    pub fn new() -> Self {
        // Initialize 4 physical plant zones
        let mut z1 = GasMixture::new(10000.0); // Turbine hall
        z1.set_composition_stp(101.325, 298.15, 0.2095, 0.7808);

        let mut z2 = GasMixture::new(8000.0);  // Boiler hall
        z2.set_composition_stp(101.325, 310.15, 0.2050, 0.7850);

        let mut z3 = GasMixture::new(5000.0);  // Chemical storage
        z3.set_composition_stp(101.325, 293.15, 0.2095, 0.7808);

        let mut z4 = GasMixture::new(3000.0);  // Substation and battery bay
        z4.set_composition_stp(101.325, 295.15, 0.2095, 0.7808);

        let zones = vec![z1, z2, z3, z4];
        let zone_names = vec![
            "Turbine Hall".to_string(),
            "Boiler Building".to_string(),
            "Process Bay".to_string(),
            "BESS Substation".to_string(),
        ];

        // 4-bus microgrid
        let mut b1 = ElectricalBus::new("BUS-1-GRID", BUS_SLACK, 13.8, 100.0);
        b1.voltage_magnitude_pu = 1.0;
        b1.voltage_angle_rad = 0.0;

        let mut b2 = ElectricalBus::new("BUS-2-TURBINE", BUS_PV, 13.8, 100.0);
        b2.p_gen_mw = 45.0;
        b2.voltage_magnitude_pu = 1.02;

        let mut b3 = ElectricalBus::new("BUS-3-LOAD", BUS_PQ, 4.16, 100.0);
        b3.p_load_mw = 35.0;
        b3.q_load_mvar = 12.0;

        let mut b4 = ElectricalBus::new("BUS-4-BESS", BUS_PQ, 4.16, 100.0);
        b4.p_gen_mw = 5.0;
        b4.p_load_mw = 2.0;

        let lines = vec![
            TransmissionLine::new("TL-1-2", 0, 1, 0.015, 0.065, 0.010),
            TransmissionLine::new("TL-2-3", 1, 2, 0.020, 0.080, 0.012),
            TransmissionLine::new("TL-3-4", 2, 3, 0.010, 0.040, 0.005),
            TransmissionLine::new("TL-1-4", 0, 3, 0.025, 0.095, 0.015),
        ];

        let power_flow = PowerFlowSolver::new(vec![b1, b2, b3, b4], lines);
        let plc = PlcState::new(128, 64);

        // Control loops
        let mut pid_pressure = PidController::new("PIC-101", 1.8, 4.0, 0.2);
        pid_pressure.sp = 65.0; // 65 bar steam
        pid_pressure.pv = 62.0;

        let mut pid_temp = PidController::new("TIC-201", 2.2, 8.0, 0.5);
        pid_temp.sp = 480.0; // 480 C superheater
        pid_temp.pv = 475.0;

        let mut pid_level = PidController::new("LIC-301", 1.5, 3.0, 0.1);
        pid_level.sp = 50.0; // 50% drum level
        pid_level.pv = 49.5;

        // Alarms
        let alarms = vec![
            AlarmRecord::new("ALM-001", "Boiler Drum Overpressure", ALARM_PRIO_CRITICAL),
            AlarmRecord::new("ALM-002", "Combustion Chamber Flameout", ALARM_PRIO_HIGH),
            AlarmRecord::new("ALM-003", "Bus 3 Under-Voltage Sag", ALARM_PRIO_HIGH),
            AlarmRecord::new("ALM-004", "BESS Cell Thermal Warning", ALARM_PRIO_HIGH),
        ];

        // Spatial grid for robotics (30 x 20 layout)
        let mut grid = SpatialGrid::new(30, 20);
        // Build perimeter and equipment barriers
        for x in 0..30 {
            grid.set_obstacle(x, 0, true);
            grid.set_obstacle(x, 19, true);
        }
        for y in 0..20 {
            grid.set_obstacle(0, y, true);
            grid.set_obstacle(29, y, true);
        }
        // Central machinery column
        for y in 6..14 {
            grid.set_obstacle(15, y, true);
        }

        let robot_pos = (2, 2);
        let robot_target = (25, 15);
        let robot_path = grid.find_path_a_star(2, 2, 25, 15).unwrap_or_default();

        let mut engine = Self {
            tick: 0,
            sim_time_sec: 0.0,
            dt: 0.05,
            zones,
            zone_names,
            power_flow,
            plc,
            pid_pressure,
            pid_temp,
            pid_level,
            alarms,
            grid,
            robot_pos,
            robot_target,
            robot_path,
            event_log: Vec::new(),
            bess_soc: 85.0,
            fault_active: false,
        };

        engine.log("Plenum digital twin kernel booted successfully.");
        engine.log("Deterministic multi-rate scheduler active: thermo 20Hz, power flow 2Hz, PLC 100Hz.");
        engine
    }

    pub fn log(&mut self, msg: &str) {
        let entry = format!("[T+{:07.2}s] {}", self.sim_time_sec, msg);
        if self.event_log.len() >= 100 {
            self.event_log.remove(0);
        }
        self.event_log.push(entry);
    }

    pub fn step(&mut self) {
        self.tick += 1;
        self.sim_time_sec += self.dt;

        // 1. Thermodynamic step
        // Ambient heat transfer and small process noise
        let boiler_q = if self.fault_active { 8000.0 } else { 15000.0 };
        self.zones[1].add_thermal_energy(boiler_q * self.dt);

        // Slow diffusion between boiler hall (zone 1) and turbine hall (zone 0)
        let delta_t = self.zones[1].temperature_k - self.zones[0].temperature_k;
        let cond_k = 120.0;
        let q_transfer = cond_k * delta_t * self.dt;
        self.zones[1].add_thermal_energy(-q_transfer);
        self.zones[0].add_thermal_energy(q_transfer);

        // 2. Process Control (PID loops)
        // Simulated process responses
        let cv_press = self.pid_pressure.compute_step(self.dt);
        self.pid_pressure.pv += (cv_press * 0.01 - 0.5) * self.dt;

        let cv_temp = self.pid_temp.compute_step(self.dt);
        self.pid_temp.pv += (cv_temp * 0.08 - 4.0) * self.dt;

        let cv_level = self.pid_level.compute_step(self.dt);
        self.pid_level.pv += (cv_level * 0.02 - 1.0) * self.dt;

        // 3. Electrical Microgrid step (every 10 ticks = 2 Hz)
        if self.tick % 10 == 0 {
            // Load fluctuation
            let t_cycle = (self.sim_time_sec * 0.1).sin();
            self.power_flow.buses[2].p_load_mw = 35.0 + t_cycle * 3.0;

            // BESS contribution
            if self.power_flow.buses[2].p_load_mw > 36.0 {
                self.bess_soc = (self.bess_soc - 0.01).max(10.0);
                self.power_flow.buses[3].p_gen_mw = 6.5;
            } else {
                self.bess_soc = (self.bess_soc + 0.005).min(100.0);
                self.power_flow.buses[3].p_gen_mw = 2.0;
            }

            self.power_flow.solve();
        }

        // 4. Robotics step (every 5 ticks)
        if self.tick % 5 == 0 && !self.robot_path.is_empty() {
            let next_waypoint = self.robot_path.remove(0);
            self.robot_pos = next_waypoint;

            if self.robot_pos == self.robot_target {
                self.log(&format!("Service robot reached checkpoint at ({}, {}).", self.robot_target.0, self.robot_target.1));
                // Target next waypoint in a loop
                if self.robot_target == (25, 15) {
                    self.robot_target = (5, 15);
                } else if self.robot_target == (5, 15) {
                    self.robot_target = (5, 4);
                } else {
                    self.robot_target = (25, 15);
                }
                if let Some(p) = self.grid.find_path_a_star(self.robot_pos.0, self.robot_pos.1, self.robot_target.0, self.robot_target.1) {
                    self.robot_path = p;
                }
            }
        }

        // 5. Alarm evaluation
        if self.pid_pressure.pv > 70.0 {
            if self.alarms[0].state == AlarmState::Normal {
                self.alarms[0].trip();
                self.log("ALARM TRIP: Boiler Drum Overpressure exceeds 70.0 bar limit!");
            }
        } else if self.alarms[0].state != AlarmState::Normal && self.pid_pressure.pv < 67.0 {
            self.alarms[0].clear();
            self.log("ALARM CLEAR: Boiler Drum Pressure returned to safe bounds.");
        }
    }

    pub fn inject_fault(&mut self, fault_name: &str) {
        self.fault_active = true;
        match fault_name {
            "feedwater_loss" => {
                self.pid_level.pv -= 15.0;
                self.log("FAULT INJECTED: Main Boiler Feedwater Pump Trip");
            },
            "line_trip" => {
                self.power_flow.lines[1].is_in_service = false;
                self.log("FAULT INJECTED: Intertie Line TL-2-3 Tripped by Overcurrent Relay 50/51");
            },
            "gas_leak" => {
                self.zones[0].moles[GAS_CH4] += 50.0;
                self.log("FAULT INJECTED: Natural Gas Fuel Train Flange Rupture in Turbine Hall");
            },
            _ => {
                self.log(&format!("FAULT INJECTED: Unrecognized event {}", fault_name));
            }
        }
    }

    pub fn metrics(&self) -> PlantMetrics {
        let z1_moles = self.zones[0].total_moles();
        let z1_o2 = if z1_moles > 1e-4 { (self.zones[0].moles[GAS_O2] / z1_moles) * 100.0 } else { 0.0 };
        let active_alarms = self.alarms.iter().filter(|a| a.state != AlarmState::Normal).count();

        PlantMetrics {
            sim_time: self.sim_time_sec,
            boiler_pressure_bar: self.pid_pressure.pv,
            turbine_power_mw: self.power_flow.buses[1].p_gen_mw,
            grid_frequency_hz: self.power_flow.buses[0].frequency_hz,
            zone1_temp_k: self.zones[0].temperature_k,
            zone1_o2_percent: z1_o2,
            bess_soc_percent: self.bess_soc,
            active_alarms_count: active_alarms,
        }
    }
}
