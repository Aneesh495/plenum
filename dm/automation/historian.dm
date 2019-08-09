// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Telemetry Time-Series Historian & Swinging Door Compression
// Language: Dream Maker (DM)

#ifndef PLENUM_AUTOMATION_HISTORIAN_DM
#define PLENUM_AUTOMATION_HISTORIAN_DM

#include "../defines.dm"
#include "../core/datum.dm"

/datum/historian_sample
    var/timestamp_s = 0.0
    var/sample_value = 0.0

/datum/historian_sample/New(ts, val)
    ..()
    timestamp_s = ts
    sample_value = val

/datum/telemetry_historian_tag
    var/tag_name = "FIT-101.PV"
    var/compression_deviation_epsilon = 0.05 // Bounded error tolerance
    var/max_time_span_seconds = 300.0        // Force sample every 5 minutes if flat
    var/list/archived_samples = list()
    
    // Swinging Door Compression Working State
    var/last_archived_time = 0.0
    var/last_archived_val = 0.0
    var/slope_upper = 999999.0
    var/slope_lower = -999999.0
    var/datum/historian_sample/prev_sample = null

/datum/telemetry_historian_tag/New(name, epsilon = 0.05)
    ..()
    tag_name = name
    compression_deviation_epsilon = epsilon

/datum/telemetry_historian_tag/proc/RecordSample(time_s, value)
    if(archived_samples.len == 0)
        // First sample always archived
        archived_samples += new /datum/historian_sample(time_s, value)
        last_archived_time = time_s
        last_archived_val = value
        prev_sample = new /datum/historian_sample(time_s, value)
        slope_upper = 999999.0
        slope_lower = -999999.0
        return TRUE

    var/dt = time_s - last_archived_time
    if(dt <= 0.0001)
        return FALSE

    // Swinging Door Trending (SDT) slope bounds:
    // Upper door slope = (V - (V0 + eps)) / dt
    // Lower door slope = (V - (V0 - eps)) / dt
    var/s_up = (value - (last_archived_val + compression_deviation_epsilon)) / dt
    var/s_lo = (value - (last_archived_val - compression_deviation_epsilon)) / dt

    slope_upper = min(slope_upper, s_up)
    slope_lower = max(slope_lower, s_lo)

    // Check if doors have crossed or max time span exceeded
    if(slope_lower > slope_upper || dt >= max_time_span_seconds)
        // Archive the PREVIOUS point
        archived_samples += prev_sample
        last_archived_time = prev_sample.timestamp_s
        last_archived_val = prev_sample.sample_value
        
        // Reset doors for new segment
        var/new_dt = time_s - last_archived_time
        slope_upper = (value - (last_archived_val + compression_deviation_epsilon)) / max(0.001, new_dt)
        slope_lower = (value - (last_archived_val - compression_deviation_epsilon)) / max(0.001, new_dt)
        prev_sample = new /datum/historian_sample(time_s, value)
        return TRUE

    prev_sample.timestamp_s = time_s
    prev_sample.sample_value = value
    return FALSE

/datum/telemetry_historian_tag/proc/ComputeTimeWeightedAverage(start_time, end_time)
    if(archived_samples.len == 0 || end_time <= start_time)
        return 0.0

    var/integral_area = 0.0
    var/total_time = end_time - start_time
    
    for(var/i = 1 to (archived_samples.len - 1))
        var/datum/historian_sample/s1 = archived_samples[i]
        var/datum/historian_sample/s2 = archived_samples[i + 1]
        
        if(s2.timestamp_s < start_time || s1.timestamp_s > end_time)
            continue

        var/t_a = max(start_time, s1.timestamp_s)
        var/t_b = min(end_time, s2.timestamp_s)
        var/dt = t_b - t_a
        if(dt > 0.0)
            var/avg_val = (s1.sample_value + s2.sample_value) * 0.5
            integral_area += avg_val * dt

    return integral_area / total_time

#endif // PLENUM_AUTOMATION_HISTORIAN_DM
