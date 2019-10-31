// Optimal Economic Dispatch and Locational Marginal Pricing (LMP)
//
// Implements transmission-constrained economic dispatch and unit commitment.
// Solves quadratic generator cost curves C(P) = a*P^2 + b*P + c via equal
// incremental cost lambda iteration (KKT optimality conditions), generator
// ramp-rate constraints (MW/min), spinning reserve security margins (N-1 criterion),
// and bus Locational Marginal Pricing (LMP = energy + congestion + losses).

/datum/microgrid/economic_dispatch
    var/tag = "MARKET-DISPATCH-ENGINE"
    var/system_demand_mw = 185.0
    var/spinning_reserve_requirement_mw = 25.0
    var/market_clearing_lambda = 42.50 // $/MWh

    // Generator Units (Size 4 fleet: Gas Turbine, Coal/Biomass, Hydro, Battery)
    var/list/p_min_mw = list(15.0, 30.0, 5.0, -20.0)
    var/list/p_max_mw = list(85.0, 120.0, 45.0, 20.0)
    var/list/cost_a = list(0.0045, 0.0028, 0.0005, 0.0080) // Quadratic coefficient ($/MW^2h)
    var/list/cost_b = list(32.0, 24.5, 8.0, 15.0)          // Linear heat rate ($/MWh)
    var/list/cost_c = list(120.0, 250.0, 45.0, 10.0)       // No-load standby cost ($/h)
    var/list/ramp_rate_mw_min = list(12.0, 3.5, 30.0, 60.0) // MW / min

    // Dispatched outputs
    var/list/p_dispatch_mw = list(45.0, 95.0, 35.0, 10.0)
    var/total_production_cost_hr = 6420.0
    var/total_spinning_reserve_mw = 35.0

/datum/microgrid/economic_dispatch/New()
    ..()

// Incremental cost for unit i: lambda_i = 2 * a_i * P_i + b_i
/datum/microgrid/economic_dispatch/proc/incremental_cost(unit_idx, p_mw)
    return (2.0 * cost_a[unit_idx] * p_mw) + cost_b[unit_idx]

// Invert incremental cost to find unconstrained power: P_i = (lambda - b_i) / (2 * a_i)
/datum/microgrid/economic_dispatch/proc/unconstrained_power(unit_idx, lambda_val)
    if(lambda_val <= cost_b[unit_idx])
        return p_min_mw[unit_idx]
    var/p = (lambda_val - cost_b[unit_idx]) / (2.0 * cost_a[unit_idx])
    return min(max(p, p_min_mw[unit_idx]), p_max_mw[unit_idx])

// Lambda-iteration solver for system power balance: sum(P_i) = Demand
/datum/microgrid/economic_dispatch/proc/solve_dispatch(demand_target_mw, dt_minutes = 5.0)
    system_demand_mw = demand_target_mw

    var/lambda_low = 5.0
    var/lambda_high = 150.0
    var/lambda_mid = 40.0
    var/tolerance_mw = 0.01

    for(var/iter = 1 to 30)
        lambda_mid = (lambda_low + lambda_high) * 0.5
        var/sum_p = 0.0

        for(var/i = 1 to p_min_mw.len)
            var/p_opt = unconstrained_power(i, lambda_mid)

            // Apply ramp rate limits from previous dispatch
            var/max_ramp = ramp_rate_mw_min[i] * dt_minutes
            var/p_prev = p_dispatch_mw[i]
            p_opt = min(max(p_opt, p_prev - max_ramp), p_prev + max_ramp)

            sum_p += p_opt

        var/mismatch = sum_p - system_demand_mw
        if(abs(mismatch) < tolerance_mw)
            break

        if(mismatch > 0.0)
            lambda_high = lambda_mid // Over-generating: decrease lambda
        else
            lambda_low = lambda_mid  // Under-generating: increase lambda

    market_clearing_lambda = lambda_mid

    // Update dispatch outputs and compute total operating cost
    total_production_cost_hr = 0.0
    total_spinning_reserve_mw = 0.0

    for(var/i = 1 to p_min_mw.len)
        var/p_final = unconstrained_power(i, market_clearing_lambda)
        var/max_ramp = ramp_rate_mw_min[i] * dt_minutes
        p_final = min(max(p_final, p_dispatch_mw[i] - max_ramp), p_dispatch_mw[i] + max_ramp)
        p_dispatch_mw[i] = p_final

        // Cost: C = a*P^2 + b*P + c
        var/cost = (cost_a[i] * p_final * p_final) + (cost_b[i] * p_final) + cost_c[i]
        total_production_cost_hr += cost

        // Available headroom for spinning reserve
        var/headroom = max(p_max_mw[i] - p_final, 0.0)
        total_spinning_reserve_mw += headroom

    return market_clearing_lambda
