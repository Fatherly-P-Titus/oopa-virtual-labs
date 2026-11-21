# Circuit Builder — Inductor milestone

The Circuit Builder now includes an **IND** component alongside the existing battery, resistor, LEDs, switch, diode, and capacitor.

## Component behavior

- Default inductance: **100 mH**; adjustable from **1–1000 mH** using the selected-component slider.
- Two terminals with the same multi-wire connection behavior as the other two-terminal components.
- The board draws a cyan coil symbol and displays the component's inductance.
- The transient solver uses a backward-Euler RL companion model. Current through an inductor changes over simulation time instead of jumping instantly, and the small winding resistance provides a finite DC path.
- The inductor's previous branch current is retained between simulation steps and cleared when the component or board is removed.
- The existing capacitor charging behavior and all previous component visuals, switch port mapping, and multi-wire support are preserved.

## Regression tests

The Circuit Builder test script covers parallel and series LED wiring, capacitor charging, and inductor current ramp-up:

```bash
godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd
```

Runtime execution requires Godot 4. If Godot is not installed in the build environment, these tests cannot be executed there.
