# OOPA Logic Gate Builder

Standalone Godot 4 digital logic laboratory. This project is intentionally kept separate from the existing Circuit Builder and lives under `labs/engineering/logic_gate_builder/standalone_project/`.

## Features in this milestone
- AND, OR, NOT, NAND, NOR, XOR and XNOR gates.
- Input switches (Boolean 0/1) and output indicators.
- Click-to-connect wiring, signal visualization, selection, deletion and directional nudging.
- Manual-start simulation: circuits load stopped; students click Play Simulation to activate live Boolean evaluation and can pause before editing. Unconnected gate inputs default to LOW.
- Generated truth tables for up to 8 input switches.
- Half-adder challenge prompt.
- Starter AND circuit and reset control. Reset returns the simulation to STOPPED.
- Root OOPA Engineering menu card integration.

## Run standalone
Open `standalone_project/project.godot` in Godot 4.7+ and run the project.

## Run truth tests
`godot --headless --path standalone_project --script res://tests/logic_gate_truth_test.gd`

## Known limits in this first milestone
- Wiring is performed by clicking ports; drag-to-wire is not included yet.
- Component placement uses add + select + arrow controls, not free dragging.
- Truth-table generation enumerates the current combinational network; feedback is guarded by cycle detection and resolves to LOW on the recursive edge rather than modeling sequential memory.
- The half-adder challenge is a guided task prompt; automatic solution validation and save/load are planned for a later milestone.
