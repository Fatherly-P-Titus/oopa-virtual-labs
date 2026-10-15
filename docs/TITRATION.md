# Titration (Chemistry lab)

`labs/chemistry/titration/` – an acid–base titration with a burette, flask, indicator, pH meter and live curve.

## Chemistry
- Acid and base react 1 : 1 at 25 °C (Kw = 1 × 10⁻¹⁴). Equivalence volume: `Veq = Ca × Va ÷ Cb`.
- The pH is found from the exact charge balance of the mixed solution, so the start, buffer region, equivalence point and excess-titrant region all come from one equation. With `A = Ca·Va/(Va+Vb)` and `B = Cb·Vb/(Va+Vb)`:
  - strong acid / strong base: `[H⁺] − [OH⁻] = acid − base`, a quadratic in `[H⁺]`
  - weak acid (Ka) with NaOH: `[H⁺] + B = [OH⁻] + A·Ka/([H⁺] + Ka)`, solved by bisection on pH
  - weak base (Kb) with HCl: `[H⁺] + A·[H⁺]/([H⁺] + Kw/Kb) = [OH⁻] + B`
- Reactions offered: strong acid + strong base, weak acid (ethanoic, Ka 1.8 × 10⁻⁵) + strong base, strong base + strong acid, weak base (ammonia, Kb 1.8 × 10⁻⁵) + strong acid.
- Indicators: the fraction in the base colour is `1 / (1 + 10^(pK_in − pH))`, and the flask colour blends the two colours by that fraction. Methyl orange (pK 3.7), methyl red (5.1), bromothymol blue (7.0), phenolphthalein (9.4).
- Activity effects are ignored, so very concentrated solutions differ slightly from a real meter.

## Using it
- Add titrant with **+1 mL**, **+0.1 mL**, **+1 drop** (0.05 mL) or **Run** at a chosen flow rate. **Undo** steps back to the previous recorded point; **Start over** refills the burette. Changing the reaction or a concentration or volume starts over; changing the indicator does not.
- The graph plots the learner's own points. Optional: the full theoretical curve (dashed) and the equivalence point.
- The shaded band on the graph is the chosen indicator's colour-change range. The **indicator check** finds the volume at which the indicator reaches its pK and reports how far that is from the equivalence point (within 1 % = good, within 5 % = acceptable, otherwise poor).
- The burette holds 50 mL. If a titration would need more, the page says so.

## Unknown mode
Tick **Unknown flask solution**. The flask strength is chosen at random (0.060–0.240 M) and hidden, and the equivalence point, full curve and indicator check are hidden too. Titrate to the colour change, press **Record endpoint**, calculate `flask strength = burette strength × volume added ÷ flask volume`, type the answer and press **Check answer**. The page reveals the true value and the percentage error. **New unknown** picks another.
