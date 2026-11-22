# M9.2 — Apparatus Visual Architecture

**Project:** OOPA Virtual Labs  
**Engine:** Godot 4.7.2  
**Renderer:** GL Compatibility  
**Base viewport:** 1280×720, canvas-item stretch  
**Architecture baseline:** M7 commit `79e2243a7b288ef9cfb3b390c519b71882dc44bd`  
**Current implementation baseline:** `70bb3c4b530ba770dbeb556d7e69830fee730021`  
**Status:** implementation specification for M9.3/M9.4, based on the M9.1 inventory.

## 1. Principles

1. Existing simulation models, constants, equations, validation and outputs remain authoritative.
2. Apparatus presentation belongs in the lab view or reusable visual scene; do not move scientific calculations into visual nodes.
3. Existing `LabShell` stage, extra and sidebar hosts remain the integration points. Preserve its navigation, theme, responsive layout and Jenny service.
4. Use the least expensive representation that communicates the science. Conceptual plots, circuit/logic schematics and field diagrams remain 2D. Use 2.5D for apparatus where form and layering help explain operation. Use real 3D only where object movement or inspection has educational value.
5. The current project targets GL Compatibility and older integrated GPUs. Avoid runtime-generated high-resolution meshes, expensive transparent materials, real-time shadows, high particle counts and post-processing.
6. Visual state derives from existing model properties/result dictionaries. No visual-only quantity is displayed as a measured scientific result.

## 2. Scene and source layout

```text
godot/
  scenes/equipment/
    shared/                 reusable Control-based 2D/2.5D apparatus
    fluid_dynamics/         pipe and measurement presentation
    pendulum/               SubViewport3D apparatus presentation
  scripts/equipment/        visual-only scripts and adapter helpers
  assets/equipment/
    textures/               authored/licensed raster textures, if needed
    materials/               reusable lightweight material resources
  docs/                     asset notes, source attribution and integration reports
```

Use descriptive `snake_case` scene/script/resource names. A reusable component receives only display inputs (for example diameter ratio, pH colour, position, angle, flow speed and state flags) through exported properties or a narrow setter. It must not instantiate a scientific model or silently recalculate outputs. Use PackedScenes when the component owns a useful node hierarchy; use draw helpers for small schematic marks that do not warrant a node tree.

## 3. Representation-specific integration

### Advanced 2D

- Use `Control`/`Node2D` and `CanvasItem` drawing for diagrams, instruments, wires, cells, particle fields and plots.
- Keep labels, axes, values, selection, hit testing and existing interaction in 2D.
- For Circuit Builder and Logic Gate Builder, the board topology and components are the circuit/logic model. Improve substrate, outlines, layering, pins and state contrast while preserving node IDs, ports, wires, hit regions and editing operations.
- In data-led labs, improve hierarchy, depth cues and use of color only where it clarifies the output. Do not add fictitious lab apparatus to graph-only simulations.

### Detailed 2.5D

- Compose layered `Control`/`Node2D` visuals: base, body, opening/rim, glass/highlight, liquid/contents, shadow and labels.
- Use restrained gradients, translucent fills and fixed soft shadows; keep important text and controls as normal UI nodes.
- Build flow/level/color indicators from the exact model result already used by labels and graphs. Reuse common drawing helpers only where physical semantics match.
- Preferred first integration: Fluid Dynamics Venturi pipe with model-derived diameters, station values, flow speed and pressure. Chemistry glassware follows the same layering vocabulary but has separate semantic data mapping.

### 3D in a 2D workspace

- Embed a fixed-cost `SubViewport` inside `SubViewportContainer` in the existing lab stage or extra host. Keep surrounding controls and plots in 2D.
- Use one `Camera3D`, simple built-in or authored low-poly meshes, one environment/light setup, no real-time shadows by default and a bounded viewport size.
- The Pendulum & Springs prototype displays a pendulum only. Update the rod and bob transforms from `PendulumSpringsModel` state (`length`, `theta`, `bob_position()`); do not add a second integrator or out-of-plane motion. Keep the existing model, spring mode, energy bars, phase plot, keyboard controls, play/pause, step, reset and parameter controls intact.
- Offer no camera interaction unless it is needed and tested. A fixed three-quarter view is the initial prototype; optional orbit/zoom is a later decision.

## 4. Data synchronization and motion

