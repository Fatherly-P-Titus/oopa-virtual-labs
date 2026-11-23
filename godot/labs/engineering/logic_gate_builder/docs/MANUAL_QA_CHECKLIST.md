# Logic Gate Builder manual QA checklist

Run from the integrated OOPA project in Godot 4.7.2. Automated tests do not replace visual and interaction review.

## Launch and visual layout

- [ ] Open Logic Gate Builder from Engineering and confirm it remains inside the shared LabShell.
- [ ] Confirm the library, canvas, inspector, live outputs, and truth-table panel fit without overlap at the project window size.
- [ ] Check text, terminal labels, gate symbols, selected outlines, and signal colors at normal zoom.

## Construction and wiring

- [ ] Drag input, gate, and output entries onto the canvas; verify grid-aligned placement.
- [ ] Move components and confirm wires remain attached to the correct pins.
- [ ] Pan with middle mouse and zoom with the wheel around the pointer.
- [ ] Drag a source Y pin to gate A/B and output Y inputs; verify clear wire and terminal feedback.
- [ ] Replace an occupied destination and verify the previous driver is removed with a status message.
- [ ] Try self-feedback and a multi-gate directed cycle; verify rejection and no fabricated logic result.
- [ ] Select and delete a wire; delete a component and verify attached wires are removed.
- [ ] Toggle input switches; verify output lamps and wires reflect evaluated values.

## Analysis and correctness

- [ ] Check the starter AND circuit for all four input combinations.
- [ ] Load the half-adder and verify SUM is XOR and CARRY is AND for all combinations.
- [ ] Create an incomplete circuit and verify UNKNOWN/UNCONNECTED status and truth-table refusal.
- [ ] Generate a truth table for a complete circuit; confirm input/output columns and row values.
- [ ] Generate a table with multiple outputs and verify the table matches the live evaluation.
- [ ] Confirm truth-table generation restores the current input settings.
- [ ] Clear/reset the workspace and verify the expected empty/starter state.

## Preservation

- [ ] Open the separate analog Circuit Builder and confirm its existing electrical simulation still loads and behaves as before.
- [ ] Confirm other laboratory routes and shared application navigation remain available.
