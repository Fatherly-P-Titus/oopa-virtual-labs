# Logic Gate Builder Manual QA Checklist

Run in both the integrated OOPA project and the standalone project using Godot 4.

## Wiring
- [ ] Select a gate's green Y port, then connect to a gate's yellow A port.
- [ ] Connect a second source to B; verify labels and wire endpoints align.
- [ ] Connect to an output indicator's yellow Y input.
- [ ] Attempt to wire an output indicator as a source; verify a clear rejection.
- [ ] Attempt a self-connection; verify rejection.
- [ ] Attempt a directed feedback cycle (A → B → A); verify rejection.
- [ ] Replace an occupied input; verify the old wire is replaced and a message appears.
- [ ] Verify the selected source gets a highlight and clears after a connection attempt.

## Placement and simulation
- [ ] Drag each component type and verify wires remain attached.
- [ ] Drag components to board edges; verify they stay within bounds.
- [ ] Click an input switch without dragging; verify its value toggles.
- [ ] Play and pause; verify status/button labels and live signal propagation.
- [ ] Reset; verify the starter AND circuit returns and simulation stops.
- [ ] Generate a truth table and verify input values are restored afterward.
- [ ] Run the half-adder challenge and verify its instructions.

## Integration
- [ ] Open Logic Gate Builder from the integrated hub.
- [ ] Confirm integrated and standalone scripts are byte-identical.
- [ ] Run the standalone truth-table test and the project circuit-builder regression test.
