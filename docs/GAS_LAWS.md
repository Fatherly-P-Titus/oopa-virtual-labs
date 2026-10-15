# Gas Laws (Chemistry lab)

`labs/chemistry/gas_laws/` – an ideal gas in a cylinder with a movable piston, a pressure gauge, a graph and a data table.

## Model
- One ideal gas: `PV = nRT`, with P in kPa, V in litres, T in kelvin, n in moles and R = 8.314 J/(mol·K). (kPa × L = J, so the units agree.)
- Pressure is **calculated** from the law. The moving dots are an illustration: their speed follows `v_rms ∝ √T`, their number follows `n` (40 per mole), and the container height follows `V`. They do not collide with each other, and they do not produce the pressure reading.
- Limits: V 2–30 L, T 100–800 K, n 0.1–3.0 mol. The gauge is logarithmic, 1–10 000 kPa.

## Laws
Choosing a law captures the current state as a baseline. That law holds two quantities at their baseline values and gives the learner one control; the fourth quantity follows from PV = nRT.

| Law | Held constant | You control | Follows | Constant shown |
|-----|---------------|-------------|---------|----------------|
| Free play | nothing | V, T, n | P | PV ÷ nT (= R) |
| Boyle’s | T, n | V | P | P × V |
| Charles’s | P, n | T | V | V ÷ T |
| Gay-Lussac’s | V, n | T | P | P ÷ T |
| Avogadro’s | P, T | n | V | V ÷ n |

In Charles’s and Avogadro’s laws the piston can reach its limit. The control then stops at that value and a note appears.

## Using it
Press **Record data point** at several settings. The table’s last column should be the same in every row (that is the law), and the graph shows the points against the law’s prediction. The dashed prediction line runs back toward the origin; the solid red part is the range the piston can reach. Recording is cleared whenever the law changes, because the graph axes change with it.

## Notes
- Mass of gas is in moles, not grams, to keep the focus on the laws.
- Pause stops only the dots; the readouts and graph still respond to the controls.
