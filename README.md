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

## Demo admin passcode
`12346`

## Important security note
The passcode is checked in browser-side JavaScript and is visible to anyone who inspects the source. This is suitable only for a local prototype/demo. Before deployment, implement server-side authentication, password hashing, secure sessions, and access control. Do not store real secrets in front-end files.

## Dependencies
- jQuery 3.7.1 via CDN.
- Google Fonts via CSS imports.
Internet access is needed for these CDN-hosted dependencies. The page structure and core CSS still exist if those services are unavailable, but jQuery interactions and web fonts may not load.
