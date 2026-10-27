# OOPA Virtual Labs — Starter Project

## Included
- `main-menu.html`: responsive public landing page.
- `docs/`: Jenny guide (`JENNY.md`) and simulator notes (`PARTICLE_MOTION.md`, `PROJECTILE_MOTION.md`, `GAS_LAWS.md`, `TITRATION.md`, `CELL_DIFFUSION_OSMOSIS.md`, `SINGLE_CELL.md`, `PREDATOR_PREY.md`, `ECOSYSTEM.md`, `CIRCUIT_BUILDER.md`, `TRUSS_BEAM_LOADS.md`, `SIMPLE_MACHINES.md`, `LOGIC_GATES.md`, `GEAR_TRAINS.md`, `SPRING_MASS_DAMPER.md`, `STRESS_STRAIN.md`, `ROBOT_ARM.md`, `FLUID_DYNAMICS.md`, `HEAT_TRANSFER.md`, `FLUID_MECHANICS.md`, `REACTION_RATES.md`, `CHEMICAL_EQUILIBRIUM.md`, `BUFFERS.md`, `ELECTROCHEMISTRY.md`, `CALORIMETRY.md`, `IDEAL_REAL_GASES.md`, `THERMOCHEMISTRY.md`, `CHEMICAL_REACTIONS.md`).
- `jenny-agu.html`: "Meet Jenny Agu" page (styled by `styles/jenny-page.css`).
- `admin-login.html`: demo administrator login.
- `admin-page.html`: starter administration dashboard.
- `styles/`: separate stylesheets for each main page.
- `scripts/`: separate jQuery-powered scripts.
- `scripts/jenny/`, `styles/jenny*.css`, `assets/jenny/`: the Jenny Agu guide engine.
- `labs/`: one entry per field. Physics (2), Chemistry (10), Biology (4) and Engineering (11) have working projects; Mathematics is still a hub waiting for projects.
- `styles/lab-shell.css`: shared header/footer/card styles for pages inside `labs/<field>/`.

## Lab structure
```
labs/
  physics/
    index.html                      <- field hub (lists its projects)
    particle_motion/                <- project: Particle Motion
    projectile_motion/              <- project: Projectile Motion
  chemistry/
    index.html                      <- field hub
    gas_laws/                       <- project: Gas Laws
    titration/
    reaction_rates/                 <- project: Reaction Rates
    chemical_equilibrium/           <- project: Chemical Equilibrium
    buffers/                       <- project: Acid-Base / Buffers
    electrochemistry/              <- project: Electrochemistry / Galvanic Cell
    calorimetry/                   <- project: Calorimetry
    ideal_real_gases/              <- project: Ideal vs Real Gases
    thermochemistry/               <- project: Thermochemistry / Hess's Law
    chemical_reactions/            <- project: Chemical Reactions                      <- project: Titration
  biology/
    index.html                      <- field hub
    cell_diffusion_osmosis/         <- project: Cell Diffusion and Osmosis
    single_celled_organisms/        <- project: Single-Celled Organisms
    predator_prey/                  <- project: Predator–Prey Populations
    ecosystems/                     <- project: Ecosystems
  engineering/
    index.html                      <- field hub
    circuit_builder/                <- project: Circuit Builder
    truss_beam_loads/               <- project: Truss and Beam Loads
    simple_machines/                <- project: Simple Machines
    logic_gates/                    <- project: Logic Gates
    gear_trains/                    <- project: Gear Trains
    spring_mass_damper/             <- project: Spring–Mass–Damper
    stress_strain/                  <- project: Stress and Strain
    robot_arm/                      <- project: Robot Arm
    fluid_dynamics/                 <- project: Fluid Dynamics
    heat_transfer/                  <- project: Heat Transfer
    fluid_mechanics/                <- project: Fluid Mechanics
  mathematics/index.html            <- field hub, no projects yet
  coming-soon.html

Every project folder has the same shape:
  <project>/index.html
  <project>/scripts/
  <project>/styles/
```
To add a project: create `labs/<field>/<project>/` with `index.html`, `scripts/`, `styles/`; link `../../../styles/lab-shell.css` and the Jenny loader (`../../../scripts/jenny/jenny-loader.js` with a new `data-page` key); add a card to the field's `index.html` and tips to `scripts/jenny/jenny_texts.js`.