- Read a single solved result snapshot per update. Do not call a model solver from a draw function to produce decorative state.
- Fluid particles use the existing `v1`/`v2` and pipe geometry results. Smoothly interpolate displayed velocity through the transition region; freeze at zero/near-zero flow; preserve particle phase when inputs change. Bound frame-step advancement to avoid jumps after a stall.
- Pendulum visuals receive model state after the model's existing `step()`/`step_frame()` logic. Transform updates are presentation-only and must not write to `theta`, `omega`, elapsed time or energy.
- Chemical level/color visuals use existing model values (remaining burette volume, pH, species amount). Color maps are explanatory, labeled and consistent, not new measurements.
- State updates should occur in `_process` or a narrow setter, not trigger work for every node on every input event if the model result has not changed.

## 5. Materials, lighting, labels and interaction

- 2D palette inherits discipline accents from `LabShell`; use high-contrast outlines and readable labels. Glass is represented with a pale translucent body and explicit rim/highlight rather than low-alpha whole-scene modulation.
- 3D prototypes use a small shared palette of `StandardMaterial3D` resources. Avoid custom shaders unless a measured requirement cannot be met by built-in materials.
- Fix labels and instruments in the 2D layer where possible. 3D labels use short screen-space callouts and must not obscure the control panel.
- Only add hit targets for controls already supported by the simulation or an explicitly designed apparatus interaction. A visual knob with no corresponding model input is not interactive.
- Existing sliders, buttons, keyboard shortcuts, reset/preset workflows and output readouts remain unchanged and authoritative.

## 6. Performance and resource policy

- Reuse meshes, materials, textures and PackedScenes; avoid one unique resource allocation per frame.
- Keep 3D viewport dimensions proportional to the apparatus panel and no larger than needed for clear edges. Prefer low-poly mesh detail and baked/simple lighting.
- Keep procedural 2D draw counts bounded; cache invariant point arrays and redraw only when visual inputs change, except genuinely animated views.
- Measure scene load, render behavior and responsiveness on the available Godot 4.7.2 environment. Do not claim memory/frame figures without a measurement source.
- Imported textures should be justified, licensed or original, sized to display needs and documented with source/license. No external asset dependency is required for the initial prototypes.

## 7. M9.3 prototype mapping

| Required approach | Lab | Prototype | Authoritative data |
|---|---|---|---|
| Advanced 2D | Circuit Builder | Refined circuit substrate, component state/readability and wires while retaining editing semantics. | `CircuitModel` component and connection state. |
| Detailed 2.5D | Fluid Dynamics | Layered Venturi pipe, wall/rim/highlight cues and velocity-responsive flow markers. | `FluidDynamicsModel.solve()` result (`d1`, `d2`, `v1`, `v2`, `p1`, `p2`, `z1`, `z2`, `hL`). |
| Genuine 3D | Pendulum & Springs | Fixed-view 3D pendulum apparatus inside a SubViewport; keep spring mode and all existing plots/outputs available. | `PendulumSpringsModel` length, bob position, theta, energy and phase. |

Titration is the chemistry apparatus reference and fallback for the 2.5D review. This is a visual prototype matrix; it does not require replacing the UI or changing any model.

## 8. Production application to the M9.1 inventory

- **Tier 1:** prototype/reference scenes: Circuit Builder, Fluid Dynamics, Pendulum & Springs; Titration receives the shared glassware treatment.
- **Tier 2:** Gas Laws, Buffers, Chemical Reactions, Heat Transfer, Robot Arm, Simple Machines and Logic Gate Builder receive discipline-appropriate apparatus or component refinement.
- **Tier 3:** Reaction Rates, Chemical Equilibrium, Single-Celled Organisms, Predator–Prey, Ecosystems, Evolution, Ecology, Particle Motion, Projectile Motion, Collision Motion and Wave Interference retain scientifically appropriate 2D/data displays. Production work is limited to clear apparatus-like diagrams, data-linked state cues and readability, not invented physical rigs or ornamental 3D.

Every manifest lab is assigned a production disposition. For each lab, the implementation report must identify touched files, model data used, key controls preserved, and checks performed. If a lab has no physical apparatus, document that the 2D scientific visualization is the correct apparatus representation.

## 9. Acceptance and change control

- M9.3 acceptance requires working examples of 2D, 2.5D and 3D, source/integration notes, model-to-visual mapping, actual Godot screenshots and honest performance observations.
- M9.4 is delivered in small discipline batches. After each batch, run parser/scene checks and the relevant existing tests before continuing.
- Never alter a simulation model to make a visual pass. If an existing data output cannot support a desired effect, omit the effect and record the limitation.
- Keep all work in `godot/`; do not modify the root web app, original project, project settings, instructor/exam logic or unrelated application architecture.
