# M9.4 — Apparatus and Equipment Production Pass

**Project:** OOPA Virtual Labs  
**Engine tested:** Godot 4.7.2 stable  
**Branch:** `integration/godot-app-preservation`  
**Implementation baseline:** `70bb3c4b530ba770dbeb556d7e69830fee730021`  
**Change boundary:** Godot presentation scripts, M9 documentation and rendered evidence only.

## Production changes

| Laboratory | Presentation update | Model/control preservation |
|---|---|---|
| Gas Laws | Chamber depth/shadow, glass edge highlights, piston cap bevel and gauge scale ticks. | `GasLawsModel`, gas particle state, law selection, sliders, gauge value and plot are unchanged. |
| Acid–Base & Buffers | Beaker tint/rim, side reflections, liquid surface and subtle bench shadow. | `BuffersModel` pH/color and concentration readouts remain authoritative; mode and perturbation controls are unchanged. |
| Chemical Reactions | Replaced the rectangular flask illustration with a glass Erlenmeyer silhouette, liquid surface, shadow and reflection. | Reactant/product results, equation, limiting reagent and catalogue behavior are unchanged. The illustrative flask fill remains a visual convention, not a measured volume. |
| Acid–Base Titration | Burette glass highlights and flask neck/liquid surface highlight. | `TitrationModel`, titrant/pH/indicator values, additions, controls and curve are unchanged. |
| Heat Transfer | Wall shadow, subtle top/bottom layer bevels and hot-side border highlight. | Layer thickness/material and temperature inputs, heat flux and graph continue to use the existing model. |
| Robot Arm | Layered link bodies and concentric joint/end-effector highlights. | Planar FK/IK, link lengths, joint controls, target interaction and existing readouts are unchanged. |
| Simple Machines | Bevel and shadows for the lever beam/load/fulcrum, incline, pulley sheaves and wheel. | Existing mechanism geometry, force values, controls and motion calculations are unchanged. |
| Logic Gate Builder | Recessed board border, fasteners, component shadows and upper-edge highlights. | Node IDs/positions, pins, ports, wires, hit areas, graph evaluation, signal state and controls are unchanged. |

### Manifest disposition (all 22 labs)

| Discipline | M9.3/M9.4 apparatus-forward work | Appropriate 2D/data representation retained |
|---|---|---|
| Chemistry | Gas Laws, Acid–Base & Buffers, Chemical Reactions, Acid–Base Titration | Reaction Rates and Chemical Equilibrium remain plot/species-data views; neither currently models a physical vessel. |
| Biology | None; the population/world views were not changed in this equipment pass. | Single-Celled Organisms, Predator–Prey, Ecosystems, Evolution and Ecology remain field, population or data diagrams. |
| Physics | Pendulum & Springs (M9.3 3D apparatus) | Particle Motion, Projectile Motion, Collision Motion and Wave Interference remain physical-model diagrams, fields or plots. |
| Engineering | Circuit Builder and Fluid Dynamics (M9.3); Heat Transfer, Robot Arm, Simple Machines and Logic Gate Builder (M9.4) | — |

The eleven retained Tier 3 labs are intentionally not presented as missing physical equipment: their current scientific content is conceptual or data-led. Adding a fabricated rig without corresponding model state would imply unsupported measurements.

## Rendered evidence

M9.3 reference captures: [Circuit Builder](evidence/M9_3_Circuit_Builder.png), [Fluid Dynamics](evidence/M9_3_Fluid_Dynamics.png), [Fluid motion frame 0](evidence/M9_3_Fluid_Dynamics_Motion_0.png), [Fluid motion frame 1](evidence/M9_3_Fluid_Dynamics_Motion_1.png), [Pendulum & Springs](evidence/M9_3_Pendulum_3D.png).

M9.4 runtime captures:

- Chemistry: [Gas Laws](evidence/M9_4_Gas_Laws.png), [Buffers](evidence/M9_4_Buffers.png), [Chemical Reactions](evidence/M9_4_Chemical_Reactions.png), [Titration](evidence/M9_4_Titration.png).
- Engineering: [Heat Transfer](evidence/M9_4_Heat_Transfer.png), [Robot Arm](evidence/M9_4_Robot_Arm.png), [Simple Machines](evidence/M9_4_Simple_Machines.png), [Logic Gate Builder](evidence/M9_4_Logic_Gate_Builder.png).

All images are rendered by Godot 4.7.2 from the integration project at 1280×720 and were visually reviewed. Captures use the machine's Intel HD 4600/ANGLE renderer.

## Verification results

- **Editor scan:** Godot 4.7.2 completed a headless editor filesystem scan. No script parse errors appeared. Existing notice: the nested standalone Logic Gate project is skipped by the root project scan.
- **Scene launches/rendering:** Godot rendered evidence frames for all eight M9.4 scenes and the three M9.3 reference scenes. Headless launch attempts produced no GDScript or scene error diagnostics; individual headless exit statuses were not reliably captured by the shell wrapper. A two-frame capture also confirmed live flow particles advance in Fluid Dynamics. A bare `--script` flow test was invalid because that mode bypasses `JennyService`; its output was discarded and is not counted as passing.
- **Circuit regression:** `tests/circuit_builder_multiwire_test.gd` completed with all checks passing, including parallel and series circuits, transient capacitor/inductor response, potentiometer, fuse, motor, lamp and transistor behavior.
- **Diff hygiene:** `git diff --check` reported no whitespace errors. The full source diff was reviewed to confirm the changes are visual draw/scene integration only; no model, LabShell, instructor/exam, global theme, application navigation or root web-app source was edited.
- **Generated capture artifacts:** only PNG evidence is retained; movie audio sidecars were removed.

## Known environment notices

Godot selected ANGLE for the available Intel HD 4600 and logged its low-quality OpenGL 3.3 warning. Headless startup also logged that the system root certificate store could not be read. Neither notice produced a scene/script parse error or prevented the captured local scenes from rendering. No frame-rate or memory benchmark is claimed.

## Scope and repository state

All implementation, specification and evidence added for this report is under `godot/`. The pre-existing untracked M9.1 audit draft and `godot/oopa_virtual_labs_m7.zip` were left untouched. No model files, project settings, shared LabShell, protected instructor/exam features or root web application files were changed. This report does not create or imply a commit/push; the M9.3/M9.4 work remains available for owner review.

