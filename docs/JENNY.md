# Jenny Agu – On-Screen Guide (OOPA Virtual Labs)

Contextual helper: avatar + message strip, floating button (FAB), welcome splash and per-page tips.

## Add Jenny to a page (one tag)

```html
<!-- root pages -->
<script defer src="scripts/jenny/jenny-loader.js" data-page="main-menu" data-splash></script>
<!-- pages inside /labs/<field>/ use ../../ ; projects use ../../../ -->
<script defer src="../../scripts/jenny/jenny-loader.js" data-page="physics"></script>
```

The loader resolves every path from its own location, injects the CSS, markup and scripts (in that order), and starts Jenny.

| Attribute | Meaning |
|-----------|---------|
| `data-page` | Key in `JENNY_TEXTS` (default `welcome`) |
| `data-splash` | Show the welcome splash (first visit, once per session) |
| `data-autoshow="false"` | Don't open on load – only pulse the button |
| `data-extras="biocell"` | Load optional module `scripts/jenny/jenny-biocell.js` |

Any element with `data-jenny-action="replay-intro"` re-opens the splash; `data-jenny-action="toggle"` opens/closes Jenny.

## Page keys

`welcome`, `main-menu`, `admin-login`, `admin-dashboard`, `physics` (hub), `particle-motion`, `projectile-motion`, `chemistry`, `gas-laws`, `titration`, `biology`, `cell-diffusion-osmosis`, `single-cell`, `predator-prey`, `ecosystem`, `mathematics`, `engineering`, `circuit-builder`, `truss-beam`, `simple-machines`, `logic-gates`, `gear-trains`, `spring-mass-damper`, `stress-strain`, `robot-arm`, `fluid-dynamics`, `heat-transfer`, `fluid-mechanics`, `reaction-rates`, `chemical-equilibrium`, `buffers`, `electrochemistry`, `calorimetry`, `ideal-real-gases`, `thermochemistry`, `chemical-reactions`, `coming-soon`, plus the BioCell Sim set `lab`, `tutorial`, `exam`.

## Adding or editing tips

Edit `scripts/jenny/jenny_texts.js`. Each tip needs a **unique, stable `id`** (used for "Don't show again"), a `type` (`info` | `caution` | `warning`), a `title` and `text`. Text is rendered as plain text. **Never put passcodes or other secrets in this file** – it is public.

To give a new lab its own tips, add a key (e.g. `labPage("astronomy", "Astronomy", "stars and planets")` or a hand-written entry) and set `data-page` to it.

## Public API (`window.Jenny`, `window.JennySplash`)

| Call | Purpose |
|------|---------|
| `Jenny.setPage(name, { autoShow, force })` | Set context; optionally open first visible tip |
| `Jenny.show(page, index)` / `next()` / `prev()` | Navigate tips |
| `Jenny.hide()` / `toggle()` | Close / toggle |
| `Jenny.notifyNewTip(page)` | Pulse the button for an unseen tip |
| `Jenny.dismissMessage(id)` / `restorePage(page)` / `resetDismissals()` | Manage "don't show again" |
| `Jenny.resetSession()` | Clear session seen/badge state |
| `Jenny.configure({ avatarIdle, avatarSpeaking, defaultPage })` | Host configuration |
| `JennySplash.showIfFirstVisit({ onContinue })` / `show({ force })` / `reset()` | Splash control |

## Storage keys

| Key | Store | Meaning |
|-----|-------|---------|
| `jenny_splash_seen` | localStorage | Splash permanently skipped |
| `jenny_splash_session` | sessionStorage | Splash already shown this visit |
| `jenny_dismissed` | localStorage | Dismissed tip ids |
| `jenny_seen_pages` / `jenny_badge_pages` | sessionStorage | Auto-shown pages / unseen-tip badges |

To see everything again while developing: `JennySplash.reset(); Jenny.resetDismissals(); Jenny.resetSession();`

## Files

```
assets/jenny/      jenny-lab.jpg (idle), jenny-speaking.jpg (while typing), jenny-neutral.jpg, jenny-agu.svg, oopa-splash-banner.jpg
scripts/jenny/     jenny-loader.js, jenny.js, jenny-splash.js, jenny_texts.js, jenny-biocell.js (optional)
styles/            jenny.css, jenny-splash.css
```
