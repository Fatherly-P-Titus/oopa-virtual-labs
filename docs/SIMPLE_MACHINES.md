# Simple Machines (Engineering lab)

`labs/engineering/simple_machines/` – interactive levers, inclined planes, pulleys and wheel-and-axle.

## Machines

### Lever
- Classes 1, 2 and 3 (fulcrum between, load between, effort between).
- Ideal mechanical advantage: \(MA = d_E / d_L\) (effort arm / load arm).
- Effort required (ideal): \(E = W / MA\). With efficiency \(\eta\): \(E = W / (MA \cdot \eta)\).

### Inclined plane
- Angle \(\theta\) or height/length. Ideal MA: \(1 / \sin\theta\) (effort parallel to plane, load vertical).
- With friction coefficient \(\mu\): efficiency drops; effort rises.

### Pulley
- Fixed single (MA ≈ 1), movable single (MA ≈ 2), block-and-tackle with \(n\) supporting strands (ideal MA = \(n\)).
- Ideal effort \(E = W / n\); actual \(E = W / (n \cdot \eta)\).

### Wheel and axle
- Effort on wheel radius \(R\), load on axle radius \(r\). Ideal MA: \(R / r\).

## Limits of the model
- Quasi-static idealised geometry; no inertia, no cable stretch.
- Friction is a single efficiency factor or Coulomb \(\mu\) on the plane—not a full contact model.
- Pulleys are massless and friction is lumped into \(\eta\).
- No compound machines in one diagram (you can still compare MA values across modes).

## Files
- `scripts/simple-machines-model.js` – pure formulae (`window.SimpleMachinesModel`).
- `scripts/simple-machines.js` – canvas UI and controls.
- `styles/simple-machines.css` – layout; chrome from `lab-shell.css`.
