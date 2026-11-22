# M9.1 — Apparatus & Equipment Audit

**Project:** OOPA Virtual Labs  
**Branch:** `integration/godot-app-preservation`  
**Audit baseline:** `79e2243a7b288ef9cfb3b390c519b71882dc44bd`  
**Engine:** Godot 4.7.2  
**Status:** M9.1 audit draft for owner review; no production visual work started.

## 1. Scope and method

The authoritative catalogue is [`data/config/labs_manifest.json`](../data/config/labs_manifest.json). It currently contains 22 labs, all marked `available`: Chemistry 6, Biology 5, Physics 5 and Engineering 6. Each manifest scene and its implementation script were checked for existence. The Logic Gate Builder scene is under `labs/engineering/logic_gate_builder/`; its nonstandard location is still resolved correctly by the manifest.

This is a source and scene-structure audit. It reviews each lab's manifest entry, scene/script, visual drawing paths and model dependency. It is not a new interactive operation of all 22 labs. The M6 scene-load and representative regression evidence remains the available runtime evidence.

## 2. Current visual and simulation architecture

- The 22 lab scripts use the shared `LabShell` workspace. Equipment/experiment stages are hosted inside that workspace; the shell provides navigation, responsive layout, theme, status and shared Jenny integration.
- The 21 conventional lab simulations use discipline-specific model classes under `scripts/models/`, separate from their lab presentation scripts. The Logic Gate Builder is the exception: gate graph and signal behaviour live in its lab script. Preserve that existing behavior; do not refactor it as part of a visual pass.
- Apparatus and experiment views are predominantly procedural 2D, drawn by `Control.draw` callbacks. Supporting charts, scales and annotations are also drawn in code. The scenes do not currently contain `Node3D`, `MeshInstance3D`, `Camera3D` or `SubViewport` equipment presentations.
- No GLB/GLTF/Blender equipment sources or laboratory apparatus image library were found. The existing Godot assets are branding, fonts and Jenny artwork.
- The project uses the GL Compatibility renderer, a 1280×720 base viewport and canvas-item stretch. A 3D prototype should be embedded in the existing workspace and profiled on the available Intel HD 4600/ANGLE environment; no performance figures have been measured.

## 3. Laboratory inventory and recommended visual category

The category column is the recommended target for M9, not a claim about current visual fidelity. “Advanced 2D” is intentionally retained for conceptual models, plots and schematics where depth would add little or could mislead. “Hybrid” keeps measurement plots and controls 2D while giving physical apparatus an appropriate dimensional presentation.

