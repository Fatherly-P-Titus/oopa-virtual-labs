# Projectile Motion (Physics lab)

`labs/physics/projectile_motion/` – launch a projectile and compare it with the ideal parabola.

## Model (SI units, y up)
- Acceleration: `a = ( -(c/m)·|v_rel|·v_rel.x , -g - (c/m)·|v_rel|·v_rel.y )`, where `v_rel` is velocity relative to the wind and `c = ½ρC_dA` (kg/m).
- Integrated with RK4 on a fixed 1/240 s step, independent of frame rate.
- Ground impact is located by interpolating inside the step, so landing x and t are accurate to a small fraction of a millimetre.
- On impact: `vy → −e·vy` and `vx → (1 − μ)·vx`. Below 0.4 m/s of bounce speed the projectile rolls, decelerating at `μ·g`, until it stops. Drag and wind are ignored while rolling.
- The ideal path is the vacuum parabola from the same launch speed, angle, height and gravity: `T = (v_y + √(v_y² + 2gh)) / g`, `R = v_x·T`, `H = h + v_y²/2g`.
- A run stops at rest or at a 180 s limit.

## Controls
Launch speed, angle and height (changing these returns to the ready state); gravity with Earth / Moon / Mars / Jupiter presets; air drag; wind; mass; bounciness; friction; ideal path, velocity arrow and trail toggles; presets (Max range, Moon shot, From a cliff, Air drag, Bouncing ball); Launch / Pause / Resume, Step, Reset, time scale. Keyboard: Space, S, R.

## Readouts
Live time, position, velocity components and speed; a table of simulated against ideal range, flight time and maximum height (first flight); an energy graph of kinetic, potential and total energy.

## Notes
- The scale only zooms out during a flight, so the picture never jumps.
- Mass matters only when drag is on (acceleration is `c/m` times a speed term) and for the energy values.
