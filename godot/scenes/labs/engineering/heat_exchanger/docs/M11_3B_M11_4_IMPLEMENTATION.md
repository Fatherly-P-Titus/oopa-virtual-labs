# M11.3B and M11.4 Implementation Record

## M11.3B — Double-pipe equipment

- Added a reusable 2.5D double-pipe equipment scene with an outer pressure pipe, visible inner tube, annular passage, connections, flanged unions, supports, and instrument locations.
- Added external, cutaway, flow-path, and restore transitions; selectable component descriptions and highlights.
- Parallel flow places the annular inlet and outlet at the same respective ends as the tube circuit. Counter-current flow moves the annular inlet to the opposite end and reverses the path arrows.
- The equipment representation is separate from the calculation models.

## M11.4 — Interactive operation

- Added shell-and-tube/double-pipe selection and supported configuration controls.
- Added controls for hot/cold inlet temperatures, mass flow rates, heat-transfer area, clean U, and both fouling resistances.
- Each input update calls `HeatExchangerModel.solve_design`; outlet temperatures, heat duty, effective U, effectiveness, NTU and balance discrepancy are displayed from its result.
- Temperature tint and equipment outlet readouts receive the same model output. Invalid model inputs suppress these cues instead of reusing stale results.
- Pressure drop calls the existing Darcy–Weisbach model for each stream with the explicitly displayed water-property and equivalent-passage assumptions. It is an educational single-passage estimate, not a detailed exchanger hydraulic rating.
- Flow arrows and animated markers are representative visual cues, not CFD.

## Verification

- M11.2 calculation regression suite: PASS in Godot 4.7.2 headless.
- M11.4 scene and interaction check at `res://tests/heat_exchanger/m11_4_operation_test.gd`: PASS in Godot 4.7.2 headless. It exercises model-driven duty changes, both double-pipe flow arrangements, inlet-end placement, cutaway transition, restore, and shell-and-tube model-state delivery.
- Heat Exchanger Lab scene launch: PASS in Godot 4.7.2 headless with no parser/resource/runtime errors.
- Godot GUI visual inspection and screenshots: not captured by this implementation run. Headless resource and runtime checks do not establish visual acceptance.

## M11.4 scope boundary

Variable fluid-property tables, transient operation, and detailed shell-and-tube hydraulic rating remain outside the implemented model scope. M11.5 analysis and education deliverables are recorded in `M11_5_ANALYSIS_AND_EDUCATION.md`.
