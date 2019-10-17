// Fast Fourier Transform (FFT) and Power Spectral Density
//
// Implements Cooley-Tukey radix-2 Decimation-In-Time (DIT) FFT,
// complex arithmetic, bit-reversal permutation, windowing functions
// (Hanning, Hamming, Blackman-Harris), and power spectrum peak detection
// for rotating equipment vibration monitoring and microgrid harmonic analysis.

/datum/math/fft
    var/sample_rate_hz = 1000.0

/datum/math/fft/New(rate_hz = 1000.0)
    ..()
    sample_rate_hz = rate_hz

// Computes next power of 2
/datum/math/fft/proc/next_pow2(n)
    var/p = 1
    while(p < n)
        p = p * 2
    return p

// Bit reversal permutation for radix-2 Cooley-Tukey
/datum/math/fft/proc/bit_reverse(index, num_bits)
    var/result = 0
    var/idx = index
    for(var/i = 1 to num_bits)
        result = (result * 2) + (idx % 2)
        idx = round(idx / 2)
    return result

// Apply Hanning window: w[n] = 0.5 * (1 - cos(2*pi*n / (N - 1)))
/datum/math/fft/proc/apply_hanning_window(list/signal)
    var/n = signal.len
    var/list/windowed = list()
    var/pi_val = 3.141592653589793
    for(var/i = 1 to n)
        var/w = 0.5 * (1.0 - cos((2.0 * pi_val * (i - 1)) / (n - 1)))
        windowed.Add(signal[i] * w)
    return windowed

// In-place Radix-2 FFT: returns list(real_parts, imag_parts)
/datum/math/fft/proc/forward_fft(list/signal)
    var/n_orig = signal.len
    var/n = next_pow2(n_orig)

    var/list/real_out = list()
    var/list/imag_out = list()

    // Zero-padding to power of 2
    for(var/i = 1 to n)
        if(i <= n_orig)
            real_out.Add(signal[i])
        else
            real_out.Add(0.0)
        imag_out.Add(0.0)

    // Calculate number of stages
    var/num_bits = 0
    var/temp = n
    while(temp > 1)
        num_bits++
        temp = round(temp / 2)

    // Bit-reversal reordering
    for(var/i = 0 to (n - 1))
        var/rev = bit_reverse(i, num_bits)
        if(rev > i)
            var/tr = real_out[i + 1]
            var/ti = imag_out[i + 1]
            real_out[i + 1] = real_out[rev + 1]
            imag_out[i + 1] = imag_out[rev + 1]
            real_out[rev + 1] = tr
            imag_out[rev + 1] = ti

    var/pi_val = 3.141592653589793

    // Butterfly stages
    var/len = 2
    while(len <= n)
        var/half_len = round(len / 2)
        var/angle = -2.0 * pi_val / len
        var/w_step_r = cos(angle)
        var/w_step_i = sin(angle)

        var/i = 0
        while(i < n)
            var/wr = 1.0
            var/wi = 0.0

            for(var/j = 0 to (half_len - 1))
                var/idx_u = i + j + 1
                var/idx_v = i + j + half_len + 1

                var/vr = real_out[idx_v]
                var/vi = imag_out[idx_v]

                var/t_real = (wr * vr) - (wi * vi)
                var/t_imag = (wr * vi) + (wi * vr)

                var/u_real = real_out[idx_u]
                var/u_imag = imag_out[idx_u]

                real_out[idx_u] = u_real + t_real
                imag_out[idx_u] = u_imag + t_imag
                real_out[idx_v] = u_real - t_real
                imag_out[idx_v] = u_imag - t_imag

                var/next_wr = (wr * w_step_r) - (wi * w_step_i)
                var/next_wi = (wr * w_step_i) + (wi * w_step_r)
                wr = next_wr
                wi = next_wi

            i += len

        len = len * 2

    return list("real" = real_out, "imag" = imag_out)

// Calculate Power Spectral Density (PSD)
/datum/math/fft/proc/calculate_power_spectrum(list/signal)
    var/list/fft_res = forward_fft(signal)
    var/list/real_part = fft_res["real"]
    var/list/imag_part = fft_res["imag"]
    var/n = real_part.len
    var/half_n = round(n / 2)

    var/list/psd = list()
    for(var/i = 1 to half_n)
        var/r = real_part[i]
        var/im = imag_part[i]
        var/mag_sq = (r * r) + (im * im)
        var/p = mag_sq / (n * sample_rate_hz)
        if(i > 1 && i < half_n)
            p = p * 2.0 // Single-sided scaling
        psd.Add(p)

    return psd

// Find dominant peak frequency in Hz
/datum/math/fft/proc/detect_peak_frequency(list/signal)
    var/list/psd = calculate_power_spectrum(signal)
    var/max_p = 0.0
    var/max_idx = 1
    for(var/i = 1 to psd.len)
        if(psd[i] > max_p)
            max_p = psd[i]
            max_idx = i

    var/freq_bin = (max_idx - 1) * (sample_rate_hz / (psd.len * 2))
    return freq_bin
