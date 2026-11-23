# Logic Gate Builder implementation notes

## Integration route and boundaries

The Engineering hub launches `res://labs/engineering/logic_gate_builder/scenes/logic_gate_builder_lab.tscn`. That scene inherits the existing `LabShell`. The digital Boolean lab is distinct from the analog Circuit Builder at `res://scenes/labs/engineering/circuit_builder/circuit_lab.tscn`; the analog model and route are preserved.

## Production architecture

- `res://scripts/models/engineering/logic_circuit_model.gd` owns component data, graph topology, validation, Boolean evaluation, cycle checks, expressions, and truth-table generation.
- `res://labs/engineering/logic_gate_builder/scripts/logic_gate_canvas.gd` renders the grid, gate packages/symbols, terminals and wires; it translates pointer gestures into controller signals.
- `res://labs/engineering/logic_gate_builder/scripts/logic_gate_builder_lab.gd` integrates the model and canvas with LabShell, component library, inspector, output readouts, controls, and truth-table view.
- `res://tests/logic_circuit_model_test.gd` exercises the production model, not a duplicate implementation.

## Signal and connection rules

The supported gates are AND, OR, NOT, NAND, NOR, XOR, and XNOR. NOT has one input; each binary gate has two. Input switches provide Boolean LOW/HIGH values. Output lamps only display evaluated values. Each destination input accepts one driver; an explicit replacement removes its prior wire. Self-links and cycles are rejected. Removing a component removes attached wires.

Unconnected gate inputs evaluate to UNKNOWN and are reported. UNKNOWN propagates through the relevant gate and output. Evaluation does not claim an incomplete circuit is valid for truth-table generation. Invalid dependencies/cycles produce errors. A truth table is generated only for a complete, valid circuit, enumerates up to eight independent inputs, supports multiple outputs, and restores the live switch values afterward.

## Interaction

Drag a component-library entry onto the canvas to place it. Drag a component body to move it on the 32-unit grid. Drag an output terminal to a destination input terminal to connect it. Click an input switch to toggle its state. Middle-drag pans; the wheel zooms about the pointer. Select a wire and press Delete to remove it; select a component and press Delete or use the inspector action to remove it and attached wires.

## Verification

Run the production Boolean model suite using:

`godot --headless --path . --script res://tests/logic_circuit_model_test.gd`

The analog model regression at `res://tests/circuit_builder_multiwire_test.gd` remains a separate preservation check. Headless scene loading checks integration and parsing; manual Godot review is still required for visual quality and pointer interaction.
