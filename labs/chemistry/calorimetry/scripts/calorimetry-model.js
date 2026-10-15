/**
 * CalorimetryModel – coffee-cup and bomb energy balances.
 */
(function (global) {
  "use strict";

  var CW = 4.184; // J/(g·°C) water
  var R = 8.314; // J/(mol·K)

  var METALS = {
    Al: { name: "Aluminium", c: 0.900, color: "#b0bec5" },
    Fe: { name: "Iron", c: 0.450, color: "#78909c" },
    Cu: { name: "Copper", c: 0.385, color: "#c62828" },
    Pb: { name: "Lead", c: 0.128, color: "#546e7a" },
    Au: { name: "Gold", c: 0.129, color: "#ffc107" },
    Ag: { name: "Silver", c: 0.235, color: "#bdbdbd" },
    custom: { name: "Custom metal", c: 0.400, color: "#90a4ae" }
  };

  var SALTS = {
    NaOH: { name: "NaOH(s)", dH: -44.5, // kJ/mol approx dissolution
      exo: true },
    NH4NO3: { name: "NH₄NO₃(s)", dH: 25.7, exo: false },
    CaCl2: { name: "CaCl₂(s)", dH: -81.3, exo: true },
    KCl: { name: "KCl(s)", dH: 17.2, exo: false },
    custom: { name: "Custom salt", dH: -20, exo: true }
  };

  function CalorimetryModel() {
    this.mode = "metal"; // metal | solution | neut | bomb
    this.Ccal = 0;       // J/°C calorimeter constant
    // metal mode
    this.metal = "Cu";
    this.mMetal = 50;    // g
    this.cMetal = METALS.Cu.c;
    this.Tmetal = 100;   // °C
    this.mWater = 100;   // g
    this.Twater = 25;
    // solution mode
    this.salt = "NaOH";
    this.nSalt = 0.05;   // mol
    this.dHsoln = SALTS.NaOH.dH; // kJ/mol
    this.mSolvent = 100; // g water
    this.Tsoln = 25;
    // neutralisation
    this.Cacid = 1.0;    // mol/L
    this.Cbase = 1.0;
    this.Vacid = 50;     // mL
    this.Vbase = 50;     // mL
    this.Tneut = 25;
    this.dHneut = -55.8; // kJ/mol H2O for strong-strong approx (used if predicting T)
    // bomb
    this.mSample = 1.0;  // g
    this.molarMass = 180; // g/mol (e.g. glucose)
    this.Cbomb = 2500;   // J/°C bomb heat capacity
    this.mBombWater = 2000; // g
    this.Tbomb = 25;
    this.dUcomb = -2800; // kJ/mol (combustion internal energy, approx)
    this.dNg = 0;        // Δn_gas for ΔH ≈ ΔU + Δn_g RT
  }

  CalorimetryModel.METALS = METALS;
  CalorimetryModel.SALTS = SALTS;
  CalorimetryModel.CW = CW;

  CalorimetryModel.prototype.setMetal = function (key) {
    this.metal = key;
    var m = METALS[key] || METALS.Cu;
    if (key !== "custom") this.cMetal = m.c;
  };

  CalorimetryModel.prototype.setSalt = function (key) {
    this.salt = key;
    var s = SALTS[key] || SALTS.NaOH;
    if (key !== "custom") this.dHsoln = s.dH;
  };

  /**
   * Metal into water: solve Tf from energy balance.
   * m_m c_m (Tf - Tm) + m_w c_w (Tf - Tw) + Ccal (Tf - Tw) = 0
   */
  CalorimetryModel.prototype.solveMetal = function () {
    var mm = this.mMetal, cm = this.cMetal, Tm = this.Tmetal;
    var mw = this.mWater, cw = CW, Tw = this.Twater;
    var Cc = this.Ccal;
    var num = mm * cm * Tm + mw * cw * Tw + Cc * Tw;
    var den = mm * cm + mw * cw + Cc;
    var Tf = num / Math.max(den, 1e-12);
    var qMetal = mm * cm * (Tf - Tm); // usually negative (metal cools)
    var qWater = mw * cw * (Tf - Tw);
    var qCal = Cc * (Tf - Tw);
    return {
      mode: "metal",
      Tf: Tf,
      qMetal: qMetal,
      qWater: qWater,
      qCal: qCal,
      cMetal: cm,
      // recover c from experiment perspective if Tf known
      cRecovered: Math.abs(Tf - Tm) > 1e-9
        ? -(mw * cw + Cc) * (Tf - Tw) / (mm * (Tf - Tm))
        : cm
    };
  };

  /**
   * Dissolution: q_rxn = n * ΔH (J), absorbed by water + cal.
   * n*ΔH*1000 + (m c + Ccal)(Tf - Ti) = 0
   * → Tf = Ti - n*ΔH*1000 / (m c + Ccal)
   * ΔH in kJ/mol: negative = exo = heats solution
   */
  CalorimetryModel.prototype.solveSolution = function () {
    var n = this.nSalt;
    var dH = this.dHsoln * 1000; // J/mol
    var m = this.mSolvent;
    var Ti = this.Tsoln;
    var cap = m * CW + this.Ccal;
    var qRxn = n * dH; // J (negative if exo)
    var Tf = Ti - qRxn / Math.max(cap, 1e-12);
    var qCal = cap * (Tf - Ti);
    return {
      mode: "solution",
      Tf: Tf,
      Ti: Ti,
      qRxn: qRxn,
      qCal: qCal,
      dH: this.dHsoln,
      n: n,
      // experimental ΔH from measured ΔT
      dHexp: -qCal / Math.max(n, 1e-12) / 1000
    };
  };

  /**
   * Neutralisation strong-strong: limiting moles of H2O formed.
   * q_rxn = n_lim * ΔH_neut; Tf from coffee-cup.
   */
  CalorimetryModel.prototype.solveNeut = function () {
    var nAcid = this.Cacid * this.Vacid / 1000;
    var nBase = this.Cbase * this.Vbase / 1000;
    var nLim = Math.min(nAcid, nBase);
    var m = this.Vacid + this.Vbase; // mL ≈ g for dilute aqueous
    var Ti = this.Tneut;
    var dH = this.dHneut * 1000; // J/mol
    var cap = m * CW + this.Ccal;
    var qRxn = nLim * dH;
    var Tf = Ti - qRxn / Math.max(cap, 1e-12);
    var qCal = cap * (Tf - Ti);
    return {
      mode: "neut",
      Tf: Tf,
      Ti: Ti,
      nLim: nLim,
      nAcid: nAcid,
      nBase: nBase,
      qRxn: qRxn,
      qCal: qCal,
      dH: this.dHneut,
      dHexp: nLim > 0 ? -qCal / nLim / 1000 : 0,
      m: m
    };
  };

  /**
   * Bomb: combustion releases heat into bomb + water.
   * q_rxn = n * ΔU; Tf = Ti - q_rxn / C_total
   * ΔH ≈ ΔU + Δn_g RT
   */
  CalorimetryModel.prototype.solveBomb = function () {
    var n = this.mSample / Math.max(this.molarMass, 1e-9);
    var dU = this.dUcomb * 1000; // J/mol
    var Ctot = this.Cbomb + this.mBombWater * CW;
    var Ti = this.Tbomb;
    var qRxn = n * dU;
    var Tf = Ti - qRxn / Math.max(Ctot, 1e-12);
    var qCal = Ctot * (Tf - Ti);
    var dUexp = -qCal / Math.max(n, 1e-12) / 1000; // kJ/mol
    var dH = this.dUcomb + this.dNg * R * (Ti + 273.15) / 1000; // kJ/mol
    var dHexp = dUexp + this.dNg * R * (Ti + 273.15) / 1000;
    return {
      mode: "bomb",
      Tf: Tf,
      Ti: Ti,
      n: n,
      qRxn: qRxn,
      qCal: qCal,
      Ctot: Ctot,
      dU: this.dUcomb,
      dUexp: dUexp,
      dH: dH,
      dHexp: dHexp
    };
  };

  CalorimetryModel.prototype.solve = function () {
    if (this.mode === "metal") return this.solveMetal();
    if (this.mode === "solution") return this.solveSolution();
    if (this.mode === "neut") return this.solveNeut();
    return this.solveBomb();
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = CalorimetryModel;
  }
  global.CalorimetryModel = CalorimetryModel;
})(typeof window !== "undefined" ? window : global);
