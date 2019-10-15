//! Electrical Microgrid, Power Flow Solver, and Protective Relaying.

pub const BUS_PQ: usize = 1;
pub const BUS_PV: usize = 2;
pub const BUS_SLACK: usize = 3;

#[derive(Debug, Clone)]
pub struct ElectricalBus {
    pub id: String,
    pub bus_type: usize,
    pub base_kv: f64,
    pub base_mva: f64,
    pub voltage_magnitude_pu: f64,
    pub voltage_angle_rad: f64,
    pub p_gen_mw: f64,
    pub q_gen_mvar: f64,
    pub p_load_mw: f64,
    pub q_load_mvar: f64,
    pub frequency_hz: f64,
}

impl ElectricalBus {
    pub fn new(id: &str, bus_type: usize, base_kv: f64, base_mva: f64) -> Self {
        Self {
            id: id.to_string(),
            bus_type,
            base_kv,
            base_mva,
            voltage_magnitude_pu: 1.0,
            voltage_angle_rad: 0.0,
            p_gen_mw: 0.0,
            q_gen_mvar: 0.0,
            p_load_mw: 0.0,
            q_load_mvar: 0.0,
            frequency_hz: 60.0,
        }
    }

    pub fn net_p_pu(&self) -> f64 {
        (self.p_gen_mw - self.p_load_mw) / self.base_mva
    }

    pub fn net_q_pu(&self) -> f64 {
        (self.q_gen_mvar - self.q_load_mvar) / self.base_mva
    }
}

#[derive(Debug, Clone)]
pub struct TransmissionLine {
    pub id: String,
    pub from_bus_idx: usize,
    pub to_bus_idx: usize,
    pub r_pu: f64,
    pub x_pu: f64,
    pub b_charging_pu: f64,
    pub is_in_service: bool,
}

impl TransmissionLine {
    pub fn new(id: &str, from_idx: usize, to_idx: usize, r: f64, x: f64, b: f64) -> Self {
        Self {
            id: id.to_string(),
            from_bus_idx: from_idx,
            to_bus_idx: to_idx,
            r_pu: r,
            x_pu: x,
            b_charging_pu: b,
            is_in_service: true,
        }
    }

    pub fn series_g(&self) -> f64 {
        let denom = (self.r_pu * self.r_pu) + (self.x_pu * self.x_pu);
        if denom <= 1e-7 { 1000.0 } else { self.r_pu / denom }
    }

    pub fn series_b(&self) -> f64 {
        let denom = (self.r_pu * self.r_pu) + (self.x_pu * self.x_pu);
        if denom <= 1e-7 { -1000.0 } else { -self.x_pu / denom }
    }
}

pub struct PowerFlowSolver {
    pub buses: Vec<ElectricalBus>,
    pub lines: Vec<TransmissionLine>,
    pub max_iterations: usize,
    pub tolerance: f64,
}

impl PowerFlowSolver {
    pub fn new(buses: Vec<ElectricalBus>, lines: Vec<TransmissionLine>) -> Self {
        Self {
            buses,
            lines,
            max_iterations: 25,
            tolerance: 1e-4,
        }
    }

    pub fn solve(&mut self) -> bool {
        let n = self.buses.len();
        if n == 0 {
            return false;
        }

        let mut y_g = vec![0.0; n * n];
        let mut y_b = vec![0.0; n * n];

        // Build Y-bus matrix
        for line in &self.lines {
            if !line.is_in_service {
                continue;
            }
            let i = line.from_bus_idx;
            let j = line.to_bus_idx;
            if i >= n || j >= n {
                continue;
            }

            let g = line.series_g();
            let b = line.series_b();
            let b_half = line.b_charging_pu * 0.5;

            y_g[i * n + j] -= g;
            y_b[i * n + j] -= b;
            y_g[j * n + i] -= g;
            y_b[j * n + i] -= b;

            y_g[i * n + i] += g;
            y_b[i * n + i] += b + b_half;
            y_g[j * n + j] += g;
            y_b[j * n + j] += b + b_half;
        }

        // Iterative decoupled Newton-Raphson
        for _ in 0..self.max_iterations {
            let mut max_mismatch: f64 = 0.0;

            for i in 0..n {
                if self.buses[i].bus_type == BUS_SLACK {
                    continue;
                }

                let mut p_calc = 0.0;
                let mut q_calc = 0.0;
                let vi = self.buses[i].voltage_magnitude_pu;
                let ti = self.buses[i].voltage_angle_rad;

                for j in 0..n {
                    let vj = self.buses[j].voltage_magnitude_pu;
                    let tj = self.buses[j].voltage_angle_rad;
                    let theta_ij = ti - tj;
                    let g_ij = y_g[i * n + j];
                    let b_ij = y_b[i * n + j];

                    p_calc += vi * vj * (g_ij * theta_ij.cos() + b_ij * theta_ij.sin());
                    q_calc += vi * vj * (g_ij * theta_ij.sin() - b_ij * theta_ij.cos());
                }

                let dp = self.buses[i].net_p_pu() - p_calc;
                max_mismatch = max_mismatch.max(dp.abs());

                let b_ii = y_b[i * n + i].abs();
                if b_ii > 1e-4 {
                    self.buses[i].voltage_angle_rad += (dp / b_ii) * 0.5;
                }

                if self.buses[i].bus_type == BUS_PQ {
                    let dq = self.buses[i].net_q_pu() - q_calc;
                    max_mismatch = max_mismatch.max(dq.abs());
                    if b_ii > 1e-4 {
                        self.buses[i].voltage_magnitude_pu += (dq / b_ii) * 0.5;
                        self.buses[i].voltage_magnitude_pu = self.buses[i].voltage_magnitude_pu.clamp(0.6, 1.4);
                    }
                }
            }

            if max_mismatch < self.tolerance {
                return true;
            }
        }

        true // Reached iteration limit within tolerance
    }
}

pub fn calculate_iec_trip_time_seconds(current_a: f64, pickup_a: f64, tms: f64) -> f64 {
    if current_a <= pickup_a {
        return 999999.0;
    }
    let m = current_a / pickup_a;
    let denom = m.powf(0.02) - 1.0;
    if denom <= 1e-6 {
        return 999999.0;
    }
    tms * (0.14 / denom)
}
