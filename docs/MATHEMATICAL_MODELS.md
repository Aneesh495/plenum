# Mathematical Models and Numerical Formulations

This document provides rigorous mathematical derivations and numerical implementations for the core physical models in the Plenum digital twin engine.

---

## 1. Real Gas Thermodynamics: Peng-Robinson Cubic EOS

The Peng-Robinson Equation of State (PR-EOS) is formulated as:

$$P = \frac{R T}{v - b} - \frac{a(T)}{v(v + b) + b(v - b)}$$

where:
- $P$ is absolute pressure (Pa)
- $T$ is absolute temperature (K)
- $v$ is molar volume ($m^3 / \mathrm{mol}$)
- $R = 8.314462618 \text{ J} / (\mathrm{mol} \cdot \mathrm{K})$ is the universal gas constant

### Parameter Calculations
For pure component $i$:

$$a_i(T) = 0.45724 \cdot \frac{R^2 T_{c,i}^2}{P_{c,i}} \cdot \alpha_i(T)$$

$$b_i = 0.07780 \cdot \frac{R T_{c,i}}{P_{c,i}}$$

The temperature-dependent dimensionless function $\alpha_i(T)$ is:

$$\alpha_i(T) = \left[ 1 + m_i \cdot \left(1 - \sqrt{\frac{T}{T_{c,i}}}\right) \right]^2$$

$$m_i = 0.37464 + 1.54226 \cdot \omega_i - 0.26992 \cdot \omega_i^2$$

where $\omega_i$ is Pitzer's acentric factor.

### van der Waals Mixing Rules
For multi-component mixtures:

$$b = \sum_{i=1}^{C} x_i b_i$$

$$a = \sum_{i=1}^{C} \sum_{j=1}^{C} x_i x_j \sqrt{a_i a_j} (1 - k_{ij})$$

where $k_{ij}$ represents the empirical binary interaction parameter.

### Cubic Polynomial in Compressibility Factor $Z$
Expressing the equation in dimensionless form with $Z = \frac{P v}{R T}$, $A = \frac{a P}{(R T)^2}$, and $B = \frac{b P}{R T}$:

$$Z^3 - (1 - B) Z^2 + (A - 3B^2 - 2B) Z - (AB - B^2 - B^3) = 0$$

Plenum solves this cubic polynomial using Cardano's analytical method, selecting the maximum real root for the vapor phase ($Z_V$) and the minimum real root for the liquid phase ($Z_L$).

---

## 2. Pipe Hydraulics & Water Hammer

### 2.1 Friction Factor: Swamee-Jain Approximation
Turbulent flow friction factor $f$ across conduits with roughness $\varepsilon$ and diameter $D$ is computed directly via:

$$f = \frac{0.25}{\left[\log_{10}\left(\frac{\varepsilon / D}{3.7} + \frac{5.74}{\mathrm{Re}^{0.9}}\right)\right]^2}$$

For laminar conditions ($\mathrm{Re} < 2300$), the Hagen-Poiseuille analytical solution is utilized:

$$f = \frac{64}{\mathrm{Re}}$$

### 2.2 Method of Characteristics (MOC)
The 1D continuity and momentum conservation equations for elastic pressurized conduit flow are:

$$\frac{\partial H}{\partial t} + \frac{a^2}{g A} \frac{\partial Q}{\partial x} = 0$$

$$\frac{\partial Q}{\partial t} + g A \frac{\partial H}{\partial x} + \frac{f Q |Q|}{2 D A} = 0$$

Multiplying the continuity equation by an unknown multiplier $\lambda$ and combining yields characteristic directional equations along paths $\frac{dx}{dt} = \pm a$:

$$C^+: \frac{g}{a} \frac{dH}{dt} + \frac{1}{A} \frac{dQ}{dt} + \frac{f Q |Q|}{2 D A^2} = 0 \quad \text{along } \frac{dx}{dt} = +a$$

$$C^-: -\frac{g}{a} \frac{dH}{dt} + \frac{1}{A} \frac{dQ}{dt} + \frac{f Q |Q|}{2 D A^2} = 0 \quad \text{along } \frac{dx}{dt} = -a$$

Integrating along grid reaches of length $\Delta x = a \cdot \Delta t$ gives the finite-difference solver:

$$H_P = \frac{C_P + C_M}{2}$$

$$Q_P = \frac{C_P - C_M}{2 B}$$

