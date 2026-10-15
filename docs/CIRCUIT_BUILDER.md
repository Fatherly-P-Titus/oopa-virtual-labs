# Circuit Builder (Engineering lab)

`labs/engineering/circuit_builder/` – interactive DC circuit workspace with batteries, resistors, switches and meters.

## Model
- Ideal DC only. Wires have zero resistance. Batteries are ideal voltage sources. Resistors are ideal (Ohm’s law \(V = IR\)).
- Switches are either open (\(R = \infty\)) or closed (\(R = 0\)).
- Ammeters are placed in series and report the current through their branch; they add negligible resistance.
- Voltmeters report the potential difference between the two nodes they span; they draw no current.
- The solver uses **nodal analysis**. One terminal of the first battery is treated as ground (0 V). Node voltages are found from the conductance matrix; branch currents follow from Ohm’s law and KCL.
- Circuits with no path from battery positive back to negative (open) give zero current. Short circuits across a battery are flagged and not solved as infinite current.

## Limits of the model
- No AC, capacitors, inductors, diodes or non-linear devices.
- Maximum practical size is about a dozen components (matrix stays small and the canvas stays readable).
- Ideal components only: no internal resistance, no temperature effects, no wire resistance.
- Floating sub-circuits (nodes with no path to ground) are reported as unresolved.

## Controls
- **Palette**: Battery, Resistor, Switch, Wire, Ammeter, Voltmeter, Delete.
- Click a tool, then click the canvas (snap grid) to place a component. Click two terminals in sequence to draw a wire.
- Click a switch on the canvas to open or close it.
- Select a component to edit its value (voltage or resistance).
- Presets load ready-made series, parallel and mixed circuits.
- Clear removes everything. Analyse recalculates voltages and currents (also runs live after most edits).

## Files
- `scripts/circuit-model.js` – pure circuit graph, nodal solver (`window.CircuitModel`, also require-able).
- `scripts/circuit-builder.js` – canvas drawing, placement, palette, readouts and presets.
- `styles/circuit-builder.css` – page layout; shared chrome from `styles/lab-shell.css`.

## Testing notes
No automated tests are shipped with this project. It is intended to be exercised in a browser. Known intentional simplifications are listed above.
