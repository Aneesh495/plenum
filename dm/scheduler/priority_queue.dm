// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Min-Heap Event Priority Queue for Discrete-Event Simulation
// Language: Dream Maker (DM)

#ifndef PLENUM_SCHEDULER_PRIORITY_QUEUE_DM
#define PLENUM_SCHEDULER_PRIORITY_QUEUE_DM

#include "../core/datum.dm"

/datum/discrete_event
    var/scheduled_time_s = 0.0
    var/event_type = "GENERIC_EVENT"
    var/datum/target_object = null
    var/action_proc_name = ""
    var/list/event_args = null

/datum/discrete_event/New(time_s, type, target, proc_name, list/args = null)
    ..()
    scheduled_time_s = time_s
    event_type = type
    target_object = target
    action_proc_name = proc_name
    event_args = args

/datum/min_heap_event_queue
    var/list/heap_array = list() // 1-based indexed binary min-heap

/datum/min_heap_event_queue/proc/InsertEvent(datum/discrete_event/ev)
    if(!ev) return
    heap_array += ev
    SiftUp(heap_array.len)

/datum/min_heap_event_queue/proc/PeekNextTime()
    if(heap_array.len == 0)
        return 999999999.0
    var/datum/discrete_event/root = heap_array[1]
    return root.scheduled_time_s

/datum/min_heap_event_queue/proc/PopNextEvent()
    if(heap_array.len == 0)
        return null

    var/datum/discrete_event/root = heap_array[1]
    var/last_idx = heap_array.len
    
    if(last_idx == 1)
        heap_array.Cut(1, 2)
        return root

    // Move last element to root and sift down
    heap_array[1] = heap_array[last_idx]
    heap_array.Cut(last_idx, last_idx + 1)
    SiftDown(1)
    return root

/datum/min_heap_event_queue/proc/SiftUp(index)
    var/curr = index
    while(curr > 1)
        var/parent = round(curr / 2)
        var/datum/discrete_event/node_c = heap_array[curr]
        var/datum/discrete_event/node_p = heap_array[parent]
        
        if(node_c.scheduled_time_s < node_p.scheduled_time_s)
            // Swap
            heap_array[curr] = node_p
            heap_array[parent] = node_c
            curr = parent
        else
            break

/datum/min_heap_event_queue/proc/SiftDown(index)
    var/curr = index
    var/count = heap_array.len

    while(TRUE)
        var/left = curr * 2
        var/right = left + 1
        var/smallest = curr

        if(left <= count)
            var/datum/discrete_event/nl = heap_array[left]
            var/datum/discrete_event/ns = heap_array[smallest]
            if(nl.scheduled_time_s < ns.scheduled_time_s)
                smallest = left

        if(right <= count)
            var/datum/discrete_event/nr = heap_array[right]
            var/datum/discrete_event/ns = heap_array[smallest]
            if(nr.scheduled_time_s < ns.scheduled_time_s)
                smallest = right

        if(smallest != curr)
            var/datum/discrete_event/temp = heap_array[curr]
            heap_array[curr] = heap_array[smallest]
            heap_array[smallest] = temp
            curr = smallest
        else
            break

#endif // PLENUM_SCHEDULER_PRIORITY_QUEUE_DM
