// Scenario: SCADA False Data Injection & VFD Critical Resonance Cyberattack
//
// Simulates an Advanced Persistent Threat (APT / Stuxnet archetype) industrial
// control systems attack targeting uranium enrichment centrifuges and gas compressors.
// Intercepts Modbus TCP/IP packets to spoof normal steady-state telemetry to operator
// HMIs while surreptitiously modulating Variable Frequency Drive (VFD) PWM frequencies
// into mechanical critical resonance eigenmodes (rotor destructive whirling bands).

/datum/scenario/cyber_stuxnet
    var/name = "Industrial SCADA False Data Injection & Rotor Resonance"
    var/description = "Covert VFD drive frequency manipulation and HMI telemetry replay spoofing"
    var/duration_ticks = 300
    var/elapsed_ticks = 0
    var/active = 0

    // Actual physical equipment states
    var/actual_vfd_frequency_hz = 1000.0 // 60,000 RPM nominal
    var/actual_vibration_rms_mm_s = 1.25 // Normal smooth operation < 2.5 mm/s
    var/actual_bearing_temp_k = 338.15   // 65 C
    var/rotor_shaft_displacement_um = 12.0 // Microns

    // Spoofed HMI telemetry presented to operators
    var/spoofed_hmi_frequency_hz = 1000.0
    var/spoofed_hmi_vibration_mm_s = 1.25
    var/spoofed_hmi_bearing_temp_k = 338.15

    // Attack progression flags
    var/malware_payload_active = 0
    var/mechanical_failure_tripped = 0

/datum/scenario/cyber_stuxnet/New()
    ..()

/datum/scenario/cyber_stuxnet/proc/start_scenario()
    active = 1
    elapsed_ticks = 0
    actual_vfd_frequency_hz = 1000.0
    actual_vibration_rms_mm_s = 1.25
    malware_payload_active = 0

/datum/scenario/cyber_stuxnet/proc/step_scenario(dt_sec)
    if(!active)
        return

    elapsed_ticks++

    if(elapsed_ticks == 20)
        // Malware intercepts PLC comms and begins telemetry recording for replay loop
        malware_payload_active = 1

    if(malware_payload_active)
        // 1. Man-in-the-Middle spoofing: HMI sees frozen / low-noise benign readings
        spoofed_hmi_frequency_hz = 1000.0 + ((elapsed_ticks % 3) - 1) * 0.2
        spoofed_hmi_vibration_mm_s = 1.22 + ((elapsed_ticks % 4) * 0.02)
        spoofed_hmi_bearing_temp_k = 338.15

        // 2. Covertly overdrive VFD frequency into first critical resonance band (1410 Hz)
        if(elapsed_ticks < 150)
            actual_vfd_frequency_hz = min(actual_vfd_frequency_hz + (8.5 * dt_sec), 1410.0)
        else
            // Rapidly slam frequency down to second resonance mode (2 Hz) to induce severe torque transients
            actual_vfd_frequency_hz = max(actual_vfd_frequency_hz - (15.0 * dt_sec), 250.0)

        // 3. Mechanical rotor dynamics near resonance peak:
        // Vibration amplitude spikes exponentially as omega approaches omega_crit
        var/critical_freq = 1410.0
        var/freq_delta = abs(actual_vfd_frequency_hz - critical_freq)
        if(freq_delta < 30.0)
            // Resonance amplification: Q-factor ~ 25
            actual_vibration_rms_mm_s = min(actual_vibration_rms_mm_s + (4.5 * dt_sec), 38.0)
            rotor_shaft_displacement_um = min(rotor_shaft_displacement_um + (18.0 * dt_sec), 240.0)
            actual_bearing_temp_k += 2.5 * dt_sec

        // Catastrophic rotor casing contact if displacement exceeds 150 microns
        if(rotor_shaft_displacement_um > 150.0)
            mechanical_failure_tripped = 1

    if(elapsed_ticks >= duration_ticks)
        active = 0
