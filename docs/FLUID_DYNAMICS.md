# Fluid Dynamics (Engineering lab)

`labs/engineering/fluid_dynamics/` – steady incompressible pipe flow: continuity, Bernoulli and a simple venturi.

## Model
- Incompressible continuity: \(A_1 v_1 = A_2 v_2 = Q\)
- Bernoulli along a streamline (ideal, no losses):
  \[
  \frac{p}{\rho} + \frac{v^2}{2} + gz = \text{constant}
  \]
- With a head-loss term between stations: \(h_L = f \frac{L}{D}\frac{v^2}{2g}\) (Darcy–Weisbach, single factor \(f\)).
- Venturi: two sections (inlet diameter \(D_1\), throat \(D_2\)) at heights \(z_1\), \(z_2\). Given \(Q\) (or \(v_1\)), solve pressures from Bernoulli + optional \(h_L\).

## Limits
- Steady, 1D, incompressible liquid. No compressibility, no free surface waves.
- Friction is a single lumped factor, not a full Moody chart.
- No pumps, turbines or unsteady effects.

## Files
- `scripts/fluid-model.js` – pure formulae.
- `scripts/fluid-dynamics.js` – pipe diagram + controls.
- `styles/fluid-dynamics.css` – layout.
