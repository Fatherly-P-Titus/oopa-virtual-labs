/* Registry of the lab entry points present in this project archive.
 * Assessment is deliberately marked unverified until a lab-specific adapter and rubric are tested.
 */
(function (root) {
  'use strict';
  const LABS = [
    ['physics','particle_motion','Particle Motion'], ['physics','projectile_motion','Projectile Motion'],
    ['chemistry','gas_laws','Gas Laws'], ['chemistry','titration','Titration'], ['chemistry','reaction_rates','Reaction Rates'],
    ['chemistry','chemical_equilibrium','Chemical Equilibrium'], ['chemistry','buffers','Acid–Base Strength / Buffers'],
    ['chemistry','electrochemistry','Electrochemistry / Galvanic Cell'], ['chemistry','calorimetry','Calorimetry'],
    ['chemistry','ideal_real_gases','Ideal vs Real Gases'], ['chemistry','thermochemistry','Thermochemistry / Hess’s Law'],
    ['chemistry','chemical_reactions','Chemical Reactions'], ['biology','cell_diffusion_osmosis','Cell Diffusion and Osmosis'],
    ['biology','single_celled_organisms','Single-Celled Organisms'], ['biology','predator_prey','Predator–Prey'], ['biology','ecosystems','Ecosystems'],
    ['engineering','circuit_builder','Circuit Builder'], ['engineering','truss_beam_loads','Truss and Beam Loads'],
    ['engineering','simple_machines','Simple Machines'], ['engineering','logic_gates','Logic Gates'], ['engineering','gear_trains','Gear Trains'],
    ['engineering','spring_mass_damper','Spring–Mass–Damper'], ['engineering','stress_strain','Stress and Strain'],
    ['engineering','robot_arm','Robot Arm'], ['engineering','fluid_dynamics','Fluid Dynamics'], ['engineering','heat_transfer','Heat Transfer'],
    ['engineering','fluid_mechanics','Fluid Mechanics']
  ].map(([hubId, slug, name]) => Object.freeze({
    id: hubId + '.' + slug,
    hubId,
    hubName: hubId.charAt(0).toUpperCase() + hubId.slice(1),
    name,
    path: 'labs/' + hubId + '/' + slug + '/index.html',
    available: true,
    capabilities: Object.freeze({ interactive: true, evidenceCapture: false, autoGrading: false, manualReview: true }),
    assessmentStatus: 'not-verified',
    assessmentNote: 'Lab exists in this project; assessment adapter and grading criteria have not yet been verified.'
  }));
  function getAll() { return LABS.slice(); }
  function getById(id) { return LABS.find(lab => lab.id === id) || null; }
  function getByHub(hubId) { return LABS.filter(lab => lab.hubId === hubId); }
  function getAssessable() { return LABS.filter(lab => lab.capabilities.autoGrading || lab.capabilities.manualReview); }
  root.OOPAExamLabRegistry = Object.freeze({ getAll, getById, getByHub, getAssessable, count: LABS.length });
  if (typeof module !== 'undefined' && module.exports) module.exports = root.OOPAExamLabRegistry;
})(typeof globalThis !== 'undefined' ? globalThis : this);
