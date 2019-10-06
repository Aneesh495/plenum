// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Monotonic Cubic Spline (PCHIP) & Bilinear Interpolation
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_INTERPOLATION_DM
#define PLENUM_LIBRARIES_INTERPOLATION_DM

#include "../core/datum.dm"

/datum/interpolator_1d
    var/list/x_points = list()
    var/list/y_points = list()
    var/list/slopes = list() // PCHIP derivatives d_i

/datum/interpolator_1d/proc/AddPoint(px, py)
    x_points += px
    y_points += py

/datum/interpolator_1d/proc/BuildPCHIP()
    // Piecewise Cubic Hermite Interpolating Polynomial (Preserves monotonicity)
    var/n = x_points.len
    if(n < 2) return
    slopes = list()
    slopes.len = n

    var/list/h = list()
    var/list/delta = list()
    h.len = n - 1
    delta.len = n - 1

    for(var/i = 1 to (n - 1))
        h[i] = x_points[i + 1] - x_points[i]
        delta[i] = (y_points[i + 1] - y_points[i]) / h[i]

    // Endpoint derivatives
    slopes[1] = delta[1]
    slopes[n] = delta[n - 1]

    // Interior derivatives: weighted harmonic mean of secant slopes
    for(var/i = 2 to (n - 1))
        if(delta[i - 1] * delta[i] > 0.0)
            var/w1 = 2.0 * h[i] + h[i - 1]
            var/w2 = h[i] + 2.0 * h[i - 1]
            slopes[i] = (w1 + w2) / ((w1 / delta[i - 1]) + (w2 / delta[i]))
        else
            slopes[i] = 0.0 // Extrema flat tangent

/datum/interpolator_1d/proc/Evaluate(qx)
    var/n = x_points.len
    if(n == 0) return 0.0
    if(qx <= x_points[1]) return y_points[1]
    if(qx >= x_points[n]) return y_points[n]

    // Binary search for interval [x_k, x_{k+1}]
    var/low = 1
    var/high = n - 1
    var/k = 1
    while(low <= high)
        var/mid = round((low + high) / 2)
        if(qx >= x_points[mid] && qx <= x_points[mid + 1])
            k = mid
            break
        else if(qx < x_points[mid])
            high = mid - 1
        else
            low = mid + 1

    var/h = x_points[k + 1] - x_points[k]
    var/t = (qx - x_points[k]) / h
    var/t2 = t * t
    var/t3 = t2 * t

    // Cubic Hermite basis functions
    var/h00 = (2.0 * t3) - (3.0 * t2) + 1.0
    var/h10 = t3 - (2.0 * t2) + t
    var/h01 = (-2.0 * t3) + (3.0 * t2)
    var/h11 = t3 - t2

    return (h00 * y_points[k]) + (h10 * h * slopes[k]) + (h01 * y_points[k + 1]) + (h11 * h * slopes[k + 1])

/datum/interpolator_2d
    var/list/x_grid = list()
    var/list/y_grid = list()
    var/datum/matrix_nd/z_values = null

/datum/interpolator_2d/proc/BilinearEvaluate(qx, qy)
    // 2D Bilinear Surface Interpolation
    if(!z_values) return 0.0
    var/nx = x_grid.len
    var/ny = y_grid.len
    if(nx < 2 || ny < 2) return 0.0

    // Clamp coordinates to grid
    var/cx = max(x_grid[1], min(x_grid[nx], qx))
    var/cy = max(y_grid[1], min(y_grid[ny], qy))

    var/i = 1
    while(i < nx - 1 && x_grid[i + 1] < cx) i++
    var/j = 1
    while(j < ny - 1 && y_grid[j + 1] < cy) j++

    var/x1 = x_grid[i]
    var/x2 = x_grid[i + 1]
    var/y1 = y_grid[j]
    var/y2 = y_grid[j + 1]

    var/tx = (cx - x1) / (x2 - x1)
    var/ty = (cy - y1) / (y2 - y1)

    var/q11 = z_values.Get(i, j)
    var/q21 = z_values.Get(i + 1, j)
    var/q12 = z_values.Get(i, j + 1)
    var/q22 = z_values.Get(i + 1, j + 1)

    var/f_xy1 = (1.0 - tx) * q11 + tx * q21
    var/f_xy2 = (1.0 - tx) * q12 + tx * q22
    return (1.0 - ty) * f_xy1 + ty * f_xy2

#endif // PLENUM_LIBRARIES_INTERPOLATION_DM
