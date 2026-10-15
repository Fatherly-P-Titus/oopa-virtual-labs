# Particle Motion (Physics lab)

`labs/physics/particle_motion/` – a 2D gas of hard discs in a box.

## Model
- All particles have mass 1. The world is a fixed 800 x 500 box, scaled to the canvas, so results never depend on screen size.
- Fixed physics step of 1/120 s, independent of frame rate. Free flight is exact; walls and particle collisions are handled per step.
- Disc-disc collisions: equal masses exchange the velocity component along the line of centres. Elasticity `e` below 1 removes energy.
- Floor and ceiling: speed at the wall comes from energy conservation, so an elastic bounce under gravity loses no energy.
- Temperature T sets the RMS speed: `v_rms = 30 * sqrt(T)` px/s.
- Pressure = momentum delivered to the walls per second per unit of wall length.

## Controls
Particles, Temperature, Gravity, Particle size, Elasticity, collisions on/off, motion trails; presets (Ideal gas, Hot gas, Settling); Pause/Play, Step, Reset, time scale.

## Validation (headless, 2D, mass 1)
| Check | Result |
|-------|--------|
| Total energy, no gravity, e = 1, 30 s | conserved to 1e-15 |
| Total energy, gravity 300, e = 1, collisions on, 30 s | drift under 0.002% |
| Start with all speeds equal, relax with collisions: mean speed / RMS speed | 0.887 (theory for 2D Maxwell–Boltzmann: sqrt(pi)/2 = 0.886) |
| Ideal gas law: P·A / (N·kT) | 0.99 to 1.01 |

## Adding another physics project
Create `labs/physics/<project>/` with `index.html`, `scripts/`, `styles/`; link `../../../styles/lab-shell.css` and `../../../scripts/jenny/jenny-loader.js` (new `data-page` key, tips in `scripts/jenny/jenny_texts.js`); add a card to `labs/physics/index.html`.
