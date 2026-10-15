# Electrochemistry / Galvanic Cell (Chemistry lab)

`labs/chemistry/electrochemistry/` – galvanic cells, standard potentials, Nernst equation, free energy and cell diagrams.

## Model
- Half-reactions written as reductions. The electrode with the **higher** reduction potential is the cathode (reduction); the lower is the anode (oxidation).
- Standard cell potential:
  \[
  E^\circ_{\mathrm{cell}} = E^\circ_{\mathrm{cathode}} - E^\circ_{\mathrm{anode}}
  \]
- Nernst equation (25 °C, concentrations in mol/L as activity proxies):
  \[
  E = E^\circ - \frac{0.05916}{n}\log_{10} Q
  \]
  where \(Q\) is the reaction quotient for the balanced cell reaction and \(n\) is the number of electrons transferred.
- Gibbs free energy: \(\Delta G = -nFE\) (J), with \(F = 96485\) C/mol. Spontaneous when \(E > 0\) (\(\Delta G < 0\)).
- Equilibrium constant: \(\log_{10} K = n E^\circ / 0.05916\).

## Electrodes included
Li⁺, K⁺, Ca²⁺, Na⁺, Mg²⁺, Al³⁺, Zn²⁺, Fe²⁺, Ni²⁺, Sn²⁺, Pb²⁺, H⁺ (SHE), Cu²⁺, Ag⁺, Au³⁺ (and Cl₂/Cl⁻ as a non-metal option).

## Limits
- Ideal dilute aqueous half-cells; no overpotential, resistance, or kinetic limitations.
- Activities ≈ concentrations. No complexation or pH-dependent oxide films.
- Salt bridge is schematic (ion flow indicated, not simulated).

## Files
- `scripts/electrochemistry-model.js` – potentials, Nernst, ΔG, K.
- `scripts/electrochemistry.js` – cell diagram + controls.
- `styles/electrochemistry.css` – layout.