| Discipline / lab | Existing apparatus or experiment representation and simulation dependency | Recommended M9 category | Priority |
|---|---|---|---|
| Chemistry — Gas Laws | `GasLawsModel`; code-drawn gas chamber, movable piston, gas particles and pressure gauge; separate relation plot and recorded points. | Hybrid 2D/2.5D: depth-aware chamber and piston, with particles, gauge values and plots driven by the existing model. | Tier 2 |
| Chemistry — Acid–Base Titration | `TitrationModel`; code-drawn stand/clamp, graduated burette, stopcock/nozzle and Erlenmeyer flask. Titrant level, used volume, pH and indicator colour are tied to the model. | Hybrid 2D/2.5D: detailed glassware/stand illustration; retain the pH curve and controls as 2D. | Tier 1; 2.5D prototype candidate |
| Chemistry — Reaction Rates | `ReactionRatesModel`; plot-centric stage showing concentration against time, half-life and optional comparison run. No vessel or experimental apparatus is presently drawn. | Advanced 2D: kinetics plots remain primary; any future vessel inset must be clearly illustrative and must not imply unmodelled chemistry. | Tier 3 |
| Chemistry — Acid–Base & Buffers | `BuffersModel`; code-drawn beaker with pH-dependent liquid colour, pH/pKa scale and HA/A⁻ concentration-ratio bars. | Hybrid 2D/2.5D: a reusable beaker/solution visual plus 2D pH scale and species data. | Tier 2 |
| Chemistry — Chemical Equilibrium | `EquilibriumModel`; initial/equilibrium species concentration bars, labels, reaction selection, Kc/volume/temperature controls; no vessel depiction. | Advanced 2D first. A vessel/species illustration is optional and should be linked only to calculated concentrations. | Tier 3 |
| Chemistry — Chemical Reactions | `ChemicalReactionsModel`; two code-drawn flasks for reactants/products, equation, reaction type, limiting reagent, extent and product amounts. | Hybrid 2D/2.5D: improve flask/glass/liquid illustration while retaining stoichiometry and equation as 2D. | Tier 2 |
| Biology — Single-Celled Organisms | `SingleCellModel`; simulated bounded culture world, organism/cell markers, nutrient/waste field and population graph. This is a digital specimen view, not a physical apparatus. | Advanced 2D: microscope-like labelled field or culture-dish presentation; preserve model-scale clarity. | Tier 3 |
| Biology — Predator–Prey | `PredatorPreyModel`; population time series and prey-vs-predator phase portrait; no physical equipment view. | Advanced 2D: data visualization is the scientific representation. | Tier 3 |
| Biology — Ecosystems | `EcosystemsModel`; trophic pyramid whose widths follow biomass, population series and recycling/detritus indicators. | Advanced 2D: retain the explanatory ecology diagram and model-linked population data. | Tier 3 |
| Biology — Evolution | `EvolutionModel`; trait distribution by generation, population markers, mean/optimum indicators and fitness/trait plots. | Advanced 2D: distribution and selection visuals are more accurate than fabricated lab apparatus. | Tier 3 |
| Biology — Ecology | `EcologyModel`; two-species time series and phase-plane trajectory for competition/coexistence. | Advanced 2D: data visualization is the scientific representation. | Tier 3 |
| Physics — Particle Motion | `ParticleModel`; particle-box simulation, vectors and speed-distribution visualization. | Advanced 2D: preserve vector and distribution readability. | Tier 3 |
| Physics — Projectile Motion | `ProjectileModel`; simulated projectile, ideal and simulated trajectories, ghost/hoop markers, drag/wind/bounce parameters. No detailed physical launcher is drawn. | Advanced 2D: clear trajectory and measured-state depiction; avoid adding a 3D trajectory that obscures the 2D model. | Tier 3 |
| Physics — Pendulum & Springs | `PendulumSpringsModel`; code-drawn pivot/support, pendulum rod and bob or spring/mass, motion trace and phase/energy plots. | Hybrid 2D/3D: candidate for a genuine 3D apparatus view synchronized to the existing planar state, with plots kept 2D. Do not add out-of-plane physics. | Tier 1; 3D prototype candidate |
| Physics — Collision Motion | `CollisionModel`; two moving bodies, trails and velocity vectors; 1D/2D collision settings and outputs. | Advanced 2D: the collision plane, vectors and conservation values should remain explicit. | Tier 3 |
| Physics — Wave Interference | `WaveModel`; coherent sources, rendered interference field, screen position and screen-intensity graph. | Advanced 2D: spatial field and fringe geometry are inherently diagrammatic. | Tier 3 |
| Engineering — Circuit Builder | `CircuitModel`; code-drawn board/grid, wires and interactive battery, resistor, switch, diode/LED, meters and later-added capacitor, inductor, potentiometer, fuse, motor, lamp and NPN transistor. Solver state supplies component readings and visual states. | Advanced 2D: retain schematic/breadboard semantics and make component symbols/material cues clearer; do not replace the circuit solver. | Tier 1; 2D prototype candidate |
| Engineering — Logic Gate Builder | Logic graph and signal propagation implemented in `logic_gate_builder_lab.gd`; code-drawn gate nodes, input/output pins, wires, switches, state indicators and truth table. | Advanced 2D: logic diagrams are clearest as a precise, interactive schematic. | Tier 2 |
| Engineering — Fluid Dynamics | `FluidDynamicsModel`; code-drawn changing-diameter/elevated pipe (Venturi-style), moving flow markers, inlet/section pressure and velocity annotations, pressure bars and graph. Values are taken from the model result. | Hybrid 2D/2.5D: depth-aware pipe and pressure taps with 2D labels/graph, all linked to existing outputs. | Tier 1; 2.5D prototype candidate |
| Engineering — Heat Transfer | `HeatTransferModel`; coloured multilayer wall cross-section, hot/cold boundaries, material/thickness labels, interface temperatures, heat flux and temperature profile. No material asset set is present. | Hybrid 2D/2.5D: layered cutaway with restrained material cues; keep the 1D calculation and graph authoritative. | Tier 2 |
| Engineering — Robot Arm | `RobotArmModel`; planar two-link base/elbow/end-effector, target and reachable workspace, forward/inverse kinematics controls. | Hybrid 2D/2.5D: preserve the planar kinematic model; use depth only for link/joint readability, not additional degrees of freedom. | Tier 2 |
| Engineering — Simple Machines | `SimpleMachinesModel`; alternate lever/fulcrum, inclined plane, pulley/strands and wheel-and-axle drawings with load/effort annotations. | Detailed 2.5D illustrations with 2D force/distance labels; geometry must continue to represent the selected ideal/mechanical model. | Tier 2 |

## 4. Animation and interaction opportunities

