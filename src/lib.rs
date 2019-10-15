//! Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
//!
//! A high-performance, deterministic execution engine and validation runtime
//! for Dream Maker (DM) cyber-physical process models, atmospheric thermodynamics,
//! microgrid power networks, and industrial control systems (ICS/SCADA).

pub mod dm_parser;
pub mod thermo;
pub mod microgrid;
pub mod automation;
pub mod robotics;
pub mod simulator;
pub mod tui;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const PROJECT_NAME: &str = "Plenum";
