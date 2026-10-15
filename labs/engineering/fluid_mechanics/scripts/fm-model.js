/**
 * FMModel – hydrostatics, manometer, buoyancy.
 */
(function (global) {
  "use strict";

  var G = 9.81;
  var FLUIDS = {
    water: { name: "Water", rho: 1000, color: "#42a5f5" },
    seawater: { name: "Seawater", rho: 1025, color: "#1e88e5" },
    oil: { name: "Oil", rho: 850, color: "#ffb74d" },
    mercury: { name: "Mercury", rho: 13600, color: "#9e9e9e" },
    alcohol: { name: "Alcohol", rho: 790, color: "#ce93d8" }
  };

  var FMModel = {
    FLUIDS: FLUIDS,
    G: G,

    hydrostatic: function (rho, h, patm) {
      rho = rho || 1000;
      h = Math.max(h, 0);
      patm = patm != null ? patm : 101325;
      var pGauge = rho * G * h;
      return {
        type: "hydrostatic",
        rho: rho,
        h: h,
        pGauge: pGauge,
        pAbs: patm + pGauge,
        patm: patm
      };
    },

    manometer: function (rho, dh) {
      rho = rho || 1000;
      dh = dh || 0;
      var dp = rho * G * dh;
      return {
        type: "manometer",
        rho: rho,
        dh: dh,
        dp: dp
      };
    },

    /**
     * Rectangular block: base area A, height H, density rhoObj in fluid rhoF.
     * Returns draft, FB, W, floating/sinking.
     */
    buoyancy: function (rhoF, rhoObj, A, H) {
      rhoF = rhoF || 1000;
      rhoObj = rhoObj || 500;
      A = Math.max(A, 1e-6);
      H = Math.max(H, 1e-6);
      var V = A * H;
      var W = rhoObj * G * V;
      var floats = rhoObj < rhoF;
      var draft, Vdisp, FB;
      if (floats) {
        // equilibrium: rhoF * g * A * draft = W
        draft = (rhoObj / rhoF) * H;
        draft = Math.min(draft, H);
        Vdisp = A * draft;
        FB = rhoF * G * Vdisp;
      } else {
        draft = H; // fully submerged
        Vdisp = V;
        FB = rhoF * G * V;
      }
      return {
        type: "buoyancy",
        rhoF: rhoF,
        rhoObj: rhoObj,
        A: A,
        H: H,
        V: V,
        W: W,
        FB: FB,
        draft: draft,
        Vdisp: Vdisp,
        floats: floats,
        netForce: FB - W // positive upward
      };
    }
  };

  if (typeof module !== "undefined" && module.exports) module.exports = FMModel;
  global.FMModel = FMModel;
})(typeof window !== "undefined" ? window : global);
