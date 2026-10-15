/**
 * ReactionRatesModel – zero / first / second order + Arrhenius.
 */
(function (global) {
  "use strict";

  var R = 8.314; // J/(mol·K)

  function ReactionRatesModel() {
    this.order = 1;       // 0 | 1 | 2
    this.A0 = 1.0;        // mol/L
    this.k = 0.05;        // rate constant (units depend on order)
    this.T = 298;         // K
    this.Ea = 50e3;       // J/mol
    this.Af = null;       // pre-factor; if set, k is computed from Arrhenius
    this.useArrhenius = false;
  }

  ReactionRatesModel.prototype.effectiveK = function () {
    if (this.useArrhenius && this.Af != null && this.Af > 0) {
      return this.Af * Math.exp(-this.Ea / (R * Math.max(this.T, 1)));
    }
    return this.k;
  };

  /** Concentration at time t */
  ReactionRatesModel.prototype.concentration = function (t) {
    var A0 = this.A0;
    var k = this.effectiveK();
    t = Math.max(t, 0);
    if (this.order === 0) {
      return Math.max(0, A0 - k * t);
    }
    if (this.order === 1) {
      return A0 * Math.exp(-k * t);
    }
    // second order
    return A0 / (1 + k * A0 * t);
  };

  ReactionRatesModel.prototype.halfLife = function () {
    var k = this.effectiveK();
    if (k <= 0) return Infinity;
    if (this.order === 0) return this.A0 / (2 * k);
    if (this.order === 1) return Math.LN2 / k;
    return 1 / (k * this.A0);
  };

  /** Rate at time t: k [A]^n */
  ReactionRatesModel.prototype.rate = function (t) {
    var A = this.concentration(t);
    var k = this.effectiveK();
    if (this.order === 0) return A > 0 ? k : 0;
    if (this.order === 1) return k * A;
    return k * A * A;
  };

  /**
   * Sample [A](t) from 0 to tMax with n points.
   * Returns [{ t, A, rate }]
   */
  ReactionRatesModel.prototype.series = function (tMax, n) {
    n = n || 200;
    tMax = Math.max(tMax, 1e-6);
    var out = [];
    for (var i = 0; i <= n; i++) {
      var t = (i / n) * tMax;
      out.push({ t: t, A: this.concentration(t), rate: this.rate(t) });
    }
    return out;
  };

  /** Set Af so that at Tref the rate constant equals k */
  ReactionRatesModel.prototype.calibrateArrhenius = function (Tref) {
    Tref = Tref || this.T;
    this.Af = this.k * Math.exp(this.Ea / (R * Tref));
    this.useArrhenius = true;
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = ReactionRatesModel;
  }
  global.ReactionRatesModel = ReactionRatesModel;
})(typeof window !== "undefined" ? window : global);
