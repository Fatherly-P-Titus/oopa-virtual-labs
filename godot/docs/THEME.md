# OOPA Theme (`themes/oopa_theme.tres`)

Translated from web `styles/lab-shell.css` + `main-menu.css` + lab `.panel`/`.chip`/`.stage` rules.

## Tokens (`themes/oopa_colors.gd`)

| Token | Hex | CSS |
|-------|-----|-----|
| RED | #b22222 | --red |
| RED_DARK | #741717 | --red-dark |
| INK | #1b1b1b | --ink |
| MUTED | #666666 | --muted |
| LINE | #e7e3e0 | --line |
| OFF | #f7f6f4 | --off |
| BG_STAGE | #161616 | .stage |

## Type variations (assign in Inspector → Theme Type Variation)

| Variation | Base | Use for |
|-----------|------|---------|
| Eyebrow | Label | `CHEMISTRY / GAS LAWS` |
| H1 | Label | Page title |
| H2 | Label | Section heads |
| Lead | Label | Intro paragraph |
| PanelTitle | Label | Sidebar section labels |
| StatLabel | Label | Readout keys |
| StatValue | Label | Readout numbers |
| Muted / Hint / HintFree | Label | Secondary text |
| CtlLabel / CtlValue | Label | Slider row |
| GhostButton | Button | Outline buttons |
| Chip / ChipActive | Button | Law/preset pills |
| Stage | PanelContainer | Dark canvas frame |
| Card / CardPlanned | PanelContainer | Hub cards |
| StatCell / StatLaw | PanelContainer | Stats grid cells |

## Usage

```gdscript
theme = preload("res://themes/oopa_theme.tres")
# On a Label:
theme_type_variation = &"Eyebrow"
```

Default `Button` is primary (fire-brick). Use `GhostButton` / `Chip` for secondary controls.

**Rule:** avoid `add_theme_*_override` — add a variation instead.
