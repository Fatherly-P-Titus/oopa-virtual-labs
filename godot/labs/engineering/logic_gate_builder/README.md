# Logic Gate Builder

The integrated Logic Gate Builder is the OOPA Engineering laboratory for Boolean digital circuits. It is launched by the existing Engineering hub route at `res://labs/engineering/logic_gate_builder/scenes/logic_gate_builder_lab.tscn` and continues to use the shared `LabShell`.

## Integrated features

- Input switches, output indicators, and AND, OR, NOT, NAND, NOR, XOR, and XNOR gates.
- A model-backed circuit graph with deterministic Boolean evaluation, explicit UNKNOWN and ERROR states, single-driver inputs, cycle prevention, component deletion cleanup, and multi-output circuits.
- A 2D engineering workspace with gate symbols, terminal pins, signal-coloured curved wires, selection, grid-snapped movement, drag-to-wire, pan, and zoom.
- A categorized component library, contextual inspector, live output panel, starter AND circuit, half-adder example, and generated truth tables (up to eight independent inputs).
- Truth tables are blocked when the circuit is incomplete or invalid; Boolean outputs are never guessed for unconnected ports or feedback loops.

## Automated checks

Run from the Godot project root with Godot 4.7.2:

```text
godot --headless --path . --script res://tests/logic_circuit_model_test.gd
godot --headless --path . --scene res://labs/engineering/logic_gate_builder/scenes/logic_gate_builder_lab.tscn --quit-after 2
```

`res://tests/circuit_builder_multiwire_test.gd` remains a regression check for the separate analog Circuit Builder and is not the digital logic model test.

## Standalone copy

`standalone_project/` is a legacy, separate project copy. The integrated app route uses the production scene and scripts described above; the standalone implementation is not authoritative for current integrated behavior.
