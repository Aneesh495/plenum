// Universal Quasi-Chemical (UNIQUAC) Activity Coefficient Model
//
// Implements Abrams and Prausnitz UNIQUAC activity model for highly non-ideal
// polar, hydrogen-bonding, and azeotropic chemical mixtures (ethanol-water,
// acetone-chloroform, bio-fermentation broths). Decouples excess Gibbs free energy
// into combinatorial entropic size/shape effects (Staverman-Guggenheim lattice)
// and energetic residual local composition intermolecular interactions.

/datum/chemistry/uniquac
    var/tag = "UNIQUAC-VLE-MODEL"
    var/coordination_number_z = 10.0 // Lattice coordination number

    // Binary Ethanol (1) - Water (2) System
    // Pure component volume (r) and surface area (q) parameters
    var/r1 = 2.5755 // Ethanol
    var/q1 = 2.5880
    var/r2 = 0.9200 // Water
    var/q2 = 1.4000

    // Binary interaction energy parameters: Delta u_ij (cal/mol)
    var/u12 = -52.39  // Ethanol-Water
    var/u21 = 399.55  // Water-Ethanol

    // Activity coefficients
    var/gamma_1 = 1.0
    var/gamma_2 = 1.0

/datum/chemistry/uniquac/New()
    ..()

// Combinatorial parameter: l_i = (z/2) * (r_i - q_i) - (r_i - 1)
/datum/chemistry/uniquac/proc/calculate_l(r_val, q_val)
    return (0.5 * coordination_number_z * (r_val - q_val)) - (r_val - 1.0)

// Calculate liquid activity coefficients gamma_1 and gamma_2
/datum/chemistry/uniquac/proc/calculate_activity_coefficients(x1, temp_k)
    var/x2 = 1.0 - x1
    var/r_gas = 1.9872 // cal / (mol * K)

    // Segment volume fractions (Phi_i) and area fractions (theta_i)
    var/sum_rx = (x1 * r1) + (x2 * r2)
    var/phi1 = (x1 * r1) / max(sum_rx, 1e-6)
    var/phi2 = (x2 * r2) / max(sum_rx, 1e-6)

    var/sum_qx = (x1 * q1) + (x2 * q2)
    var/theta1 = (x1 * q1) / max(sum_qx, 1e-6)
    var/theta2 = (x2 * q2) / max(sum_qx, 1e-6)

    var/l1 = calculate_l(r1, q1)
    var/l2 = calculate_l(r2, q2)
    var/sum_lx = (x1 * l1) + (x2 * l2)

    // 1. Combinatorial Part:
    // ln(gamma_i_C) = ln(Phi_i/x_i) + (z/2)*q_i*ln(theta_i/Phi_i) + l_i - (Phi_i/x_i)*sum(x_j*l_j)
    var/ln_g1_c = 0.0
    var/ln_g2_c = 0.0

    if(x1 > 1e-6)
        var/term1_1 = log(phi1 / x1)
        var/term2_1 = 5.0 * q1 * log(theta1 / phi1)
        var/term3_1 = l1 - ((phi1 / x1) * sum_lx)
        ln_g1_c = term1_1 + term2_1 + term3_1

    if(x2 > 1e-6)
        var/term1_2 = log(phi2 / x2)
        var/term2_2 = 5.0 * q2 * log(theta2 / phi2)
        var/term3_2 = l2 - ((phi2 / x2) * sum_lx)
        ln_g2_c = term1_2 + term2_2 + term3_2

    // 2. Residual Part:
    // tau_ij = exp(-Delta_u_ij / (R * T))
    var/tau12 = exp(-u12 / (r_gas * temp_k))
    var/tau21 = exp(-u21 / (r_gas * temp_k))

    var/s1 = theta1 + (theta2 * tau21)
    var/s2 = (theta1 * tau12) + theta2

    // ln(gamma_1_R) = q1 * [1 - ln(s1) - (theta1/s1 + theta2*tau12/s2)]
    var/ln_g1_r = q1 * (1.0 - log(max(s1, 1e-6)) - ((theta1 / max(s1, 1e-6)) + ((theta2 * tau12) / max(s2, 1e-6))))
    var/ln_g2_r = q2 * (1.0 - log(max(s2, 1e-6)) - (((theta1 * tau21) / max(s1, 1e-6)) + (theta2 / max(s2, 1e-6))))

    gamma_1 = exp(min(max(ln_g1_c + ln_g1_r, -5.0), 5.0))
    gamma_2 = exp(min(max(ln_g2_c + ln_g2_r, -5.0), 5.0))
    return list(gamma_1, gamma_2)
