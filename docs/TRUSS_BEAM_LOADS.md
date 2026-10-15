# Truss and Beam Loads (Engineering lab)

`labs/engineering/truss_beam_loads/` – interactive 2D structures for exploring forces, supports and load paths.

## Two modes

### Truss
- Pin-jointed bars that carry **axial force only** (tension or compression).
- Joints (nodes) on a snap grid. Members connect two joints.
- Supports: **pin** (resists Hx and Hy) and **roller** (resists vertical force only).
- Point loads applied at joints (Fx, Fy in model units; positive X right, positive Y up).
- The solver assembles equilibrium equations (ΣFx = 0, ΣFy = 0 at every joint) for member forces and support reactions, then solves the linear system.
- Members are coloured: **blue = tension**, **red = compression**. Force magnitude is labelled on each bar.
- Only **statically determinate** trusses are solved cleanly. Mechanisms (too few members/supports) or indeterminate frames are reported as unsolvable.

### Beam
- A single horizontal beam with a pin support and a roller support (simply supported) or a fixed-style cantilever idealisation.
- Point loads downward on the span.
- Reactions from vertical and moment equilibrium.
- **Shear force** and **bending moment** diagrams drawn under the beam (sign convention: positive shear when left face pushes up; positive moment when beam is in sagging).

## Limits of the model
- Linear, static, two-dimensional, small-deflection.
- Truss members have no bending stiffness; joints are ideal pins.
- Self-weight of members is ignored unless you add it as joint loads.
- No buckling check, no material stress limits, no 3D frames.
- Beam mode is a single span only (no continuous beams or frames).

## Controls
- Mode toggle: Truss / Beam.
- Tools: Select, Joint, Member, Pin support, Roller support, Load, Delete.
- Presets for common teaching examples (triangle, roof truss, simple beam, cantilever-style loads).
- Edit selected load magnitude; Analyse recomputes (also runs after most edits).

## Files
- `scripts/truss-model.js` – pure statics (`window.TrussModel`, require-able).
- `scripts/truss-beam.js` – canvas UI, diagrams, presets.
- `styles/truss-beam.css` – layout; shared chrome from `lab-shell.css`.
