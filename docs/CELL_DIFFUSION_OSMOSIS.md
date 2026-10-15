# Cell Diffusion and Osmosis (Biology lab)

`labs/biology/cell_diffusion_osmosis/` – two experiments on one page, chosen with the radio buttons.

## Diffusion
- A tank is divided by a membrane. Particles move in straight runs, change direction at random (about every half second), and move faster when warmer (speed ∝ √absolute temperature).
- At the membrane a particle crosses with probability **openness × size factor**; otherwise it bounces back. Size factors: oxygen 1, glucose 0.5, starch 0 (too large to pass).
- Nothing pushes particles from the crowded side to the sparse side. The net movement appears because more particles reach the membrane from the crowded side, as in real diffusion.
- Readouts: particles in each half, net movement, and smoothed crossings per second each way. "Dynamic equilibrium" means the halves are within 6 % of each other (at least 3 particles) while particles keep crossing.
- Changing the particle type or the starting numbers restarts the run. Temperature and openness act live.

## Osmosis
- The cell holds a fixed amount of solute, so its inside concentration is `c_in = 300 / V`, with V the volume relative to normal.
- Water flows at a rate proportional to the concentration difference: `dV/dt = 0.08 × channels × (c_in − c_out − turgor) / 300`.
- **Animal cell:** no turgor; it bursts at V ≥ 1.6 (outside below about 187 mOsm/L) and shrinks and crinkles below V = 0.85. The final volume is `300 / c_out`.
- **Plant cell:** the wall pushes back with `turgor = 2000 × max(0, V − 1)` (mOsm/L), so it swells only a little and becomes firm (turgid). In strong solution the membrane pulls away from the wall (plasmolysis).
- The graph shows volume over time, the volume the cell is heading for (solved from the model), and the bursting line for animal cells.
- The dots are illustrative: inside dots keep a fixed count so they crowd together as the cell shrinks, and outside dots follow the chosen concentration. Blue dots show water crossing, with more going the way the net flow runs.

## Limits of the model
Two-dimensional, schematic, no solute crossing the cell membrane, 300 mOsm/L inside (typical of animal cells). Plant cell values are chosen for a clear demonstration, not measured.
