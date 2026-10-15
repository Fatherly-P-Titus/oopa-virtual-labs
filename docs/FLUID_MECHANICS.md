# Fluid Mechanics (Engineering lab)

`labs/engineering/fluid_mechanics/` – hydrostatics, manometers and buoyancy (Archimedes).

## Modes

### Hydrostatic pressure
- Gauge pressure at depth \(h\): \(p = \rho g h\)
- Absolute pressure: \(p_{\mathrm{abs}} = p_{\mathrm{atm}} + \rho g h\)
- Density of common liquids selectable.

### U-tube manometer
- Pressure difference from column height difference: \(\Delta p = \rho g \Delta h\)
- Optional second fluid (air side simplified as gauge).

### Buoyancy
- Displaced volume \(V_{\mathrm{disp}}\) for a partially or fully submerged block.
- Buoyant force \(F_B = \rho_{\mathrm{fluid}} g V_{\mathrm{disp}}\)
- Weight \(W = \rho_{\mathrm{obj}} g V_{\mathrm{obj}}\)
- Floats when \(F_B = W\) at equilibrium draft; sinks if density exceeds fluid density.

## Limits
- Incompressible static fluid. No free-surface waves, no viscosity-driven flow, no compressible gas columns beyond a simple air-side gauge assumption.

## Files
- `scripts/fm-model.js` – pure formulae.
- `scripts/fluid-mechanics.js` – canvas modes + controls.
- `styles/fluid-mechanics.css` – layout.
