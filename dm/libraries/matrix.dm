// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Linear Algebra Matrix Operations & LU Decomposition
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_MATRIX_DM
#define PLENUM_LIBRARIES_MATRIX_DM

#include "../core/datum.dm"

/datum/matrix_nd
    var/rows = 1
    var/cols = 1
    var/list/data = null // Flat row-major array: (r - 1) * cols + c

/datum/matrix_nd/New(r = 1, c = 1, initial_val = 0.0)
    ..()
    rows = max(1, r)
    cols = max(1, c)
    data = list()
    data.len = rows * cols
    for(var/i = 1 to (rows * cols))
        data[i] = initial_val

/datum/matrix_nd/proc/Get(r, c)
    if(r < 1 || r > rows || c < 1 || c > cols)
        return 0.0
    var/idx = ((r - 1) * cols) + c
    return data[idx]

/datum/matrix_nd/proc/Set(r, c, val)
    if(r < 1 || r > rows || c < 1 || c > cols)
        return
    var/idx = ((r - 1) * cols) + c
    data[idx] = val

/datum/matrix_nd/proc/SetIdentity()
    for(var/r = 1 to rows)
        for(var/c = 1 to cols)
            Set(r, c, (r == c) ? 1.0 : 0.0)

/datum/matrix_nd/proc/Add(datum/matrix_nd/other)
    if(!other || other.rows != rows || other.cols != cols)
        return null
    var/datum/matrix_nd/result = new /datum/matrix_nd(rows, cols)
    for(var/i = 1 to (rows * cols))
        result.data[i] = data[i] + other.data[i]
    return result

/datum/matrix_nd/proc/Subtract(datum/matrix_nd/other)
    if(!other || other.rows != rows || other.cols != cols)
        return null
    var/datum/matrix_nd/result = new /datum/matrix_nd(rows, cols)
    for(var/i = 1 to (rows * cols))
        result.data[i] = data[i] - other.data[i]
    return result

/datum/matrix_nd/proc/Scale(factor)
    var/datum/matrix_nd/result = new /datum/matrix_nd(rows, cols)
    for(var/i = 1 to (rows * cols))
        result.data[i] = data[i] * factor
    return result

/datum/matrix_nd/proc/Multiply(datum/matrix_nd/other)
    if(!other || cols != other.rows)
        return null
    var/datum/matrix_nd/result = new /datum/matrix_nd(rows, other.cols)
    for(var/i = 1 to rows)
        for(var/j = 1 to other.cols)
            var/sum = 0.0
            for(var/k = 1 to cols)
                sum += Get(i, k) * other.Get(k, j)
            result.Set(i, j, sum)
    return result

/datum/matrix_nd/proc/Transpose()
    var/datum/matrix_nd/result = new /datum/matrix_nd(cols, rows)
    for(var/r = 1 to rows)
        for(var/c = 1 to cols)
            result.Set(c, r, Get(r, c))
    return result

/datum/matrix_nd/proc/SolveLU(list/b_vec)
    // Doolittle LU Decomposition with Partial Pivoting to solve A * x = b
    if(rows != cols || b_vec.len != rows)
        return null

    var/n = rows
    var/datum/matrix_nd/a_copy = new /datum/matrix_nd(n, n)
    for(var/k = 1 to (n * n))
        a_copy.data[k] = data[k]

    var/list/piv = list()
    piv.len = n
    for(var/i = 1 to n)
        piv[i] = i

    // LU decomposition with partial row pivoting
    for(var/i = 1 to n)
        // Find pivot
        var/max_val = abs(a_copy.Get(i, i))
        var/pivot_row = i
        for(var/k = (i + 1) to n)
            var/val = abs(a_copy.Get(k, i))
            if(val > max_val)
                max_val = val
                pivot_row = k

        if(max_val < 0.000000001)
            qdel(a_copy)
            return null // Singular matrix

        if(pivot_row != i)
            // Swap rows in a_copy
            for(var/c = 1 to n)
                var/temp = a_copy.Get(i, c)
                a_copy.Set(i, c, a_copy.Get(pivot_row, c))
                a_copy.Set(pivot_row, c, temp)
            // Swap pivot permutation index
            var/p_temp = piv[i]
            piv[i] = piv[pivot_row]
            piv[pivot_row] = p_temp

        // Elimination
        for(var/j = (i + 1) to n)
            var/factor = a_copy.Get(j, i) / a_copy.Get(i, i)
            a_copy.Set(j, i, factor)
            for(var/k = (i + 1) to n)
                var/new_val = a_copy.Get(j, k) - (factor * a_copy.Get(i, k))
                a_copy.Set(j, k, new_val)

    // Forward Substitution to solve L * y = P * b
    var/list/y = list()
    y.len = n
    for(var/i = 1 to n)
        var/sum = b_vec[piv[i]]
        for(var/k = 1 to (i - 1))
            sum -= a_copy.Get(i, k) * y[k]
        y[i] = sum

    // Back Substitution to solve U * x = y
    var/list/x = list()
    x.len = n
    for(var/i = n to 1 step -1)
        var/sum = y[i]
        for(var/k = (i + 1) to n)
            sum -= a_copy.Get(i, k) * x[k]
        x[i] = sum / a_copy.Get(i, i)

    qdel(a_copy)
    return x

/datum/matrix_nd/proc/Invert()
    if(rows != cols)
        return null
    var/n = rows
    var/datum/matrix_nd/inv = new /datum/matrix_nd(n, n)
    for(var/col = 1 to n)
        var/list/b = list()
        b.len = n
        for(var/i = 1 to n)
            b[i] = (i == col) ? 1.0 : 0.0
        var/list/x = SolveLU(b)
        if(!x)
            qdel(inv)
            return null
        for(var/r = 1 to n)
            inv.Set(r, col, x[r])
    return inv

#endif // PLENUM_LIBRARIES_MATRIX_DM
