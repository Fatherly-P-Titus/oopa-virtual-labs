# Ideal vs Real Gases (Chemistry lab)

`labs/chemistry/ideal_real_gases/` – compare the ideal-gas law with the van der Waals equation; isotherms, compressibility factor Z, and departure from ideality.

## Model
- Ideal: \(PV = nRT\)
- van der Waals:
  \[
  \left(P + a\frac{n^2}{V^2}\right)(V - nb) = nRT
  \]
  Solved for \(P(V)\) at fixed \(T, n\):
  \[
  P = \frac{nRT}{V - nb} - a\frac{n^2}{V^2}
  \]
- Compressibility: \(Z = PV/(nRT)\). Ideal gas → \(Z = 1\).
- Critical constants (from \(a, b\)):
  \[
  T_c = \frac{8a}{27Rb},\quad P_c = \frac{a}{27b^2},\quad V_c = 3nb
  \]
- Reduced variables optional for corresponding-states insight.

## Gases
CO₂, N₂, O₂, H₂, He, CH₄, NH₃, H₂O(g), with literature-style \(a, b\) (L²·bar·mol⁻² and L·mol⁻¹).

## Limits
- Single-phase van der Waals isotherms (loops in the two-phase region are shown but not Maxwell-constructed).
- No virial expansion beyond van der Waals; no quantum gases.

## Files
- `scripts/irg-model.js` – ideal / van der Waals solvers.
- `scripts/ideal-real-gases.js` – isotherm chart + Z chart + controls.
- `styles/ideal-real-gases.css` – layout.
