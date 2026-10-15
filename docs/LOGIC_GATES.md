# Logic Gates (Engineering lab)

`labs/engineering/logic_gates/` – interactive combinational logic: place gates, wire them, toggle inputs and watch levels propagate.

## Gates
| Gate | Inputs | Output |
|------|--------|--------|
| NOT  | 1 | ¬A |
| AND  | 2 | A ∧ B |
| OR   | 2 | A ∨ B |
| NAND | 2 | ¬(A ∧ B) |
| NOR  | 2 | ¬(A ∨ B) |
| XOR  | 2 | A ⊕ B |
| XNOR | 2 | ¬(A ⊕ B) |

Also: **Input** switches (user-driven 0/1) and **Output** probes (display only).

## Evaluation
- Levels are boolean (0 / 1). Unconnected inputs read as 0.
- Propagation is combinatorial: the circuit is evaluated in topological order each time an input changes. Cycles are detected and reported (no sequential/memory devices in this lab).
- Ideal gates only — no delay, no voltage thresholds, no fan-out limits.

## Controls
- Palette: Select, Input, Output, each gate type, Wire, Delete.
- Click canvas to place; click two ports (output → input) to wire.
- Click an Input switch to toggle 0 ↔ 1.
- Presets: inverter, AND-OR, half-adder, XOR from NAND.
- Truth table panel for a selected 1- or 2-input gate.

## Files
- `scripts/logic-gates-model.js` – graph + evaluate (`window.LogicGatesModel`).
- `scripts/logic-gates.js` – canvas UI.
- `styles/logic-gates.css` – layout.
