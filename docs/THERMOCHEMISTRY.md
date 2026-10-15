# Thermochemistry / Hess’s Law (Chemistry lab)

`labs/chemistry/thermochemistry/` – standard enthalpies of formation, Hess’s-law cycles and bond-enthalpy estimates.

## Modes
1. **Formation enthalpies** — \(\Delta H^\circ_{\mathrm{rxn}} = \sum \nu \Delta H_f^\circ(\mathrm{products}) - \sum \nu \Delta H_f^\circ(\mathrm{reactants})\).
2. **Hess’s law cycle** — algebraically combine given thermochemical equations (reverse, scale, add) to obtain a target \(\Delta H\).
3. **Bond enthalpies** — estimate \(\Delta H\) from bonds broken − bonds formed (approximate, gas-phase).

## Data
- Standard \(\Delta H_f^\circ\) (kJ/mol) for common elements and compounds at 298 K.
- Average bond enthalpies (kJ/mol) for common bonds.
- Built-in target reactions and step libraries for classic Hess demonstrations (e.g. C → CO → CO₂, formation of CH₄).

## Limits
- Standard-state values only; no temperature dependence (Kirchhoff).
- Bond method ignores resonance, strain and phase changes beyond the tabulated averages.
- Cycle solver is exact arithmetic on the provided steps (no regression / least-squares).

## Files
- `scripts/thermochemistry-model.js` – formation, cycle and bond calculators.
- `scripts/thermochemistry.js` – UI, cycle diagram, controls.
- `styles/thermochemistry.css` – layout.