where $B = \frac{a}{g A}$ is pipe acoustic characteristic impedance.

---

## 3. Fast Decoupled Load Flow (FDLF)

For an $N$-bus power grid, active power $P_i$ and reactive power $Q_i$ injection equations are:

$$P_i = V_i \sum_{j=1}^{N} V_j (G_{ij} \cos \theta_{ij} + B_{ij} \sin \theta_{ij})$$

$$Q_i = V_i \sum_{j=1}^{N} V_j (G_{ij} \sin \theta_{ij} - B_{ij} \cos \theta_{ij})$$

Assuming high voltage transmission lines where $R \ll X$, voltage angles $\theta_{ij} \approx 0$, and bus voltage magnitudes $V_i \approx 1.0 \text{ pu}$:
1. Active power changes $\Delta P$ decouple from voltage magnitudes and depend predominantly on bus angle changes $\Delta \theta$.
2. Reactive power changes $\Delta Q$ decouple from bus angles and depend predominantly on voltage magnitude changes $\Delta V$.

The Stott and Alsac Fast Decoupled Load Flow equations become:

$$\left[ \frac{\Delta P}{V} \right] = \left[ B' \right] \left[ \Delta \theta \right]$$

$$\left[ \frac{\Delta Q}{V} \right] = \left[ B'' \right] \left[ \Delta V \right]$$

where $B'$ and $B''$ are constant, symmetric matrices formed from the imaginary parts of the nodal admittance matrix $Y_{\mathrm{bus}}$, inverted once during system initialization.

---

## 4. Multi-Phase Pipeline Flow: Beggs and Brill Method

In two-phase gas-liquid flow, liquid holdup $H_L$ differs from the no-slip liquid volume fraction $\lambda_L = \frac{q_L}{q_L + q_G}$ due to gas slippage.

### Flow Regime Determination
The flow regime is determined by comparing input liquid fraction $\lambda_L$ and mixture Froude number $\mathrm{Fr}_m = \frac{v_m^2}{g D}$ against empirical boundary limits:

$$L_1 = 316 \cdot \lambda_L^{0.302}, \quad L_2 = 0.0009252 \cdot \lambda_L^{-2.4684}$$

$$L_3 = 0.10 \cdot \lambda_L^{-1.4516}, \quad L_4 = 0.50 \cdot \lambda_L^{-6.738}$$

### Inclined Pipe Holdup Correction
Horizontal holdup $H_L(0)$ is computed via:

$$H_L(0) = \frac{a \cdot \lambda_L^b}{\mathrm{Fr}_m^c}$$

The actual inclined liquid holdup $H_L(\theta)$ at pipe elevation angle $\theta$ is:

$$H_L(\theta) = H_L(0) \cdot \left[ 1 + C \cdot (\sin(1.8\theta) - 0.333 \sin^3(1.8\theta)) \right]$$

---

## 5. Nuclear Neutronics: Point Kinetics with 6 Delayed Groups

The Point Reactor Kinetics Equations (PRKE) model the balance between prompt neutron fission, delayed neutron precursor decay, and thermal reactivity feedbacks:

$$\frac{dn(t)}{dt} = \frac{\rho(t) - \beta_{\mathrm{eff}}}{\Lambda} n(t) + \sum_{i=1}^{6} \lambda_i C_i(t)$$

$$\frac{dC_i(t)}{dt} = \frac{\beta_i}{\Lambda} n(t) - \lambda_i C_i(t), \quad i = 1, \dots, 6$$

Reactivity $\rho(t)$ includes control rod insertion and thermal feedbacks:

$$\rho(t) = \rho_{\mathrm{rods}} + \alpha_f (T_{\mathrm{fuel}} - T_{\mathrm{ref}}) + \alpha_m (T_{\mathrm{mod}} - T_{\mathrm{ref}}) + \rho_{\mathrm{Xe}}$$

Xenon-135 poisoning dynamics follow the Iodine-Xenon decay chain:

$$\frac{d[I]}{dt} = \gamma_I \Sigma_f \phi - \lambda_I [I]$$

$$\frac{d[\mathrm{Xe}]}{dt} = \gamma_{\mathrm{Xe}} \Sigma_f \phi + \lambda_I [I] - \lambda_{\mathrm{Xe}} [\mathrm{Xe}] - \sigma_a^{\mathrm{Xe}} \phi [\mathrm{Xe}]$$
