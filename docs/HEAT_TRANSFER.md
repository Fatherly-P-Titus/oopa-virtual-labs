# Heat Transfer (Engineering lab)

`labs/engineering/heat_transfer/` – steady one-dimensional conduction through a plane wall (single or multi-layer).

## Model
- Fourier’s law: \(q'' = -k\,dT/dx\)
- Steady 1D plane wall, no generation: heat flux \(q''\) is constant through the stack.
- Thermal resistance of a layer: \(R'' = L / k\) (per unit area).
- Overall: \(q'' = (T_{\mathrm{hot}} - T_{\mathrm{cold}}) / \sum R_i''\)
- Interface temperatures from cumulative resistance drops.
- Optional surface convection: \(R_{\mathrm{conv}}'' = 1/h\) on either side.

## Limits
- Steady state, one dimension, constant \(k\). No radiation network, no transient diffusion, no 2D edge effects.

## Files
- `scripts/heat-model.js` – pure thermal-resistance network.
- `scripts/heat-transfer.js` – wall diagram, T(x) plot, controls.
- `styles/heat-transfer.css` – layout.
