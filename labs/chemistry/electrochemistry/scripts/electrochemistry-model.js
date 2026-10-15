/**
 * ElectrochemistryModel – galvanic cell, Nernst, ΔG, K.
 * Standard reduction potentials at 25 °C (V vs SHE).
 */
(function (global) {
  "use strict";

  var F = 96485; // C/mol
  var R = 8.314;
  var T = 298.15;
  var LN10 = Math.LN10;
  // 2.303 RT/F at 25 °C ≈ 0.05916 V
  var NERNST = (2.302585 * R * T) / F;

  var HALF_CELLS = {
    Li:  { name: "Li⁺/Li",     metal: "Li",  ion: "Li⁺",  E0: -3.04, n: 1, color: "#b0bec5" },
    K:   { name: "K⁺/K",       metal: "K",   ion: "K⁺",   E0: -2.93, n: 1, color: "#90a4ae" },
    Ca:  { name: "Ca²⁺/Ca",    metal: "Ca",  ion: "Ca²⁺", E0: -2.87, n: 2, color: "#a1887f" },
    Na:  { name: "Na⁺/Na",     metal: "Na",  ion: "Na⁺",  E0: -2.71, n: 1, color: "#78909c" },
    Mg:  { name: "Mg²⁺/Mg",    metal: "Mg",  ion: "Mg²⁺", E0: -2.37, n: 2, color: "#8d6e63" },
    Al:  { name: "Al³⁺/Al",    metal: "Al",  ion: "Al³⁺", E0: -1.66, n: 3, color: "#b0bec5" },
    Zn:  { name: "Zn²⁺/Zn",    metal: "Zn",  ion: "Zn²⁺", E0: -0.76, n: 2, color: "#9e9e9e" },
    Fe:  { name: "Fe²⁺/Fe",    metal: "Fe",  ion: "Fe²⁺", E0: -0.44, n: 2, color: "#607d8b" },
    Ni:  { name: "Ni²⁺/Ni",    metal: "Ni",  ion: "Ni²⁺", E0: -0.25, n: 2, color: "#546e7a" },
    Sn:  { name: "Sn²⁺/Sn",    metal: "Sn",  ion: "Sn²⁺", E0: -0.14, n: 2, color: "#78909c" },
    Pb:  { name: "Pb²⁺/Pb",    metal: "Pb",  ion: "Pb²⁺", E0: -0.13, n: 2, color: "#455a64" },
    H:   { name: "H⁺/H₂",     metal: "Pt",  ion: "H⁺",   E0:  0.00, n: 2, color: "#e0e0e0", gas: true },
    Cu:  { name: "Cu²⁺/Cu",    metal: "Cu",  ion: "Cu²⁺", E0:  0.34, n: 2, color: "#c62828" },
    Ag:  { name: "Ag⁺/Ag",     metal: "Ag",  ion: "Ag⁺",  E0:  0.80, n: 1, color: "#bdbdbd" },
    Au:  { name: "Au³⁺/Au",    metal: "Au",  ion: "Au³⁺", E0:  1.50, n: 3, color: "#ffc107" },
    Cl2: { name: "Cl₂/Cl⁻",    metal: "Pt",  ion: "Cl⁻",  E0:  1.36, n: 2, color: "#66bb6a", gas: true, anion: true }
  };

  function ElectrochemistryModel() {
    this.left = "Zn";   // electrode key
    this.right = "Cu";
    this.cLeft = 1.0;   // ion concentration (mol/L)
    this.cRight = 1.0;
    // For anion half-cells (Cl2), concentration is of Cl-
  }

  ElectrochemistryModel.HALF_CELLS = HALF_CELLS;
  ElectrochemistryModel.F = F;
  ElectrochemistryModel.NERNST = NERNST;

  ElectrochemistryModel.prototype.half = function (key) {
    return HALF_CELLS[key] || HALF_CELLS.Zn;
  };

  /**
   * Balance electrons: lcm of n values for cell reaction.
   * Returns { n, anode, cathode, E0, Q, E, dG, K, reaction, oxidation, reduction }
   */
  ElectrochemistryModel.prototype.solve = function () {
    var L = this.half(this.left);
    var R = this.half(this.right);

    // Higher E0 is cathode (reduction). Track by side so concentration cells work.
    var cathodeSide, anodeSide, cath, an, cathodeKey, anodeKey;
    if (R.E0 > L.E0 + 1e-12) {
      cathodeSide = "right"; anodeSide = "left";
      cath = R; an = L;
      cathodeKey = this.right; anodeKey = this.left;
    } else if (L.E0 > R.E0 + 1e-12) {
      cathodeSide = "left"; anodeSide = "right";
      cath = L; an = R;
      cathodeKey = this.left; anodeKey = this.right;
    } else {
      // Equal E0 (e.g. concentration cell): higher ion concentration is cathode
      if (this.cRight >= this.cLeft) {
        cathodeSide = "right"; anodeSide = "left";
        cath = R; an = L;
        cathodeKey = this.right; anodeKey = this.left;
      } else {
        cathodeSide = "left"; anodeSide = "right";
        cath = L; an = R;
        cathodeKey = this.left; anodeKey = this.right;
      }
    }

    // Electrons transferred: LCM of half-cell n values
    var n = lcm(an.n, cath.n);
    var multAn = n / an.n;
    var multCath = n / cath.n;

    var E0 = cath.E0 - an.E0;

    var cAnode = anodeSide === "left" ? this.cLeft : this.cRight;
    var cCathode = cathodeSide === "left" ? this.cLeft : this.cRight;
    cAnode = Math.max(cAnode, 1e-12);
    cCathode = Math.max(cCathode, 1e-12);

    var Q;
    if (an.anion && cath.anion) {
      // both anion-type (rare): Q uses anion concentrations inverted
      Q = Math.pow(cCathode, multCath) / Math.pow(cAnode, multAn);
    } else if (an.anion) {
      // anode is Cl2/Cl- (oxidation produces Cl2, consumes Cl-)
      Q = Math.pow(cAnode, multAn) / Math.pow(cCathode, multCath);
    } else if (cath.anion) {
      Q = Math.pow(cAnode, multAn) * Math.pow(cCathode, multCath);
    } else {
      // standard metal/metal-ion or H+
      Q = Math.pow(cAnode, multAn) / Math.pow(cCathode, multCath);
    }

    var E = E0 - (NERNST / n) * log10(Q);

    // If E < 0, the opposite orientation is spontaneous — swap anode/cathode
    if (E < -1e-12) {
      var tmpKey = anodeKey; anodeKey = cathodeKey; cathodeKey = tmpKey;
      var tmpSide = anodeSide; anodeSide = cathodeSide; cathodeSide = tmpSide;
      var tmpH = an; an = cath; cath = tmpH;
      var tmpM = multAn; multAn = multCath; multCath = tmpM;
      var tmpC = cAnode; cAnode = cCathode; cCathode = tmpC;
      if (an.anion && cath.anion) {
        Q = Math.pow(cCathode, multCath) / Math.pow(cAnode, multAn);
      } else if (an.anion) {
        Q = Math.pow(cAnode, multAn) / Math.pow(cCathode, multCath);
      } else if (cath.anion) {
        Q = Math.pow(cAnode, multAn) * Math.pow(cCathode, multCath);
      } else {
        Q = Math.pow(cAnode, multAn) / Math.pow(cCathode, multCath);
      }
      E0 = cath.E0 - an.E0;
      E = E0 - (NERNST / n) * log10(Q);
    }

    var dG = -n * F * E; // J/mol
    var dG0 = -n * F * E0;
    var logK = (n * E0) / NERNST;
    var K = Math.pow(10, clampLogK(logK));

    var oxidation = formatOxidation(an, multAn);
    var reduction = formatReduction(cath, multCath);
    var reaction = oxidation + "  +  " + reduction;

    return {
      anodeKey: anodeKey,
      cathodeKey: cathodeKey,
      anode: an,
      cathode: cath,
      n: n,
      multAn: multAn,
      multCath: multCath,
      E0: E0,
      E: E,
      Q: Q,
      dG: dG,
      dG0: dG0,
      K: K,
      logK: logK,
      spontaneous: E > 0,
      oxidation: oxidation,
      reduction: reduction,
      reaction: reaction,
      cAnode: cAnode,
      cCathode: cCathode,
      left: L,
      right: R,
      leftKey: this.left,
      rightKey: this.right,
      anodeSide: anodeSide,
      cathodeSide: cathodeSide
    };
  };

  function log10(x) { return Math.log(x) / LN10; }
  function clampLogK(x) {
    if (!isFinite(x)) return x > 0 ? 300 : -300;
    return Math.max(-300, Math.min(300, x));
  }

  function gcd(a, b) {
    a = Math.abs(a); b = Math.abs(b);
    while (b) { var t = b; b = a % b; a = t; }
    return a || 1;
  }
  function lcm(a, b) { return Math.abs(a * b) / gcd(a, b); }

  function formatOxidation(h, mult) {
    if (h.anion) {
      // 2Cl- → Cl2 + 2e-
      return (mult * h.n > 1 ? (mult * h.n) : "") + "Cl⁻ → " +
        (mult > 1 ? mult : "") + "Cl₂ + " + (mult * h.n) + "e⁻";
    }
    if (h.gas && h.ion === "H⁺") {
      // H2 → 2H+ + 2e-
      return (mult > 1 ? mult : "") + "H₂ → " + (mult * h.n) + "H⁺ + " + (mult * h.n) + "e⁻";
    }
    // Zn → Zn2+ + 2e-
    var ions = mult * h.n;
    return (mult > 1 ? mult : "") + h.metal + " → " +
      (mult > 1 ? mult : "") + h.ion + " + " + ions + "e⁻";
  }

  function formatReduction(h, mult) {
    if (h.anion) {
      return (mult > 1 ? mult : "") + "Cl₂ + " + (mult * h.n) + "e⁻ → " + (mult * h.n) + "Cl⁻";
    }
    if (h.gas && h.ion === "H⁺") {
      return (mult * h.n) + "H⁺ + " + (mult * h.n) + "e⁻ → " + (mult > 1 ? mult : "") + "H₂";
    }
    return (mult > 1 ? mult : "") + h.ion + " + " + (mult * h.n) + "e⁻ → " +
      (mult > 1 ? mult : "") + h.metal;
  }

  if (typeof module !== "undefined" && module.exports) {
    module.exports = ElectrochemistryModel;
  }
  global.ElectrochemistryModel = ElectrochemistryModel;
})(typeof window !== "undefined" ? window : global);
