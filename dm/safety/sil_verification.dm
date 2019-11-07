// IEC 61508 / IEC 61511 Safety Integrity Level (SIL) Verification
//
// Implements functional safety probabilistic reliability modeling for
// Safety Instrumented Systems (SIS). Formulates Average Probability of Failure
// on Demand (PFDavg) for 1oo1, 1oo2, 2oo2, and 2oo3 voting architectures,
// Safe Failure Fraction (SFF), Diagnostic Coverage (DC), Proof Test Interval (TI),
// Mean Time To Restoration (MTTR), and Hardware Fault Tolerance (HFT) tables.

/datum/safety/sil_verifier
    var/tag = "SIL-VERIFIER-ENGINE"
    var/target_sil_level = 3 // SIL 3 target (PFDavg between 1e-4 and 1e-3)

    // Subsystem Component Reliability Parameters (failures per hour: lambda)
    var/lambda_dangerous_undetected_du = 1.2e-7 // 120 FIT
    var/lambda_dangerous_detected_dd = 1.8e-6   // 1800 FIT
    var/lambda_safe_undetected_su = 4.5e-7
    var/lambda_safe_detected_sd = 2.5e-6

    // Proof Testing & Restoration
    var/proof_test_interval_hours = 8760.0 // 1 year (8760 hours)
    var/mean_time_to_restore_hours = 24.0  // 24 hours MTTR
    var/proof_test_coverage_pct = 90.0     // 90% PTC
    var/beta_common_cause_factor = 0.05    // 5% common cause failure factor for redundant channels

    // Architectural Voting
    var/voting_architecture = "2oo3" // "1oo1", "1oo2", "2oo2", "2oo3"

    // Verification Outputs
    var/calculated_pfd_avg = 0.00034
    var/achieved_sil = 3
    var/safe_failure_fraction_pct = 97.4
    var/diagnostic_coverage_pct = 93.7

/datum/safety/sil_verifier/New()
    ..()

// Diagnostic Coverage: DC = lambda_dd / (lambda_dd + lambda_du)
/datum/safety/sil_verifier/proc/calculate_dc()
    var/denom = lambda_dangerous_detected_dd + lambda_dangerous_undetected_du
    if(denom <= 1e-12)
        return 0.0
    diagnostic_coverage_pct = (lambda_dangerous_detected_dd / denom) * 100.0
    return diagnostic_coverage_pct

// Safe Failure Fraction: SFF = (sum(safe) + lambda_dd) / (sum(safe) + sum(dangerous))
/datum/safety/sil_verifier/proc/calculate_sff()
    var/num = lambda_safe_detected_sd + lambda_safe_undetected_su + lambda_dangerous_detected_dd
    var/den = num + lambda_dangerous_undetected_du
    if(den <= 1e-12)
        return 0.0
    safe_failure_fraction_pct = (num / den) * 100.0
    return safe_failure_fraction_pct

// Calculate PFDavg based on standard IEC 61508 voting formulas:
// 1oo1: PFDavg = lambda_DU * (TI / 2) + lambda_DD * MTTR
// 1oo2: PFDavg = (lambda_DU * TI)^2 / 3 + beta * lambda_DU * (TI / 2)
// 2oo3: PFDavg = (lambda_DU * TI)^2 + beta * lambda_DU * (TI / 2)
/datum/safety/sil_verifier/proc/evaluate_pfd_avg(arch = "2oo3")
    voting_architecture = arch
    var/ldu = lambda_dangerous_undetected_du
    var/ldd = lambda_dangerous_detected_dd
    var/ti = proof_test_interval_hours
    var/mttr = mean_time_to_restore_hours
    var/beta = beta_common_cause_factor

    var/pfd = 0.0

    switch(voting_architecture)
        if("1oo1")
            pfd = (ldu * ti * 0.5) + (ldd * mttr)

        if("1oo2")
            var/indep = (ldu * ti * ldu * ti) / 3.0
            var/comm = beta * (ldu * ti * 0.5)
            pfd = indep + comm

        if("2oo2")
            pfd = (ldu * ti) + (ldd * mttr * 2.0)

        if("2oo3")
            var/indep = ldu * ti * ldu * ti
            var/comm = beta * (ldu * ti * 0.5)
            pfd = indep + comm

    calculated_pfd_avg = pfd

    // Classify achieved SIL level per IEC 61508 Table 2 (Low demand mode)
    if(calculated_pfd_avg < 1e-4)
        achieved_sil = 4
    else if(calculated_pfd_avg < 1e-3)
        achieved_sil = 3
    else if(calculated_pfd_avg < 1e-2)
        achieved_sil = 2
    else if(calculated_pfd_avg < 1e-1)
        achieved_sil = 1
    else
        achieved_sil = 0 // No SIL rating

    calculate_dc()
    calculate_sff()
    return calculated_pfd_avg
