# Circuit Builder — Transistor milestone

The NPN transistor is the seventh component milestone in the Engineering Circuit Builder.

## Component

- Three terminals: collector (port 0), base (port 1), emitter (port 2).
- Adjustable educational DC current gain, β: 20–300; default 100.
- Green base port, blue collector port, red emitter port, and a recognizable NPN symbol.
- Selected-component readout includes estimated base current, collector current, collector-emitter voltage, and cutoff/active state.

## Circuit model

This is an educational, piecewise-linear NPN model. A forward-biased base-emitter junction drives a beta-controlled collector current. Collector current is limited by a simplified saturation constraint to avoid unlimited current-source behavior when the collector load cannot supply the requested current. It is suitable for illustrating common-emitter switching and basic current gain, not for precision analog design.

It does not model frequency response, charge storage, Early effect, detailed temperature dependence, leakage, or manufacturer-specific SPICE parameters. The model is NPN-only; PNP support is not included in this milestone.

## Regression test

Run from the project root with Godot installed:

```bash
godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd
```

The regression script checks three terminals, common-emitter wiring, forward base current, controlled collector current, and reduced collector current when base drive is reduced.
