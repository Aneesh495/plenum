// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Digital Signal Processing, FFT & Spectral Density
// Language: Dream Maker (DM)

#ifndef PLENUM_LIBRARIES_SIGNAL_PROCESSING_DM
#define PLENUM_LIBRARIES_SIGNAL_PROCESSING_DM

#include "../core/datum.dm"

/datum/signal_processor
    var/tag_name = "dsp_processor"

/datum/signal_processor/proc/ApplyHanningWindow(list/signal)
    var/n = signal.len
    var/list/windowed = list()
    windowed.len = n
    var/pi = 3.14159265
    for(var/i = 1 to n)
        // w[i] = 0.5 * (1 - cos(2*pi*(i-1)/(N-1)))
        var/angle_deg = (360.0 * (i - 1)) / (n - 1)
        var/w = 0.5 * (1.0 - cos(angle_deg))
        windowed[i] = signal[i] * w
    return windowed

/datum/signal_processor/proc/ComputeDFT(list/real_signal)
    // Discrete Fourier Transform: X_k = sum_{n=0}^{N-1} x_n * exp(-j * 2*pi*k*n / N)
    var/n = real_signal.len
    var/list/amplitudes = list()
    amplitudes.len = round(n / 2)

    for(var/k = 0 to (round(n / 2) - 1))
        var/real_part = 0.0
        var/imag_part = 0.0
        for(var/m = 0 to (n - 1))
            var/angle_deg = (360.0 * k * m) / n
            var/val = real_signal[m + 1]
            real_part += val * cos(angle_deg)
            imag_part -= val * sin(angle_deg)

        var/mag = sqrt((real_part * real_part) + (imag_part * imag_part)) / n
        if(k > 0) mag *= 2.0 // Single-sided spectrum factor
        amplitudes[k + 1] = mag

    return amplitudes

/datum/signal_processor/proc/ComputePowerSpectralDensity(list/signal, sample_rate_hz = 100.0)
    var/list/fft_mag = ComputeDFT(ApplyHanningWindow(signal))
    var/list/psd = list()
    psd.len = fft_mag.len
    for(var/i = 1 to fft_mag.len)
        var/mag = fft_mag[i]
        // Power spectral density (V^2 / Hz)
        psd[i] = (mag * mag) / sample_rate_hz
    return psd

/datum/signal_processor/proc/MovingAverageFIR(list/signal, window_size = 5)
    var/n = signal.len
    var/list/filtered = list()
    filtered.len = n
    var/half_w = round(window_size / 2)

    for(var/i = 1 to n)
        var/sum = 0.0
        var/count = 0
        var/start_idx = max(1, i - half_w)
        var/end_idx = min(n, i + half_w)
        for(var/k = start_idx to end_idx)
            sum += signal[k]
            count++
        filtered[i] = sum / count

    return filtered

#endif // PLENUM_LIBRARIES_SIGNAL_PROCESSING_DM
