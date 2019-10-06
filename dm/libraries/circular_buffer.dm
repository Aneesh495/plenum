// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Circular Ring Buffer & Sliding Window Collections
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_CIRCULAR_BUFFER_DM
#define PLENUM_LIBRARIES_CIRCULAR_BUFFER_DM

#include "../core/datum.dm"

/datum/circular_buffer
    var/capacity = 128
    var/list/buffer_array = null
    var/head_idx = 1
    var/tail_idx = 1
    var/item_count = 0

/datum/circular_buffer/New(cap = 128)
    ..()
    capacity = max(2, cap)
    buffer_array = list()
    buffer_array.len = capacity

/datum/circular_buffer/proc/Push(item)
    buffer_array[head_idx] = item
    head_idx = (head_idx % capacity) + 1
    if(item_count < capacity)
        item_count++
    else
        // Overwrite oldest item: advance tail
        tail_idx = (tail_idx % capacity) + 1

/datum/circular_buffer/proc/Pop()
    if(item_count == 0)
        return null
    var/val = buffer_array[tail_idx]
    buffer_array[tail_idx] = null
    tail_idx = (tail_idx % capacity) + 1
    item_count--
    return val

/datum/circular_buffer/proc/PeekOldest()
    if(item_count == 0) return null
    return buffer_array[tail_idx]

/datum/circular_buffer/proc/PeekNewest()
    if(item_count == 0) return null
    var/idx = head_idx - 1
    if(idx < 1) idx = capacity
    return buffer_array[idx]

/datum/circular_buffer/proc/Clear()
    for(var/i = 1 to capacity)
        buffer_array[i] = null
    head_idx = 1
    tail_idx = 1
    item_count = 0

#endif // PLENUM_LIBRARIES_CIRCULAR_BUFFER_DM
