// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Differential Drive Kinematics & Odometry Integration
// Language: Dream Maker (DM)

#ifndef PLENUM_ROBOTICS_KINEMATICS_DM
#define PLENUM_ROBOTICS_KINEMATICS_DM

#include "../core/datum.dm"

/datum/differential_kinematics
    var/wheel_radius_meters = 0.10      // 10 cm wheel
    var/track_width_meters = 0.50       // 50 cm wheelbase
    
    // Position & Heading State
    var/pos_x_meters = 0.0
    var/pos_y_meters = 0.0
    var/heading_radians = 0.0
    
    // Velocities
    var/linear_velocity_mps = 0.0
    var/angular_velocity_rad_s = 0.0
    
    // Actuator Limits
    var/max_wheel_rpm = 300.0
    var/max_linear_accel_mps2 = 1.5
    var/max_angular_accel_rad_s2 = 3.0

/datum/differential_kinematics/proc/ForwardKinematics(left_rad_s, right_rad_s)
    // Forward kinematics: v = r * (w_R + w_L) / 2
    linear_velocity_mps = wheel_radius_meters * (right_rad_s + left_rad_s) * 0.5
    // Angular velocity: omega = r * (w_R - w_L) / L
    angular_velocity_rad_s = wheel_radius_meters * (right_rad_s - left_rad_s) / track_width_meters
    return list(linear_velocity_mps, angular_velocity_rad_s)

/datum/differential_kinematics/proc/InverseKinematics(target_v, target_omega)
    // Inverse kinematics:
    // w_L = (v - omega * L / 2) / r
    // w_R = (v + omega * L / 2) / r
    var/half_l_omega = (target_omega * track_width_meters) * 0.5
    var/w_left = (target_v - half_l_omega) / wheel_radius_meters
    var/w_right = (target_v + half_l_omega) / wheel_radius_meters
    return list(w_left, w_right)

/datum/differential_kinematics/proc/IntegrateOdometryMidpoint(delta_time_seconds)
    // 2nd-order Runge-Kutta / Midpoint Integration for Dead-Reckoning
    var/delta_theta = angular_velocity_rad_s * delta_time_seconds
    var/theta_mid = heading_radians + (delta_theta * 0.5)

    var/delta_dist = linear_velocity_mps * delta_time_seconds
    var/dx = delta_dist * cos(theta_mid * 57.2957795) // DM cos expects degrees
    var/dy = delta_dist * sin(theta_mid * 57.2957795)

    pos_x_meters += dx
    pos_y_meters += dy
    heading_radians += delta_theta

    // Normalize heading to [-pi, +pi]
    var/pi = 3.14159265
    while(heading_radians > pi) heading_radians -= (2.0 * pi)
    while(heading_radians < -pi) heading_radians += (2.0 * pi)

    return list(pos_x_meters, pos_y_meters, heading_radians)

#endif // PLENUM_ROBOTICS_KINEMATICS_DM
