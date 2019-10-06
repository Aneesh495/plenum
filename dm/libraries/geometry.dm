// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Computational Geometry, Shoelace Area & Polygon Clipping
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_GEOMETRY_DM
#define PLENUM_LIBRARIES_GEOMETRY_DM

#include "../core/datum.dm"

/datum/vector2d
    var/x = 0.0
    var/y = 0.0

/datum/vector2d/New(px = 0.0, py = 0.0)
    ..()
    x = px
    y = py

/datum/vector2d/proc/Length()
    return sqrt((x * x) + (y * y))

/datum/vector2d/proc/Dot(datum/vector2d/other)
    return (x * other.x) + (y * other.y)

/datum/vector2d/proc/Cross(datum/vector2d/other)
    return (x * other.y) - (y * other.x)

/datum/vector2d/proc/Normalize()
    var/l = Length()
    if(l > 0.000001)
        x /= l
        y /= l
    return src

/datum/polygon2d
    var/list/vertices = list() // List of /datum/vector2d

/datum/polygon2d/proc/AddVertex(px, py)
    vertices += new /datum/vector2d(px, py)

/datum/polygon2d/proc/CalculateAreaShoelace()
    // Shoelace formula: Area = 0.5 * |sum_{i=0}^{n-1} (x_i * y_{i+1} - x_{i+1} * y_i)|
    var/n = vertices.len
    if(n < 3) return 0.0

    var/area_sum = 0.0
    for(var/i = 1 to n)
        var/j = (i % n) + 1
        var/datum/vector2d/v1 = vertices[i]
        var/datum/vector2d/v2 = vertices[j]
        area_sum += (v1.x * v2.y) - (v2.x * v1.y)

    return abs(area_sum) * 0.5

/datum/polygon2d/proc/ContainsPoint(px, py)
    // Ray-casting Jordan Curve algorithm
    var/n = vertices.len
    if(n < 3) return FALSE
    
    var/inside = FALSE
    for(var/i = 1 to n)
        var/j = (i % n) + 1
        var/datum/vector2d/v1 = vertices[i]
        var/datum/vector2d/v2 = vertices[j]

        if(((v1.y > py) != (v2.y > py)) && (px < (v2.x - v1.x) * (py - v1.y) / (v2.y - v1.y + 0.00000001) + v1.x))
            inside = !inside

    return inside

#endif // PLENUM_LIBRARIES_GEOMETRY_DM
