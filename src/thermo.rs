//! Thermodynamics, Fluid Dynamics, and Chemical Reaction Kinetics.

pub const R_GAS: f64 = 8.314462618;
pub const STANDARD_TEMP_K: f64 = 293.15;
pub const STANDARD_PRESSURE_PA: f64 = 101325.0;
pub const GRAVITY_ACCEL: f64 = 9.80665;

pub const GAS_O2: usize = 0;
pub const GAS_N2: usize = 1;
pub const GAS_CO2: usize = 2;
pub const GAS_H2O: usize = 3;
pub const GAS_H2: usize = 4;
pub const GAS_CH4: usize = 5;
pub const GAS_CO: usize = 6;
pub const GAS_AR: usize = 7;
pub const GAS_SF6: usize = 8;
pub const GAS_R134A: usize = 9;
pub const NUM_SPECIES: usize = 10;

pub const MOLAR_MASSES: [f64; NUM_SPECIES] = [
    0.0319988, 0.0280134, 0.0440100, 0.0180153, 0.0020159,
    0.0160425, 0.0280101, 0.0399480, 0.1460600, 0.1020300,
];

pub const CV_VALUES: [f64; NUM_SPECIES] = [
    21.0, 20.8, 28.5, 28.0, 20.4,
    27.1, 20.9, 12.5, 97.0, 78.2,
];

#[derive(Debug, Clone)]
pub struct GasMixture {
    pub volume_liters: f64,
    pub temperature_k: f64,
    pub moles: [f64; NUM_SPECIES],
}

impl Default for GasMixture {
    fn default() -> Self {
        Self::new(2500.0)
    }
}

impl GasMixture {
    pub fn new(volume_liters: f64) -> Self {
        Self {
            volume_liters: volume_liters.max(0.1),
            temperature_k: STANDARD_TEMP_K,
            moles: [0.0; NUM_SPECIES],
        }
    }

    pub fn set_composition_stp(&mut self, pressure_kpa: f64, temp_k: f64, o2_ratio: f64, n2_ratio: f64) {
        self.temperature_k = temp_k.max(0.1);
        let vol_m3 = self.volume_liters * 0.001;
        let press_pa = pressure_kpa * 1000.0;
        let total_n = (press_pa * vol_m3) / (R_GAS * self.temperature_k);
        self.moles = [0.0; NUM_SPECIES];
        self.moles[GAS_O2] = total_n * o2_ratio;
        self.moles[GAS_N2] = total_n * n2_ratio;
    }

    pub fn total_moles(&self) -> f64 {
        self.moles.iter().sum()
    }

    pub fn heat_capacity_cv(&self) -> f64 {
        let mut sum = 0.0;
        for i in 0..NUM_SPECIES {
            sum += self.moles[i] * CV_VALUES[i];
        }
        sum.max(0.0001)
    }

    pub fn calculate_pressure_ideal(&self) -> f64 {
        let total_n = self.total_moles();
        if total_n <= 1e-7 || self.volume_liters <= 1e-4 {
            return 0.0;
        }
        let vol_m3 = self.volume_liters * 0.001;
        (total_n * R_GAS * self.temperature_k) / vol_m3
    }

    pub fn add_thermal_energy(&mut self, delta_joules: f64) {
        let cv = self.heat_capacity_cv();
        if cv > 1e-4 {
            self.temperature_k += delta_joules / cv;
            if self.temperature_k < 0.1 {
                self.temperature_k = 0.1;
            }
        }
    }

    pub fn merge(&mut self, other: &GasMixture) {
        let cv_self = self.heat_capacity_cv();
        let cv_other = other.heat_capacity_cv();
        let e_total = (cv_self * self.temperature_k) + (cv_other * other.temperature_k);

        for i in 0..NUM_SPECIES {
            self.moles[i] += other.moles[i];
        }

        let cv_new = self.heat_capacity_cv();
        if cv_new > 1e-4 {
            self.temperature_k = e_total / cv_new;
        }
    }

    pub fn remove_fraction(&mut self, fraction: f64) -> GasMixture {
        let frac = fraction.clamp(0.0, 1.0);
        let mut removed = GasMixture::new(self.volume_liters * frac);
        removed.temperature_k = self.temperature_k;

        for i in 0..NUM_SPECIES {
            let m = self.moles[i] * frac;
            self.moles[i] -= m;
            removed.moles[i] = m;
        }
        removed
    }
}

pub fn calculate_darcy_weisbach_friction(reynolds: f64, roughness_m: f64, diameter_m: f64) -> f64 {
    if reynolds < 2300.0 {
        if reynolds <= 0.0 { return 0.064; }
        return 64.0 / reynolds;
    }
    let eps_d = roughness_m / diameter_m;
    let term1 = eps_d / 3.7;
    let term2 = 5.74 / reynolds.powf(0.9);
    let log_val = (term1 + term2).log10();
    0.25 / (log_val * log_val)
}

pub fn calculate_joukowsky_surge(density: f64, wave_speed: f64, delta_v: f64) -> f64 {
    density * wave_speed * delta_v.abs()
}

pub fn calculate_antoine_water_pressure_pa(temp_k: f64) -> f64 {
    let t = temp_k.clamp(273.0, 500.0);
    // log10(P_bar) = 4.6543 - 1435.264 / (T - 64.848)
    let exponent = 4.6543 - (1435.264 / (t - 64.848));
    let p_bar = 10.0_f64.powf(exponent);
    p_bar * 100000.0
}
