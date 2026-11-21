# Circuit Builder — Motor Milestone

## Component
- Added a two-terminal DC motor tile to the Engineering Circuit Builder.
- Default armature resistance: 12 Ω; adjustable from 1 Ω to 100 Ω.
- The motor has a recognizable round rotor symbol with a rotation indicator and an RPM readout.
- The selected-component panel reports terminal voltage, branch current, armature resistance, and approximate speed.

## Simulation model
The motor uses a simplified DC armature model: current is calculated from terminal voltage minus a speed-dependent back electromotive force (back-EMF), divided by armature resistance. Rotor speed is represented from 0 to 1 and displayed as an educational 0–3000 RPM scale. Speed rises when powered and coasts down when current disappears. This is an illustrative first-order model, not a calibrated mechanical simulation: it does not yet model shaft load, inertia, torque curves, gearing, or thermal limits.

The transient update is driven by the existing Circuit Builder frame step, so the motor animation and back-EMF respond over time. Existing capacitor, inductor, potentiometer, fuse, switch, diode, LED, and multi-wire features remain in the project.

## Regression test
Run from the project root with Godot 4 installed:

```bash
godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd
```

The regression script includes motor terminal/wiring checks, startup current, acceleration, and current reduction as back-EMF rises. Runtime tests should be executed in a Godot 4 environment; this environment does not currently have the Godot executable available.
