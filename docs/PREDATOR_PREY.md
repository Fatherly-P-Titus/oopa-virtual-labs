# Predator–Prey (Biology)

Path: `labs/biology/predator_prey/` · Jenny page key: `predator-prey`

## Model
Lotka–Volterra with an optional food limit for prey:

    dx/dt = r·x·(1 − x/K) − a·x·y      prey
    dy/dt = b·a·x·y − m·y              predators

| Symbol | Control | Meaning |
|---|---|---|
| r | Prey growth rate | births minus deaths of prey per year |
| a | Predation rate | how often a predator meets and catches prey |
| b | Predator efficiency | predators born per prey eaten |
| m | Predator death rate | per year |
| K | Food limit for prey | slider at 500 means "no limit" (classic model) |

Balance point: `x* = m/(a·b)`, `y* = r/a` (no limit) or `y* = r/a·(1 − x*/K)` (limit). With a limit, predators cannot survive if `y* ≤ 0`; the readout shows "none".

Extinction rule (optional checkbox): a group under 1 animal is set to 0. Without it the smooth model never reaches zero.

## Files
- `scripts/predator-prey-model.js`: pure maths (`window.PredPreyModel`, also `require`-able in Node). Fixed-step RK4, `dt = 0.01` years.
- `scripts/predator-prey.js`: sliders, presets, readouts, two canvases (population over time, phase portrait). Simulation clock runs 2 years per real second × Time setting, independent of frame rate. Starts paused if the visitor prefers reduced motion.
- `styles/predator-prey.css`: page styles; shared chrome comes from `styles/lab-shell.css`.

## Behaviour notes
- Rate sliders and the food limit change the running simulation live. Starting prey and predators reset the run.
- Step advances 0.5 years and pauses.
- Cycle length is the time between the last two prey peaks, shown after two peaks have occurred.
- Jenny shows one tip the first time a rate slider is moved (`Jenny.notifyNewTip("predator-prey")`).

## Numerical checks run during development (model only, Node)
- Classic model: conserved quantity drifted by about 1e-12 (relative) over 30 years.
- Default parameters: small-amplitude cycle length 12.83 years vs theory 2π/√(r·m) = 12.83 years.
- Starting at the balance point stays there.

The page itself (UI, drawing, presets, mobile layout) was not covered by tests at the time of writing.
