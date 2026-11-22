# M9.3 — Apparatus Visual Prototypes

**Project:** OOPA Virtual Labs  
**Engine tested:** Godot 4.7.2 stable  
**Branch:** `integration/godot-app-preservation`  
**Implementation baseline:** `70bb3c4b530ba770dbeb556d7e69830fee730021`  
**Scope:** presentation-only; existing models remain authoritative.

## Implemented prototypes

| Mode | Laboratory | Presentation and source data |
|---|---|---|
| Advanced 2D | Circuit Builder | Layered board substrate, fine grid and corner fasteners. Existing component placement, ports, wires, readouts and `CircuitModel` remain in control. |
| Detailed 2.5D | Fluid Dynamics | Pipe shadow, inner channel, wall/rim highlights and inlet/outlet collars. The previously implemented particle animation uses the model's solved `v1` and `v2`, easing between them through the contraction; no solver or equations changed. |
| 3D in 2D workspace | Pendulum & Springs | New fixed-camera, low-poly pendulum scene hosted in a bounded `SubViewport`. Length and angle are supplied by `PendulumSpringsModel`. Spring mode stays in its existing 2D view; the phase plot, energy bars, controls and LabShell remain visible. |

The 3D scene is presentation-only: it does not advance or write simulation state. No new apparatus was added to conceptual or data-led experiments.

## Rendered evidence

- [Circuit Builder — 2D prototype](evidence/M9_3_Circuit_Builder.png)
- [Fluid Dynamics — 2.5D prototype](evidence/M9_3_Fluid_Dynamics.png)
- Fluid animation frames: [frame 0](evidence/M9_3_Fluid_Dynamics_Motion_0.png), [frame 1](evidence/M9_3_Fluid_Dynamics_Motion_1.png) (captured at 4 FPS from the live lab).
- [Pendulum & Springs — 3D prototype](evidence/M9_3_Pendulum_3D.png)

Each capture is a Godot-rendered 1280×720 frame from the integration project on the available Intel HD 4600/ANGLE path. The pendulum image shows the apparatus beside the phase plot with the main controls still present.

## Validation

- Godot 4.7.2 headless editor filesystem scan completed and registered `PendulumApparatus3D`; it reported no GDScript parse errors. It did report the existing nested standalone Logic Gate project directory and skipped that nested project during root scanning.
- Direct launch checks were attempted for the 11 modified lab scenes. No GDScript/scene error diagnostics appeared in their captured output. Process exit codes were not reliably exposed by the shell wrapper, so those attempts are not treated as an independent pass/fail test suite.
- Actual rendered frames were captured and visually inspected for all three prototype modes.
- A two-frame live Fluid Dynamics capture shows particle positions advancing. The implementation reads the current solved velocities; the D₁/D₂/Q handlers re-solve and refresh the result each time a control changes.
- A separate `--script` test attempt was invalid because bare script mode skipped the project's `JennyService` autoload; its PASS lines were discarded. The temporary scene test was also not loadable through that CLI invocation. Neither failed harness is counted as a passing test.
- The existing Circuit Builder multi-wire regression script completed with all checks passing, including parallel/series branches and dynamic components.
- `git diff --check` is part of final closeout; results are recorded in the M9.4 report after the full M9 diff review.

## Limits and observations

- The pendulum camera is fixed and shows only pendulum mode; spring mode intentionally remains 2D.
- The frame pair confirms particle travel at the default Venturi settings. I did not interactively change D₁, D₂ or flow rate during this run, so response to those inputs is code-reviewed rather than interaction-tested.
- Godot selected ANGLE for the installed Intel HD 4600. The driver emits a low-quality OpenGL 3.3 warning. No sustained frame-rate or memory benchmark is claimed.
- Godot logged an inability to read the system root certificate store in a headless startup. This did not prevent local scenes from loading or rendering and is unrelated to the apparatus changes.

## Files

Prototype source changes are in `scenes/labs/engineering/circuit_builder/circuit_lab.gd`, `scenes/labs/engineering/fluid_dynamics/fluid_dynamics_lab.gd`, `scenes/labs/physics/pendulum_springs/pendulum_lab.gd`, and `scenes/equipment/pendulum/`. The velocity-responsive flow particle implementation at the starting commit is documented above; it was not duplicated as a second flow solver.

