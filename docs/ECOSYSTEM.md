# Ecosystems (Biology)

Path: `labs/biology/ecosystems/` · Jenny page key: `ecosystem`

## Model
A closed matter cycle with five pools, in matter units: nutrients N, plants P, herbivores H, carnivores C, dead matter D. Time is in years, integrated with fixed-step RK4 (`dt = 0.02`).

| Flow | Rule |
|---|---|
| Plant growth | `0.94 × sunlight × P × N/(100 + N)`. Nutrients to plants. Drought multiplies it by 0.4 for 10 years. |
| Grazing | `appetite × P/(300 + P) × H`. Herbivores keep 30%; the rest goes to dead matter. |
| Predation | `hunting × H/(120 + H) × C`. Carnivores keep 25%; the rest goes to dead matter. |
| Deaths | Plants 0.3, herbivores 0.5, carnivores 0.3 per year, all to dead matter. |
| Decomposition | `activity × D`, dead matter back to nutrients. |
| Optional | Nutrients washed in (per year) and washed out (fraction of N per year). |

With wash-in and wash-out at 0 and no events, `N + P + H + C + D` is constant (1000 at the start). A group that falls under 0.2 units dies out for good and its matter moves to dead matter. Defaults were set so the Balanced preset has a coexistence point near P 300, H 50, C 7, D 390, N 250; the run starts away from it (P 200, H 30, C 4, D 300, N 466).

Events: Wildfire (80% of plants to dead matter), Drought (10 years), Fertilizer runoff (+300 nutrients), Hunt carnivores (all carnivores to dead matter), Add herbivores (+30). Wildfire and Hunt keep total matter; Fertilizer and Add herbivores add to it.

The energy pyramid shows each level's new body matter per year: plants `G`, herbivores `0.3 × grazing`, carnivores `0.25 × predation`, with each as a share of the level below.

## Files
- `scripts/ecosystem-model.js`: pure maths (`window.EcoModel`, also `require`-able in Node).
- `scripts/ecosystem.js`: sliders, presets, events, readouts, the food-web diagram, the chart and the pyramid. The clock runs 5 years per real second × the Time setting, independent of frame rate. Starts paused if the visitor prefers reduced motion.
- `styles/ecosystem.css`: page styles; shared chrome comes from `styles/lab-shell.css`.

## Behaviour notes
- Sliders change the running ecosystem live. Presets and Reset restart it.
- Food web: circle area grows with the amount in each pool; arrow thickness and numbers are matter per year. Extinct groups show as dashed circles.
- The chart can show plants and animals, or nutrients and dead matter. Dashed lines mark events.
- Jenny gives one tip the first time a slider is moved.

## Testing
No tests have been run on this project. It is intended to be run in a browser and any problems reported. The default parameters were worked out by hand from the coexistence point above, so how stable that point is has not been checked.
