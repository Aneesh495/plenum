// Hamilton Unit Quaternions and 3D Attitude Kinematics
//
// Provides 4D hypercomplex quaternion algebra (q = w + xi + yj + zk)
// for singularity-free 3D spatial rotation, attitude estimation,
// Spherical Linear Interpolation (SLERP), and Euler angle transformations
// used in autonomous aerial drone flight and 6-DOF robotic arm kinematics.

/datum/math/quaternion
    var/w = 1.0
    var/x = 0.0
    var/y = 0.0
    var/z = 0.0

/datum/math/quaternion/New(qw = 1.0, qx = 0.0, qy = 0.0, qz = 0.0)
    ..()
    w = qw
    x = qx
    y = qy
    z = qz

/datum/math/quaternion/proc/set_components(qw, qx, qy, qz)
    w = qw
    x = qx
    y = qy
    z = qz

/datum/math/quaternion/proc/norm()
    return sqrt((w * w) + (x * x) + (y * y) + (z * z))

/datum/math/quaternion/proc/normalize()
    var/n = norm()
    if(n > 1e-12)
        w = w / n
        x = x / n
        y = y / n
        z = z / n
    else
        w = 1.0
        x = 0.0
        y = 0.0
        z = 0.0
    return src

/datum/math/quaternion/proc/conjugate()
    var/datum/math/quaternion/q_conj = new /datum/math/quaternion(w, -x, -y, -z)
    return q_conj

// Hamilton product: q1 * q2
/datum/math/quaternion/proc/multiply(datum/math/quaternion/q2)
    var/nw = (w * q2.w) - (x * q2.x) - (y * q2.y) - (z * q2.z)
    var/nx = (w * q2.x) + (x * q2.w) + (y * q2.z) - (z * q2.y)
    var/ny = (w * q2.y) - (x * q2.z) + (y * q2.w) + (z * q2.x)
    var/nz = (w * q2.z) + (x * q2.y) - (y * q2.x) + (z * q2.w)

    var/datum/math/quaternion/res = new /datum/math/quaternion(nw, nx, ny, nz)
    return res

// Create quaternion from Axis-Angle (axis vector + angle in radians)
/datum/math/quaternion/proc/from_axis_angle(ax, ay, az, angle_rad)
    var/mag = sqrt((ax * ax) + (ay * ay) + (az * az))
    if(mag <= 1e-12)
        w = 1.0
        x = 0.0
        y = 0.0
        z = 0.0
        return src

    var/half_angle = angle_rad * 0.5
    var/s = sin(half_angle) / mag
    w = cos(half_angle)
    x = ax * s
    y = ay * s
    z = az * s
    normalize()
    return src

// Create quaternion from Euler angles: roll (X), pitch (Y), yaw (Z) in radians
/datum/math/quaternion/proc/from_euler(roll, pitch, yaw)
    var/cr = cos(roll * 0.5)
    var/sr = sin(roll * 0.5)
    var/cp = cos(pitch * 0.5)
    var/sp = sin(pitch * 0.5)
    var/cy = cos(yaw * 0.5)
    var/sy = sin(yaw * 0.5)

    w = (cr * cp * cy) + (sr * sp * sy)
    x = (sr * cp * cy) - (cr * sp * sy)
    y = (cr * sp * cy) + (sr * cp * sy)
    z = (cr * cp * sy) - (sr * sp * cy)
    normalize()
    return src

// Convert to Euler angles: returns list("roll", "pitch", "yaw") in radians
/datum/math/quaternion/proc/to_euler()
    // Roll (x-axis rotation)
    var/sinr_cosp = 2.0 * ((w * x) + (y * z))
    var/cosr_cosp = 1.0 - (2.0 * ((x * x) + (y * y)))
    var/roll = arctan2(sinr_cosp, cosr_cosp)

    // Pitch (y-axis rotation)
    var/sinp = 2.0 * ((w * y) - (z * x))
    var/pitch = 0.0
    if(abs(sinp) >= 1.0)
        pitch = (sinp >= 0 ? 1.0 : -1.0) * (3.141592653589793 * 0.5) // Gimbal lock clamp
    else
        pitch = arcsin(sinp)

    // Yaw (z-axis rotation)
    var/siny_cosp = 2.0 * ((w * z) + (x * y))
    var/cosy_cosp = 1.0 - (2.0 * ((y * y) + (z * z)))
    var/yaw = arctan2(siny_cosp, cosy_cosp)

    return list("roll" = roll, "pitch" = pitch, "yaw" = yaw)

