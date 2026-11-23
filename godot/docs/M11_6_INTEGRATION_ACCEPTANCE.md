# M11.6 — Integration and Acceptance Report

**Status:** Integration checks pass; limited rendered evidence is available; owner acceptance remains outstanding.

## Scope and preservation

- Tested only the integration checkout on `integration/godot-app-preservation`.
- The original project at `C:\Users\hp\Documents\_GAME_PROJECTS\oopa_virtual_labs` was not opened for editing.
- M11.1/M11.2 scientific model scripts and project-level settings are unchanged by the M11.5 implementation.
- Existing application navigation and the shared `LabShell` remain the Heat Exchanger entry path.
- Existing Logic Circuit and Circuit Builder regression tests pass.
- The root web application was not changed.
- Existing untracked imports, UID files, and the M7 ZIP were not staged or removed.

## Automated checks

Run with Godot 4.7.2 using `--headless --path godot --script <test>`:

| Check | Result |
|---|---|
| `tests/heat_exchanger/route_foundation_test.gd` | PASS — manifest, LabShell identity, and Engineering hub navigation |
| `tests/heat_exchanger/m11_2_calculation_test.gd` | PASS — known values, ranges, fouling, pressure estimate, and coordinated results |
| `tests/heat_exchanger/m11_4_operation_test.gd` | PASS — equipment selection, input recalculation, arrangement direction, cutaway/restore, and default reset |
| `tests/heat_exchanger/m11_5_analysis_test.gd` | PASS — charts, saved cases, fouling response, guided setup, invalid input handling |
| `tests/logic_circuit_model_test.gd` | PASS |
| `tests/circuit_builder_multiwire_test.gd` | PASS — wire branches, circuit devices, and transient behavior |

These are automated headless results; they do not establish visual acceptance.

## Visual evidence

Godot 4.7.2's rendered frame-writer produced two consecutive frames of the shell-and-tube external view. The first frame is retained as `evidence/M11_6_HeatExchanger_External00000000.png` and was visually inspected. It confirms the lab scene, operating controls, and live readings render together. This is a narrow visual check: it does not cover double-pipe, cutaway/exploded states, or the Analysis and Experiments tabs. The Windows computer-use helper timed out on `list_apps`, including its prescribed wait, reset, and retry, so broader interactive screenshot coverage was unavailable.

## Owner review still required

The owner has previously accepted the shell-and-tube M11.3A view. The new double-pipe equipment and M11.5 analysis/experiment pages still require manual visual review in Godot 4.7.2. The M11 master acceptance criterion requiring the owner's personal review is therefore not marked complete.

## Final recommendation

**READY FOR OWNER REVIEW — NOT YET FORMALLY ACCEPTED.** Automated integration and preservation checks pass, with one retained Godot-rendered external-view frame. Open the Engineering hub, select Heat Exchanger, review both equipment types, their view controls, the Analysis page and all six experiment starting conditions, then approve M11 when satisfied.
