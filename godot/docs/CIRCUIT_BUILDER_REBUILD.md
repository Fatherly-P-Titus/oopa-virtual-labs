# Circuit Builder — Electrical Solver Rebuild

## Changes in this pass
- Removed all Load Demo buttons and helper functions; the board now starts empty.
- Replaced the old fixed-resistance LED calculation with a piecewise-linear nonlinear DC nodal solver.
- Added a general diode component with forward conduction, reverse blocking leakage, and approximate reverse breakdown. White LEDs use a 3.0 V knee; orange LEDs use a 2.0 V knee. These are educational nominal models, not manufacturer-specific curves.
- Added finite wire/contact resistance so branch wire currents can be estimated rather than painting every wire with the same maximum current.
- Added selected-component voltage drop and signed current readouts; battery power uses the solved battery current.
- Added a one-battery guard, convergence/error messages, and small leakage conductance to handle floating subcircuits.

## Model limitations
The diode model is piecewise-linear, not a full temperature-dependent Shockley model. Reverse breakdown is approximate. The battery is an ideal fixed-voltage source with no internal resistance. The simulator is intended for learning and must not be used to design or certify real hardware.

## Test
Open `project.godot` in Godot 4.x and run the Circuit Builder scene. The board should start empty. Add BAT, R, LED/diode, and connect a closed loop. Select each component to inspect signed current and voltage drop. Reverse a diode by swapping its port connections and verify that current falls to leakage except above the approximate breakdown knee. Godot runtime verification is still required on the target host.
