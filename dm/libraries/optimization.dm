// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Non-Linear Optimization & Nelder-Mead Simplex
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_OPTIMIZATION_DM
#define PLENUM_LIBRARIES_OPTIMIZATION_DM

#include "../core/datum.dm"

/datum/objective_function
    var/parameter_dimension = 2

/datum/objective_function/proc/Evaluate(list/params)
    // Default: Sphere function f(x) = sum(x_i^2)
    var/sum = 0.0
    for(var/p in params)
        sum += p * p
    return sum

/datum/golden_section_search
    var/phi = 0.6180339887 // (sqrt(5) - 1) / 2

/datum/golden_section_search/proc/Minimize(datum/objective_function/obj, a, b, tol = 1.0e-5, max_iter = 50)
    var/c = b - phi * (b - a)
    var/d = a + phi * (b - a)

    var/list/pc = list(c)
    var/list/pd = list(d)
    var/fc = obj.Evaluate(pc)
    var/fd = obj.Evaluate(pd)

    for(var/iter = 1 to max_iter)
        if(abs(b - a) < tol)
            break
        if(fc < fd)
            b = d
            d = c
            fd = fc
            c = b - phi * (b - a)
            pc[1] = c
            fc = obj.Evaluate(pc)
        else
            a = c
            c = d
            fc = fd
            d = a + phi * (b - a)
            pd[1] = d
            fd = obj.Evaluate(pd)

    return (a + b) * 0.5

/datum/nelder_mead_simplex
    var/alpha_reflect = 1.0
    var/gamma_expand = 2.0
    var/rho_contract = 0.5
    var/sigma_shrink = 0.5
    var/max_iterations = 100
    var/tolerance = 1.0e-5

/datum/nelder_mead_simplex/proc/Minimize(datum/objective_function/obj, list/initial_guess)
    // N-dimensional Nelder-Mead Simplex optimization
    var/dim = initial_guess.len
    var/num_vertices = dim + 1
    
    // Construct simplex vertices
    var/list/simplex = list()
    simplex.len = num_vertices
    var/list/scores = list()
    scores.len = num_vertices

    simplex[1] = initial_guess.Copy()
    scores[1] = obj.Evaluate(simplex[1])

    for(var/i = 1 to dim)
        var/list/vertex = initial_guess.Copy()
        vertex[i] += (vertex[i] != 0.0) ? (0.05 * vertex[i]) : 0.00025
        simplex[i + 1] = vertex
        scores[i + 1] = obj.Evaluate(vertex)

    for(var/iter = 1 to max_iterations)
        // Sort simplex vertices by score ascending
        for(var/i = 1 to num_vertices)
            for(var/j = i + 1 to num_vertices)
                if(scores[j] < scores[i])
                    var/temp_score = scores[i]
                    scores[i] = scores[j]
                    scores[j] = temp_score
                    var/list/temp_v = simplex[i]
                    simplex[i] = simplex[j]
                    simplex[j] = temp_v

        // Check convergence on difference between best and worst
        if(abs(scores[num_vertices] - scores[1]) < tolerance)
            break

        // Compute centroid of all vertices except worst
        var/list/centroid = list()
        centroid.len = dim
        for(var/d = 1 to dim)
            centroid[d] = 0.0
            for(var/v = 1 to dim)
                var/list/vert = simplex[v]
                centroid[d] += vert[d]
            centroid[d] /= dim

        // Reflection
        var/list/worst = simplex[num_vertices]
        var/list/reflected = list()
        reflected.len = dim
        for(var/d = 1 to dim)
            reflected[d] = centroid[d] + alpha_reflect * (centroid[d] - worst[d])
        var/score_r = obj.Evaluate(reflected)

        if(scores[1] <= score_r && score_r < scores[dim])
            simplex[num_vertices] = reflected
            scores[num_vertices] = score_r
        else if(score_r < scores[1])
            // Expansion
            var/list/expanded = list()
            expanded.len = dim
            for(var/d = 1 to dim)
                expanded[d] = centroid[d] + gamma_expand * (reflected[d] - centroid[d])
            var/score_e = obj.Evaluate(expanded)
            if(score_e < score_r)
                simplex[num_vertices] = expanded
                scores[num_vertices] = score_e
            else
                simplex[num_vertices] = reflected
                scores[num_vertices] = score_r
        else
            // Contraction
            var/list/contracted = list()
            contracted.len = dim
            for(var/d = 1 to dim)
                contracted[d] = centroid[d] + rho_contract * (worst[d] - centroid[d])
            var/score_c = obj.Evaluate(contracted)
            if(score_c < scores[num_vertices])
                simplex[num_vertices] = contracted
                scores[num_vertices] = score_c
            else
                // Shrink
                var/list/best = simplex[1]
                for(var/v = 2 to num_vertices)
                    var/list/curr_v = simplex[v]
                    for(var/d = 1 to dim)
                        curr_v[d] = best[d] + sigma_shrink * (curr_v[d] - best[d])
                    scores[v] = obj.Evaluate(curr_v)

    return simplex[1] // Optimal parameter vector

#endif // PLENUM_LIBRARIES_OPTIMIZATION_DM
