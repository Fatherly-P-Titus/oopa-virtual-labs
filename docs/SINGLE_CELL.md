# Single-Celled Organisms (Biology)

Path: `labs/biology/single_celled_organisms/` · Jenny page key: `single-cell`

## Model
Agent-based. Each cell has a position, heading, energy, age and its own speed factor (0.8 to 1.2 × the speed setting). The dish is 800 × 500 model units with bouncing walls. The model steps at 1/30 s. Time is in seconds.

| Process | Rule |
|---|---|
| Feeding | Touching a food particle gives 10 energy (capped at 1.5 × the divide energy). |
| Movement | Cells swim along their heading. With sensing range above 0 they steer toward the nearest food in range (up to 5 rad/s). Otherwise they run and tumble at random. |
| Upkeep | Each cell loses `resting energy use + 0.01 × speed × its speed factor` per second. Faster swimming costs more. |
| Growth | Radius runs from 5 (no energy) to 11 (at the divide energy). Cells shrink when hungry. |
| Reproduction | At the divide energy a cell splits in two. Each cell keeps `(energy − 2) / 2` and restarts at age 0. The original cell keeps its id. Limit: 300 cells. |
| Death | Energy reaching 0 is starvation. Reaching the lifespan without dividing is old age. Lifespan 600 means no limit. |
| Food | Arrives at the food supply rate at random spots, up to 500 particles. 80 particles at the start. |

Cells pass through each other, and there is no mutation, waste or competition for space.

## Files
- `scripts/cell-model.js`: pure logic (`window.CellModel`, also `require`-able in Node). Food is bucketed in a 40-unit grid so each cell only checks nearby particles. Uses a seeded random generator (`init(p, n0, food0, seed)`).
- `scripts/single-cell.js`: sliders, presets, readouts, the dish canvas (drawn in model units, so it scales to any screen) and the population chart. The simulation clock runs 2 s per real second × the Time setting, independent of frame rate. Starts paused if the visitor prefers reduced motion.
- `styles/single-cell.css`: page styles; shared chrome comes from `styles/lab-shell.css`.

## Behaviour notes
- Rate sliders (food supply, speed, resting energy use, sensing range, energy to divide, lifespan) change the running dish live. Starting cells reset the run.
- Colours: brown is hungry, green is well fed, a white outline is ready to divide, a gold ring is a feeding flash. Event rings: white is a division, red is starvation, grey is old age.
- Click a cell, or press Follow a cell, to inspect it: what it is doing, age, size and an energy meter. Its sensing range is drawn on the dish. When it dies the panel says how.
- Step advances 0.5 s and pauses.
- Jenny gives one tip the first time a rate slider is moved.

## Testing
No tests have been run on this project. It is intended to be run in a browser and any problems reported.
