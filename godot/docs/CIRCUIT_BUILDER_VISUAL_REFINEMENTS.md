# Circuit Builder visual refinements

- Reduced wire strokes to 2 px for the main segment and 1.5 px for endpoint fan-out; pending wires are 2 px.
- Changed white and orange LEDs, plus the diode, to round component bodies.
- Moved battery and resistor terminals to separated points along the top edge; placed all four switch terminals along its top edge; positioned LED/diode terminals slightly apart near the top of each round body.
- Added visible component symbols: battery plates/polarity, resistor zig-zag, diode symbol, LED symbol with light arrows, and switch contact/lever with ON/OFF state.
- Component rotation remains available before wiring, and terminal hit-testing continues to take priority over component-body clicks.

Runtime validation requires Godot 4. Run the project's regression test with:

```bash
godot --headless --path . --script res://tests/circuit_builder_multiwire_test.gd
```
