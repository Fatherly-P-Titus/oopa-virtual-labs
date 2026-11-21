# Circuit Builder — Incandescent Lamp Milestone

## Component

- Two terminals, using the same multi-wire port behavior as the existing components.
- Default nominal hot-filament resistance: 12 Ω.
- Adjustable nominal resistance: 1–100 Ω.
- Round bulb body, crossed filament symbol, and warm glow that scales with simulated filament temperature.
- Selected-component readout reports terminal voltage, signed branch current, estimated hot resistance, and normalized brightness.

## Educational model

This is a simplified incandescent-lamp thermal model, not a precision electrothermal solver. The filament resistance varies from 12% of nominal resistance when cold to the selected nominal resistance when hot. Electrical power drives a normalized filament-temperature state upward; when power is reduced or disconnected, the state cools gradually. The UI uses this state for brightness and glow.

This model demonstrates cold-filament inrush and the reduction in current as filament resistance rises. It does not model real tungsten temperature, radiation/convection losses, lamp lifetime, rated voltage, or detailed nonlinear resistance curves. The lamp's slider is nominal hot resistance rather than a voltage rating.

## Regression test

The shared regression suite covers the two-terminal layout, accepted wiring, initial cold-lamp current, filament warm-up, visible glow, current reduction as resistance rises, and cooling after disconnecting the supply.

Run with Godot 4:

```bash
godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd
```
