# OOPA Godot Design System

M1 introduces a reusable visual foundation without restyling existing screens. The project theme remains the source of shared Control styling; existing labs retain their specialized simulation stages and named variations.

## Tokens

`themes/oopa_colors.gd` defines the approved Midnight Navy, Deep Slate, Graphite Blue, Cool Mist, Clean White, Scientific Teal, Instrument Blue and Signal Amber colors, semantic status colors, type sizes, spacing, radii, border width, page margin, sidebar width and header height. Existing fire-brick constants remain aliases for legacy scenes during future migration.

Typography uses the bundled Inter Regular, SemiBold and Bold fonts. The scale is Display 36, Page 28, Section 20, Body 14, Secondary 12, Label 11 and Readout 24. The existing theme keeps its legacy H1/H2/readout variations for compatibility.

Spacing uses a 4 px base (`4, 8, 12, 16, 24, 32, 48`). Standard radii are 6, 10, 14 and 20 px; shared borders are 1 px. Recommended page margin is 32 px, header height 64 px and sidebar width 320 px. Existing LabShell retains its current 330 px sidebar so M1 does not alter active layouts.

## Theme and variants

`themes/oopa_theme.tres` styles common Godot 4.7 controls and preserves existing variations. Button variations: `PrimaryButton`, `SecondaryButton`, `TertiaryButton`, `DestructiveButton`, `IconButton`, and legacy `GhostButton`/`Chip`. All provide normal, hover, pressed, focus and disabled styles. Destructive is reserved for irreversible actions.

Panel variations: `ElevatedPanel`, `ScientificCard`, `MetricCard`, `SidebarPanel`, and existing `Stage`, `Card`, `StatCell`. Status variations `StatusSuccess`, `StatusInfo`, `StatusWarning`, `StatusError` provide semantic starting points. Use dark surfaces for navigation or simulation context and light surfaces for reading and data inspection.

Input styling covers LineEdit, TextEdit, CheckBox, CheckButton, OptionButton, HSlider and VSlider. The theme also provides ProgressBar, TabBar, TabContainer, PopupMenu, ScrollContainer, Panel and PanelContainer defaults. No signal or input behavior is changed.

## Reusable scenes

- `scenes/design_system/section_panel.tscn`: titled content container. Add controls under `Body`.
- `scenes/design_system/metric_card.tscn`: label, value and unit readout. Update the child labels from the owning screen.
- `scenes/design_system/status_banner.tscn`: informational banner with a semantic `StatusInfo` variation. Screens may select another status variation and set the indicator color for success, warning or error.

Buttons are native `Button` controls using `theme_type_variation`, so their signals and keyboard behavior remain standard. Components inherit the project theme and require no external dependencies.

## Layout and migration

Use 16 px for component gaps, 24 px between related groups, 32 px page margins and 48 px between major sections. Preserve specialized scientific canvases. M1 does not retrofit screens; future screen work can adopt these tokens and components incrementally. Avoid scattered theme overrides when a shared variation is suitable.

## Compatibility

The project is declared for Godot 4.7. Existing colors and variation names remain to support current scenes. Runtime theme loading and visual review should be performed in Godot 4.7 before M1 approval; the implementation report should distinguish static checks from editor/runtime verification.
