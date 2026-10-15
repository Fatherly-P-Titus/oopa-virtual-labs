/**
 * Ecosystem model (OOPA Virtual Labs / Biology) - pure maths, no DOM.
 *
 * A closed matter cycle with five pools, measured in matter units:
 *   N nutrients in the soil, P plants, H herbivores, C carnivores, D dead matter.
 *
 *   plant growth     G   = g * sun * P * N/(kN + N)            nutrients -> plants
 *   grazing          Gr  = aH * P/(kP + P) * H                  plants -> herbivores (share eH is kept)
 *   predation        Pr  = aC * H/(kH + H) * C                  herbivores -> carnivores (share eC is kept)
 *   deaths           mP*P, mH*H, mC*C                           -> dead matter
 *   waste            (1-eH)*Gr, (1-eC)*Pr                       -> dead matter
 *   decomposition    Dec = d * D                                dead matter -> nutrients
 *   optional         + inflow into N, - loss * N out of the ecosystem
 *
 * With inflow = loss = 0 and no events, N+P+H+C+D stays constant: matter is recycled, never created.
 * Energy is not tracked in the pools; the "production" figures (what each level gains per year)
 * are used for the energy pyramid. Time is in years. Integrated with fixed-step RK4.
 * Loaded by the page (window.EcoModel) and usable from Node.
 */
(function (root) {
  "use strict";

  var K = { g: 0.94, mP: 0.3, kP: 300, eH: 0.3, mH: 0.5, kH: 120, eC: 0.25, mC: 0.3, kN: 100 };
  var EXT = 0.2;               // a group below this amount dies out
  var DROUGHT_YEARS = 10, DROUGHT_GROWTH = 0.4;

  function init() { return { t: 0, N: 466, P: 200, H: 30, C: 4, D: 300, drought: 0 }; }
  function total(s) { return s.N + s.P + s.H + s.C + s.D; }
  function growthMult(s) { return s.drought > 0 ? DROUGHT_GROWTH : 1; }

  /** All flows (matter units per year) for pool amounts v = [N, P, H, C, D]. */
  function rates(p, v, gm) {
    var N = v[0], P = v[1], H = v[2], C = v[3], D = v[4];
    var G = K.g * gm * p.light * P * N / (K.kN + N);
    var Gr = p.aH * P / (K.kP + P) * H;
    var Pr = p.aC * H / (K.kH + H) * C;
    return {
      G: G, Gr: Gr, Pr: Pr,
      toD_P: K.mP * P,
      toD_H: K.mH * H + (1 - K.eH) * Gr,
      toD_C: K.mC * C + (1 - K.eC) * Pr,
      dec: p.d * D, leach: p.leach * N, inflow: p.inflow,
      prodH: K.eH * Gr, prodC: K.eC * Pr
    };
  }

  /** Flows for the current state (used by the diagram and the energy pyramid). */
  function flows(p, s) { return rates(p, [s.N, s.P, s.H, s.C, s.D], growthMult(s)); }

  function deriv(p, v, gm) {
    var r = rates(p, v, gm);
    return [
      r.dec - r.G - r.leach + r.inflow,
      r.G - r.toD_P - r.Gr,
      K.eH * r.Gr - K.mH * v[2] - r.Pr,
      K.eC * r.Pr - K.mC * v[3],
      r.toD_P + r.toD_H + r.toD_C - r.dec
    ];
  }

  function nudge(v, k, h) { return [v[0] + h * k[0], v[1] + h * k[1], v[2] + h * k[2], v[3] + h * k[3], v[4] + h * k[4]]; }

  /** Advance by dt years. p may be edited between calls. */
  function step(p, s, dt) {
    var gm = growthMult(s), v = [s.N, s.P, s.H, s.C, s.D], i, w = [];
    var k1 = deriv(p, v, gm), k2 = deriv(p, nudge(v, k1, dt / 2), gm), k3 = deriv(p, nudge(v, k2, dt / 2), gm), k4 = deriv(p, nudge(v, k3, dt), gm);
    for (i = 0; i < 5; i++) { w[i] = v[i] + dt / 6 * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]); if (w[i] < 0) w[i] = 0; }
    s.N = w[0]; s.P = w[1]; s.H = w[2]; s.C = w[3]; s.D = w[4];
    // a group that falls under the threshold dies out; its matter goes to dead matter
    if (s.P < EXT) { s.D += s.P; s.P = 0; }
    if (s.H < EXT) { s.D += s.H; s.H = 0; }
    if (s.C < EXT) { s.D += s.C; s.C = 0; }
    if (s.drought > 0) s.drought = Math.max(0, s.drought - dt);
    s.t += dt;
  }

  /** One-off disturbances. */
  function applyEvent(s, kind) {
    if (kind === "fire") { var burnt = 0.8 * s.P; s.P -= burnt; s.D += burnt; }
    else if (kind === "drought") { s.drought = DROUGHT_YEARS; }
    else if (kind === "fertilizer") { s.N += 300; }
    else if (kind === "hunt") { s.D += s.C; s.C = 0; }
    else if (kind === "invade") { s.H += 30; }
  }

  function status(p, s) {
    if (s.P <= 0) return "Plants have died out. Nothing else can survive without them.";
    if (s.H <= 0 && s.C <= 0) return "Only plants remain.";
    if (s.H <= 0) return "Herbivores have died out. The carnivores will starve.";
    if (s.C <= 0) return "Carnivores have died out. Herbivores can now grow without a predator.";
    if (s.drought > 0) return "Drought for " + Math.ceil(s.drought) + " more years. Plants grow slowly.";
    if (s.D > 0.6 * total(s)) return "Dead matter is piling up, so few nutrients are left for plants.";
    return "Plants, herbivores and carnivores are all surviving.";
  }

  var api = { K: K, init: init, total: total, flows: flows, step: step, applyEvent: applyEvent, status: status };
  if (typeof module !== "undefined" && module.exports) module.exports = api; else root.EcoModel = api;
})(typeof window !== "undefined" ? window : this);
