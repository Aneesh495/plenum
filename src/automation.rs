//! Industrial Automation, IEC 61131-3 PLC, PID and ISA 18.2 Alarms.

#[derive(Debug, Clone)]
pub struct PlcState {
    pub discrete_inputs: Vec<bool>,
    pub discrete_outputs: Vec<bool>,
    pub memory_flags: Vec<bool>,
    pub analog_inputs: Vec<f64>,
    pub analog_outputs: Vec<f64>,
    pub holding_registers: Vec<u16>,
}

impl Default for PlcState {
    fn default() -> Self {
        Self::new(256, 128)
    }
}

impl PlcState {
    pub fn new(num_discrete: usize, num_analog: usize) -> Self {
        Self {
            discrete_inputs: vec![false; num_discrete],
            discrete_outputs: vec![false; num_discrete],
            memory_flags: vec![false; num_discrete * 2],
            analog_inputs: vec![0.0; num_analog],
            analog_outputs: vec![0.0; num_analog],
            holding_registers: vec![0; num_discrete],
        }
    }
}

#[derive(Debug, Clone)]
pub struct PidController {
    pub tag: String,
    pub kp: f64,
    pub ti: f64,
    pub td: f64,
    pub sp: f64,
    pub pv: f64,
    pub out_min: f64,
    pub out_max: f64,
    pub integral: f64,
    pub last_pv: f64,
}

impl PidController {
    pub fn new(tag: &str, kp: f64, ti: f64, td: f64) -> Self {
        Self {
            tag: tag.to_string(),
            kp,
            ti: ti.max(0.001),
            td,
            sp: 50.0,
            pv: 50.0,
            out_min: 0.0,
            out_max: 100.0,
            integral: 0.0,
            last_pv: 50.0,
        }
    }

    pub fn compute_step(&mut self, dt: f64) -> f64 {
        let err = self.sp - self.pv;
        let p_term = self.kp * err;

        // Derivative on PV
        let d_pv = self.pv - self.last_pv;
        let d_term = -self.kp * self.td * (d_pv / dt.max(0.001));
        self.last_pv = self.pv;

        // Anti-reset windup clamping
        let unclipped = p_term + self.integral + d_term;
        if (unclipped < self.out_max || err < 0.0) && (unclipped > self.out_min || err > 0.0) {
            self.integral += (self.kp / self.ti) * err * dt;
        }

        let total = p_term + self.integral + d_term;
        total.clamp(self.out_min, self.out_max)
    }
}

pub const ALARM_PRIO_LOW: usize = 1;
pub const ALARM_PRIO_HIGH: usize = 2;
pub const ALARM_PRIO_CRITICAL: usize = 3;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AlarmState {
    Normal,
    ActiveUnacknowledged,
    ActiveAcknowledged,
    ClearedUnacknowledged,
}

#[derive(Debug, Clone)]
pub struct AlarmRecord {
    pub tag: String,
    pub description: String,
    pub priority: usize,
    pub state: AlarmState,
}

impl AlarmRecord {
    pub fn new(tag: &str, description: &str, priority: usize) -> Self {
        Self {
            tag: tag.to_string(),
            description: description.to_string(),
            priority,
            state: AlarmState::Normal,
        }
    }

    pub fn trip(&mut self) {
        self.state = AlarmState::ActiveUnacknowledged;
    }

    pub fn acknowledge(&mut self) {
        if self.state == AlarmState::ActiveUnacknowledged {
            self.state = AlarmState::ActiveAcknowledged;
        } else if self.state == AlarmState::ClearedUnacknowledged {
            self.state = AlarmState::Normal;
        }
    }

    pub fn clear(&mut self) {
        if self.state == AlarmState::ActiveUnacknowledged {
            self.state = AlarmState::ClearedUnacknowledged;
        } else {
            self.state = AlarmState::Normal;
        }
    }
}

#[derive(Debug, Clone)]
pub struct IsaAlarm {
    pub tag: String,
    pub state: AlarmState,
    pub setpoint: f64,
    pub deadband: f64,
}

impl IsaAlarm {
    pub fn new(tag: &str, sp: f64, db: f64) -> Self {
        Self {
            tag: tag.to_string(),
            state: AlarmState::Normal,
            setpoint: sp,
            deadband: db,
        }
    }

    pub fn evaluate(&mut self, pv: f64) -> AlarmState {
        let is_tripped = if self.state == AlarmState::Normal || self.state == AlarmState::ClearedUnacknowledged {
            pv >= self.setpoint
        } else {
            pv >= (self.setpoint - self.deadband)
        };

        match self.state {
            AlarmState::Normal => {
                if is_tripped {
                    self.state = AlarmState::ActiveUnacknowledged;
                }
            }
            AlarmState::ActiveUnacknowledged => {
                if !is_tripped {
                    self.state = AlarmState::ClearedUnacknowledged;
                }
            }
            AlarmState::ActiveAcknowledged => {
                if !is_tripped {
                    self.state = AlarmState::Normal;
                }
            }
            AlarmState::ClearedUnacknowledged => {
                if is_tripped {
                    self.state = AlarmState::ActiveUnacknowledged;
                }
            }
        }

        self.state
    }

    pub fn acknowledge(&mut self) {
        if self.state == AlarmState::ActiveUnacknowledged {
            self.state = AlarmState::ActiveAcknowledged;
        } else if self.state == AlarmState::ClearedUnacknowledged {
            self.state = AlarmState::Normal;
        }
    }
}
