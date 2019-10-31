// Harmonic Power Flow, IEEE 519 Compliance, and Tuned LC Filters
//
// Implements electrical network harmonic distortion analysis and mitigation.
// Models harmonic spectrum injection from 6-pulse / 12-pulse variable frequency
// drives (VFD) and arc furnaces (h = 5, 7, 11, 13, 17, 19), Total Harmonic
// Distortion (THD_V and TDD_I per IEEE 519 standard), parallel resonance impedance
// scan, and shunt single-tuned passive LC harmonic filter notch design.

/datum/microgrid/harmonics
    var/tag = "HARMONIC-FILTER-STATION"
    var/fundamental_freq_hz = 60.0
    var/nominal_voltage_kv = 13.8

    // Harmonic Orders Analyzed: h = [1, 5, 7, 11, 13]
    var/list/harmonic_orders = list(1, 5, 7, 11, 13)
    var/list/voltage_magnitudes_v = list(13800.0, 420.0, 310.0, 180.0, 125.0)
    var/list/current_injections_a = list(450.0, 68.0, 42.0, 24.0, 18.0)

    // IEEE 519 Distortion Metrics
    var/thd_voltage_pct = 3.98 // IEEE 519 limit < 5.0%
    var/tdd_current_pct = 6.25 // Limit < 8.0%
    var/ieee_519_violation = 0

    // Passive 5th Harmonic Shunt Filter (h = 5, f = 300 Hz)
    var/filter_in_service = 1
    var/filter_mvar_rating = 2.5
    var/filter_capacitance_uf = 34.8
    var/filter_inductance_mh = 8.1
    var/filter_quality_factor_q = 45.0

/datum/microgrid/harmonics/New()
    ..()

// Total Harmonic Distortion for Voltage:
// THD_V = sqrt(sum(V_h^2, h=2..N)) / V_1 * 100%
/datum/microgrid/harmonics/proc/calculate_thd_voltage()
    var/v1 = voltage_magnitudes_v[1]
    if(v1 <= 1.0)
        return 0.0

    var/sum_sq = 0.0
    for(var/i = 2 to voltage_magnitudes_v.len)
        var/vh = voltage_magnitudes_v[i]
        sum_sq += vh * vh

    thd_voltage_pct = (sqrt(sum_sq) / v1) * 100.0
    return thd_voltage_pct

// Total Demand Distortion for Current (TDD_I per IEEE 519):
// TDD = sqrt(sum(I_h^2, h=2..N)) / I_load_max * 100%
/datum/microgrid/harmonics/proc/calculate_tdd_current(max_demand_current_a = 500.0)
    var/sum_sq = 0.0
    for(var/i = 2 to current_injections_a.len)
        var/ih = current_injections_a[i]
        sum_sq += ih * ih

    tdd_current_pct = (sqrt(sum_sq) / max(max_demand_current_a, 1.0)) * 100.0
    return tdd_current_pct

// LC Filter Notch Impedance:
// Z_filter(omega) = R + j * (omega * L - 1 / (omega * C))
/datum/microgrid/harmonics/proc/calculate_filter_impedance(order)
    var/omega = 2.0 * 3.14159 * fundamental_freq_hz * order
    var/l_henries = filter_inductance_mh * 0.001
    var/c_farads = filter_capacitance_uf * 1e-6
    var/xl = omega * l_henries
    var/xc = 1.0 / max(omega * c_farads, 1e-12)

    var/x_net = xl - xc
    var/r_res = (sqrt(l_henries / c_farads)) / max(filter_quality_factor_q, 1.0)
    return sqrt((r_res * r_res) + (x_net * x_net))

// Step harmonic evaluation and passive notch filter attenuation
/datum/microgrid/harmonics/proc/step_harmonics(dt_sec, vfd_load_multiplier = 1.0)
    // 1. Scale non-linear current injections with VFD load
    current_injections_a[2] = 68.0 * vfd_load_multiplier // 5th harmonic
    current_injections_a[3] = 42.0 * vfd_load_multiplier // 7th harmonic
    current_injections_a[4] = 24.0 * vfd_load_multiplier // 11th harmonic
    current_injections_a[5] = 18.0 * vfd_load_multiplier // 13th harmonic

    // 2. Bus harmonic voltages: V_h = I_h * |Z_grid(h) || Z_filter(h)|
    for(var/i = 2 to harmonic_orders.len)
        var/h = harmonic_orders[i]
        var/z_grid = 1.2 * h // Grid inductive reactance increases with frequency
        var/z_eff = z_grid

        if(filter_in_service && h == 5)
            // 5th harmonic tuned filter traps current
            var/z_filt = calculate_filter_impedance(h)
            z_eff = (z_grid * z_filt) / (z_grid + z_filt)

        voltage_magnitudes_v[i] = current_injections_a[i] * z_eff

    // 3. Compute IEEE 519 compliance
    calculate_thd_voltage()
    calculate_tdd_current(500.0)

    if(thd_voltage_pct > 5.0 || tdd_current_pct > 8.0)
        ieee_519_violation = 1
    else
        ieee_519_violation = 0
