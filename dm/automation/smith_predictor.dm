// Smith Predictor Dead-Time Compensator for Long Transport Delays
//
// Implements O.J.M. Smith dead-time compensation architecture for pipelines,
// chemical plug-flow reactors, and reboilers where time delay theta exceeds
// the dominant process time constant (theta / tau > 1.0). Eliminates phase lag
// from the inner feedback loop by subtracting the delayed internal model response
// and feeding back the fast delay-free predictive model estimate.

/datum/automation/smith_predictor
    var/tag = "DEADTIME-SMITH-PREDICTOR"
    var/process_gain_k = 2.4
    var/time_constant_tau_sec = 15.0
    var/dead_time_theta_sec = 45.0 // 45 seconds transport lag
    var/sample_dt_sec = 1.0

    // Internal model states
    var/y_fast_model = 0.0    // Delay-free model response: G0(s)
    var/y_delayed_model = 0.0 // Delayed model response: G0(s) * exp(-theta * s)

    // Delay ring buffer
    var/list/delay_ring_buffer = list()
    var/buffer_size = 45
    var/buffer_head = 1

    // Integrated PID controller
    var/datum/automation/pid_controller/internal_pid = null

/datum/automation/smith_predictor/New()
    ..()
    internal_pid = new /datum/automation/pid_controller()
    internal_pid.kp = 1.8
    internal_pid.ti = 12.0
    internal_pid.td = 0.5
    internal_pid.output_min = 0.0
    internal_pid.output_max = 100.0

    delay_ring_buffer = list()
    buffer_size = round(dead_time_theta_sec / sample_dt_sec)
    for(var/i = 1 to buffer_size)
        delay_ring_buffer.Add(0.0)

// Step Smith Predictor and return controller output u(t)
/datum/automation/smith_predictor/proc/step_predictor(actual_process_pv, setpoint_sp, dt_sec)
    // 1. Fast delay-free model integration (First-order ODE: tau * dy/dt + y = K * u)
    var/u_curr = internal_pid.current_output
    var/dy_fast = ((process_gain_k * u_curr - y_fast_model) / max(time_constant_tau_sec, 0.1)) * dt_sec
    y_fast_model += dy_fast

    // 2. Read delayed model response from ring buffer
    y_delayed_model = delay_ring_buffer[buffer_head]

    // Store newest fast model output in ring buffer
    delay_ring_buffer[buffer_head] = y_fast_model
    buffer_head++
    if(buffer_head > buffer_size)
        buffer_head = 1

    // 3. Model mismatch / disturbance estimate: d_hat = actual_pv - y_delayed_model
    var/disturbance_estimate = actual_process_pv - y_delayed_model

    // 4. Effective feedback to primary controller: y_feedback = y_fast_model + d_hat
    var/effective_feedback = y_fast_model + disturbance_estimate

    // 5. Execute internal PID scan on compensated feedback signal
    var/u_new = internal_pid.compute_pid(effective_feedback, setpoint_sp, dt_sec)
    return u_new
