// Plenum: Cyber-Physical Process Control & Multi-Zone Digital Twin Engine
// Module: Global Definitions, Physical Constants, and Enums
// Language: Dream Maker (DM)

#ifndef PLENUM_DEFINES_DM
#define PLENUM_DEFINES_DM

// ============================================================================
// Physical Constants (SI Units: m, kg, s, K, mol, Pa, J, W, V, A, Ohm)
// ============================================================================

#define R_IDEAL_GAS_CONSTANT            8.314462618     // J / (mol * K)
#define STANDARD_TEMPERATURE_KELVIN     293.15          // 20 degrees Celsius in Kelvin
#define ABSOLUTE_ZERO_KELVIN            0.0             // 0 Kelvin
#define STANDARD_PRESSURE_PASCALS       101325.0        // Standard atmospheric pressure in Pa
#define STEFAN_BOLTZMANN_CONSTANT       5.670374e-8     // W / (m^2 * K^4)
#define STANDARD_GRAVITY_ACCEL          9.80665         // m / s^2
#define AVOGADRO_CONSTANT               6.02214076e23   // Particles / mol
#define AIR_SPECIFIC_HEAT_RATIO         1.400           // Diatomic gamma (Cp / Cv)
#define WATER_DENSITY_STP               998.2           // kg / m^3 at 20 C
#define WATER_LATENT_HEAT_VAPORIZATION  2257000.0       // J / kg at 100 C

// Minimum threshold constants to prevent floating point division by zero
#define EPSILON_TEMPERATURE            0.0001          // Kelvin minimum threshold
#define EPSILON_PRESSURE               0.0001          // Pascal minimum threshold
#define EPSILON_MOLES                  0.0000001       // Mole minimum threshold
#define EPSILON_VOLTAGE                0.0001          // Volt minimum threshold

// ============================================================================
// Gas Species Identifiers & Properties
// ============================================================================

#define GAS_O2                          1       // Molecular Oxygen (O2)
#define GAS_N2                          2       // Molecular Nitrogen (N2)
#define GAS_CO2                         3       // Carbon Dioxide (CO2)
#define GAS_H2O                         4       // Water Vapor (H2O)
#define GAS_H2                          5       // Molecular Hydrogen (H2)
#define GAS_CH4                         6       // Methane (CH4)
#define GAS_CO                          7       // Carbon Monoxide (CO)
#define GAS_AR                          8       // Argon (Ar)
#define GAS_SF6                         9       // Sulfur Hexafluoride (SF6)
#define GAS_R134A                       10      // 1,1,1,2-Tetrafluoroethane (R-134a)
#define GAS_SPECIES_COUNT               10

// Molar Masses (kg / mol)
#define MOLAR_MASS_O2                   0.0319988
#define MOLAR_MASS_N2                   0.0280134
#define MOLAR_MASS_CO2                  0.0440100
#define MOLAR_MASS_H2O                  0.0180153
#define MOLAR_MASS_H2                   0.0020159
#define MOLAR_MASS_CH4                  0.0160425
#define MOLAR_MASS_CO                   0.0280101
#define MOLAR_MASS_AR                   0.0399480
#define MOLAR_MASS_SF6                  0.1460600
#define MOLAR_MASS_R134A                0.1020300

// Constant-Volume Specific Heat Capacities Cv (J / (mol * K)) at 300K
#define CV_O2                           21.0
#define CV_N2                           20.8
#define CV_CO2                          28.5
#define CV_H2O                          28.0
#define CV_H2                           20.4
#define CV_CH4                          27.1
#define CV_CO                           20.9
#define CV_AR                           12.5
#define CV_SF6                          97.0
#define CV_R134A                        78.2

// Peng-Robinson Equation of State Parameters: Critical Temp (K) & Critical Pressure (Pa)
#define TC_O2                           154.58
#define PC_O2                           5043000.0
#define ACENTRIC_O2                     0.0222

#define TC_N2                           126.19
#define PC_N2                           3395800.0
#define ACENTRIC_N2                     0.0372

#define TC_CO2                          304.13
#define PC_CO2                          7377300.0
#define ACENTRIC_CO2                    0.2239

#define TC_H2O                          647.10
#define PC_H2O                          22064000.0
#define ACENTRIC_H2O                    0.3443

#define TC_H2                           33.15
#define PC_H2                           1296400.0
#define ACENTRIC_H2                    -0.2160

#define TC_CH4                          190.56
#define PC_CH4                          4599200.0
#define ACENTRIC_CH4                    0.0114

#define TC_CO                           132.86
#define PC_CO                           3494000.0
#define ACENTRIC_CO                     0.0497

