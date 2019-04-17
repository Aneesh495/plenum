// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Spatial Hash Grid and Raycasting Accelerator
// Language: Dream Maker (DM)

#ifndef PLENUM_CORE_SPATIAL_GRID_DM
#define PLENUM_CORE_SPATIAL_GRID_DM

#include "datum.dm"

/datum/spatial_grid
    var/width = 32
    var/height = 32
    var/depth = 1
    var/list/turf_matrix = null         // Flat 1D index array: (z-1)*W*H + (y-1)*W + (x-1) + 1
    var/list/spatial_hash_buckets = null// Hash map: "bx_by_bz" -> list(entities)
    var/bucket_size = 4                 // 4x4 turf chunks

/datum/spatial_grid/New(w = 32, h = 32, d = 1)
    ..()
    width = w
    height = h
    depth = d
    turf_matrix = list()
    turf_matrix.len = width * height * depth
    spatial_hash_buckets = list()

/datum/spatial_grid/proc/GetIndex(x_coord, y_coord, z_coord)
    if(x_coord < 1 || x_coord > width || y_coord < 1 || y_coord > height || z_coord < 1 || z_coord > depth)
        return 0
    return ((z_coord - 1) * width * height) + ((y_coord - 1) * width) + x_coord

/datum/spatial_grid/proc/SetTurf(x_coord, y_coord, z_coord, turf/T)
    var/idx = GetIndex(x_coord, y_coord, z_coord)
    if(idx > 0)
        turf_matrix[idx] = T

/datum/spatial_grid/proc/GetTurf(x_coord, y_coord, z_coord)
    var/idx = GetIndex(x_coord, y_coord, z_coord)
    if(idx > 0)
        return turf_matrix[idx]
    return null

/datum/spatial_grid/proc/GetBucketKey(x_coord, y_coord, z_coord)
    var/bx = round((x_coord - 1) / bucket_size)
    var/by = round((y_coord - 1) / bucket_size)
    var/bz = z_coord
    return "[bx]_[by]_[bz]"

/datum/spatial_grid/proc/InsertEntity(atom/movable/ent)
    if(!ent || !ent.loc)
        return
    var/key = GetBucketKey(ent.x, ent.y, ent.z)
    if(!spatial_hash_buckets[key])
        spatial_hash_buckets[key] = list()
    var/list/bucket = spatial_hash_buckets[key]
    bucket += ent

/datum/spatial_grid/proc/RemoveEntity(atom/movable/ent, old_x, old_y, old_z)
    var/key = GetBucketKey(old_x, old_y, old_z)
    if(spatial_hash_buckets[key])
        var/list/bucket = spatial_hash_buckets[key]
        bucket -= ent

/datum/spatial_grid/proc/QueryRadius(center_x, center_y, center_z, radius)
    var/list/results = list()
    var/min_bx = round(max(1, center_x - radius - 1) / bucket_size)
    var/max_bx = round(min(width, center_x + radius - 1) / bucket_size)
    var/min_by = round(max(1, center_y - radius - 1) / bucket_size)
    var/max_by = round(min(height, center_y + radius - 1) / bucket_size)

    var/r2 = radius * radius
    for(var/bx = min_bx to max_bx)
        for(var/by = min_by to max_by)
            var/key = "[bx]_[by]_[center_z]"
            if(spatial_hash_buckets[key])
                var/list/bucket = spatial_hash_buckets[key]
                for(var/atom/movable/ent in bucket)
                    var/dx = ent.x - center_x
                    var/dy = ent.y - center_y
                    if((dx * dx + dy * dy) <= r2)
                        results += ent
    return results

/datum/spatial_grid/proc/RaycastBresenham(x0, y0, x1, y1, z_coord, pass_flags = PASS_OPTICAL)
    // Bresenham line generation algorithm to find line of sight and occlusions
    var/list/hit_tiles = list()
    var/dx = abs(x1 - x0)
    var/dy = abs(y1 - y0)
    var/sx = (x0 < x1) ? 1 : -1
    var/sy = (y0 < y1) ? 1 : -1
    var/err = dx - dy

    var/cur_x = x0
    var/cur_y = y0

    while(TRUE)
        var/turf/plenum_turf/T = GetTurf(cur_x, cur_y, z_coord)
        if(!T)
            break
        hit_tiles += T
        
        // Check for line of sight blocking
        if((T.permeability_flags & pass_flags) != pass_flags || T.opacity)
            break

        if(cur_x == x1 && cur_y == y1)
            break

        var/e2 = 2 * err
        if(e2 > -dy)
            err -= dy
            cur_x += sx
        if(e2 < dx)
            err += dx
            cur_y += sy

    return hit_tiles

/datum/spatial_grid/proc/FloodFillConnectedZone(start_x, start_y, z_coord, pass_flags = PASS_GAS)
    // Breath-First Search flood fill to identify contiguous fluid/gas containment zones
    var/list/visited = list()
    var/list/queue = list()
    
    var/turf/start_turf = GetTurf(start_x, start_y, z_coord)
    if(!start_turf)
        return visited

    queue += start_turf
    visited[start_turf] = TRUE

    while(queue.len > 0)
        var/turf/plenum_turf/curr = queue[1]
        queue.Cut(1, 2)

        if(!curr.cardinal_neighbors)
            curr.CacheNeighbors()

        for(var/turf/plenum_turf/neighbor in curr.cardinal_neighbors)
            if(!visited[neighbor] && (neighbor.permeability_flags & pass_flags))
                visited[neighbor] = TRUE
                queue += neighbor

    return visited

#endif // PLENUM_CORE_SPATIAL_GRID_DM
