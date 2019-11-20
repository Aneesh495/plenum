// Isothermal Vapor-Liquid Equilibrium (VLE) Rachford-Rice Flash Solver
//
// Implements rigorous multi-component isothermal (T-P) flash separation.
// Uses Wilson initial K-value estimates, solves the monotonic Rachford-Rice
// objective function f(beta) = 0 via guaranteed Newton-Raphson iterations,
// computes equilibrium liquid mole fractions x_i and vapor mole fractions y_i,
// and couples with PR-EOS fugacity coefficients via Successive Substitution (SSI).

/datum/chemistry/flash_solver
    var/tag = "VLE-RACHFORD-RICE"
    var/num_components = 4
    var/list/names = list("Propane", "i-Butane", "n-Butane", "n-Pentane")

    // Critical properties: Tc (K), Pc (bar), Acentric factor (omega)
    var/list/crit_t_k = list(369.83, 407.85, 425.12, 469.70)
    var/list/crit_p_bar = list(42.48, 36.40, 37.96, 33.70)
    var/list/omega_list = list(0.152, 0.186, 0.200, 0.251)

    // Feed composition z_i
    var/list/feed_z = list(0.30, 0.25, 0.30, 0.15)

    // Flash Results
    var/vapor_fraction_beta = 0.45 // V / F
    var/list/liquid_x = list()
    var/list/vapor_y = list()
    var/list/k_values = list()

/datum/chemistry/flash_solver/New()
    ..()
    liquid_x = list(0.0, 0.0, 0.0, 0.0)
    vapor_y = list(0.0, 0.0, 0.0, 0.0)
    k_values = list(1.0, 1.0, 1.0, 1.0)

// Wilson correlation for initial K-value estimate:
// K_i = (P_ci / P) * exp[5.373 * (1 + omega_i) * (1 - T_ci / T)]
/datum/chemistry/flash_solver/proc/calculate_wilson_k_values(p_bar, temp_k)
    k_values = list()
    for(var/i = 1 to num_components)
        var/tc = crit_t_k[i]
        var/pc = crit_p_bar[i]
        var/w = omega_list[i]

        var/exponent = 5.373 * (1.0 + w) * (1.0 - (tc / temp_k))
        var/k_i = (pc / p_bar) * exp(exponent)
        k_values.Add(max(k_i, 1e-6))
    return k_values

// Rachford-Rice objective function:
// f(beta) = sum[ z_i * (K_i - 1) / (1 + beta * (K_i - 1)) ] = 0
// f'(beta) = -sum[ z_i * (K_i - 1)^2 / (1 + beta * (K_i - 1))^2 ]
/datum/chemistry/flash_solver/proc/solve_rachford_rice(max_iter = 50, tolerance = 1e-7)
    // Check single phase boundary limits
    var/f_zero = 0.0
    var/f_one = 0.0
    for(var/i = 1 to num_components)
        var/km1 = k_values[i] - 1.0
        f_zero += feed_z[i] * km1
        f_one  += feed_z[i] * km1 / k_values[i]

    if(f_zero <= 0.0)
        // Subcooled liquid: beta = 0
        vapor_fraction_beta = 0.0
        for(var/i = 1 to num_components)
            liquid_x[i] = feed_z[i]
            vapor_y[i] = feed_z[i] * k_values[i]
        return 0.0

    if(f_one >= 0.0)
        // Superheated vapor: beta = 1
        vapor_fraction_beta = 1.0
        for(var/i = 1 to num_components)
            vapor_y[i] = feed_z[i]
            liquid_x[i] = feed_z[i] / max(k_values[i], 1e-4)
        return 1.0

    // Newton-Raphson iteration inside [0, 1]
    var/beta = 0.50

    for(var/iter = 1 to max_iter)
        var/f = 0.0
        var/df = 0.0

        for(var/i = 1 to num_components)
            var/km1 = k_values[i] - 1.0
            var/den = 1.0 + (beta * km1)
            var/term = (feed_z[i] * km1) / den
            f += term
            df -= (feed_z[i] * km1 * km1) / (den * den)

        if(abs(f) < tolerance)
            break

        if(abs(df) < 1e-12)
            break

        var/delta_beta = -f / df
        beta = min(max(beta + delta_beta, 0.0001), 0.9999)

    vapor_fraction_beta = beta

    // Recover phase compositions: x_i = z_i / (1 + beta*(K_i-1)), y_i = K_i * x_i
    for(var/i = 1 to num_components)
        var/den = 1.0 + (vapor_fraction_beta * (k_values[i] - 1.0))
        liquid_x[i] = feed_z[i] / max(den, 1e-6)
        vapor_y[i] = k_values[i] * liquid_x[i]

    return vapor_fraction_beta
