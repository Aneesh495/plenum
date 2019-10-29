// Compressible Gas Dynamics in Ducts: Fanno and Rayleigh Flow
//
// Implements 1D compressible fluid dynamics for high-velocity industrial gas piping,
// relief headers, and burner fuel supply lines. Formulates adiabatic flow with wall
// friction (Fanno flow), frictionless flow with heat addition (Rayleigh flow),
// Mach number progression, sonic choking limits (M = 1.0), and stagnation pressure loss.

/datum/hydraulics/compressible_duct
    var/tag = "COMPRESSIBLE-DUCT-01"
    var/duct_diameter_m = 0.40
    var/duct_length_m = 150.0
    var/darcy_friction_factor = 0.016

    // Gas Properties (Air / Natural Gas)
    var/gas_gamma = 1.40 // Heat capacity ratio Cp / Cv
    var/gas_r_specific = 287.05 // J / (kg * K)

    // Inlet Conditions
    var/inlet_mach = 0.25
    var/inlet_static_press_pa = 500000.0 // 5 bar
    var/inlet_static_temp_k = 300.0
    var/inlet_stagnation_press_pa = 522000.0
    var/inlet_stagnation_temp_k = 303.75

    // Outlet States
    var/outlet_mach = 0.48
    var/outlet_static_press_pa = 245000.0
    var/outlet_static_temp_k = 288.5
    var/choked = 0
    var/max_choked_mass_flow_kg_s = 65.5

/datum/hydraulics/compressible_duct/New()
    ..()

// Acoustic speed of sound: c = sqrt(gamma * R * T)
/datum/hydraulics/compressible_duct/proc/speed_of_sound(temp_k)
    return sqrt(gas_gamma * gas_r_specific * max(temp_k, 1.0))

// Stagnation (Total) Temperature: T0 = T * (1 + (gamma - 1)/2 * M^2)
/datum/hydraulics/compressible_duct/proc/stagnation_temp(static_t, mach)
    var/factor = 1.0 + (((gas_gamma - 1.0) * 0.5) * (mach * mach))
    return static_t * factor

// Stagnation (Total) Pressure: P0 = P * (1 + (gamma - 1)/2 * M^2)^(gamma / (gamma - 1))
/datum/hydraulics/compressible_duct/proc/stagnation_pressure(static_p, mach)
    var/base = 1.0 + (((gas_gamma - 1.0) * 0.5) * (mach * mach))
    var/exponent = gas_gamma / (gas_gamma - 1.0)
    return static_p * exp(exponent * log(max(base, 1.0)))

// Fanno flow friction parameter to sonic choke:
// 4 * f * L* / D = (1 - M^2) / (gamma * M^2) + (gamma + 1) / (2 * gamma) * ln(((gamma + 1) * M^2) / (2 * (1 + (gamma - 1)/2 * M^2)))
/datum/hydraulics/compressible_duct/proc/fanno_parameter(mach)
    var/m = min(max(mach, 0.01), 0.999)
    var/m2 = m * m
    var/g = gas_gamma
    var/term1 = (1.0 - m2) / (g * m2)
    var/num = (g + 1.0) * m2
    var/den = 2.0 * (1.0 + (((g - 1.0) * 0.5) * m2))
    var/term2 = ((g + 1.0) / (2.0 * g)) * log(num / den)
    return term1 + term2

// Step compressible Fanno flow along duct length
/datum/hydraulics/compressible_duct/proc/step_fanno(mass_flow_kg_s)
    var/area = 3.14159 * (duct_diameter_m * 0.5) * (duct_diameter_m * 0.5)

    // Inlet acoustic and Mach calculation
    var/rho_in = inlet_static_press_pa / (gas_r_specific * inlet_static_temp_k)
    var/v_in = mass_flow_kg_s / (rho_in * area)
    var/c_in = speed_of_sound(inlet_static_temp_k)
    inlet_mach = min(v_in / max(c_in, 1.0), 0.95)

    // Maximum duct length before choking (L*)
    var/fanning_f = darcy_friction_factor * 0.25
    var/fanno_in = fanno_parameter(inlet_mach)
    var/l_star_max = (fanno_in * duct_diameter_m) / (4.0 * fanning_f)

    if(duct_length_m >= l_star_max)
        // Duct is sonically choked at the exit (M_out = 1.0)
        choked = 1
        outlet_mach = 1.0
        // Maximum choked mass flow rate through duct
        var/t0 = inlet_stagnation_temp_k
        var/p0 = inlet_stagnation_press_pa
        var/g = gas_gamma
        var/choke_constant = sqrt(g / gas_r_specific) * exp(((g + 1.0) / (2.0 * (1.0 - g))) * log((g + 1.0) * 0.5))
        max_choked_mass_flow_kg_s = (p0 * area / sqrt(max(t0, 1.0))) * choke_constant
    else
        choked = 0
        // Calculate outlet Mach number by finding M_out such that:
        // 4*f*L/D = fanno(M_in) - fanno(M_out)
        var/delta_fanno = (4.0 * fanning_f * duct_length_m) / duct_diameter_m
        var/fanno_out_target = max(fanno_in - delta_fanno, 0.0)

        // Simple Newton-Raphson inversion to find M_out
        var/m_guess = inlet_mach + 0.15
        for(var/iter = 1 to 5)
            var/f_val = fanno_parameter(m_guess)
            var/err = f_val - fanno_out_target
            m_guess = min(max(m_guess + (err * 0.1), inlet_mach), 0.99)
        outlet_mach = m_guess

    // Static pressure and temperature ratios in Fanno flow:
    // T / T* = (gamma + 1) / (2 * (1 + (gamma - 1)/2 * M^2))
    // P / P* = (1 / M) * sqrt(T / T*)
    var/g_f = gas_gamma
    var/t_ratio_in = (g_f + 1.0) / (2.0 * (1.0 + (((g_f - 1.0) * 0.5) * (inlet_mach * inlet_mach))))
    var/t_ratio_out = (g_f + 1.0) / (2.0 * (1.0 + (((g_f - 1.0) * 0.5) * (outlet_mach * outlet_mach))))
    outlet_static_temp_k = inlet_static_temp_k * (t_ratio_out / max(t_ratio_in, 1e-4))

    var/p_ratio_in = (1.0 / max(inlet_mach, 0.01)) * sqrt(t_ratio_in)
    var/p_ratio_out = (1.0 / max(outlet_mach, 0.01)) * sqrt(t_ratio_out)
    outlet_static_press_pa = inlet_static_press_pa * (p_ratio_out / max(p_ratio_in, 1e-4))