// Rotate a 3D vector v = (vx, vy, vz) by this quaternion: v' = q * v * q_conj
/datum/math/quaternion/proc/rotate_vector(vx, vy, vz)
    // Formula: v' = v + 2 * cross(q.xyz, cross(q.xyz, v) + q.w * v)
    var/tx = 2.0 * ((y * vz) - (z * vy))
    var/ty = 2.0 * ((z * vx) - (x * vz))
    var/tz = 2.0 * ((x * vy) - (y * vx))

    var/cx = (y * tz) - (z * ty)
    var/cy = (z * tx) - (x * tz)
    var/cz = (x * ty) - (y * tx)

    var/rx = vx + (w * tx) + cx
    var/ry = vy + (w * ty) + cy
    var/rz = vz + (w * tz) + cz

    return list(rx, ry, rz)

// Spherical Linear Interpolation (SLERP) between q1 and q2 with parameter t in [0, 1]
/datum/math/quaternion/proc/slerp(datum/math/quaternion/q2, t)
    var/cos_half_theta = (w * q2.w) + (x * q2.x) + (y * q2.y) + (z * q2.z)

    var/target_w = q2.w
    var/target_x = q2.x
    var/target_y = q2.y
    var/target_z = q2.z

    // If negative dot product, invert target to take shortest geodesic path
    if(cos_half_theta < 0.0)
        cos_half_theta = -cos_half_theta
        target_w = -target_w
        target_x = -target_x
        target_y = -target_y
        target_z = -target_z

    if(abs(cos_half_theta) >= 1.0)
        // Quaternions are identical: return copy
        var/datum/math/quaternion/res = new /datum/math/quaternion(w, x, y, z)
        return res

    var/half_theta = arccos(cos_half_theta)
    var/sin_half_theta = sqrt(1.0 - (cos_half_theta * cos_half_theta))

    var/datum/math/quaternion/res = new /datum/math/quaternion()
    if(abs(sin_half_theta) < 0.001)
        // Linear interpolation when angle is very small
        res.w = (w * (1.0 - t)) + (target_w * t)
        res.x = (x * (1.0 - t)) + (target_x * t)
        res.y = (y * (1.0 - t)) + (target_y * t)
        res.z = (z * (1.0 - t)) + (target_z * t)
        res.normalize()
    else
        var/ratio_a = sin((1.0 - t) * half_theta) / sin_half_theta
        var/ratio_b = sin(t * half_theta) / sin_half_theta
        res.w = (w * ratio_a) + (target_w * ratio_b)
        res.x = (x * ratio_a) + (target_x * ratio_b)
        res.y = (y * ratio_a) + (target_y * ratio_b)
        res.z = (z * ratio_a) + (target_z * ratio_b)

    return res

/datum/math/quaternion/proc/arctan2(y_val, x_val)
    if(abs(x_val) < 1e-12)
        if(y_val > 0.0) return 3.141592653589793 * 0.5
        if(y_val < 0.0) return -3.141592653589793 * 0.5
        return 0.0
    var/ang = arctan(y_val / x_val)
    if(x_val < 0.0)
        ang += (y_val >= 0.0 ? 3.141592653589793 : -3.141592653589793)
    return ang

/datum/math/quaternion/proc/arcsin(val)
    var/clamped = min(max(val, -1.0), 1.0)
    if(clamped == 1.0) return 3.141592653589793 * 0.5
    if(clamped == -1.0) return -3.141592653589793 * 0.5
    return arctan(clamped / sqrt(1.0 - (clamped * clamped)))

/datum/math/quaternion/proc/arccos(val)
    var/clamped = min(max(val, -1.0), 1.0)
    return (3.141592653589793 * 0.5) - arcsin(clamped)
