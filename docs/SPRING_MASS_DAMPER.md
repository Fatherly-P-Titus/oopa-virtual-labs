# Spring–Mass–Damper (Engineering lab)

`labs/engineering/spring_mass_damper/` – single-degree-of-freedom vibration: free and forced response.

## Model
Equation of motion:

\[
m\ddot{x} + c\dot{x} + kx = F(t)
\]

- Natural frequency: \(\omega_n = \sqrt{k/m}\)
- Damping ratio: \(\zeta = c / (2\sqrt{km})\)
- Free response regimes: underdamped (\(\zeta < 1\)), critically damped (\(\zeta = 1\)), overdamped (\(\zeta > 1\))
- Forced input: \(F(t) = F_0\cos(\omega t)\) (optional). Steady-state amplitude uses the standard magnification factor.

Time integration: fixed-step RK4 on the state \((x, v)\).

## Limits
- Linear spring and viscous damper only.
- One DOF; no multi-mass chains or continuous beams.
- No coulomb friction, backlash or geometric nonlinearity.

## Files
- `scripts/smd-model.js` – pure dynamics (`window.SMDModel`).
- `scripts/smd.js` – animation, strip chart, controls.
- `styles/smd.css` – layout.
