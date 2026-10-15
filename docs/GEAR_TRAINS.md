# Gear Trains (Engineering lab)

`labs/engineering/gear_trains/` – interactive spur-gear trains: ratio, speed, torque and direction.

## Model
- Ideal spur gears, constant pitch so centre distance ∝ (N₁ + N₂).
- Meshing pair: speed ratio \(n_2 / n_1 = -N_1 / N_2\) (negative = opposite rotation).
- Compound shaft: two gears fixed together share the same angular speed.
- Overall train ratio (magnitude): product of (driven teeth / driver teeth) for each mesh.
- Ideal torque: \(\tau_{\mathrm{out}} = \tau_{\mathrm{in}} \times |ratio|\) (no losses). With efficiency \(\eta\): \(\tau_{\mathrm{out}} = \tau_{\mathrm{in}} \times |ratio| \times \eta\).
- Power conserved in the ideal case: \(\tau\omega\) constant along the train.

## Train types in the lab
1. **Simple pair** – two gears.
2. **Idler** – three gears in a line (idler reverses direction twice → output same sense as input; ratio from first/last only).
3. **Compound** – two pairs with a shared intermediate shaft (two gears locked together).

## Limits
- No backlash, tooth strength, or helical/bevel gears.
- Efficiency is a single factor on output torque, not a detailed mesh-loss model.
- Animation is kinematic (angles from integrated speed), not a dynamics simulation.

## Files
- `scripts/gear-trains-model.js` – pure ratio / speed / torque maths.
- `scripts/gear-trains.js` – canvas gears + controls.
- `styles/gear-trains.css` – layout.