- **Direct model-driven motion/state:** Pendulum & Springs pose/trace, Robot Arm joint and end-effector pose, Circuit Builder component state/readings, Fluid Dynamics pressure/velocity/flow cues, Heat Transfer layer/interface temperatures, Titration burette volume/flask pH colour, Buffers beaker pH colour, Chemical Reactions reactant/product amounts, and the population/particle states in Biology and Particle Motion.
- **Existing user interaction to preserve:** circuit placement/wiring/switches, logic node placement and wiring, robot-arm angle/target interaction, projectile hoop placement, and the parameter controls already exposed by each model-driven lab.
- **Animation policy:** animate only observable state already represented by the simulation. Titrant motion, a pendulum swing, spring displacement, flow markers, indicator colour or a circuit's operating state can visualize existing outputs. Do not imply a measured fluid path, reaction mechanism, thermal gradient or 3D degree of freedom that the model does not calculate.
- **Check before connecting:** some particles and pulses are managed by view scripts rather than model outputs. M9.2 should trace those values before treating their motion as scientific state. Static conceptual and chart-led labs do not need decorative equipment animation.

## 5. Reuse opportunities

1. **Glassware family:** burette, flask and beaker visuals can share glass outlines, graduations, liquid fill and colour-state components across Titration, Buffers and Chemical Reactions. Their chemistry/model semantics must remain separate.
2. **Measurement instruments:** reusable gauge/scale and labelled-value patterns apply to Gas Laws and Fluid Dynamics; reusable model-driven meter/readout styles apply to Circuit Builder and Heat Transfer.
3. **Mechanical parts:** pivot, link, mass, spring, pulley and wheel components can inform Pendulum & Springs, Robot Arm and Simple Machines. Share visuals only when proportions and physical meaning match.
4. **Data visuals:** keep graphs, axes, labels and population/particle diagrams in 2D. They are not candidates for ornamental 3D conversion.
5. **Workspace mounting:** attach equipment presentations through `LabShell` stage/extra hosts. Retain the shared shell, theme, navigation, status row and existing responsive layout.

## 6. Constraints and preservation notes

- Keep each existing model and its current inputs/results authoritative. In particular, Circuit Builder visuals must continue to reflect `CircuitModel`; Venturi dimensions, pressure and velocity should come from `FluidDynamicsModel`; titration colour/volume/pH from `TitrationModel`; and pendulum/spring pose from `PendulumSpringsModel`.
- Most models are already separate from view scripts. Logic Gate Builder is the exception; M9 should preserve its existing script behavior unless a separately reviewed architecture decision authorizes work outside visualization.
- There is no established 3D asset-import pipeline, equipment asset directory or editable Blender source set. M9.2 should specify conventions before adding production assets.
- The GL Compatibility renderer and the observed Intel HD 4600/ANGLE path make high-cost shaders, transparent glass, dynamic shadows and dense meshes a risk to measure, not assume. No performance measurements are claimed by this audit.
- The manifest includes no dedicated chemical-process plant lab (for example, a distillation or reactor simulation). Fluid Dynamics is the closest process-flow visualization candidate; Titration is the strongest existing chemistry glassware candidate.

## 7. Recommended sequence

### M9.3 prototype candidates (after M9.2 is reviewed and accepted)

1. **Circuit Builder — Advanced 2D.** It is the strongest case for a refined schematic and has a distinct, testable model-to-component state link.
2. **Fluid Dynamics — detailed 2.5D.** Its pipe geometry, diameter transition, flow markers, pressure and velocity outputs give dimensional treatment a clear teaching purpose. Titration is an alternate if the owner prefers a chemistry glassware prototype.
3. **Pendulum & Springs — genuine 3D.** The existing model supplies a planar state that can drive a 3D presentation without changing the physics. Keep the model plane and its graphs visible.

This selection represents the three approved visualization modes and electrical, engineering and physics content. It does not claim that any M9.3 prototype has started.

### Production prioritisation after prototype acceptance

- **Tier 1 — prototype/reference set:** Circuit Builder, Fluid Dynamics, Pendulum & Springs; also use Titration as the alternate chemistry apparatus reference.
- **Tier 2 — equipment-forward scenes:** Gas Laws, Buffers, Chemical Reactions, Heat Transfer, Robot Arm, Simple Machines and Logic Gate Builder.
- **Tier 3 — conceptual/data-led scenes:** Reaction Rates, Chemical Equilibrium, the five Biology models, Particle Motion, Projectile Motion, Collision Motion and Wave Interference.

Tier 3 is not a lower quality target. It means the audit found the scientific representation to be primarily a graph, field, population or schematic; no fabricated physical rig is recommended.

## 8. M9.1 acceptance checklist

- [x] Audited the authoritative manifest: all 22 labs are enumerated and available.
- [x] Confirmed all manifest scene paths and corresponding scripts exist.
- [x] Recorded each lab's present representation and model/script dependency.
- [x] Assigned a recommended 2D, 2.5D, 3D or hybrid target to each lab.
- [x] Identified shared component opportunities, constraints and a prioritised sequence.
- [x] No lab scene, simulation, project setting, asset or web-application file was changed for this audit.
- [ ] Owner review and acceptance of M9.1.
- [ ] M9.2 architecture work (must follow M9.1 acceptance).

**Next gate:** Submit this audit for review. Do not begin M9.2 or M9.3 until the owner accepts M9.1; do not begin M9.4 production before M9.3 prototype approval.
