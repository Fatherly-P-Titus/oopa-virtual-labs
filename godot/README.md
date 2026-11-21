# OOPA Virtual Labs (Godot 4)

Compatibility renderer. Modular virtual science labs.

## Open in Godot

1. Install **Godot 4.2+** (4.x).
2. **Import** / Open this folder (select `project.godot`).
3. Press **F5** — splash → main menu → field hubs.

## Layout

- `scenes/boot` — splash
- `scenes/hub` — main menu + field hub
- `scenes/labs` — one folder per lab (to be filled)
- `scripts/models` — pure math (no nodes)
- `data/config/labs_manifest.json` — lab catalogue
- `autoload` — AppState, JennyService, SceneRouter
- `themes` — OOPA theme + colors

## Next

Port the first lab model (e.g. Gas Laws) into `scripts/models/chemistry/` and a lab scene under `scenes/labs/chemistry/gas_laws/`, then set `"status": "available"` in the manifest.

## Circuit Builder update

The updated Circuit Builder scripts are integrated at:
- `scenes/labs/engineering/circuit_builder/circuit_lab.gd`
- `scripts/models/engineering/circuit_model.gd`

The existing lab scene and catalogue entry are preserved. See `docs/CIRCUIT_BUILDER_REBUILD.md` for rebuild notes and limitations.


## Circuit Builder solver update
The Circuit Builder now starts on an empty board (Load Demo removed), uses a DC nodal solver with piecewise-linear diode/LED behavior, and reports selected component voltage/current and branch wire current. See `docs/CIRCUIT_BUILDER_REBUILD.md` for assumptions and limitations.

## Circuit Builder parser hotfix (2026-10-24)

Fixed a GDScript indentation error in `scripts/models/engineering/circuit_model.gd` that prevented `CircuitModel` from parsing and consequently caused `circuit_lab.gd` to fail loading. The LED lit-state assignment is now correctly nested under the non-empty chip check. Please reopen the project in Godot and run a project scan; runtime validation still needs to be performed in the Godot editor.


## Circuit Builder multi-wire update (2026-10-24)

Each component port now supports multiple wire connections without a fixed four-wire cap. Port clicks take priority over component-body and wire hit-testing, including switch terminals, and wire endpoints fan out visually so connections at a shared port remain easier to distinguish. The solver continues to solve the complete connected network, so the same wiring workflow supports series loops and parallel branches.

A headless regression script is included at `tests/circuit_builder_multiwire_test.gd`. Run from the project root with Godot 4: `godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd`. It checks five-wire battery terminals in a parallel LED arrangement and a three-LED series loop. Runtime tests have not been executed in this packaging environment.

## Circuit Builder capacitor milestone (2026-10-24)

Added a two-terminal capacitor component (default 100 µF) with a standard parallel-plate symbol, adjustable capacitance, voltage/current readouts, and a backward-Euler transient companion model. The capacitor is open-circuit during static solves and draws current during time-stepped charging/discharging. The lab advances the transient solver each frame while capacitors are present. A capacitor regression test was added to `tests/circuit_builder_multiwire_test.gd` alongside the existing series/parallel LED tests.

Runtime validation requires Godot 4 and was not performed in this packaging environment.

## Circuit Builder inductor milestone (2026-10-25)

Added a two-terminal inductor (default 100 mH), adjustable from 1–1000 mH, with a recognizable coil symbol and selected-component voltage/current readouts. The transient solver now uses a backward-Euler RL companion model with winding resistance so inductor current ramps over time. Capacitor behavior is preserved, and the regression suite now includes an inductor energization/current-ramp test. See `docs/CIRCUIT_BUILDER_INDUCTOR.md`.

Runtime validation requires Godot 4; it was not performed in this packaging environment because the Godot executable is unavailable.


Added a three-terminal potentiometer (default 10 kΩ), adjustable from 100 Ω to 100 kΩ, with a separate 0–100% wiper-position control and voltage-divider behavior. The regression suite now checks that moving the wiper changes the divider output. See `docs/CIRCUIT_BUILDER_POTENTIOMETER.md`.

## Circuit Builder fuse milestone (2026-10-25)
The Circuit Builder now includes a two-terminal fuse with an adjustable 0.1–5.0 A current rating. The simplified educational model trips open when solved branch current exceeds the rating, visibly marks the broken fuse, and allows manual reset after correcting the overcurrent condition. See `docs/CIRCUIT_BUILDER_FUSE.md`. Regression coverage includes fuse trip and current interruption; run the suite with Godot 4 using `godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd`.


### Engineering Circuit Builder — Motor milestone

The Circuit Builder now includes an adjustable two-terminal DC motor with a simplified speed-dependent back-EMF model and RPM readout. See `docs/CIRCUIT_BUILDER_MOTOR.md` for the model assumptions and regression-test command.


### Engineering Circuit Builder — Lamp milestone

The Circuit Builder now includes a two-terminal incandescent lamp with adjustable nominal hot-filament resistance (1–100 Ω). Its simplified thermal model simulates cold-filament inrush, resistance rising as the filament warms, brightness increasing with temperature, and gradual cooling after power is removed. See `docs/CIRCUIT_BUILDER_LAMP.md` for assumptions and regression-test instructions.

### Engineering Circuit Builder — Transistor milestone
The Circuit Builder now includes a three-terminal educational NPN transistor (collector, base, emitter) with adjustable approximate DC current gain β (20–300). A forward-biased base-emitter junction controls collector current, with a simplified saturation limit for common-emitter switching examples. See `docs/CIRCUIT_BUILDER_TRANSISTOR.md` for model assumptions and regression-test instructions. This completes the seven-component implementation sequence.


## Logic Gate Builder milestone
A standalone Godot 4 digital logic project is included at `labs/engineering/logic_gate_builder/standalone_project/`. The integrated Engineering Lab menu also exposes Logic Gate Builder. See `labs/engineering/logic_gate_builder/README.md` for features and test instructions.
