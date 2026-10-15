/**
 * StressStrainModel – axial bar stress, strain, safety factor.
 */
(function (global) {
  "use strict";

  var MATERIALS = {
    steel: { name: "Structural steel", E: 200e9, sy: 250e6, color: "#546e7a" },
    aluminum: { name: "Aluminium alloy", E: 70e9, sy: 150e6, color: "#90a4ae" },
    titanium: { name: "Titanium alloy", E: 110e9, sy: 900e6, color: "#78909c" },
    concrete: { name: "Concrete (comp.)", E: 30e9, sy: 30e6, color: "#a1887f" },
    rubber: { name: "Rubber (idealised)", E: 50e6, sy: 15e6, color: "#5d4037" }
  };

  function StressStrainModel() {
    this.F = 50e3;       // N
    this.L = 1.0;        // m
    this.d = 0.02;       // m diameter
    this.material = "steel";
  }

  StressStrainModel.MATERIALS = MATERIALS;

  StressStrainModel.prototype.area = function () {
    return Math.PI * this.d * this.d / 4;
  };

  StressStrainModel.prototype.mat = function () {
    return MATERIALS[this.material] || MATERIALS.steel;
  };

  StressStrainModel.prototype.solve = function () {
    var A = this.area();
    var mat = this.mat();
    var E = mat.E;
    var sy = mat.sy;
    var sigma = this.F / Math.max(A, 1e-12);
    var delta = this.F * this.L / (A * E);
    var eps = delta / Math.max(this.L, 1e-12);
    // elastic prediction; if beyond yield, still report engineering stress but flag
    var yielded = Math.abs(sigma) >= sy;
    var n = sy / Math.max(Math.abs(sigma), 1e-12);
    return {
      A: A,
      sigma: sigma,
      eps: eps,
      delta: delta,
      E: E,
      sy: sy,
      n: n,
      yielded: yielded,
      materialName: mat.name,
      color: mat.color
    };
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = StressStrainModel;
  }
  global.StressStrainModel = StressStrainModel;
})(typeof window !== "undefined" ? window : global);
