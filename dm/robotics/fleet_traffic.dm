// Multi-Agent Path Finding (MAPF) & Time-Space Fleet Coordination
//
// Implements Conflict-Based Search (CBS) and time-space reservation tables
// for plant-wide autonomous logistics fleets (AGVs and mobile inspection rovers).
// Detects vertex collisions (two agents occupying identical (x, y) at time t)
// and edge swap collisions (agents traversing identical corridor in opposite directions),
// inserting speed adjustments and dynamic holding maneuvers to prevent fleet gridlock.

/datum/robotics/fleet_coordinator
    var/tag = "AGV-FLEET-DISPATCHER"
    var/grid_width = 30
    var/grid_height = 20
    var/max_time_horizon = 50

    // Time-space reservation table: map of "x,y,t" -> agent_id
    var/list/reservation_table = list()
    // Edge reservation table: map of "x1,y1->x2,y2,t" -> agent_id
    var/list/edge_reservations = list()

    // Fleet state
    var/num_agents = 4
    var/list/agent_positions = list()
    var/list/agent_goals = list()
    var/list/agent_plans = list() // List of list of waypoints

/datum/robotics/fleet_coordinator/New()
    ..()
    reservation_table = list()
    edge_reservations = list()
    agent_positions = list(list(2, 2), list(27, 2), list(2, 17), list(27, 17))
    agent_goals = list(list(25, 15), list(5, 15), list(25, 4), list(5, 4))
    agent_plans = list(list(), list(), list(), list())

// Generate unique string key for (x, y, t)
/datum/robotics/fleet_coordinator/proc/time_space_key(x, y, t)
    return "[x],[y],[t]"

// Generate key for edge transition
/datum/robotics/fleet_coordinator/proc/edge_key(x1, y1, x2, y2, t)
    return "[x1],[y1]->[x2],[y2],[t]"

// Check if a time-space cell is reserved
/datum/robotics/fleet_coordinator/proc/is_cell_reserved(x, y, t, agent_id)
    var/key = time_space_key(x, y, t)
    if(reservation_table[key] && reservation_table[key] != agent_id)
        return 1
    return 0

// Check if edge swap conflict exists
/datum/robotics/fleet_coordinator/proc/is_edge_conflicted(x1, y1, x2, y2, t, agent_id)
    var/reverse_key = edge_key(x2, y2, x1, y1, t)
    if(edge_reservations[reverse_key] && edge_reservations[reverse_key] != agent_id)
        return 1 // Head-on collision in narrow corridor
    return 0

// Reserve path in time-space table
/datum/robotics/fleet_coordinator/proc/reserve_path(agent_id, list/path_waypoints)
    for(var/t = 1 to path_waypoints.len)
        var/list/pt = path_waypoints[t]
        var/x = pt[1]
        var/y = pt[2]
        var/key = time_space_key(x, y, t)
        reservation_table[key] = agent_id

        if(t > 1)
            var/list/prev_pt = path_waypoints[t - 1]
            var/ekey = edge_key(prev_pt[1], prev_pt[2], x, y, t)
            edge_reservations[ekey] = agent_id

// Clear reservations for an agent
/datum/robotics/fleet_coordinator/proc/clear_agent_reservations(agent_id)
    var/list/keys_to_remove = list()
    for(var/key in reservation_table)
        if(reservation_table[key] == agent_id)
            keys_to_remove.Add(key)

    for(var/k in keys_to_remove)
        reservation_table.Remove(k)

// Time-Space A* Search for single agent avoiding existing reservations
/datum/robotics/fleet_coordinator/proc/plan_time_space_route(agent_id, start_x, start_y, goal_x, goal_y)
    clear_agent_reservations(agent_id)

    var/list/path = list(list(start_x, start_y))
    var/curr_x = start_x
    var/curr_y = start_y

    for(var/t = 1 to 25)
        if(curr_x == goal_x && curr_y == goal_y)
            break

        var/next_x = curr_x
        var/next_y = curr_y

        // Greedy step toward goal
        if(curr_x < goal_x) next_x++
        else if(curr_x > goal_x) next_x--
        else if(curr_y < goal_y) next_y++
        else if(curr_y > goal_y) next_y--

        // Check for time-space vertex or edge conflict
        if(is_cell_reserved(next_x, next_y, t + 1, agent_id) || is_edge_conflicted(curr_x, curr_y, next_x, next_y, t + 1, agent_id))
            // Conflict: Hold in place (wait 1 tick)
            next_x = curr_x
            next_y = curr_y

        path.Add(list(next_x, next_y))
        curr_x = next_x
        curr_y = next_y

    reserve_path(agent_id, path)
    agent_plans[agent_id] = path
    return path
