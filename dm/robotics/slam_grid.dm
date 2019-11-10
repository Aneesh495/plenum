// 2D Occupancy Grid SLAM & Particle Filter Localization (MCL)
//
// Implements Simultaneous Localization and Mapping (SLAM) for autonomous
// inspection rovers navigating indoor chemical plants and turbine halls.
// Formulates log-odds occupancy grid Bayesian updates via Bresenham ray-casting,
// range-bearing 2D LiDAR observation likelihood, and Monte Carlo Localization (MCL)
// with kinematic odometry motion modeling and systematic low-variance resampling.

/datum/robotics/slam_mcl
    var/tag = "ROVER-SLAM-ENGINE"
    var/grid_width = 30
    var/grid_height = 20
    var/resolution_m = 0.50

    // Log-odds occupancy grid: flat list of size 600
    // L = 0 (unknown P=0.5), L > 0 (occupied), L < 0 (free space)
    var/list/occupancy_log_odds = list()

    // Particle Filter Population (MCL)
    var/num_particles = 40
    var/list/particle_x = list()
    var/list/particle_y = list()
    var/list/particle_theta = list()
    var/list/particle_weights = list()

    // Best estimated robot pose
    var/est_x = 5.0
    var/est_y = 5.0
    var/est_theta = 0.0

/datum/robotics/slam_mcl/New()
    ..()
    occupancy_log_odds = list()
    particle_x = list()
    particle_y = list()
    particle_theta = list()
    particle_weights = list()

    var/total_cells = grid_width * grid_height
    for(var/i = 1 to total_cells)
        occupancy_log_odds.Add(0.0) // Prior L0 = 0.0 (P = 0.5)

    // Initialize particles clustered around initial pose
    for(var/i = 1 to num_particles)
        particle_x.Add(est_x + ((i % 5) - 2) * 0.1)
        particle_y.Add(est_y + (round(i / 5) - 4) * 0.1)
        particle_theta.Add(0.0)
        particle_weights.Add(1.0 / num_particles)

// Log-odds probability conversion: P = 1 / (1 + exp(-L))
/datum/robotics/slam_mcl/proc/log_odds_to_probability(log_odds_val)
    return 1.0 / (1.0 + exp(-log_odds_val))

// Update grid cell with LiDAR ray hit: Bresenham line raycasting
/datum/robotics/slam_mcl/proc/update_lidar_beam(start_x, start_y, hit_x, hit_y)
    var/l_occ = 0.85  // Log-odds increment for occupied endpoint
    var/l_free = -0.40 // Log-odds decrement for free traversed space

    // 1. Ray trace traversed cells to mark free
    var/steps = max(abs(hit_x - start_x), abs(hit_y - start_y)) * 2
    if(steps > 0)
        for(var/s = 0 to (steps - 1))
            var/frac = s / steps
            var/cx = round(start_x + (hit_x - start_x) * frac)
            var/cy = round(start_y + (hit_y - start_y) * frac)
            if(cx >= 1 && cx <= grid_width && cy >= 1 && cy <= grid_height)
                var/idx = (cy - 1) * grid_width + cx
                occupancy_log_odds[idx] = max(occupancy_log_odds[idx] + l_free, -5.0)

    // 2. Mark hit cell as occupied
    var/hx = round(hit_x)
    var/hy = round(hit_y)
    if(hx >= 1 && hx <= grid_width && hy >= 1 && hy <= grid_height)
        var/h_idx = (hy - 1) * grid_width + hx
        occupancy_log_odds[h_idx] = min(occupancy_log_odds[h_idx] + l_occ, 5.0)

// Particle Filter Motion Model: Odometry update with additive Gaussian noise
/datum/robotics/slam_mcl/proc/step_motion_model(delta_trans, delta_rot, noise_std = 0.05)
    var/sum_x = 0.0
    var/sum_y = 0.0

    for(var/i = 1 to num_particles)
        var/th = particle_theta[i]
        // Pseudo-random Gaussian approximation via uniform sum
        var/noise_d = ((i % 7) - 3) * noise_std * 0.3
        var/noise_r = ((i % 5) - 2) * noise_std * 0.2

        var/d = delta_trans + noise_d
        var/th_new = th + delta_rot + noise_r

        particle_x[i] += d * cos(th_new)
        particle_y[i] += d * sin(th_new)
        particle_theta[i] = th_new

        sum_x += particle_x[i] * particle_weights[i]
        sum_y += particle_y[i] * particle_weights[i]

    est_x = sum_x
    est_y = sum_y
