# Circuit Builder — Fuse milestone

The Engineering Circuit Builder now includes a two-terminal **FUSE** component. This milestone preserves the existing battery, resistor, LED, switch, diode, capacitor, inductor, and potentiometer features.

## Component behavior

- Default current rating: **0.5 A**, adjustable from **0.1 A to 5.0 A**.
- The intact fuse is modeled as a low-resistance series element; when its solved branch current exceeds its selected rating, it latches open and the circuit is re-solved.
- A blown fuse is shown with a broken link and red styling. The selected-component readout reports its state and the solver status warns that a fuse has blown.
- Select the fuse and use **Reset blown fuse** to restore it. If the overcurrent condition still exists, it will blow again immediately; correct the circuit or increase the rating first.
- This is a simplified educational threshold model, not a thermal/I²t time-current fuse model.

## Regression tests

The regression suite covers series/parallel LEDs, capacitor charging, inductor current rise, potentiometer divider control, and fuse overcurrent interruption.

Run with Godot 4:

```bash
godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd
```

Runtime tests require a Godot 4 executable. If Godot is not installed in the build environment, the tests cannot be executed there.
