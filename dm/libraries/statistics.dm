// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Streaming Statistics (Welford's Algorithm) & Reliability Distributions
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_STATISTICS_DM
#define PLENUM_LIBRARIES_STATISTICS_DM

#include "../core/datum.dm"

/datum/streaming_statistics
    var/sample_count = 0
    var/mean = 0.0
    var/m2_accumulator = 0.0             // Sum of squared differences
    var/min_value = 999999999.0
    var/max_value = -999999999.0

/datum/streaming_statistics/proc/Update(val)
    // Welford's single-pass algorithm for numerical stability
    sample_count++
    var/delta = val - mean
    mean += delta / sample_count
    var/delta2 = val - mean
    m2_accumulator += delta * delta2

    if(val < min_value) min_value = val
    if(val > max_value) max_value = val

/datum/streaming_statistics/proc/GetVariance()
    if(sample_count < 2) return 0.0
    return m2_accumulator / (sample_count - 1)

/datum/streaming_statistics/proc/GetStandardDeviation()
    return sqrt(GetVariance())

/datum/reliability_distributions

/datum/reliability_distributions/proc/NormalPDF(x, mu = 0.0, sigma = 1.0)
    if(sigma <= 0.0) return 0.0
    var/z = (x - mu) / sigma
    // 1 / (sigma * sqrt(2*pi)) * exp(-0.5 * z^2)
    var/norm_factor = 1.0 / (sigma * 2.50662827)
    return norm_factor * exp(-0.5 * z * z)

/datum/reliability_distributions/proc/ErrorFunctionErf(x)
    // Abramowitz and Stegun numerical approximation: maximum error < 1.5e-7
    var/sign = (x >= 0.0) ? 1 : -1
    var/ax = abs(x)
    var/t = 1.0 / (1.0 + (0.3275911 * ax))
    var/poly = (0.254829592 * t) - (0.284496736 * t * t) + (1.421413741 * t * t * t) - (1.453152027 * (t ** 4)) + (1.061405429 * (t ** 5))
    return sign * (1.0 - poly * exp(-ax * ax))

/datum/reliability_distributions/proc/NormalCDF(x, mu = 0.0, sigma = 1.0)
    // Phi(x) = 0.5 * (1 + erf((x - mu) / (sigma * sqrt(2))))
    if(sigma <= 0.0) return (x >= mu) ? 1.0 : 0.0
    var/z = (x - mu) / (sigma * 1.41421356)
    return 0.5 * (1.0 + ErrorFunctionErf(z))

/datum/reliability_distributions/proc/WeibullHazardRate(time_hours, beta_shape = 1.5, eta_scale_hours = 50000.0)
    // h(t) = (beta / eta) * (t / eta)^(beta - 1)
    if(time_hours <= 0.0 || eta_scale_hours <= 0.0) return 0.0
    var/ratio = time_hours / eta_scale_hours
    return (beta_shape / eta_scale_hours) * (ratio ** (beta_shape - 1.0))

#endif // PLENUM_LIBRARIES_STATISTICS_DM
