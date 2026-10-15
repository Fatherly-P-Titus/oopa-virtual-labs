/**
 * GearTrainsModel – spur gear ratio, speed, torque.
 */
(function (global) {
  "use strict";

  function clamp(v, a, b) {
    return Math.max(a, Math.min(b, v));
  }

  var GearTrainsModel = {
    /**
     * Simple pair: driver N1, driven N2.
     * ratio = ω2/ω1 = -N1/N2
     */
    simple: function (N1, N2, nIn, tauIn, eta) {
      N1 = Math.max(8, Math.round(N1));
      N2 = Math.max(8, Math.round(N2));
      eta = clamp(eta == null ? 1 : eta, 0.2, 1);
      nIn = nIn || 0;
      tauIn = tauIn || 0;
      var ratio = -N1 / N2; // signed speed ratio out/in
      var nOut = nIn * ratio;
      var tauOut = tauIn * Math.abs(N2 / N1) * eta;
      return {
        type: "simple",
        gears: [
          { id: "g1", teeth: N1, role: "driver" },
          { id: "g2", teeth: N2, role: "driven" }
        ],
        meshes: [{ a: 0, b: 1 }],
        ratio: ratio,
        ratioMag: Math.abs(ratio),
        nIn: nIn,
        nOut: nOut,
        tauIn: tauIn,
        tauOut: tauOut,
        eta: eta,
        direction: ratio < 0 ? "opposite" : "same"
      };
    },

    /**
     * Idler train: G1 – G2(idler) – G3.
     * ratio = ω3/ω1 = + N1/N3  (two reversals)
     */
    idler: function (N1, N2, N3, nIn, tauIn, eta) {
      N1 = Math.max(8, Math.round(N1));
      N2 = Math.max(8, Math.round(N2));
      N3 = Math.max(8, Math.round(N3));
      eta = clamp(eta == null ? 1 : eta, 0.2, 1);
      nIn = nIn || 0;
      tauIn = tauIn || 0;
      // ω2/ω1 = -N1/N2; ω3/ω2 = -N2/N3 → ω3/ω1 = N1/N3
      var ratio = N1 / N3;
      var nOut = nIn * ratio;
      var tauOut = tauIn * Math.abs(N3 / N1) * eta;
      return {
        type: "idler",
        gears: [
          { id: "g1", teeth: N1, role: "driver" },
          { id: "g2", teeth: N2, role: "idler" },
          { id: "g3", teeth: N3, role: "driven" }
        ],
        meshes: [{ a: 0, b: 1 }, { a: 1, b: 2 }],
        ratio: ratio,
        ratioMag: Math.abs(ratio),
        nIn: nIn,
        nOut: nOut,
        tauIn: tauIn,
        tauOut: tauOut,
        eta: eta,
        direction: "same"
      };
    },

    /**
     * Compound: shaft A has G1 (driver); meshes with G2 on intermediate shaft;
     * intermediate also has G3 fixed to G2; G3 meshes with G4 (output).
     * ratio = ω4/ω1 = (N1/N2)*(N3/N4) with sign (-)(-) = +
     */
    compound: function (N1, N2, N3, N4, nIn, tauIn, eta) {
      N1 = Math.max(8, Math.round(N1));
      N2 = Math.max(8, Math.round(N2));
      N3 = Math.max(8, Math.round(N3));
      N4 = Math.max(8, Math.round(N4));
      eta = clamp(eta == null ? 1 : eta, 0.2, 1);
      nIn = nIn || 0;
      tauIn = tauIn || 0;
      var ratio = (N1 / N2) * (N3 / N4); // both meshes reverse → overall same sense if even meshes
      // Actually each mesh flips sign: (-) * (-) = +
      var nOut = nIn * ratio;
      var tauOut = tauIn * Math.abs(1 / ratio) * eta;
      // Wait: |ω_out/ω_in| = (N1/N2)*(N3/N4); torque multiplies by inverse
      // tauOut/tauIn = |ω_in/ω_out| * eta = 1/|ratio| * eta
      return {
        type: "compound",
        gears: [
          { id: "g1", teeth: N1, role: "driver" },
          { id: "g2", teeth: N2, role: "driven / compound" },
          { id: "g3", teeth: N3, role: "compound driver" },
          { id: "g4", teeth: N4, role: "output" }
        ],
        meshes: [{ a: 0, b: 1 }, { a: 2, b: 3 }],
        compounds: [{ a: 1, b: 2 }], // same shaft
        ratio: ratio,
        ratioMag: Math.abs(ratio),
        nIn: nIn,
        nOut: nOut,
        tauIn: tauIn,
        tauOut: tauOut,
        eta: eta,
        direction: "same"
      };
    },

    /** Angular speeds for each gear given train result and type layout */
    gearSpeeds: function (res) {
      var nIn = res.nIn;
      if (res.type === "simple") {
        return [nIn, nIn * res.ratio];
      }
      if (res.type === "idler") {
        var n2 = nIn * (-res.gears[0].teeth / res.gears[1].teeth);
        var n3 = nIn * res.ratio;
        return [nIn, n2, n3];
      }
      // compound
      var n1 = nIn;
      var n2 = nIn * (-res.gears[0].teeth / res.gears[1].teeth);
      var n3 = n2; // same shaft
      var n4 = n3 * (-res.gears[2].teeth / res.gears[3].teeth);
      return [n1, n2, n3, n4];
    }
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = GearTrainsModel;
  }
  global.GearTrainsModel = GearTrainsModel;
})(typeof window !== "undefined" ? window : global);