## Jenny Agu (on-screen guide)
Every page loads Jenny through one `jenny-loader.js` tag: a welcome splash on the main menu, a floating help button, and contextual tips per page. See `docs/JENNY.md` for the API, how to add tips, and how to add her to new lab pages.

## Run locally
Open `main-menu.html` in a modern browser, or serve this folder with a local development server.

## Prototype Overall Admin login
- **Admin Name:** `Admin001`
- **Staff ID:** `AdminStaff/001`
- **Passcode:** `12346`

The Administration Portal is login-only. Instructor accounts are created from the authenticated Overall Admin workspace; there is no public account-creation form.

## Important security note
The passcode is checked in browser-side JavaScript and is visible to anyone who inspects the source. This is suitable only for a local prototype/demo. Before deployment, implement server-side authentication, password hashing, secure sessions, and access control. Do not store real secrets in front-end files.

## Dependencies
- jQuery 3.7.1 via CDN.
- Google Fonts via CSS imports.
Internet access is needed for these CDN-hosted dependencies. The page structure and core CSS still exist if those services are unavailable, but jQuery interactions and web fonts may not load.

## Submissions and grading (Milestone 5)

The instructor grading workspace is available at `grading.html`. It lists submitted attempts for exams owned by the signed-in instructor (Overall Admin can review all), shows the recorded student evidence, supports separate automatic/manual marks, feedback, reviewed/finalized statuses, append-only grade revisions, grade history, results-release controls, and CSV export. Results cannot be released until all submissions for the exam are finalized; exams configured never to release results remain blocked. See `docs/exams/MILESTONE-5.md` for details and limitations.

**Prototype limitation:** grading records, release state, and permissions are still browser-local and are not tamper-proof or synchronized across devices. No lab adapter currently supplies verified automatic marks. A trusted backend is required before real examinations.

## Examination foundation (Milestone 1)
The first shared examination services are available under `scripts/exams/`: record validation and lifecycle rules (`schema.js`), a registry of the 27 existing lab entry points (`lab-registry.js`), local-first persistence and JSON backup/restore (`storage.js`), and roster CSV helpers (`csv.js`). They are intentionally not wired into the current public pages yet; later milestones will add instructor and student workflows on top of these services.

See [`docs/exams/FOUNDATION.md`](docs/exams/FOUNDATION.md) for the data model, loading order, storage limitations and test instructions. Run the foundation tests from the project root with `node tests/exams/foundation.test.js`.

**Important:** IndexedDB/localStorage is browser-local, not shared across devices and not tamper-proof. Do not use it as authoritative storage for high-stakes exams without a trusted backend. Labs are registered as available, but automatic grading is disabled until an assessment adapter and rubric are verified.

### Management accounts (Milestone 2 — local prototype)

Schema version is now 2. The backup importer accepts Milestone 1/schema v1 backups without an `administrators` collection and initializes that collection as empty.

The management portal now provisions the specified prototype Overall Admin identity (`Admin001`, Staff ID `AdminStaff/001`, passcode `12346`) in local mode. The Administration Portal is login-only; only an Overall Admin can create, edit, activate, or deactivate instructor accounts and assign hub/lab permissions. Instructor credentials created in the workspace are flagged for change at first sign-in. Existing lab destinations remain unchanged.

**Security boundary:** this static Vercel site stores account records in browser-local IndexedDB/localStorage and keeps its session in sessionStorage. This is not secure authentication or enforceable authorization: users can inspect/modify browser data, and accounts/permissions do not sync across browsers or devices. PBKDF2 prevents plaintext passphrases being stored, but does not make client-side authorization trusted. Do not use this milestone to protect real exams or sensitive student records. Before production, move identity, sessions, permission checks, rate limiting and audit enforcement to a trusted server/backend. Instructor hub/lab grants are recorded in this milestone; exam creation and exam-operation enforcement will be integrated in later milestones.

## Examination management (Milestone 3)

Open `exams-management.html` after signing in through `admin-login.html` to manage reusable student lists and author exams. Roster CSV imports support the `S/N,Student Name,Matric Number` layout, preview valid/error rows, normalize matric numbers, and explicitly choose replace/add/cancel. Exams support permitted-lab selection, 5–60 minute durations in 5-minute increments, six-digit access codes (stored as salted verifiers), attempt limits, optional availability dates, instructions, and result policy. Publishing creates a per-exam eligibility snapshot and follows the Draft → Published → Closed → Archived lifecycle.

