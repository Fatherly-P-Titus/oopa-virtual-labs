/**
 * IRGModel – ideal gas vs van der Waals.
 * P in bar, V in L, T in K, n in mol.
 * R = 0.08314 L·bar/(mol·K)
 */
(function (global) {
  "use strict";

  var R = 0.08314; // L·bar/(mol·K)

  // a: L²·bar·mol⁻², b: L·mol⁻¹
  var GASES = {
    He:  { name: "Helium",      a: 0.0346,  b: 0.0238, color: "#90caf9" },
    H2:  { name: "Hydrogen",    a: 0.2476,  b: 0.0267, color: "#80cbc4" },
    N2:  { name: "Nitrogen",    a: 1.370,   b: 0.0387, color: "#64b5f6" },
    O2:  { name: "Oxygen",      a: 1.382,   b: 0.0319, color: "#ef9a9a" },
    CH4: { name: "Methane",     a: 2.283,   b: 0.0428, color: "#a5d6a7" },
    CO2: { name: "Carbon dioxide", a: 3.640, b: 0.0427, color: "#ffcc80" },
    NH3: { name: "Ammonia",     a: 4.225,   b: 0.0371, color: "#ce93d8" },
    H2O: { name: "Water (g)",   a: 5.536,   b: 0.0305, color: "#81d4fa" }
  };

  function IRGModel() {
    this.gas = "CO2";
    this.n = 1.0;       // mol
    this.T = 300;       // K
    this.V = 5.0;       // L (operating point)
    // custom a,b when gas === custom
    this.a = GASES.CO2.a;
    this.b = GASES.CO2.b;
  }

  IRGModel.GASES = GASES;
  IRGModel.R = R;

  IRGModel.prototype.setGas = function (key) {
    this.gas = key;
    var g = GASES[key];
    if (g) {
      this.a = g.a;
      this.b = g.b;
    }
  };

  IRGModel.prototype.Pideal = function (V) {
    V = V != null ? V : this.V;
    return (this.n * R * this.T) / Math.max(V, 1e-9);
  };

  /** van der Waals pressure at volume V */
  IRGModel.prototype.Pvdw = function (V) {
    V = V != null ? V : this.V;
    var n = this.n, a = this.a, b = this.b, T = this.T;
    var nb = n * b;
    if (V <= nb + 1e-9) return Infinity;
    return (n * R * T) / (V - nb) - a * (n * n) / (V * V);
  };

  IRGModel.prototype.Zideal = function () { return 1; };

  IRGModel.prototype.Zvdw = function (V) {
    V = V != null ? V : this.V;
    var P = this.Pvdw(V);
    if (!isFinite(P) || P <= 0) return NaN;
    return (P * V) / (this.n * R * this.T);
  };

  /** Critical constants from a,b (for 1 mol reference, scale V with n) */
  IRGModel.prototype.critical = function () {
    var a = this.a, b = this.b;
    if (b <= 0) return { Tc: 0, Pc: 0, Vc: 0 };
    var Tc = (8 * a) / (27 * R * b);
    var Pc = a / (27 * b * b);
    var Vc = 3 * this.n * b;
    return { Tc: Tc, Pc: Pc, Vc: Vc };
  };

  /**
   * Isotherm samples: array of { V, Pideal, Pvdw, Z }
   * V from slightly above nb to Vmax
   */
  IRGModel.prototype.isotherm = function (Vmin, Vmax, steps) {
    steps = steps || 200;
    var nb = this.n * this.b;
    Vmin = Math.max(Vmin || nb * 1.05, nb * 1.02);
    Vmax = Vmax || 40;
    var out = [];
    for (var i = 0; i <= steps; i++) {
      var V = Vmin + (Vmax - Vmin) * (i / steps);
      var Pi = this.Pideal(V);
      var Pv = this.Pvdw(V);
      var Z = isFinite(Pv) && Pv > 0 ? (Pv * V) / (this.n * R * this.T) : NaN;
      out.push({ V: V, Pideal: Pi, Pvdw: Pv, Z: Z });
    }
    return out;
  };

  IRGModel.prototype.solve = function () {
    var V = this.V;
    var Pi = this.Pideal(V);
    var Pv = this.Pvdw(V);
    var Z = this.Zvdw(V);
    var crit = this.critical();
    var g = GASES[this.gas] || { name: "Custom", color: "#b22222" };
    return {
      V: V,
      T: this.T,
      n: this.n,
      a: this.a,
      b: this.b,
      Pideal: Pi,
      Pvdw: Pv,
      Z: Z,
      deltaP: Pv - Pi,
      critical: crit,
      reducedT: crit.Tc > 0 ? this.T / crit.Tc : NaN,
      gasName: g.name,
      color: g.color
    };
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = IRGModel;
  }
  global.IRGModel = IRGModel;
})(typeof window !== "undefined" ? window : global);
