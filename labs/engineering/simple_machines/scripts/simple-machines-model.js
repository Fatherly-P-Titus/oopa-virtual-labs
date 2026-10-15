/**
 * SimpleMachinesModel – pure ideal / efficiency formulae.
 * window.SimpleMachinesModel / module.exports
 */
(function (global) {
  "use strict";

  function clamp(v, a, b) {
    return Math.max(a, Math.min(b, v));
  }

  var SimpleMachinesModel = {
    /**
     * Lever
     * @param {number} loadW  load force (N)
     * @param {number} dL     load arm (m)
     * @param {number} dE     effort arm (m)
     * @param {number} eta    efficiency 0–1
     * @param {1|2|3} klass   lever class (for labelling only; MA still dE/dL)
     */
    lever: function (loadW, dL, dE, eta, klass) {
      dL = Math.max(dL, 1e-6);
      dE = Math.max(dE, 1e-6);
      eta = clamp(eta == null ? 1 : eta, 0.05, 1);
      var maIdeal = dE / dL;
      var maActual = maIdeal * eta;
      var effortIdeal = loadW / maIdeal;
      var effortActual = loadW / maActual;
      return {
        type: "lever",
        class: klass || 1,
        loadW: loadW,
        dL: dL,
        dE: dE,
        eta: eta,
        maIdeal: maIdeal,
        maActual: maActual,
        effortIdeal: effortIdeal,
        effortActual: effortActual
      };
    },

    /**
     * Inclined plane – effort parallel to surface, load vertical.
     * Ideal MA = 1/sin(θ). With friction μ: E = W (sinθ + μ cosθ) upward.
     */
    incline: function (loadW, angleDeg, mu, eta) {
      var th = (clamp(angleDeg, 1, 80) * Math.PI) / 180;
      mu = Math.max(mu == null ? 0 : mu, 0);
      eta = clamp(eta == null ? 1 : eta, 0.05, 1);
      var maIdeal = 1 / Math.sin(th);
      // effort up the plane with friction
      var effortFriction = loadW * (Math.sin(th) + mu * Math.cos(th));
      var effortIdeal = loadW * Math.sin(th);
      // if eta provided and mu=0, scale effort
      var effortActual = mu > 0 ? effortFriction : effortIdeal / eta;
      var maActual = loadW / Math.max(effortActual, 1e-9);
      return {
        type: "incline",
        loadW: loadW,
        angleDeg: angleDeg,
        mu: mu,
        eta: eta,
        maIdeal: maIdeal,
        maActual: maActual,
        effortIdeal: effortIdeal,
        effortActual: effortActual,
        lengthFactor: 1 / Math.sin(th) // L/H
      };
    },

    /**
     * Pulley – n supporting strands (ideal MA = n).
     * n=1 fixed, n=2 movable, n>=2 block-and-tackle.
     */
    pulley: function (loadW, strands, eta) {
      var n = Math.max(1, Math.round(strands || 1));
      eta = clamp(eta == null ? 1 : eta, 0.05, 1);
      var maIdeal = n;
      var maActual = n * eta;
      return {
        type: "pulley",
        loadW: loadW,
        strands: n,
        eta: eta,
        maIdeal: maIdeal,
        maActual: maActual,
        effortIdeal: loadW / maIdeal,
        effortActual: loadW / maActual
      };
    },

    /**
     * Wheel and axle – effort on R, load on r.
     */
    wheelAxle: function (loadW, R, r, eta) {
      R = Math.max(R, 1e-6);
      r = Math.max(r, 1e-6);
      eta = clamp(eta == null ? 1 : eta, 0.05, 1);
      var maIdeal = R / r;
      var maActual = maIdeal * eta;
      return {
        type: "wheelAxle",
        loadW: loadW,
        R: R,
        r: r,
        eta: eta,
        maIdeal: maIdeal,
        maActual: maActual,
        effortIdeal: loadW / maIdeal,
        effortActual: loadW / maActual
      };
    }
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = SimpleMachinesModel;
  }
  global.SimpleMachinesModel = SimpleMachinesModel;
})(typeof window !== "undefined" ? window : global);
