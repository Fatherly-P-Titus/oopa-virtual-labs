# Calorimetry (Chemistry lab)

`labs/chemistry/calorimetry/` – coffee-cup and bomb calorimeters: specific heat, enthalpy of reaction/solution/neutralisation and combustion.

## Modes
1. **Specific heat of a metal** — hot metal dropped into cool water in a coffee-cup calorimeter.  
   \(m_\mathrm{m} c_\mathrm{m}(T_\mathrm{f}-T_\mathrm{m}) + m_\mathrm{w} c_\mathrm{w}(T_\mathrm{f}-T_\mathrm{w}) = 0\) (ideal, no calorimeter heat capacity unless enabled).

2. **Enthalpy of solution** — salt dissolves; temperature of water changes.  
   \(q_\mathrm{soln} = m c \Delta T\), \(\Delta H_\mathrm{soln} \approx -q / n\).

3. **Neutralisation** — strong acid + strong base.  
   \(q = m c \Delta T\), \(\Delta H_\mathrm{neut} = -q / n_{\mathrm{limiting}}\).

4. **Bomb (combustion)** — constant-volume calorimeter with known heat capacity \(C_\mathrm{cal}\).  
   \(q_\mathrm{rxn} = -(C_\mathrm{cal} + m_\mathrm{w} c_\mathrm{w})\Delta T\), \(\Delta U \approx q_\mathrm{rxn}/n\), \(\Delta H \approx \Delta U + \Delta n_g RT\) (optional gas correction).

## Model notes
- Water \(c = 4.184\) J·g⁻¹·°C⁻¹ by default.
- Optional calorimeter constant \(C_\mathrm{cal}\) (J/°C) absorbs heat with the contents.
- Ideal mixing; instantaneous thermal equilibrium; no heat loss to surroundings (adiabatic teaching model).
- Sign convention: exothermic processes warm the calorimeter (\(q_\mathrm{cal} > 0\), \(q_\mathrm{rxn} < 0\)).

## Limits
- No heat leaks, stirring losses or time-resolved cooling curves (can be added later).
- Bomb gas correction is a simple \(\Delta n_g RT\) estimate.

## Files
- `scripts/calorimetry-model.js` – pure energy balances.
- `scripts/calorimetry.js` – calorimeter diagram, thermometer, controls.
- `styles/calorimetry.css` – layout.
