# Reaction Rates (Chemistry lab)

`labs/chemistry/reaction_rates/` – chemical kinetics: rate laws, concentration–time curves, half-life and Arrhenius temperature dependence.

## Model
Single irreversible reaction A → products with rate law:

\[
-\frac{d[A]}{dt} = k [A]^n
\]

Orders supported: \(n = 0, 1, 2\).

Integrated forms:
- Zero: \([A] = [A]_0 - kt\) (until depleted)
- First: \([A] = [A]_0 e^{-kt}\), \(t_{1/2} = \ln 2 / k\)
- Second: \([A] = [A]_0 / (1 + k[A]_0 t)\), \(t_{1/2} = 1/(k[A]_0)\)

Temperature via Arrhenius:

\[
k = A_f \exp(-E_a / RT)
\]

Time integration is analytical for each order (no ODE solver required).

## Limits
- Single reactant, irreversible, constant volume.
- No complex mechanisms, no reversible equilibrium (see a future Equilibrium lab).
- Arrhenius uses a single \(E_a\); no transition-state theory detail.

## Files
- `scripts/reaction-rates-model.js` – pure kinetics.
- `scripts/reaction-rates.js` – strip chart + controls.
- `styles/reaction-rates.css` – layout.
