# Circuit Builder: Capacitor milestone

- Component tile: `CAP`
- Default capacitance: 100 µF
- Adjustable range: 1–1000 µF
- Two terminals; non-polarized capacitor symbol.
- Selected-component readouts display terminal voltage and signed current.
- Uses a backward-Euler companion model for transient charging and discharging. During a static solve, the capacitor behaves as an open circuit; during time-stepped solves, its companion conductance is `C / Δt` and its history source retains the previous capacitor voltage.
- Existing component types, switch port layout, multi-wire ports, and LED illumination logic are retained.

## Regression test

From the project root with Godot 4 installed:

```bash
godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd
```

The test covers five parallel LED branches, a three-LED series loop, and capacitor charging through a 330 Ω resistor. It checks that capacitor voltage rises toward the 9 V source while charging current decays.