**Prototype limitation:** records remain in browser-local storage and do not sync between devices. Client-side access controls are not a production security boundary, and all listed lab assessment adapters remain unverified. Do not use this static prototype for real multi-device exams until a trusted server-side backend enforces accounts, permissions, exam state, eligibility, deadlines, and submissions.

### Student examination runtime (Milestone 4)

Open `student-exam.html` for the student-facing prototype. Students enter the published exam ID, their exact registered name and matric number, and the six-digit code. The runtime checks the published exam, opening/closing window, eligibility snapshot, access-code verifier, and attempt limit; starts or resumes a persisted attempt; displays a deadline-based countdown; locally saves typed evidence; and creates a submission record on manual submit or timeout. The portal can be linked from the instructor's Student lists & exams workspace.

**Prototype limitations:** attempts and submissions are saved in browser-local storage and are not shared across computers. Browser-side identity checks, timer, attempt limits and submissions are not tamper-proof. Lab simulations are embedded with a sandbox and can also be opened separately, but their interactive state is not automatically captured. All current labs are marked `not-verified` for assessment adapters; submissions require manual review. Do not use this for high-stakes exams until server-side authentication, authorization, authoritative timing, storage and a tested adapter/rubric are implemented.


## Milestone 6: student results and backup/recovery

- `student-results.html` provides student result lookup using exam ID, registered full name, and matric number. It enforces the configured `never`, `after-release`, and `immediate` result policies in the local prototype, and displays only finalized grades. Students can print or save the displayed report as PDF.
- `backup-recovery.html` provides Overall Admin-only JSON backup export, storage health, backup validation/preview, merge restore, and full replacement restore. Backups include account credential verifiers and student records; treat them as confidential.
- Automated tests cover result policy enforcement, eligibility matching, finalized grade selection, report generation, and backup validation UI wiring.
- **Security boundary:** these checks run in the browser. The result lookup is not strong identity verification, browser records can be edited, and data does not sync across devices. A trusted server is required for official results and authoritative backup/recovery.

## Milestone 7: optional Supabase backend

The project now includes a Supabase/PostgreSQL migration, row-level security policies, management Auth integration, instructor provisioning Edge Function, and a server-side student gateway for verification, timed attempts, submissions, and result lookup. Backend mode is **off by default** and the app continues to use browser-local storage until configured. No Supabase project has been provisioned or deployed for you as part of this ZIP.

See [`docs/backend/MILESTONE-7.md`](docs/backend/MILESTONE-7.md) for database setup, initial admin provisioning, Edge Function deployment, browser config, security constraints and validation steps. Never put the Supabase service-role key in browser files. Do not use for real exams until RLS and Edge Functions have been deployed and tested in your own Supabase project.


## Milestone 8: integration hardening and launch validation

- Edge Functions use an explicit `OOPA_ALLOWED_ORIGINS` allowlist instead of wildcard CORS, validate JSON payloads and enforce request-size caps.
- Student-gateway rate limits use an atomic PostgreSQL function; instructor provisioning validates known hub/lab IDs.
- Run `node tests/exams/milestone-8.test.js` for local backend hardening checks.
- See [`docs/backend/MILESTONE-8.md`](docs/backend/MILESTONE-8.md) for configuration, deployment commands and the required live staging test matrix.
- **Not production-certified:** no live Supabase staging/production integration test or Vercel deployment was performed. Complete the staging matrix before using real student data or high-stakes exams.

## Five additional HTML/CSS/JavaScript labs

The current web milestone now includes five new interactive lab pages linked from the Physics and Biology hubs:

- **Collision Motion** — one-dimensional collisions, restitution, momentum and kinetic-energy readouts.
- **Pendulum & Springs** — pendulum and mass–spring oscillators with damping and optional periodic drive.
- **Wave Interference** — two-source field, phase controls, source amplitudes and intensity probing.
- **Ecology** — two-species Lotka–Volterra competition, carrying capacities and niche-overlap presets.
- **Evolution** — continuous heritable traits under selection, mutation, drift and a moving optimum.

The simulations share `labs/simulation-core.js` for responsive canvas rendering, experiment controls, presets and readouts. Individual model notes are in `docs/labs/`. These are browser-only scientific models; see each lab's notes for assumptions and limitations. Existing projects, including the Ecosystems lab, remain in place.
