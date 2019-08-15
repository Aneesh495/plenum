// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: IEC 61508 / 61511 Safety Instrumented Systems (SIS) Voting Logic
// Language: Dream Maker (DM)

#ifndef PLENUM_SAFETY_SIS_INTERLOCKS_DM
#define PLENUM_SAFETY_SIS_INTERLOCKS_DM

#include "../defines.dm"
#include "../core/datum.dm"

#define SIS_ARCH_1OO1        1 // 1 out of 1
#define SIS_ARCH_1OO2        2 // 1 out of 2 (Fail-Safe Trip)
#define SIS_ARCH_2OO3        3 // 2 out of 3 (Triple Modular Redundancy Majority Voting)

/datum/sif_voting_block
    var/sif_tag = "SIF-P-301"
    var/sil_rating = SIL_RATING_3        // Target SIL 3
    var/architecture = SIS_ARCH_2OO3
    
    // Sensor Input Channels (Triple Redundant Transmitters)
    var/channel_a_tripped = FALSE
    var/channel_b_tripped = FALSE
    var/channel_c_tripped = FALSE
    
    // Channel Diagnostic Discrepancy Monitoring
    var/channel_a_fault = FALSE
    var/channel_b_fault = FALSE
    var/channel_c_fault = FALSE
    var/discrepancy_timer_s = 0.0
    var/max_discrepancy_time_s = 5.0    // Alarm if channels disagree for > 5s

    // Final Trip Output
    var/voted_trip_output = FALSE
    var/total_trip_events = 0

/datum/sif_voting_block/New(tag = "SIF-P-301", arch = SIS_ARCH_2OO3, sil = SIL_RATING_3)
    ..()
    sif_tag = tag
    architecture = arch
    sil_rating = sil

/datum/sif_voting_block/proc/UpdateSensors(trip_a, trip_b, trip_c)
    channel_a_tripped = trip_a ? TRUE : FALSE
    channel_b_tripped = trip_b ? TRUE : FALSE
    channel_c_tripped = trip_c ? TRUE : FALSE

/datum/sif_voting_block/proc/EvaluateVotingLogic(delta_time_seconds)
    var/trip = FALSE

    switch(architecture)
        if(SIS_ARCH_1OO1)
            trip = channel_a_tripped

        if(SIS_ARCH_1OO2)
            // Trip if EITHER channel A or channel B demands shutdown
            trip = (channel_a_tripped || channel_b_tripped)

        if(SIS_ARCH_2OO3)
            // Majority voting: (A and B) or (B and C) or (A and C)
            var/vote_count = 0
            if(channel_a_tripped && !channel_a_fault) vote_count++
            if(channel_b_tripped && !channel_b_fault) vote_count++
            if(channel_c_tripped && !channel_c_fault) vote_count++
            trip = (vote_count >= 2)

            // Diagnostic discrepancy detection: channels disagree
            if(vote_count == 1)
                discrepancy_timer_s += delta_time_seconds
                if(discrepancy_timer_s >= max_discrepancy_time_s)
                    // Mark minority channel as suspect
                    if(event_hub)
                        event_hub.SendSignal(SIG_ALARM_STATE_CHANGED, list("sif" = sif_tag, "diag" = "CHANNEL_DISCREPANCY"))
            else
                discrepancy_timer_s = 0.0

    if(trip && !voted_trip_output)
        total_trip_events++
        if(event_hub)
            event_hub.SendSignal(SIG_ESD_TRIGGERED, list("sif" = sif_tag, "sil" = sil_rating))

    voted_trip_output = trip
    return voted_trip_output

/datum/sif_voting_block/proc/CalculatePFDavg(lambda_du_per_hour = 1.0e-7, proof_test_interval_hours = 8760.0)
    // IEC 61508 PFD_avg calculation for 2oo3 architecture:
    // PFD_avg ~ lambda_DU^2 * T_i^2
    var/t_i = proof_test_interval_hours
    var/pfd = (lambda_du_per_hour * t_i) * (lambda_du_per_hour * t_i)
    return pfd

#endif // PLENUM_SAFETY_SIS_INTERLOCKS_DM
