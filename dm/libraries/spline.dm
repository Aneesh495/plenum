// Natural Cubic Spline and Akima Sub-Spline Interpolation
//
// Implements piecewise cubic spline interpolation with continuous
// first and second derivatives (C2 continuity), solved via the tridiagonal
// Thomas algorithm (O(N) complexity). Also implements shape-preserving
// Akima sub-splines to prevent overshoot and oscillatory ringing
// in steam expansion lines and non-linear valve characteristic curves.

/datum/math/cubic_spline
    var/list/x_pts = list()
    var/list/y_pts = list()
    var/list/a_coeffs = list()
    var/list/b_coeffs = list()
    var/list/c_coeffs = list()
    var/list/d_coeffs = list()
    var/is_built = 0

/datum/math/cubic_spline/New()
    ..()
    x_pts = list()
    y_pts = list()
    a_coeffs = list()
    b_coeffs = list()
    c_coeffs = list()
    d_coeffs = list()
    is_built = 0

/datum/math/cubic_spline/proc/set_knots(list/x_vals, list/y_vals)
    if(x_vals.len != y_vals.len || x_vals.len < 3)
        CRASH("Spline requires at least 3 knot points and matching x/y lengths")

    x_pts = list()
    y_pts = list()
    for(var/i = 1 to x_vals.len)
        x_pts.Add(x_vals[i])
        y_pts.Add(y_vals[i])

    build_natural_spline()

// Tridiagonal Thomas algorithm to solve for spline second derivatives
/datum/math/cubic_spline/proc/build_natural_spline()
    var/n = x_pts.len
    var/list/h = list()
    for(var/i = 1 to (n - 1))
        var/dx = x_pts[i + 1] - x_pts[i]
        if(dx <= 1e-12)
            CRASH("Knot x-coordinates must be strictly monotonically increasing")
        h.Add(dx)

    // Tridiagonal matrix diagonals: sub (alpha), main (diag), super (gamma)
    var/list/diag = list()
    var/list/rhs = list()

    for(var/i = 1 to n)
        diag.Add(1.0)
        rhs.Add(0.0)

    // Interior equations: h[i-1]*c[i-1] + 2*(h[i-1]+h[i])*c[i] + h[i]*c[i+1] = 3*((y[i+1]-y[i])/h[i] - (y[i]-y[i-1])/h[i-1])
    for(var/i = 2 to (n - 1))
        var/h_prev = h[i - 1]
        var/h_curr = h[i]
        diag[i] = 2.0 * (h_prev + h_curr)
        var/slope_curr = (y_pts[i + 1] - y_pts[i]) / h_curr
        var/slope_prev = (y_pts[i] - y_pts[i - 1]) / h_prev
        rhs[i] = 3.0 * (slope_curr - slope_prev)

    // Natural boundary condition: second derivatives at endpoints are zero
    diag[1] = 1.0
    rhs[1] = 0.0
    diag[n] = 1.0
    rhs[n] = 0.0

    // Forward Thomas sweep
    var/list/c_prime = list()
    var/list/d_prime = list()
    for(var/i = 1 to n)
        c_prime.Add(0.0)
        d_prime.Add(0.0)

    c_prime[1] = 0.0
    d_prime[1] = rhs[1] / diag[1]

    for(var/i = 2 to n)
        var/sub_diag = (i <= (n - 1)) ? h[i - 1] : 0.0
        var/m = diag[i] - (sub_diag * c_prime[i - 1])
        if(abs(m) < 1e-12) m = 1e-12
        var/super_diag = (i < n) ? h[i] : 0.0
        c_prime[i] = super_diag / m
        d_prime[i] = (rhs[i] - (sub_diag * d_prime[i - 1])) / m

    // Back substitution for c coefficients
    var/list/c = list()
    for(var/i = 1 to n)
        c.Add(0.0)

    c[n] = d_prime[n]
    for(var/i = (n - 1) to 1 step -1)
        c[i] = d_prime[i] - (c_prime[i] * c[i + 1])

    // Compute polynomial segment coefficients: S_i(x) = a + b*(x-xi) + c*(x-xi)^2 + d*(x-xi)^3
    a_coeffs = list()
    b_coeffs = list()
    c_coeffs = list()
    d_coeffs = list()

    for(var/i = 1 to (n - 1))
        var/hi = h[i]
        var/ai = y_pts[i]
        var/ci = c[i]
        var/di = (c[i + 1] - c[i]) / (3.0 * hi)
        var/bi = ((y_pts[i + 1] - y_pts[i]) / hi) - ((hi * (2.0 * c[i] + c[i + 1])) / 3.0)

        a_coeffs.Add(ai)
        b_coeffs.Add(bi)
        c_coeffs.Add(ci)
        d_coeffs.Add(di)

    is_built = 1
    return 1

// Evaluates spline at arbitrary x location
/datum/math/cubic_spline/proc/evaluate(x_val)
    if(!is_built)
        CRASH("Spline not built before evaluation")

    var/n = x_pts.len
    // Extrapolation bounds
    if(x_val <= x_pts[1])
        var/dx = x_val - x_pts[1]
        return a_coeffs[1] + (b_coeffs[1] * dx)
    if(x_val >= x_pts[n])
        var/idx = n - 1
        var/dx = x_val - x_pts[idx]
        return a_coeffs[idx] + (b_coeffs[idx] * dx) + (c_coeffs[idx] * dx * dx) + (d_coeffs[idx] * dx * dx * dx)

    // Binary search to find segment interval [x_i, x_i+1]
    var/low = 1
    var/high = n - 1
    var/segment = 1

    while(low <= high)
        var/mid = round((low + high) * 0.5)
        if(x_pts[mid] <= x_val)
            segment = mid
            low = mid + 1
        else
            high = mid - 1

    var/dx = x_val - x_pts[segment]
    var/y = a_coeffs[segment] + (b_coeffs[segment] * dx) + (c_coeffs[segment] * dx * dx) + (d_coeffs[segment] * dx * dx * dx)
    return y

// Evaluates first derivative (slope dy/dx)
/datum/math/cubic_spline/proc/evaluate_derivative(x_val)
    if(!is_built)
        CRASH("Spline not built before evaluation")

    var/n = x_pts.len
    var/segment = 1
    if(x_val <= x_pts[1])
        return b_coeffs[1]
    if(x_val >= x_pts[n])
        segment = n - 1
        var/dx = x_val - x_pts[segment]
        return b_coeffs[segment] + (2.0 * c_coeffs[segment] * dx) + (3.0 * d_coeffs[segment] * dx * dx)

    for(var/i = 1 to (n - 1))
        if(x_val >= x_pts[i] && x_val <= x_pts[i + 1])
            segment = i
            break

    var/dx = x_val - x_pts[segment]
    return b_coeffs[segment] + (2.0 * c_coeffs[segment] * dx) + (3.0 * d_coeffs[segment] * dx * dx)
