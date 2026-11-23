# M11 Heat Exchanger Lab — Foundation and Architecture

## M11.1 scope

The integrated route is `heat_exchanger` in the `engineering` field. The manifest marks the scaffold available so it can be opened through the existing Engineering hub; the scene explicitly labels itself as an M11.1 foundation preview and does not claim to run calculations. It inherits the existing `LabShell`, uses the shared theme, and returns through the existing Engineering navigation.

This work does not alter the existing Heat Transfer wall-conduction lab, analog Circuit Builder, Fluid Dynamics, other laboratory routes, shared shell, themes, autoloads, project settings, instructor/exam systems, or root web application.

## Planned project structure

```text
scenes/labs/engineering/heat_exchanger/
  heat_exchanger_lab.tscn       # LabShell-integrated entry scene
  heat_exchanger_lab.gd         # Workspace composition and presentation coordination
  equipment/                    # Shell-and-tube and double-pipe layered equipment scenes
  visualization/                # Model-driven flow and temperature presentation
  instrumentation/              # Instruments and readings presentation
  interface/                    # Reusable controls, analysis, and graph views
  experiments/                  # Guided investigations and comparison cases
  docs/                         # Milestone design and verification notes
scripts/models/engineering/heat_exchanger/
  heat_exchanger_model.gd       # Validated shared state and result coordination
  thermal_calculations.gd       # Energy balances, resistance, and heat duty
  lmtd_model.gd                 # Flow-arrangement terminal differences and LMTD
  effectiveness_ntu_model.gd    # Supported configuration-specific effectiveness relations
  fouling_model.gd              # Fouling resistance and thermal impact
  pressure_drop_model.gd        # Documented hydraulic estimates within stated limits
tests/heat_exchanger/           # Focused numerical and route integration tests
```

## Separation of responsibilities

The mathematical models will accept SI inputs, validate ranges and physical feasibility, and return structured results or explicit errors. They will not depend on scene nodes or UI controls. The lab controller will coordinate inputs and publish model results. Equipment scenes will represent geometry and selected configuration; visualization and instrument views will consume calculated outputs and must not invent values. Educational text will expose assumptions and correlation limits alongside the relevant results.

The planned equipment presentation is 2.5D using layered Godot 2D scenes and drawing/resources; no full 3D renderer is required. Shell-side and tube-side pathways will be visually distinct. Cutaway and component selection will be implemented as real state changes in M11.3, not decorative controls in this foundation.

## Controlled phases and gates

- **M11.1 — Foundation:** isolated folder/scene, manifest identity, LabShell route, architecture and acceptance plan, route smoke check. Complete at this scaffold.
- **M11.2 — Calculation engine:** implemented and regression-tested energy balance, LMTD, overall heat-transfer, supported effectiveness–NTU, fouling and scoped pressure-drop models. See `M11_2_CALCULATION_NOTES.md` for formulas, known values, assumptions, and limits. Complete pending owner review.
- **M11.3 — Equipment:** double-pipe and shell-and-tube layered models, internal parts, cutaway/inspection and selection behavior.
- **M11.4 — Operation:** validated operating controls, model updates, representative flow/thermal displays and live instrumentation.
- **M11.5 — Analysis:** model-derived results, graphs, comparison cases, educational explanations and guided activities.
- **M11.6 — Integration/acceptance:** route and regression checks, scientific tests, runtime/visual evidence and owner review.

Do not advance into M11.2 until the owner has reviewed M11.1. Do not advance into M11.3 until the owner has reviewed M11.2.

## M11.1 acceptance evidence

1. `heat_exchanger` appears under Engineering as an openable manifest entry.
2. Its scene resolves from the manifest and inherits the existing LabShell.
3. The scene loads in Godot 4.7.2 without parser/resource errors.
4. Existing routes and global settings remain unchanged.
5. The scaffold clearly states that calculations and simulation are not yet implemented.
