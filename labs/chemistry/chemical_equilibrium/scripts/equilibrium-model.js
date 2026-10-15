/**
 * EquilibriumModel – Kc solvers for a few classic reactions.
 */
(function (global) {
  "use strict";

  var REACTIONS = {
    isom: {
      id: "isom",
      name: "A ⇌ B",
      stoich: { A: -1, B: 1 },
      species: ["A", "B"],
      KcExpr: "[B]/[A]",
      thermo: "endo" // endothermic example
    },
    addition: {
      id: "addition",
      name: "A + B ⇌ C",
      stoich: { A: -1, B: -1, C: 1 },
      species: ["A", "B", "C"],
      KcExpr: "[C]/([A][B])",
      thermo: "exo"
    },
    dimer: {
      id: "dimer",
      name: "2A ⇌ B",
      stoich: { A: -2, B: 1 },
      species: ["A", "B"],
      KcExpr: "[B]/[A]²",
      thermo: "exo"
    },
    haber: {
      id: "haber",
      name: "N₂ + 3H₂ ⇌ 2NH₃",
      stoich: { N2: -1, H2: -3, NH3: 2 },
      species: ["N2", "H2", "NH3"],
      labels: { N2: "N₂", H2: "H₂", NH3: "NH₃" },
      KcExpr: "[NH₃]²/([N₂][H₂]³)",
      thermo: "exo"
    }
  };

  function EquilibriumModel() {
    this.reaction = "isom";
    this.V = 1.0; // L
    this.Kc = 4.0;
    this.initial = { A: 1, B: 0, C: 0, N2: 1, H2: 3, NH3: 0 };
    this.T = 298; // for display / Le Chatelier narrative
  }

  EquilibriumModel.REACTIONS = REACTIONS;

  EquilibriumModel.prototype.rxn = function () {
    return REACTIONS[this.reaction] || REACTIONS.isom;
  };

  /**
   * Solve for equilibrium concentrations.
   * Returns { ok, conc, initialConc, xi, Q, message }
   */
  EquilibriumModel.prototype.solve = function () {
    var rxn = this.rxn();
    var V = Math.max(this.V, 1e-9);
    var Kc = Math.max(this.Kc, 1e-12);
    var n0 = {};
    rxn.species.forEach(function (s) {
      n0[s] = Math.max(0, this.initial[s] != null ? this.initial[s] : 0);
    }, this);

    var c0 = {};
    rxn.species.forEach(function (s) {
      c0[s] = n0[s] / V;
    });

    var result;
    if (rxn.id === "isom") result = solveIsom(c0, Kc);
    else if (rxn.id === "addition") result = solveAddition(c0, Kc);
    else if (rxn.id === "dimer") result = solveDimer(c0, Kc);
    else result = solveHaber(c0, Kc);

    if (!result.ok) {
      return { ok: false, message: result.message, conc: c0, initialConc: c0, xi: 0, Q: 0 };
    }

    var conc = result.conc;
    var Q = reactionQ(rxn, c0);
    return {
      ok: true,
      message: "Equilibrium solved.",
      conc: conc,
      initialConc: c0,
      xi: result.xi,
      Q: Q,
      Kc: Kc,
      V: V,
      rxn: rxn
    };
  };

  function reactionQ(rxn, c) {
    if (rxn.id === "isom") {
      return (c.A > 1e-15) ? c.B / c.A : (c.B > 0 ? Infinity : 0);
    }
    if (rxn.id === "addition") {
      var d = c.A * c.B;
      return d > 1e-15 ? c.C / d : (c.C > 0 ? Infinity : 0);
    }
    if (rxn.id === "dimer") {
      var a2 = c.A * c.A;
      return a2 > 1e-15 ? c.B / a2 : (c.B > 0 ? Infinity : 0);
    }
    // haber
    var den = c.N2 * Math.pow(c.H2, 3);
    return den > 1e-15 ? (c.NH3 * c.NH3) / den : (c.NH3 > 0 ? Infinity : 0);
  }

  function solveIsom(c0, Kc) {
    // A ⇌ B: cA = cA0 - x, cB = cB0 + x; K = cB/cA
    // (cB0+x)/(cA0-x) = Kc → x = (Kc*cA0 - cB0)/(1+Kc)
    var x = (Kc * c0.A - c0.B) / (1 + Kc);
    // clamp to feasible
    x = Math.min(c0.A, Math.max(-c0.B, x));
    return {
      ok: true,
      xi: x,
      conc: { A: c0.A - x, B: c0.B + x }
    };
  }

  function solveAddition(c0, Kc) {
    // A+B⇌C: x extent; cA=cA0-x, cB=cB0-x, cC=cC0+x
    // K = cC / (cA cB)
    // K(cA0-x)(cB0-x) = cC0+x
    // K(x^2 - (cA0+cB0)x + cA0 cB0) - cC0 - x = 0
    // K x^2 - (K(cA0+cB0)+1)x + (K cA0 cB0 - cC0) = 0
    var a = Kc;
    var b = -(Kc * (c0.A + c0.B) + 1);
    var c = Kc * c0.A * c0.B - c0.C;
    var disc = b * b - 4 * a * c;
    if (disc < 0) disc = 0;
    var x1 = (-b + Math.sqrt(disc)) / (2 * a);
    var x2 = (-b - Math.sqrt(disc)) / (2 * a);
    var xmax = Math.min(c0.A, c0.B);
    var xmin = -c0.C;
    function ok(x) { return x >= xmin - 1e-9 && x <= xmax + 1e-9; }
    var x = ok(x1) ? x1 : (ok(x2) ? x2 : Math.max(xmin, Math.min(xmax, x1)));
    x = Math.max(xmin, Math.min(xmax, x));
    return {
      ok: true,
      xi: x,
      conc: { A: c0.A - x, B: c0.B - x, C: c0.C + x }
    };
  }

  function solveDimer(c0, Kc) {
    // 2A⇌B: cA=cA0-2x, cB=cB0+x; K = cB/cA^2
    // K(cA0-2x)^2 = cB0+x
    // 4K x^2 - (4K cA0 + 1)x + (K cA0^2 - cB0) = 0
    var a = 4 * Kc;
    var b = -(4 * Kc * c0.A + 1);
    var c = Kc * c0.A * c0.A - c0.B;
    var disc = b * b - 4 * a * c;
    if (disc < 0) disc = 0;
    var x1 = (-b + Math.sqrt(disc)) / (2 * a);
    var x2 = (-b - Math.sqrt(disc)) / (2 * a);
    var xmax = c0.A / 2;
    var xmin = -c0.B;
    function ok(x) { return x >= xmin - 1e-9 && x <= xmax + 1e-9; }
    var x = ok(x2) ? x2 : (ok(x1) ? x1 : Math.max(xmin, Math.min(xmax, x2)));
    x = Math.max(xmin, Math.min(xmax, x));
    return {
      ok: true,
      xi: x,
      conc: { A: c0.A - 2 * x, B: c0.B + x }
    };
  }

  function solveHaber(c0, Kc) {
    // N2+3H2⇌2NH3; x extent in concentration units
    // cN2=cN20-x, cH2=cH20-3x, cNH3=cNH30+2x
    // K = cNH3^2 / (cN2 cH2^3)
    var xmax = Math.min(c0.N2, c0.H2 / 3);
    var xmin = -c0.NH3 / 2;
    if (xmax < xmin) return { ok: false, message: "Infeasible initials." };

    function f(x) {
      var n2 = c0.N2 - x;
      var h2 = c0.H2 - 3 * x;
      var nh3 = c0.NH3 + 2 * x;
      if (n2 <= 0 || h2 <= 0) return 1e15;
      return (nh3 * nh3) / (n2 * Math.pow(h2, 3)) - Kc;
    }

    // Bisection
    var lo = xmin + 1e-12, hi = xmax - 1e-12;
    if (lo >= hi) {
      var x0 = (xmin + xmax) / 2;
      return {
        ok: true,
        xi: x0,
        conc: {
          N2: Math.max(0, c0.N2 - x0),
          H2: Math.max(0, c0.H2 - 3 * x0),
          NH3: Math.max(0, c0.NH3 + 2 * x0)
        }
      };
    }
    var flo = f(lo), fhi = f(hi);
    // If same sign, pick endpoint closer to zero residual
    if (flo * fhi > 0) {
      var xBest = Math.abs(flo) < Math.abs(fhi) ? lo : hi;
      return {
        ok: true,
        xi: xBest,
        conc: {
          N2: Math.max(0, c0.N2 - xBest),
          H2: Math.max(0, c0.H2 - 3 * xBest),
          NH3: Math.max(0, c0.NH3 + 2 * xBest)
        }
      };
    }
    for (var i = 0; i < 60; i++) {
      var mid = 0.5 * (lo + hi);
      var fm = f(mid);
      if (flo * fm <= 0) { hi = mid; fhi = fm; }
      else { lo = mid; flo = fm; }
    }
    var x = 0.5 * (lo + hi);
    return {
      ok: true,
      xi: x,
      conc: {
        N2: Math.max(0, c0.N2 - x),
        H2: Math.max(0, c0.H2 - 3 * x),
        NH3: Math.max(0, c0.NH3 + 2 * x)
      }
    };
  }

  if (typeof module !== "undefined" && module.exports) {
    module.exports = EquilibriumModel;
  }
  global.EquilibriumModel = EquilibriumModel;
})(typeof window !== "undefined" ? window : global);
