/**
 * Predator-Prey model (OOPA Virtual Labs / Biology) - pure maths, no DOM.
 *
 *   dx/dt = r x (1 - x/K) - a x y        prey x   (K >= K_OFF means unlimited food)
 *   dy/dt = b a x y - m y                predators y
 *
 * r prey growth, a predation rate, b predator efficiency, m predator death rate.
 * Integrated with fixed-step RK4. Time is in years, populations in individuals.
 * Loaded by the page (window.PredPreyModel) and by Node for headless checks.
 */
(function (root) {
  "use strict";

  var K_OFF = 500;      // slider value that means "no limit on food"
  var CAP = 1e6;        // keeps an unchecked prey boom finite

  function f(p, x, y) {
    var cap = p.K >= K_OFF ? 1 : 1 - x / p.K, eat = p.a * x * y;
    return [p.r * x * cap - eat, p.b * eat - p.m * y];
  }

  function rk4(p, s, dt) {
    var k1 = f(p, s.x, s.y),
        k2 = f(p, s.x + 0.5 * dt * k1[0], s.y + 0.5 * dt * k1[1]),
        k3 = f(p, s.x + 0.5 * dt * k2[0], s.y + 0.5 * dt * k2[1]),
        k4 = f(p, s.x + dt * k3[0], s.y + dt * k3[1]);
    s.x += dt / 6 * (k1[0] + 2 * k2[0] + 2 * k3[0] + k4[0]);
    s.y += dt / 6 * (k1[1] + 2 * k2[1] + 2 * k3[1] + k4[1]);
  }

  /** Advance one step. With p.ext, a population under one individual dies out. */
  function step(p, s, dt) {
    if (s.x > 0 || s.y > 0) rk4(p, s, dt);
    if (s.x < 0) s.x = 0;
    if (s.y < 0) s.y = 0;
    if (s.x > CAP) s.x = CAP;
    if (p.ext) { if (s.x < 1) s.x = 0; if (s.y < 1) s.y = 0; }
    s.t += dt;
  }

  /** Coexistence point (null when predators could not survive on the available prey). */
  function equilibrium(p) {
    var x = p.m / (p.a * p.b), y = p.K >= K_OFF ? p.r / p.a : p.r / p.a * (1 - x / p.K);
    return y > 0 ? { x: x, y: y } : null;
  }

  /** Conserved quantity of the classic model (K off): constant along every orbit. */
  function invariant(p, x, y) {
    return p.b * p.a * x - p.m * Math.log(x) + p.a * y - p.r * Math.log(y);
  }

  function status(p, s) {
    if (s.x <= 0 && s.y <= 0) return "Both species have died out.";
    if (s.y <= 0) return p.K >= K_OFF && s.x > 0 ? "Predators have died out. With nothing to eat them, prey grow without limit." : "Predators have died out. Prey settle at the food limit.";
    if (s.x <= 0) return "Prey have died out. The predators will starve.";
    return "Both species are surviving.";
  }

  var api = { K_OFF: K_OFF, f: f, step: step, equilibrium: equilibrium, invariant: invariant, status: status };
  if (typeof module !== "undefined" && module.exports) module.exports = api; else root.PredPreyModel = api;
})(typeof window !== "undefined" ? window : this);
