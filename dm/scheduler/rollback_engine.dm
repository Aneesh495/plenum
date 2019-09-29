// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Deterministic State Checkpointing, Delta Rollback & Replay
// Language: Dream Maker (DM)

#ifndef PLENUM_SCHEDULER_ROLLBACK_ENGINE_DM
#define PLENUM_SCHEDULER_ROLLBACK_ENGINE_DM

#include "../core/datum.dm"

/datum/simulation_snapshot
    var/snapshot_tick = 0
    var/list/state_data = null
    var/state_checksum = 0

/datum/simulation_snapshot/New(tick, list/data, checksum = 0)
    ..()
    snapshot_tick = tick
    state_data = data
    state_checksum = checksum

/datum/rollback_engine
    var/list/snapshot_ring_buffer = list()
    var/max_snapshots = 64

/datum/rollback_engine/proc/CalculateStateChecksum(list/flat_data)
    // 32-bit FNV-1a non-cryptographic hash
    var/hash = 2166136261
    for(var/val in flat_data)
        var/int_val = round(abs(val) * 1000.0) & 255
        hash = hash ^ int_val
        hash = (hash * 16777619) & 4294967295
    return hash

/datum/rollback_engine/proc/SaveCheckpoint(tick_num, list/current_state)
    var/chk = CalculateStateChecksum(current_state)
    var/datum/simulation_snapshot/snap = new /datum/simulation_snapshot(tick_num, current_state.Copy(), chk)
    
    snapshot_ring_buffer += snap
    if(snapshot_ring_buffer.len > max_snapshots)
        snapshot_ring_buffer.Cut(1, 2)
    
    return chk

/datum/rollback_engine/proc/RollbackToTick(target_tick)
    var/datum/simulation_snapshot/matched = null
    for(var/i = snapshot_ring_buffer.len to 1 step -1)
        var/datum/simulation_snapshot/snap = snapshot_ring_buffer[i]
        if(snap.snapshot_tick <= target_tick)
            matched = snap
            break

    if(!matched)
        return null

    return matched.state_data.Copy()

#endif // PLENUM_SCHEDULER_ROLLBACK_ENGINE_DM
