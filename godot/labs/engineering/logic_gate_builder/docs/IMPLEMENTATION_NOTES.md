# Implementation notes

The Logic Gate Builder uses the same Godot 4 project conventions as OOPA Virtual Labs, but its standalone project has its own `project.godot` and `res://` root. The parent OOPA application opens the integrated lab scene at `labs/engineering/logic_gate_builder/scenes/logic_gate_builder_lab.tscn`.

Signal rules: all logic is Boolean; disconnected input ports read LOW; combinational cycles return LOW at the recursive edge to prevent infinite recursion. Gate expressions are shown on each gate card.


## Manual simulation control refinement
The circuit now starts in a STOPPED state. Students may set input switches and build connections before pressing **Play Simulation**. The same control toggles to **Pause Simulation** while running. Paused mode suppresses downstream live signal propagation; truth-table generation forces independent evaluations and remains available while paused. Reset returns to the stopped starter circuit.

### Manual-start behavior checks
- Initial state is STOPPED; no gate outputs or signal wires are active until Play is clicked.
- Input switches remain editable while stopped so learners can prepare test vectors.
- Play starts live combinational evaluation; the button changes to Pause Simulation.
- Pause suppresses downstream live signal propagation while retaining input settings and wiring.
- Truth-table generation uses forced evaluation and remains usable while the live simulation is paused.
- Reset restores the starter AND circuit and stops the simulation.


## Manual wiring and placement refinement (2026-10-26)

- Ports are labelled: green `Y` output ports and yellow `A`/`B` input ports.
- Wiring requires choosing a source output followed by a destination input.
- Invalid source/destination kinds, self-connections, invalid port indices, and directed feedback cycles are rejected with status messages.
- Replacing an occupied input port is allowed but explicitly reported.
- The selected source is highlighted while wire mode is active.
- Components can be dragged by their body; positions are clamped to the board bounds and wires remain attached because they are drawn from live node positions.
- Existing Play/Pause, starter circuit, reset, truth-table generation, and gate semantics are retained.
- Runtime execution tests were not run in this environment because a Godot executable was not available. Validate in Godot 4 before release.
