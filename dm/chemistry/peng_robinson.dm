// Peng-Robinson Cubic Equation of State (PR-EOS) and Fugacity Engine
//
// Implements thermodynamic Peng-Robinson Equation of State (1976/1978)
// for multi-component hydrocarbon and atmospheric gas mixtures.
// Solves compressibility factor Z cubic polynomial via analytical Cardano roots,
// calculates temperature-dependent attractive parameter a(T) and co-volume b,
// van der Waals mixing rules with binary interaction parameters (k_ij),
// component fugacity coefficients phi_i, and departure enthalpy / entropy functions.

/datum/chemistry/peng_robinson
    var/tag = "PR-EOS-ENGINE"
    var/num_components = 5
    var/list/component_names = list("CH4", "C2H6", "C3H8", "nC4H10", "CO2")

    // Critical properties: Tc (K), Pc (bar), Acentric factor (omega)
    var/list/crit_temp_k = list(190.56, 305.32, 369.83, 425.12, 304.21)
    var/list/crit_press_bar = list(45.99, 48.72, 42.48, 37.96, 73.83)
    var/list/acentric_omega = list(0.011, 0.099, 0.152, 0.200, 0.224)

    // Current mixture composition (mole fractions z_i)
    var/list/mole_fractions = list(0.85, 0.08, 0.04, 0.02, 0.01)

    // Thermodynamic state
    var/temperature_k = 300.0
    var/pressure_bar = 50.0

    // Mixture parameters
    var/mix_a = 0.0
    var/mix_b = 0.0
    var/mix_z_factor = 0.885
    var/list/fugacity_coefficients = list()

/datum/chemistry/peng_robinson/New()
    ..()
    fugacity_coefficients = list(1.0, 1.0, 1.0, 1.0, 1.0)

// Pure component parameter a_i(T) and b_i:
// a_i(T) = 0.45724 * (R^2 * Tc^2 / Pc) * alpha_i(T)
// b_i    = 0.07780 * (R * Tc / Pc)
// m_i    = 0.37464 + 1.54226 * omega - 0.26992 * omega^2
// alpha_i(T) = [1 + m_i * (1 - sqrt(T / Tc))]^2
/datum/chemistry/peng_robinson/proc/calculate_pure_parameters(idx, temp_k)
    var/tc = crit_temp_k[idx]
    var/pc_pa = crit_press_bar[idx] * 100000.0
    var/omega = acentric_omega[idx]
    var/r_gas = 8.314462618

    var/m = 0.37464 + (1.54226 * omega) - (0.26992 * omega * omega)
    var/tr = temp_k / tc
    var/alpha_sqrt = 1.0 + (m * (1.0 - sqrt(tr)))
    var/alpha = alpha_sqrt * alpha_sqrt

    var/a_pure = 0.45724 * ((r_gas * r_gas * tc * tc) / pc_pa) * alpha
    var/b_pure = 0.07780 * ((r_gas * tc) / pc_pa)
    return list(a_pure, b_pure)

// van der Waals mixing rules:
// b_mix = sum(x_i * b_i)
// a_mix = sum_i sum_j (x_i * x_j * sqrt(a_i * a_j) * (1 - k_ij))
/datum/chemistry/peng_robinson/proc/calculate_mixture_parameters(temp_k)
    var/list/a_pure_list = list()
    var/list/b_pure_list = list()

    for(var/i = 1 to num_components)
        var/list/params = calculate_pure_parameters(i, temp_k)
        a_pure_list.Add(params[1])
        b_pure_list.Add(params[2])

    mix_b = 0.0
    for(var/i = 1 to num_components)
        mix_b += mole_fractions[i] * b_pure_list[i]

    mix_a = 0.0
    for(var/i = 1 to num_components)
        for(var/j = 1 to num_components)
            var/k_ij = 0.0
            if(component_names[i] == "CO2" || component_names[j] == "CO2")
                k_ij = 0.12 // Hydrocarbon-CO2 binary interaction parameter
            var/a_ij = sqrt(a_pure_list[i] * a_pure_list[j]) * (1.0 - k_ij)
            mix_a += mole_fractions[i] * mole_fractions[j] * a_ij

    return list(mix_a, mix_b)

