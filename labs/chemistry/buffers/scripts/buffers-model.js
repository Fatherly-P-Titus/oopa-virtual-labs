/**
 * BuffersModel – weak acid, buffer (Henderson–Hasselbalch), strong acid/base.
 */
(function (global) {
  "use strict";

  var ACIDS = {
    acetic: { name: "Acetic acid", Ka: 1.8e-5, formula: "CH₃COOH" },
    formic: { name: "Formic acid", Ka: 1.8e-4, formula: "HCOOH" },
    benzoic: { name: "Benzoic acid", Ka: 6.3e-5, formula: "C₆H₅COOH" },
    hydrofluoric: { name: "Hydrofluoric acid", Ka: 6.8e-4, formula: "HF" },
    hypochlorous: { name: "Hypochlorous acid", Ka: 3.0e-8, formula: "HClO" },
    custom: { name: "Custom", Ka: 1e-5, formula: "HA" }
  };

  function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

  function BuffersModel() {
    this.mode = "weak"; // weak | buffer | strong
    this.acid = "acetic";
    this.Ka = ACIDS.acetic.Ka;
    this.CHA = 0.1;     // mol/L analytical HA (weak or buffer)
    this.CA = 0.1;      // mol/L analytical A- (buffer)
    this.Cstrong = 0.1; // strong acid or base concentration
    this.strongType = "acid"; // acid | base
    // buffer challenge: moles of strong acid/base added per litre of buffer
    this.addAcid = 0;
    this.addBase = 0;
  }

  BuffersModel.ACIDS = ACIDS;

  BuffersModel.prototype.setAcid = function (key) {
    this.acid = key;
    var a = ACIDS[key] || ACIDS.acetic;
    if (key !== "custom") this.Ka = a.Ka;
  };

  BuffersModel.prototype.pKa = function () {
    return -Math.log10(Math.max(this.Ka, 1e-20));
  };

  /** Exact weak acid [H+] via quadratic */
  BuffersModel.prototype.weakAcidH = function () {
    var Ka = this.Ka;
    var F = this.CHA;
    // x^2 + Ka x - Ka F = 0
    var x = (-Ka + Math.sqrt(Ka * Ka + 4 * Ka * F)) / 2;
    return Math.max(x, 1e-12);
  };

  BuffersModel.prototype.bufferH = function () {
    // After adding strong acid/base to buffer:
    // HA_new = CHA + addAcid - addBase
    // A_new  = CA  - addAcid + addBase
    var HA = this.CHA + this.addAcid - this.addBase;
    var A = this.CA - this.addAcid + this.addBase;
    if (HA < 0 || A < 0) {
      // buffer destroyed — treat as excess strong acid/base
      if (HA < 0) {
        // excess base: A left, OH from excess
        var excessOH = -HA;
        var OH = excessOH;
        var H = 1e-14 / Math.max(OH, 1e-15);
        return { H: H, HA: 0, A: A + HA + excessOH, broken: true };
      }
      var excessH = -A;
      return { H: excessH, HA: HA + A + excessH, A: 0, broken: true };
    }
    if (HA < 1e-12 && A < 1e-12) {
      return { H: 1e-7, HA: 0, A: 0, broken: true };
    }
    // Henderson–Hasselbalch
    var ratio = A / Math.max(HA, 1e-15);
    var pH = this.pKa() + Math.log10(Math.max(ratio, 1e-15));
    var H = Math.pow(10, -pH);
    return { H: H, HA: HA, A: A, broken: false, pH: pH };
  };

  BuffersModel.prototype.strongH = function () {
    if (this.strongType === "acid") {
      return Math.max(this.Cstrong, 1e-12);
    }
    var OH = Math.max(this.Cstrong, 1e-12);
    return 1e-14 / OH;
  };

  BuffersModel.prototype.solve = function () {
    var H, pH, extra = {};
    if (this.mode === "weak") {
      H = this.weakAcidH();
      pH = -Math.log10(H);
      var A = H; // approx from dissociation
      var HA = Math.max(0, this.CHA - H);
      extra = { HA: HA, A: A, alpha: H / Math.max(this.CHA, 1e-15) };
    } else if (this.mode === "buffer") {
      var b = this.bufferH();
      H = b.H;
      pH = b.pH != null ? b.pH : -Math.log10(H);
      extra = { HA: b.HA, A: b.A, broken: b.broken };
    } else {
      H = this.strongH();
      pH = -Math.log10(H);
      extra = { strongType: this.strongType };
    }
    pH = clamp(pH, -1, 15);
    return {
      H: H,
      pH: pH,
      pOH: 14 - pH,
      pKa: this.pKa(),
      Ka: this.Ka,
      mode: this.mode,
      acidName: (ACIDS[this.acid] || ACIDS.acetic).name,
      formula: (ACIDS[this.acid] || ACIDS.acetic).formula,
      extra: extra
    };
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = BuffersModel;
  }
  global.BuffersModel = BuffersModel;
})(typeof window !== "undefined" ? window : global);
