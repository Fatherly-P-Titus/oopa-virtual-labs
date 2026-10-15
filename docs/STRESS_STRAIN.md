# Stress and Strain (Engineering lab)

`labs/engineering/stress_strain/` – axial loading of a prismatic bar: stress, strain, Young’s modulus and safety factor.

## Model
- Axial force \(F\) on a bar of length \(L\) and cross-section area \(A\) (circular diameter \(d\): \(A = \pi d^2/4\)).
- Engineering stress: \(\sigma = F / A\)
- Engineering strain: \(\varepsilon = \delta / L\)
- Linear elastic: \(\sigma = E\varepsilon\) so elongation \(\delta = FL/(AE)\)
- Safety factor: \(n = \sigma_y / \sigma\) (yield stress over working stress). \(n < 1\) means the bar has yielded in this ideal model.
- Materials are ideal linear-elastic up to \(\sigma_y\); beyond that the lab still plots \(\sigma = F/A\) but flags yield.

## Limits
- Uniaxial tension/compression only; no bending, torsion or buckling.
- Uniform cross-section; no stress concentrations.
- No time-dependent behaviour (creep, plasticity curve beyond a simple yield flag).

## Files
- `scripts/stress-strain-model.js` – pure formulae.
- `scripts/stress-strain.js` – bar diagram, σ–ε plot, controls.
- `styles/stress-strain.css` – layout.