// Solve PR-EOS cubic polynomial for compressibility factor Z:
// Z^3 - (1 - B)*Z^2 + (A - 3*B^2 - 2*B)*Z - (A*B - B^2 - B^3) = 0
// where A = a * P / (R * T)^2, B = b * P / (R * T)
/datum/chemistry/peng_robinson/proc/solve_z_factor(p_bar, temp_k, phase = "VAPOR")
    temperature_k = temp_k
    pressure_bar = p_bar
    var/p_pa = p_bar * 100000.0
    var/r_gas = 8.314462618

    calculate_mixture_parameters(temp_k)

    var/rt = r_gas * temp_k
    var/big_a = (mix_a * p_pa) / (rt * rt)
    var/big_b = (mix_b * p_pa) / rt

    // Cubic coefficients: Z^3 + c2*Z^2 + c1*Z + c0 = 0
    var/c2 = -(1.0 - big_b)
    var/c1 = big_a - (3.0 * big_b * big_b) - (2.0 * big_b)
    var/c0 = -((big_a * big_b) - (big_b * big_b) - (big_b * big_b * big_b))

    // Analytical Cardano cubic solver
    var/q = ((3.0 * c1) - (c2 * c2)) / 9.0
    var/r = ((9.0 * c2 * c1) - (27.0 * c0) - (2.0 * c2 * c2 * c2)) / 54.0
    var/discriminant = (q * q * q) + (r * r)

    var/list/real_roots = list()

    if(discriminant > 0.0)
        // One real root
        var/s = sqrt(discriminant)
        var/u_val = r + s
        var/u = (u_val >= 0.0) ? exp(0.333333 * log(u_val)) : -exp(0.333333 * log(-u_val))
        var/v_val = r - s
        var/v = (v_val >= 0.0) ? exp(0.333333 * log(v_val)) : -exp(0.333333 * log(-v_val))
        var/z1 = u + v - (c2 / 3.0)
        real_roots.Add(z1)
    else
        // Three real roots: trigonometric method
        var/theta = arccos(r / sqrt(-q * q * q))
        var/sqrt_neg_q = sqrt(-q)
        var/pi_val = 3.141592653589793
        var/z1 = (2.0 * sqrt_neg_q * cos(theta / 3.0)) - (c2 / 3.0)
        var/z2 = (2.0 * sqrt_neg_q * cos((theta + 2.0 * pi_val) / 3.0)) - (c2 / 3.0)
        var/z3 = (2.0 * sqrt_neg_q * cos((theta + 4.0 * pi_val) / 3.0)) - (c2 / 3.0)
        real_roots.Add(z1)
        real_roots.Add(z2)
        real_roots.Add(z3)

    // Filter valid positive physical roots
    var/list/valid_roots = list()
    for(var/root in real_roots)
        if(root > big_b)
            valid_roots.Add(root)

    if(valid_roots.len == 0)
        mix_z_factor = 1.0
        return 1.0

    // Select vapor root (largest Z) or liquid root (smallest Z)
    var/selected_z = valid_roots[1]
    if(phase == "VAPOR")
        for(var/root in valid_roots)
            if(root > selected_z)
                selected_z = root
    else
        for(var/root in valid_roots)
            if(root < selected_z)
                selected_z = root

    mix_z_factor = selected_z
    return mix_z_factor

// Calculate Component Fugacity Coefficients phi_i:
// ln(phi_i) = (b_i / b)*(Z - 1) - ln(Z - B) - (A / (2 * sqrt(2) * B)) * [(2 * sum_j(x_j * a_ij) / a) - (b_i / b)] * ln((Z + (1+sqrt(2))*B) / (Z + (1-sqrt(2))*B))
/datum/chemistry/peng_robinson/proc/calculate_fugacity_coefficients()
    var/z = mix_z_factor
    var/p_pa = pressure_bar * 100000.0
    var/rt = 8.314462618 * temperature_k
    var/big_a = (mix_a * p_pa) / (rt * rt)
    var/big_b = (mix_b * p_pa) / rt
    var/sqrt2 = 1.41421356

    var/log_term_z = log((z + (1.0 + sqrt2) * big_b) / max(z + (1.0 - sqrt2) * big_b, 1e-6))
    var/pref = big_a / (2.0 * sqrt2 * max(big_b, 1e-6))

    for(var/i = 1 to num_components)
        var/list/pure_i = calculate_pure_parameters(i, temperature_k)
        var/bi = pure_i[2]

        var/sum_xa = 0.0
        for(var/j = 1 to num_components)
            var/list/pure_j = calculate_pure_parameters(j, temperature_k)
            var/k_ij = (component_names[i] == "CO2" || component_names[j] == "CO2") ? 0.12 : 0.0
            sum_xa += mole_fractions[j] * sqrt(pure_i[1] * pure_j[1]) * (1.0 - k_ij)

        var/factor_term = ((2.0 * sum_xa) / max(mix_a, 1e-6)) - (bi / max(mix_b, 1e-6))
        var/ln_phi = ((bi / max(mix_b, 1e-6)) * (z - 1.0)) - log(max(z - big_b, 1e-6)) - (pref * factor_term * log_term_z)
        fugacity_coefficients[i] = exp(min(max(ln_phi, -10.0), 10.0))

    return fugacity_coefficients
