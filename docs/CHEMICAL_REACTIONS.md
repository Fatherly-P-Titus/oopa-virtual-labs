# Chemical Reactions (Chemistry lab)

`labs/chemistry/chemical_reactions/` – pick elements from the periodic table, combine them, and see chemically realistic products, balanced equations and reaction types.

## Purpose
Explore **synthesis** and related element–element (and element–simple molecule) reactions. The lab teaches that products follow bonding rules and stoichiometry — e.g. N₂ + H₂ yields **NH₃**, not NH₂.

## Model
- Reactants are elements (or their common molecular forms: H₂, N₂, O₂, F₂, Cl₂, Br₂, I₂).
- A curated reaction table maps reactant sets → products, balanced equations, type and notes.
- Matching is order-independent. Stoichiometric coefficients are fixed for each known reaction.
- If no stable simple product is tabulated, the lab reports “no simple reaction under standard teaching conditions” with a short reason (noble gas, prefers other partners, needs extreme conditions, etc.).

## Reaction types covered
Synthesis (combination), combustion-style oxidation, halogenation, and a few displacement-style notes where an element displaces another conceptually.

## Limits
- Not a full reaction-prediction AI. Coverage focuses on main-group binary chemistry taught at introductory level.
- No aqueous ion tables, no organic functional-group reactions, no kinetics or equilibrium yields.
- States and conditions are simplified teaching defaults.

## Files
- `scripts/reactions-model.js` – element data + reaction knowledge base.
- `scripts/chemical-reactions.js` – periodic table UI + results.
- `styles/chemical-reactions.css` – layout.
