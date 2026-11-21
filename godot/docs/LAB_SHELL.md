# Shared Laboratory Workspace

`scenes/common/lab_shell.tscn` is the shared workspace chrome inherited by the manifest laboratories. It owns the application identity, discipline/lab context, hub return action, simulation stage, optional secondary-content area, lab controls area, status line, and footer.

```text
LabShell
├── Workspace header
│   ├── OOPA Virtual Labs lockup (discipline accent)
│   ├── Discipline eyebrow + current laboratory title
│   └── Back button (returns through SceneRouter)
├── Lead (optional laboratory summary)
└── Simulation layout
    ├── Main column
    │   ├── StageHost (primary simulation viewport)
    │   └── ExtraHost (optional charts or supporting cards)
    └── Sidebar (scrollable lab-authored controls)
├── StatusRow (lab-authored runtime text)
└── Footer
```

## Exports

| Property | Purpose |
|----------|---------|
| `lab_title` | Current laboratory name shown in the workspace header |
| `lab_eyebrow` | Discipline and laboratory breadcrumb |
| `lab_lead` | Optional concise context below the header |
| `field_id` | Discipline accent and hub return target |
| `page_id` | Context passed to JennyService |
| `back_label` | Visible label for the real hub-navigation action |

## API

```gdscript
var shell: LabShell = $LabShell # or the root when the scene inherits LabShell
var stage: Control = shell.get_stage()
var sidebar: VBoxContainer = shell.get_sidebar()
var extra: VBoxContainer = shell.get_extra()
shell.set_status("Running. Press Pause to stop the simulation.")
shell.add_to_stage(simulation_control)
```

The shell preserves the existing lab script API. Laboratory scripts continue to own their models, controls, rendering, reset/play/pause behavior and status wording. The shell does not infer whether a simulation is running, duplicate lab controls, or introduce placeholder actions.

## Layout behavior

- At the 1280 × 720 desktop viewport, the simulation stage expands beside a 330 px controls sidebar.
- Below 1024 px, the sidebar minimum width reduces to 290 px so more room remains for the simulation.
- Below 900 px, outer margins tighten; below 840 px, secondary brand text and the divider collapse while the lab title and Back action remain.
- `StageHost` fills the stage. Each lab remains responsible for adapting its own drawing, scrollable content, and aspect ratio.
- `ExtraHost` is optional and is used for supporting visualizations such as graphs.
- The status row displays only the exact message supplied by the laboratory script.

## Navigation and scope

Back uses the existing `SceneRouter.go_field(field_id)` contract. The field accent follows the M2 discipline palette. SceneRouter, AppState, the manifest, simulation models, and laboratory-specific controls remain outside the shell's implementation scope.

Twenty-one manifest labs inherit this shell. The nested Logic Gate Builder scene remains a separate `Control`-based project and is not wrapped by this shell; changing it would require modifying its protected scene or discovery path.
