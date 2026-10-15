# Chemical Equilibrium (Chemistry lab)

`labs/chemistry/chemical_equilibrium/` – reversible reactions, \(K_c\), ICE tables and Le Chatelier shifts.

## Reactions
1. **A ⇌ B** — isomerisation, \(K_c = [B]/[A]\)
2. **A + B ⇌ C** — \(K_c = [C]/([A][B])\)
3. **2A ⇌ B** — \(K_c = [B]/[A]^2\)
4. **N₂ + 3H₂ ⇌ 2NH₃** — Haber (concentration form), \(K_c = [NH_3]^2 / ([N_2][H_2]^3)\)

## Solver
Given initial amounts (mol in a fixed volume V) and \(K_c\), the equilibrium extent \(\xi\) is found by solving the mass-action equation (analytic for 1–2; safe numeric for Haber). Concentrations are \(n/V\).

Temperature shift is modelled by changing \(K_c\) (endothermic: higher T → larger \(K_c\); exothermic: higher T → smaller \(K_c\)). Volume/pressure effects appear by changing V for gas-phase reactions.

## Limits
- Ideal dilute / ideal gas concentrations only. No activity coefficients, no kinetics of approach (instant equilibrium), no heterogeneous solids.

## Files
- `scripts/equilibrium-model.js` – pure \(K_c\) solver.
- `scripts/equilibrium.js` – bar chart + ICE + controls.
- `styles/equilibrium.css` – layout.
