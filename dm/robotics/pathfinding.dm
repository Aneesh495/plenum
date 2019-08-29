// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Jump Point Search (JPS) & Hierarchical Grid Pathfinding
// Language: Dream Maker (DM)

#ifndef PLENUM_ROBOTICS_PATHFINDING_DM
#define PLENUM_ROBOTICS_PATHFINDING_DM

#include "../core/spatial_grid.dm"

/datum/path_node
    var/x_coord = 0
    var/y_coord = 0
    var/g_score = 999999.0
    var/f_score = 999999.0
    var/datum/path_node/parent = null

/datum/path_node/New(px, py, g = 999999.0, f = 999999.0)
    ..()
    x_coord = px
    y_coord = py
    g_score = g
    f_score = f

/datum/jps_pathfinder
    var/datum/spatial_grid/grid = null

/datum/jps_pathfinder/New(datum/spatial_grid/g)
    ..()
    grid = g

/datum/jps_pathfinder/proc/HeuristicOctile(x1, y1, x2, y2)
    // Octile distance: D1 * (|dx| + |dy|) + (D2 - 2*D1) * min(|dx|, |dy|)
    var/dx = abs(x1 - x2)
    var/dy = abs(y1 - y2)
    var/d1 = 1.0
    var/d2 = 1.41421356
    return (d1 * (dx + dy)) + ((d2 - 2.0 * d1) * min(dx, dy))

/datum/jps_pathfinder/proc/IsWalkable(px, py, z_coord)
    var/turf/plenum_turf/T = grid.GetTurf(px, py, z_coord)
    if(!T) return FALSE
    return !T.density && (T.permeability_flags & PASS_ROBOTIC)

/datum/jps_pathfinder/proc/Jump(x, y, dx, dy, target_x, target_y, z_coord)
    var/nx = x + dx
    var/ny = y + dy

    if(!IsWalkable(nx, ny, z_coord))
        return null

    if(nx == target_x && ny == target_y)
        return list(nx, ny)

    // Check for forced neighbors
    if(dx != 0 && dy != 0) // Diagonal jump
        if((IsWalkable(nx - dx, ny + dy, z_coord) && !IsWalkable(nx - dx, ny, z_coord)) || \
           (IsWalkable(nx + dx, ny - dy, z_coord) && !IsWalkable(nx, ny - dy, z_coord)))
            return list(nx, ny)
        // Check horizontal & vertical sub-jumps
        if(Jump(nx, ny, dx, 0, target_x, target_y, z_coord) != null || \
           Jump(nx, ny, 0, dy, target_x, target_y, z_coord) != null)
            return list(nx, ny)
    else if(dx != 0) // Horizontal jump
        if((IsWalkable(nx + dx, ny + 1, z_coord) && !IsWalkable(nx, ny + 1, z_coord)) || \
           (IsWalkable(nx + dx, ny - 1, z_coord) && !IsWalkable(nx, ny - 1, z_coord)))
            return list(nx, ny)
    else if(dy != 0) // Vertical jump
        if((IsWalkable(nx + 1, ny + dy, z_coord) && !IsWalkable(nx + 1, ny, z_coord)) || \
           (IsWalkable(nx - 1, ny + dy, z_coord) && !IsWalkable(nx - 1, ny, z_coord)))
            return list(nx, ny)

    return Jump(nx, ny, dx, dy, target_x, target_y, z_coord)

/datum/jps_pathfinder/proc/FindPath(start_x, start_y, target_x, target_y, z_coord = 1)
    if(!IsWalkable(target_x, target_y, z_coord))
        return null

    var/list/open_set = list()
    var/list/node_map = list()

    var/start_key = "[start_x]_[start_y]"
    var/datum/path_node/start_node = new /datum/path_node(start_x, start_y, 0.0, HeuristicOctile(start_x, start_y, target_x, target_y))
    open_set += start_node
    node_map[start_key] = start_node

    var/list/directions = list(
        list(0, 1), list(0, -1), list(1, 0), list(-1, 0),
        list(1, 1), list(1, -1), list(-1, 1), list(-1, -1)
    )

    while(open_set.len > 0)
        // Extract node with lowest f_score
        var/datum/path_node/current = open_set[1]
        var/best_idx = 1
        for(var/i = 2 to open_set.len)
            var/datum/path_node/candidate = open_set[i]
            if(candidate.f_score < current.f_score)
                current = candidate
                best_idx = i
        open_set.Cut(best_idx, best_idx + 1)

        if(current.x_coord == target_x && current.y_coord == target_y)
            // Reconstruct path
            var/list/path = list()
            var/datum/path_node/curr = current
            while(curr)
                path.Insert(1, list(curr.x_coord, curr.y_coord))
                curr = curr.parent
            return path

        for(var/list/dir in directions)
            var/list/jump_pt = Jump(current.x_coord, current.y_coord, dir[1], dir[2], target_x, target_y, z_coord)
            if(jump_pt)
                var/jx = jump_pt[1]
                var/jy = jump_pt[2]
                var/step_dist = HeuristicOctile(current.x_coord, current.y_coord, jx, jy)
                var/tentative_g = current.g_score + step_dist
                var/j_key = "[jx]_[jy]"

                var/datum/path_node/neighbor = node_map[j_key]
                if(!neighbor)
                    neighbor = new /datum/path_node(jx, jy)
                    node_map[j_key] = neighbor

                if(tentative_g < neighbor.g_score)
                    neighbor.parent = current
                    neighbor.g_score = tentative_g
                    neighbor.f_score = tentative_g + HeuristicOctile(jx, jy, target_x, target_y)
                    if(!(neighbor in open_set))
                        open_set += neighbor

    return null // No path found

#endif // PLENUM_ROBOTICS_PATHFINDING_DM
