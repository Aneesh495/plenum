// Sparse Matrix and Iterative Linear Solvers (CSR Format)
//
// Compressed Sparse Row (CSR) storage format for large, sparse linear systems
// arising from multi-bus electrical networks, pipe network nodal equations,
// and finite-difference spatial grids. Implements matrix-vector multiplication,
// Jacobi preconditioning, and Conjugate Gradient (CG) iterative solver.

/datum/math/sparse_csr
    var/rows = 0
    var/cols = 0
    var/list/values = list()
    var/list/col_indices = list()
    var/list/row_pointers = list()

/datum/math/sparse_csr/New(num_rows, num_cols)
    ..()
    rows = num_rows
    cols = num_cols
    values = list()
    col_indices = list()
    row_pointers = list()
    for(var/i = 1 to (rows + 1))
        row_pointers.Add(1)

/datum/math/sparse_csr/proc/build_from_triplets(num_rows, num_cols, list/triplet_rows, list/triplet_cols, list/triplet_vals)
    rows = num_rows
    cols = num_cols
    values = list()
    col_indices = list()
    row_pointers = list()

    var/num_entries = triplet_rows.len
    var/list/row_counts = list()
    for(var/r = 1 to rows)
        row_counts.Add(0)

    for(var/k = 1 to num_entries)
        var/r = triplet_rows[k]
        if(r >= 1 && r <= rows)
            row_counts[r] = row_counts[r] + 1

    row_pointers.Add(1)
    for(var/r = 1 to rows)
        var/prev_ptr = row_pointers[r]
        row_pointers.Add(prev_ptr + row_counts[r])

    // Pre-allocate values and column indices
    for(var/i = 1 to num_entries)
        values.Add(0.0)
        col_indices.Add(0)

    var/list/current_offset = list()
    for(var/r = 1 to rows)
        current_offset.Add(row_pointers[r])

    for(var/k = 1 to num_entries)
        var/r = triplet_rows[k]
        var/c = triplet_cols[k]
        var/val = triplet_vals[k]
        var/idx = current_offset[r]
        values[idx] = val
        col_indices[idx] = c
        current_offset[r] = idx + 1

    return 1

/datum/math/sparse_csr/proc/matvec(list/x)
    if(x.len != cols)
        CRASH("Dimension mismatch in CSR matrix-vector product: cols [cols] vs x.len [x.len]")

    var/list/y = list()
    for(var/r = 1 to rows)
        var/sum = 0.0
        var/start_idx = row_pointers[r]
        var/end_idx = row_pointers[r + 1] - 1

        for(var/idx = start_idx to end_idx)
            var/col = col_indices[idx]
            var/val = values[idx]
            sum += val * x[col]

        y.Add(sum)

    return y

/datum/math/sparse_csr/proc/get_diagonal()
    var/list/diag = list()
    for(var/r = 1 to rows)
        var/diag_val = 0.0
        var/start_idx = row_pointers[r]
        var/end_idx = row_pointers[r + 1] - 1

        for(var/idx = start_idx to end_idx)
            if(col_indices[idx] == r)
                diag_val = values[idx]
                break

        diag.Add(diag_val)

    return diag

// Conjugate Gradient (CG) Solver for Symmetric Positive Definite (SPD) Systems: A * x = b
/datum/math/sparse_csr/proc/solve_conjugate_gradient(list/b, list/x0 = null, max_iter = 100, tolerance = 1e-6)
    if(rows != cols)
        CRASH("Conjugate Gradient requires square matrix")

    var/list/x = list()
    if(x0 != null && x0.len == cols)
        for(var/v in x0)
            x.Add(v)
    else
        for(var/i = 1 to cols)
            x.Add(0.0)

    // Initial residual: r0 = b - A * x0
    var/list/ax0 = matvec(x)
    var/list/r = list()
    var/list/p = list()
    var/rsold = 0.0

    for(var/i = 1 to rows)
        var/ri = b[i] - ax0[i]
        r.Add(ri)
        p.Add(ri)
        rsold += ri * ri

    if(sqrt(rsold) < tolerance)
        return x

    for(var/iter = 1 to max_iter)
        var/list/ap = matvec(p)
        var/p_dot_ap = 0.0
        for(var/i = 1 to cols)
            p_dot_ap += p[i] * ap[i]

        if(abs(p_dot_ap) < 1e-12)
            break

        var/alpha = rsold / p_dot_ap

        var/rsnew = 0.0
        for(var/i = 1 to cols)
            x[i] = x[i] + alpha * p[i]
            r[i] = r[i] - alpha * ap[i]
            rsnew += r[i] * r[i]

        if(sqrt(rsnew) < tolerance)
            break

        var/beta = rsnew / rsold
        for(var/i = 1 to cols)
            p[i] = r[i] + beta * p[i]

        rsold = rsnew

    return x
