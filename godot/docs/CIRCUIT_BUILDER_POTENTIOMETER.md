# Circuit Builder — Potentiometer milestone

The Circuit Builder now includes a **POT** three-terminal potentiometer, preserving the battery, resistor, LEDs, switch, diode, capacitor, and inductor components.

## Component behavior

- Default total track resistance: **10 kΩ**; adjustable from **100 Ω to 100 kΩ**.
- Three terminals: track end 0, track end 1, and wiper 2. The wiper terminal is drawn below the component and colored green.
- The selected-component panel provides a total-resistance slider and a separate **0–100% wiper-position** slider.
- The solver models the potentiometer as two series track resistances split by the wiper position. With both ends connected across a supply, the wiper produces an adjustable divider output. The circuit can also use it as a two-terminal variable resistor by connecting the wiper and one track end.
- The board draws a recognizable track-and-wiper symbol and shows the nominal total resistance.
- Existing multi-wire ports, switch mapping, capacitor transient charging, and inductor transient current behavior remain in place.

## Regression tests

The Circuit Builder regression script covers parallel/series LED circuits, capacitor charging, inductor current ramp-up, and potentiometer output changes as the wiper moves. Run with Godot 4:

```bash
godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd
```

Runtime execution requires Godot 4. If Godot is not installed in the build environment, these tests cannot be executed there.
