# Acid–Base Strength / Buffers (Chemistry lab)

`labs/chemistry/buffers/` – weak acids, pH, Henderson–Hasselbalch buffers and buffer capacity.

## Modes
1. **Weak acid** — HA solution, exact quadratic for [H⁺] from \(K_a\).
2. **Buffer** — HA / A⁻ pair, Henderson–Hasselbalch with optional exact charge-balance refinement.
3. **Strong acid / strong base** — full dissociation for comparison.

## Model
- Weak acid: \(K_a = [H^+][A^-]/[HA]\), charge balance → quadratic.
- Buffer pH ≈ \(pK_a + \log_{10}([A^-]/[HA])\).
- After adding strong acid or base to a buffer, new amounts of HA and A⁻ are used in the same expression (capacity demo).
- Water autoionization neglected when [H⁺] ≫ 10⁻⁶ (typical teaching approximation); flagged at very dilute extremes.

## Limits
- Ideal dilute aqueous solutions, 25 °C. No activity coefficients, no polyprotic acids beyond a single \(K_a\).

## Files
- `scripts/buffers-model.js` – pure pH / buffer maths.
- `scripts/buffers.js` – UI + pH scale visualisation.
- `styles/buffers.css` – layout.
