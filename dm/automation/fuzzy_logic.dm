// Takagi-Sugeno and Mamdani Fuzzy Logic Inference Systems (FIS)
//
// Implements non-linear fuzzy logic control for burner temperature and pH neutralization.
// Formulates triangular and trapezoidal membership functions (fuzzification),
// multi-antecedent rule base evaluation with min-max T-norm / S-norm operations,
// and Center of Gravity (Centroid) defuzzification for smooth, chatter-free control.

/datum/automation/fuzzy_controller
    var/tag = "FIS-TEMPERATURE-TUNER"
    var/error_range = 20.0
    var/delta_error_range = 5.0
    var/output_range = 100.0

    // Consequent singleton values for 5 fuzzy sets: NB, NS, ZE, PS, PB
    var/list/singleton_outputs = list(-50.0, -20.0, 0.0, 20.0, 50.0)

/datum/automation/fuzzy_controller/New()
    ..()

// Triangular membership function: returns degree of membership in [0, 1]
/datum/automation/fuzzy_controller/proc/triangular_mf(x, a, b, c)
    if(x <= a || x >= c)
        return 0.0
    if(x == b)
        return 1.0
    if(x < b)
        return (x - a) / (b - a)
    return (c - x) / (c - b)

// Trapezoidal membership function
/datum/automation/fuzzy_controller/proc/trapezoidal_mf(x, a, b, c, d)
    if(x <= a || x >= d)
        return 0.0
    if(x >= b && x <= c)
        return 1.0
    if(x < b)
        return (x - a) / (b - a)
    return (d - x) / (d - c)

// Fuzzify input into 5 linguistic fuzzy sets: [NB, NS, ZE, PS, PB]
/datum/automation/fuzzy_controller/proc/fuzzify_variable(val, range_span)
    var/list/mu = list()
    var/r = range_span

    // NB (Negative Big): Trapezoid left
    mu.Add(trapezoidal_mf(val, -9999.0, -9999.0, -r, -0.5 * r))
    // NS (Negative Small): Triangle
    mu.Add(triangular_mf(val, -r, -0.5 * r, 0.0))
    // ZE (Zero): Triangle centered at 0
    mu.Add(triangular_mf(val, -0.5 * r, 0.0, 0.5 * r))
    // PS (Positive Small): Triangle
    mu.Add(triangular_mf(val, 0.0, 0.5 * r, r))
    // PB (Positive Big): Trapezoid right
    mu.Add(trapezoidal_mf(val, 0.5 * r, r, 9999.0, 9999.0))

    return mu

// Evaluate 5x5 Fuzzy Rule Base and compute crisp defuzzified control move
/datum/automation/fuzzy_controller/proc/evaluate_fuzzy(error_e, delta_e)
    var/list/mu_e = fuzzify_variable(error_e, error_range)
    var/list/mu_de = fuzzify_variable(delta_e, delta_error_range)

    var/numerator = 0.0
    var/denominator = 0.0

    // Standard MacVicar-Whelan 5x5 diagonal rule matrix:
    // e \ de | NB  NS  ZE  PS  PB
    // -------+-------------------
    // NB     | NB  NB  NB  NS  ZE
    // NS     | NB  NB  NS  ZE  PS
    // ZE     | NB  NS  ZE  PS  PB
    // PS     | NS  ZE  PS  PB  PB
    // PB     | ZE  PS  PB  PB  PB
    // Mapping: 1=NB, 2=NS, 3=ZE, 4=PS, 5=PB
    var/list/rule_matrix = list(
        1, 1, 1, 2, 3,
        1, 1, 2, 3, 4,
        1, 2, 3, 4, 5,
        2, 3, 4, 5, 5,
        3, 4, 5, 5, 5
    )

    for(var/i = 1 to 5)
        for(var/j = 1 to 5)
            // Min T-norm for AND premise
            var/weight = min(mu_e[i], mu_de[j])
            if(weight > 1e-4)
                var/rule_idx = (i - 1) * 5 + j
                var/consequent_set = rule_matrix[rule_idx]
                var/crisp_z = singleton_outputs[consequent_set]

                numerator += weight * crisp_z
                denominator += weight

    if(denominator <= 1e-5)
        return 0.0

    // Center of Gravity / Weighted Average
    var/crisp_output = numerator / denominator
    return crisp_output
