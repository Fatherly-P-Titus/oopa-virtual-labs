/**
 * HeatModel – steady 1D multilayer wall conduction (+ optional convection).
 */
(function (global) {
  "use strict";

  var MATERIALS = {
    brick: { name: "Brick", k: 0.7, color: "#c62828" },
    concrete: { name: "Concrete", k: 1.4, color: "#8d6e63" },
    wood: { name: "Wood", k: 0.15, color: "#6d4c41" },
    glass: { name: "Glass", k: 1.0, color: "#90caf9" },
    insulation: { name: "Insulation", k: 0.04, color: "#fff9c4" },
    steel: { name: "Steel", k: 40, color: "#90a4ae" },
    aluminium: { name: "Aluminium", k: 200, color: "#b0bec5" }
  };

  function HeatModel() {
    this.T_hot = 20;   // °C indoor or left fluid
    this.T_cold = -5;  // °C outdoor or right fluid
    this.h_hot = 10;   // W/m²K (0 = imposed wall surface temp)
    this.h_cold = 25;
    this.useConv = true;
    // layers: { material, L } L in metres
    this.layers = [
      { material: "brick", L: 0.1 },
      { material: "insulation", L: 0.05 },
      { material: "wood", L: 0.02 }
    ];
  }

  HeatModel.MATERIALS = MATERIALS;

  HeatModel.prototype.solve = function () {
    var layers = this.layers;
    var R = []; // resistances in series, including optional convection
    var labels = [];

    if (this.useConv && this.h_hot > 0) {
      R.push(1 / this.h_hot);
      labels.push("conv hot");
    }
    layers.forEach(function (layer) {
      var mat = MATERIALS[layer.material] || MATERIALS.brick;
      var Ri = layer.L / Math.max(mat.k, 1e-9);
      R.push(Ri);
      labels.push(mat.name);
    });
    if (this.useConv && this.h_cold > 0) {
      R.push(1 / this.h_cold);
      labels.push("conv cold");
    }

    var Rtot = R.reduce(function (a, b) { return a + b; }, 0);
    var dT = this.T_hot - this.T_cold;
    var q = dT / Math.max(Rtot, 1e-12); // W/m²

    // Temperatures at nodes (start at T_hot fluid or surface)
    var T = [this.T_hot];
    var t = this.T_hot;
    for (var i = 0; i < R.length; i++) {
      t = t - q * R[i];
      T.push(t);
    }

    return {
      R: R,
      labels: labels,
      Rtot: Rtot,
      q: q,
      T: T,
      layers: layers.map(function (layer) {
        var mat = MATERIALS[layer.material] || MATERIALS.brick;
        return {
          material: layer.material,
          name: mat.name,
          k: mat.k,
          L: layer.L,
          color: mat.color,
          R: layer.L / Math.max(mat.k, 1e-9)
        };
      })
    };
  };

  if (typeof module !== "undefined" && module.exports) module.exports = HeatModel;
  global.HeatModel = HeatModel;
})(typeof window !== "undefined" ? window : global);
