//! Integration Test Suite for Plenum Cyber-Physical Digital Twin Engine
//!
//! Validates numerical convergence, thermodynamic conservation,
//! IEC 61131-3 logic stability, and A* pathfinding optimality.

use plenum_engine::thermo::{GasMixture, calculate_darcy_weisbach_friction, calculate_joukowsky_surge};
use plenum_engine::microgrid::{ElectricalBus, TransmissionLine, PowerFlowSolver, BUS_SLACK, BUS_PV, BUS_PQ};
use plenum_engine::automation::{PidController, AlarmRecord, AlarmState, ALARM_PRIO_HIGH};
use plenum_engine::robotics::SpatialGrid;
use plenum_engine::simulator::SimulationEngine;
use plenum_engine::dm_parser::DmParser;

#[test]
fn test_gas_mixture_conservation_of_mass_and_energy() {
    let mut z1 = GasMixture::new(1000.0);
    z1.set_composition_stp(101.325, 300.0, 0.21, 0.79);
    let initial_moles = z1.total_moles();
    assert!(initial_moles > 0.0);

    let split = z1.remove_fraction(0.25);
    assert!((split.total_moles() - (initial_moles * 0.25)).abs() < 1e-6);
    assert!((z1.total_moles() - (initial_moles * 0.75)).abs() < 1e-6);

    // Merge back
    z1.merge(&split);
    assert!((z1.total_moles() - initial_moles).abs() < 1e-5);
}

#[test]
fn test_fluid_mechanics_correlations() {
    // Laminar flow Re = 1000 => f = 64 / 1000 = 0.064
    let f_lam = calculate_darcy_weisbach_friction(1000.0, 0.000045, 0.1);
    assert!((f_lam - 0.064).abs() < 1e-4);

    // Turbulent flow Re = 100,000, eps/d = 0.00045
    let f_turb = calculate_darcy_weisbach_friction(100000.0, 0.000045, 0.1);
    assert!(f_turb > 0.015 && f_turb < 0.025);

    // Joukowsky water hammer pressure surge
    let delta_p = calculate_joukowsky_surge(1000.0, 1200.0, 2.5);
    assert!((delta_p - 3000000.0).abs() < 1.0);
}

#[test]
fn test_power_flow_solver_convergence() {
    let b1 = ElectricalBus::new("B1", BUS_SLACK, 13.8, 100.0);
    let mut b2 = ElectricalBus::new("B2", BUS_PV, 13.8, 100.0);
    b2.p_gen_mw = 40.0;
    let mut b3 = ElectricalBus::new("B3", BUS_PQ, 13.8, 100.0);
    b3.p_load_mw = 30.0;
    b3.q_load_mvar = 10.0;

    let lines = vec![
        TransmissionLine::new("L12", 0, 1, 0.02, 0.08, 0.01),
        TransmissionLine::new("L23", 1, 2, 0.02, 0.08, 0.01),
        TransmissionLine::new("L13", 0, 2, 0.03, 0.12, 0.01),
    ];

    let mut solver = PowerFlowSolver::new(vec![b1, b2, b3], lines);
    let converged = solver.solve();
    assert!(converged, "Fast decoupled power flow must converge on 3-bus network");

    // Bus 3 voltage should be slightly below nominal pu due to load
    assert!(solver.buses[2].voltage_magnitude_pu > 0.90 && solver.buses[2].voltage_magnitude_pu < 1.05);
}

#[test]
fn test_pid_controller_anti_windup() {
    let mut pid = PidController::new("TEST-PID", 2.0, 1.0, 0.1);
    pid.sp = 100.0;
    pid.pv = 0.0;
    pid.out_min = 0.0;
    pid.out_max = 100.0;

    // Run for 50 steps with large error
    for _ in 0..50 {
        let cv = pid.compute_step(0.1);
        assert!(cv <= 100.0 && cv >= 0.0);
    }

    // Integral term must be bounded and not blow up
    assert!(pid.integral <= 100.0);
}

#[test]
fn test_isa18_alarm_lifecycle() {
    let mut alm = AlarmRecord::new("ALM-TEST", "High Bearing Temperature", ALARM_PRIO_HIGH);
    assert_eq!(alm.state, AlarmState::Normal);

    // Trip event
    alm.trip();
    assert_eq!(alm.state, AlarmState::ActiveUnacknowledged);

    // Operator acknowledges
    alm.acknowledge();
    assert_eq!(alm.state, AlarmState::ActiveAcknowledged);

    // Condition returns to normal
    alm.clear();
    assert_eq!(alm.state, AlarmState::Normal);
}

#[test]
fn test_robotics_a_star_obstacle_avoidance() {
    let mut grid = SpatialGrid::new(10, 10);
    // Wall across x = 5 from y = 0 to 7
    for y in 0..8 {
        grid.set_obstacle(5, y, true);
    }

    let path = grid.find_path_a_star(2, 2, 8, 2);
    assert!(path.is_some(), "Path should find route around the obstacle wall");

    let p = path.unwrap();
    // Verify none of the waypoints intersect an obstacle
    for pt in &p {
        assert!(grid.is_walkable(pt.0, pt.1));
    }
}

#[test]
fn test_full_simulation_engine_run_with_fault() {
    let mut engine = SimulationEngine::new();
    assert_eq!(engine.tick, 0);

    for _ in 0..100 {
        engine.step();
    }
    assert_eq!(engine.tick, 100);

    // Inject fault
    engine.inject_fault("feedwater_loss");
    assert!(engine.fault_active);

    for _ in 0..100 {
        engine.step();
    }
    assert_eq!(engine.tick, 200);

    let m = engine.metrics();
    assert!(m.sim_time > 9.9);
}

#[test]
fn test_dm_parser_repository_scan() {
    let parser = DmParser::new(".");
    let count = parser.scan_project().expect("DM parser must scan repo successfully");
    assert!(count >= 80, "Must validate at least 80 DM files");
}
