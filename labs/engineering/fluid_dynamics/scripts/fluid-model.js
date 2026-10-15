/**
 * FluidModel – continuity + Bernoulli (+ optional head loss).
 */
(function (global) {
  "use strict";

  var RHO = 1000; // kg/m³ water
  var G = 9.81;

  function FluidModel() {
    this.D1 = 0.08;   // m
    this.D2 = 0.04;   // m throat
    this.z1 = 0;      // m
    this.z2 = 0;
    this.Q = 0.005;   // m³/s
    this.p1 = 150e3;  // Pa gauge-ish absolute for display
    this.f = 0;       // friction factor (0 = ideal)
    this.L = 2;       // pipe length between stations for hL
  }

  FluidModel.prototype.A = function (D) {
    return Math.PI * D * D / 4;
  };

  FluidModel.prototype.solve = function () {
    var A1 = this.A(this.D1);
    var A2 = this.A(this.D2);
    var v1 = this.Q / Math.max(A1, 1e-12);
    var v2 = this.Q / Math.max(A2, 1e-12);

    // Head loss from 1 to 2 using average diameter for simplicity
    var Davg = 0.5 * (this.D1 + this.D2);
    var vAvg = 0.5 * (v1 + v2);
    var hL = this.f * (this.L / Math.max(Davg, 1e-6)) * (vAvg * vAvg) / (2 * G);

    // Bernoulli: p1/ρ + v1²/2 + g z1 = p2/ρ + v2²/2 + g z2 + g hL
    var p2 = this.p1 + RHO * (
      0.5 * (v1 * v1 - v2 * v2) + G * (this.z1 - this.z2) - G * hL
    );

    var H1 = this.p1 / (RHO * G) + v1 * v1 / (2 * G) + this.z1;
    var H2 = p2 / (RHO * G) + v2 * v2 / (2 * G) + this.z2;

    return {
      A1: A1, A2: A2,
      v1: v1, v2: v2,
      p1: this.p1, p2: p2,
      hL: hL,
      H1: H1, H2: H2,
      Q: this.Q,
      rho: RHO, g: G
    };
  };

  if (typeof module !== "undefined" && module.exports) module.exports = FluidModel;
  global.FluidModel = FluidModel;
})(typeof window !== "undefined" ? window : global);
