// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Graph Topology Algorithms & Dijkstra Routing
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_GRAPH_DM
#define PLENUM_LIBRARIES_GRAPH_DM

#include "../core/datum.dm"

/datum/graph_edge
    var/from_node = ""
    var/to_node = ""
    var/weight = 1.0

/datum/graph_edge/New(from_n, to_n, w = 1.0)
    ..()
    from_node = from_n
    to_node = to_n
    weight = w

/datum/directed_graph
    var/list/nodes = list()              // Unique string identifiers
    var/list/adjacency_list = list()     // node_id -> list of /datum/graph_edge

/datum/directed_graph/proc/AddNode(id)
    if(!(id in nodes))
        nodes += id
        adjacency_list[id] = list()

/datum/directed_graph/proc/AddEdge(from_id, to_id, weight = 1.0)
    AddNode(from_id)
    AddNode(to_id)
    var/list/edge_list = adjacency_list[from_id]
    edge_list += new /datum/graph_edge(from_id, to_id, weight)

/datum/directed_graph/proc/ShortestPathDijkstra(start_node, dest_node)
    if(!(start_node in nodes) || !(dest_node in nodes))
        return null

    var/list/dist = list()
    var/list/prev = list()
    var/list/unvisited = list()

    for(var/n in nodes)
        dist[n] = 999999999.0
        prev[n] = null
        unvisited += n

    dist[start_node] = 0.0

    while(unvisited.len > 0)
        // Find node with minimum distance in unvisited
        var/curr = unvisited[1]
        var/min_d = dist[curr]
        var/best_idx = 1
        for(var/i = 2 to unvisited.len)
            var/candidate = unvisited[i]
            if(dist[candidate] < min_d)
                min_d = dist[candidate]
                curr = candidate
                best_idx = i

        unvisited.Cut(best_idx, best_idx + 1)

        if(curr == dest_node)
            break
        if(min_d >= 999999990.0)
            break // Remaining nodes are unreachable

        var/list/edges = adjacency_list[curr]
        for(var/datum/graph_edge/edge in edges)
            var/alt = dist[curr] + edge.weight
            if(alt < dist[edge.to_node])
                dist[edge.to_node] = alt
                prev[edge.to_node] = curr

    // Reconstruct path
    if(dist[dest_node] >= 999999990.0)
        return null // No path exists

    var/list/path = list()
    var/step = dest_node
    while(step)
        path.Insert(1, step)
        step = prev[step]

    return path

#endif // PLENUM_LIBRARIES_GRAPH_DM