#define TC_AR                           150.87
#define PC_AR                           4898000.0
#define ACENTRIC_AR                    -0.0022

#define TC_SF6                          318.72
#define PC_SF6                          3754500.0
#define ACENTRIC_SF6                    0.2100

#define TC_R134A                        374.21
#define PC_R134A                        4059300.0
#define ACENTRIC_R134A                  0.3268

// ============================================================================
// Spatial Coordinate and Direction Flags
// ============================================================================

#define DIR_NORTH                       1
#define DIR_SOUTH                       2
#define DIR_EAST                        4
#define DIR_WEST                        8
#define DIR_NORTHEAST                   5
#define DIR_NORTHWEST                   9
#define DIR_SOUTHEAST                   6
#define DIR_SOUTHWEST                   10
#define DIR_UP                          16
#define DIR_DOWN                        32

// Permeability and Conduction Bitmasks
#define PASS_NONE                       0
#define PASS_GAS                        1
#define PASS_FLUID                      2
#define PASS_ELECTRICAL                 4
#define PASS_PNEUMATIC                  8
#define PASS_ROBOTIC                    16
#define PASS_OPTICAL                    32
#define PASS_ALL                        63

// ============================================================================
// Electrical Microgrid Classifications & Thresholds
// ============================================================================

#define BUS_TYPE_PQ                     1       // Load Bus (Real & Reactive power specified)
#define BUS_TYPE_PV                     2       // Generator Bus (Real power & Voltage mag specified)
#define BUS_TYPE_SLACK                  3       // Swing / Reference Bus (Voltage mag & angle fixed)

#define BREAKER_STATE_OPEN              0
#define BREAKER_STATE_CLOSED            1
#define BREAKER_STATE_TRIPPED           2

#define SYSTEM_FREQUENCY_NOMINAL_HZ     60.0    // Nominal AC system frequency
#define VOLTAGE_TOLERANCE_PER_UNIT      0.05    // +/- 5% ANSI C84.1 Range A envelope

// ============================================================================
// Industrial Automation & SCADA Enums
// ============================================================================

#define PLC_STATE_STOPPED               0
#define PLC_STATE_RUNNING               1
#define PLC_STATE_FAULT                 2

#define ALARM_PRIORITY_LOW              1
#define ALARM_PRIORITY_MEDIUM           2
#define ALARM_PRIORITY_HIGH             3
#define ALARM_PRIORITY_CRITICAL         4

#define ALARM_STATE_NORMAL              0       // Inactive, cleared
#define ALARM_STATE_ACTIVE_UNACK        1       // Tripped, awaiting operator acknowledgment
#define ALARM_STATE_ACTIVE_ACKED        2       // Tripped and acknowledged
#define ALARM_STATE_CLEARED_UNACK       3       // Returned to normal, awaiting acknowledgment
#define ALARM_STATE_SHELVED             4       // Operator temporarily suppressed

// Modbus Function Codes
#define MODBUS_FC_READ_COILS            1
#define MODBUS_FC_READ_DISCRETE_INPUTS  2
#define MODBUS_FC_READ_HOLDING_REGS     3
#define MODBUS_FC_READ_INPUT_REGS       4
#define MODBUS_FC_WRITE_SINGLE_COIL     5
#define MODBUS_FC_WRITE_SINGLE_REG      6
#define MODBUS_FC_WRITE_MULTIPLE_COILS  15
#define MODBUS_FC_WRITE_MULTIPLE_REGS   16

// ============================================================================
// Safety Instrumented Systems (IEC 61508 / 61511)
// ============================================================================

#define SIL_RATING_NONE                 0
#define SIL_RATING_1                    1
#define SIL_RATING_2                    2
#define SIL_RATING_3                    3
#define SIL_RATING_4                    4

#define ESD_STAGE_NONE                  0
#define ESD_STAGE_WARN                  1       // Level 1: Unit warning, localized valve isolation
#define ESD_STAGE_PROCESS_TRIP          2       // Level 2: Section depressurization & equipment trip
#define ESD_STAGE_FACILITY_BLACK        3       // Level 3: Full plant blowdown, total electrical cutoff

// ============================================================================
// Robotics & Material Handling Flags
// ============================================================================

#define ROBOT_STATE_IDLE                0
#define ROBOT_STATE_NAVIGATING          1
#define ROBOT_STATE_EXECUTING_TASK      2
#define ROBOT_STATE_CHARGING            3
#define ROBOT_STATE_ESTOP               4

#define CONVEYOR_DIR_FORWARD            1
#define CONVEYOR_DIR_REVERSE           -1
#define CONVEYOR_DIR_STOPPED            0

#endif // PLENUM_DEFINES_DM
