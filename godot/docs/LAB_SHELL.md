# LabShell (`scenes/common/lab_shell.tscn`)

Reusable chrome matching web `.lab-main` + `.sim-layout`.

```
LabShell
├── Header (Back + Eyebrow + Title)
├── Lead
└── SimLayout  (HBox, gap 20)     ← NOT HSplit
    ├── Left EXPAND
    │   ├── Stage (dark PanelContainer)
    │   │   └── StageHost         ← put canvas Control here
    │   └── ExtraHost             ← graphs / secondary cards
    └── Sidebar (330px Panel)
        └── Scroll → SidebarVBox  ← put sliders / chips here
```

## Exports

| Property | Example |
|----------|---------|
| `lab_title` | `"Gas Laws"` |
| `lab_eyebrow` | `"CHEMISTRY  /  GAS LAWS"` |
| `lab_lead` | Short intro sentence |
| `field_id` | `"chemistry"` (Back target) |
| `page_id` | `"gas_laws"` (Jenny) |
| `back_label` | `"← Chemistry"` |

## API

```gdscript
var shell: LabShell = $LabShell  # or self if extending
var stage := shell.get_stage()       # Control
var sidebar := shell.get_sidebar()   # VBoxContainer
var extra := shell.get_extra()       # VBoxContainer
shell.set_status("Ready.")
```

## How a lab uses it (Step 4 pattern)

**Option A — instance shell as root content**

```
GasLawsLab (Control)
└── LabShell (instance)
    # in _ready: add Chamber to get_stage(), controls to get_sidebar()
```

**Option B — lab script extends LabShell** (preferred once migrated)

```gdscript
extends LabShell
func _ready() -> void:
    lab_title = "Gas Laws"
    super._ready()
    var chamber := Control.new()
    chamber.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    chamber.draw.connect(_draw_chamber)
    get_stage().add_child(chamber)
```

## Layout rules

- Sidebar width **330px** fixed (`custom_minimum_size.x = 330`)
- Stage uses theme variation **`Stage`** (dark #161616, 14px radius)
- Theme is applied on the shell root — children inherit it
- No per-lab `HSplitContainer`
