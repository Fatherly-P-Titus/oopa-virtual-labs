# Circuit Builder: Multi-connection ports

## Behavior

- Any valid component port can be the endpoint of multiple wires. Four connections are supported and there is no hard-coded four-wire ceiling.
- Duplicate direct wires between the same two ports are rejected; removing a wire removes only that wire.
- Port hit-testing has priority over wire and chip-body hit-testing. This keeps connected ports selectable and allows the four terminals on a switch to be wired. Clicking the switch body away from its ports still toggles it.
- When multiple wires share a port, their endpoints are fanned out visually.
- The existing nodal solver evaluates all wire and component branches in the network. Series loops and parallel branches use the same wiring interaction; there is no separate mode toggle.

## Student wiring patterns

### Parallel LEDs

Connect the battery positive terminal to each LED's positive/blue terminal, then connect every LED's negative/red terminal to the battery negative terminal. This creates two shared nodes and one branch per LED.

### Series LEDs

Connect battery positive to LED 1 positive; LED 1 negative to LED 2 positive; continue end-to-end; then connect the last LED negative terminal to battery negative. This creates one loop.

## Regression test

Run from the project root using Godot 4:

```sh
godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd
```

The test script checks five wires on each battery terminal in a parallel circuit, and a three-LED series loop. The package was inspected statically, but Godot runtime execution was not available in the build environment; run this test and launch the lab in the editor before treating the update as runtime-verified.
