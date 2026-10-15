/**
 * ThermoModel – ΔHf formation, Hess cycles, bond enthalpies.
 * Energies in kJ/mol.
 */
(function (global) {
  "use strict";

  // Standard enthalpies of formation at 298 K (kJ/mol). Elements in standard state = 0.
  var DHF = {
    "C(s)": 0, "C(g)": 716.7, "CO(g)": -110.5, "CO2(g)": -393.5,
    "H2(g)": 0, "H(g)": 218.0, "H2O(l)": -285.8, "H2O(g)": -241.8,
    "O2(g)": 0, "O(g)": 249.2, "N2(g)": 0, "N(g)": 472.7,
    "NH3(g)": -45.9, "NO(g)": 91.3, "NO2(g)": 33.2,
    "CH4(g)": -74.8, "C2H6(g)": -84.7, "C2H4(g)": 52.3, "C2H2(g)": 227.4,
    "CH3OH(l)": -238.7, "C2H5OH(l)": -277.7,
    "Na(s)": 0, "Na+(aq)": -240.1, "Cl2(g)": 0, "Cl-(aq)": -167.2,
    "NaCl(s)": -411.2, "HCl(g)": -92.3, "HCl(aq)": -167.2,
    "Ca(s)": 0, "CaO(s)": -635.1, "CaCO3(s)": -1206.9,
    "S(s)": 0, "SO2(g)": -296.8, "SO3(g)": -395.7,
    "Fe(s)": 0, "Fe2O3(s)": -824.2
  };

  // Average bond enthalpies kJ/mol
  var BOND = {
    "H-H": 436, "H-C": 413, "H-O": 463, "H-N": 391, "H-Cl": 432,
    "C-C": 348, "C=C": 614, "C≡C": 839, "C-O": 358, "C=O": 799,
    "C-N": 293, "C≡N": 891, "O=O": 495, "O-O": 146, "N≡N": 941,
    "N-N": 163, "Cl-Cl": 243, "C-Cl": 328
  };

  // Preset target reactions for formation mode: { id, name, terms: [{species, coef}] }
  // coef > 0 product, < 0 reactant
  var TARGETS = {
    comb_ch4: {
      name: "Combustion of CH₄",
      terms: [
        { species: "CH4(g)", coef: -1 },
        { species: "O2(g)", coef: -2 },
        { species: "CO2(g)", coef: 1 },
        { species: "H2O(l)", coef: 2 }
      ]
    },
    form_h2o: {
      name: "Formation of H₂O(l)",
      terms: [
        { species: "H2(g)", coef: -1 },
        { species: "O2(g)", coef: -0.5 },
        { species: "H2O(l)", coef: 1 }
      ]
    },
    form_co2: {
      name: "Formation of CO₂",
      terms: [
        { species: "C(s)", coef: -1 },
        { species: "O2(g)", coef: -1 },
        { species: "CO2(g)", coef: 1 }
      ]
    },
    form_nh3: {
      name: "Haber: formation of NH₃",
      terms: [
        { species: "N2(g)", coef: -0.5 },
        { species: "H2(g)", coef: -1.5 },
        { species: "NH3(g)", coef: 1 }
      ]
    },
    comb_c2h2: {
      name: "Combustion of C₂H₂",
      terms: [
        { species: "C2H2(g)", coef: -1 },
        { species: "O2(g)", coef: -2.5 },
        { species: "CO2(g)", coef: 2 },
        { species: "H2O(l)", coef: 1 }
      ]
    },
    decomp_caco3: {
      name: "Decomposition of CaCO₃",
      terms: [
        { species: "CaCO3(s)", coef: -1 },
        { species: "CaO(s)", coef: 1 },
        { species: "CO2(g)", coef: 1 }
      ]
    }
  };

  // Hess cycle libraries: each step { id, equation text, terms, dH }
  var CYCLES = {
    co_path: {
      name: "C → CO → CO₂ pathway",
      targetName: "C(s) + O₂ → CO₂",
      targetTerms: [
        { species: "C(s)", coef: -1 },
        { species: "O2(g)", coef: -1 },
        { species: "CO2(g)", coef: 1 }
      ],
      steps: [
        {
          id: "s1",
          label: "C(s) + ½O₂ → CO",
          dH: -110.5,
          terms: [
            { species: "C(s)", coef: -1 },
            { species: "O2(g)", coef: -0.5 },
            { species: "CO(g)", coef: 1 }
          ]
        },
        {
          id: "s2",
          label: "CO + ½O₂ → CO₂",
          dH: -283.0,
          terms: [
            { species: "CO(g)", coef: -1 },
            { species: "O2(g)", coef: -0.5 },
            { species: "CO2(g)", coef: 1 }
          ]
        }
      ]
    },
    methane: {
      name: "Formation of CH₄ via C + 2H₂",
      targetName: "C(s) + 2H₂ → CH₄",
      targetTerms: [
        { species: "C(s)", coef: -1 },
        { species: "H2(g)", coef: -2 },
        { species: "CH4(g)", coef: 1 }
      ],
      steps: [
        {
          id: "s1",
          label: "C(s) + O₂ → CO₂",
          dH: -393.5,
          terms: [
            { species: "C(s)", coef: -1 },
            { species: "O2(g)", coef: -1 },
            { species: "CO2(g)", coef: 1 }
          ]
        },
        {
          id: "s2",
          label: "H₂ + ½O₂ → H₂O(l)",
          dH: -285.8,
          terms: [
            { species: "H2(g)", coef: -1 },
            { species: "O2(g)", coef: -0.5 },
            { species: "H2O(l)", coef: 1 }
          ]
        },
        {
          id: "s3",
          label: "CH₄ + 2O₂ → CO₂ + 2H₂O(l)",
          dH: -890.3,
          terms: [
            { species: "CH4(g)", coef: -1 },
            { species: "O2(g)", coef: -2 },
            { species: "CO2(g)", coef: 1 },
            { species: "H2O(l)", coef: 2 }
          ]
        }
      ]
    },
    water_gas: {
      name: "Water–gas shift related",
      targetName: "CO + H₂O(g) → CO₂ + H₂",
      targetTerms: [
        { species: "CO(g)", coef: -1 },
        { species: "H2O(g)", coef: -1 },
        { species: "CO2(g)", coef: 1 },
        { species: "H2(g)", coef: 1 }
      ],
      steps: [
        {
          id: "s1",
          label: "CO + ½O₂ → CO₂",
          dH: -283.0,
          terms: [
            { species: "CO(g)", coef: -1 },
            { species: "O2(g)", coef: -0.5 },
            { species: "CO2(g)", coef: 1 }
          ]
        },
        {
          id: "s2",
          label: "H₂ + ½O₂ → H₂O(g)",
          dH: -241.8,
          terms: [
            { species: "H2(g)", coef: -1 },
            { species: "O2(g)", coef: -0.5 },
            { species: "H2O(g)", coef: 1 }
          ]
        }
      ]
    }
  };

  // Bond-estimate reactions: bonds broken / formed counts
  var BOND_RXNS = {
    h2_cl2: {
      name: "H₂ + Cl₂ → 2HCl",
      broken: { "H-H": 1, "Cl-Cl": 1 },
      formed: { "H-Cl": 2 }
    },
    ch4_comb: {
      name: "CH₄ + 2O₂ → CO₂ + 2H₂O",
      broken: { "H-C": 4, "O=O": 2 },
      formed: { "C=O": 2, "H-O": 4 }
    },
    n2_h2: {
      name: "N₂ + 3H₂ → 2NH₃",
      broken: { "N≡N": 1, "H-H": 3 },
      formed: { "H-N": 6 }
    },
    c2h4_h2: {
      name: "C₂H₄ + H₂ → C₂H₆",
      broken: { "C=C": 1, "H-H": 1 },
      formed: { "C-C": 1, "H-C": 2 }
    }
  };

  function ThermoModel() {
    this.mode = "formation"; // formation | hess | bond
    this.targetId = "comb_ch4";
    this.cycleId = "co_path";
    // For each cycle step: multiplier (can be negative = reverse)
    this.multipliers = {};
    this.bondRxnId = "h2_cl2";
  }

  ThermoModel.DHF = DHF;
  ThermoModel.BOND = BOND;
  ThermoModel.TARGETS = TARGETS;
  ThermoModel.CYCLES = CYCLES;
  ThermoModel.BOND_RXNS = BOND_RXNS;

  ThermoModel.prototype.dhfOf = function (species) {
    if (DHF[species] != null) return DHF[species];
    return null;
  };

  /** ΔH°_rxn from formation enthalpies */
  ThermoModel.prototype.solveFormation = function () {
    var t = TARGETS[this.targetId] || TARGETS.comb_ch4;
    var sum = 0;
    var lines = [];
    var missing = [];
    t.terms.forEach(function (term) {
      var hf = DHF[term.species];
      if (hf == null) {
        missing.push(term.species);
        return;
      }
      var contrib = term.coef * hf;
      sum += contrib;
      lines.push({
        species: term.species,
        coef: term.coef,
        hf: hf,
        contrib: contrib
      });
    });
    return {
      mode: "formation",
      name: t.name,
      terms: t.terms,
      lines: lines,
      dH: sum,
      missing: missing,
      ok: missing.length === 0
    };
  };

  /**
   * Hess cycle: apply multipliers to steps, sum ΔH, check net stoichiometry vs target.
   */
  ThermoModel.prototype.solveHess = function () {
    var cycle = CYCLES[this.cycleId] || CYCLES.co_path;
    var mults = this.multipliers;
    // default multipliers if empty: all +1
    if (!Object.keys(mults).length) {
      cycle.steps.forEach(function (s) { mults[s.id] = 1; });
    }

    var totalDH = 0;
    var net = {}; // species → net coefficient
    var applied = [];

    cycle.steps.forEach(function (step) {
      var m = mults[step.id] != null ? mults[step.id] : 0;
      totalDH += m * step.dH;
      step.terms.forEach(function (term) {
        net[term.species] = (net[term.species] || 0) + m * term.coef;
      });
      applied.push({
        id: step.id,
        label: step.label,
        dH: step.dH,
        mult: m,
        contrib: m * step.dH,
        reversed: m < 0,
        scaled: Math.abs(m) !== 1 && m !== 0
      });
    });

    // Clean near-zero
    Object.keys(net).forEach(function (s) {
      if (Math.abs(net[s]) < 1e-9) delete net[s];
    });

    // Compare to target
    var targetNet = {};
    cycle.targetTerms.forEach(function (t) {
      targetNet[t.species] = t.coef;
    });
    var match = true;
    var allSpecies = {};
    Object.keys(net).forEach(function (s) { allSpecies[s] = true; });
    Object.keys(targetNet).forEach(function (s) { allSpecies[s] = true; });
    Object.keys(allSpecies).forEach(function (s) {
      if (Math.abs((net[s] || 0) - (targetNet[s] || 0)) > 1e-6) match = false;
    });

    // Reference ΔH from formation if possible
    var refDH = null;
    try {
      var refSum = 0;
      var ok = true;
      cycle.targetTerms.forEach(function (t) {
        if (DHF[t.species] == null) ok = false;
        else refSum += t.coef * DHF[t.species];
      });
      if (ok) refDH = refSum;
    } catch (e) { /* ignore */ }

    return {
      mode: "hess",
      name: cycle.name,
      targetName: cycle.targetName,
      targetTerms: cycle.targetTerms,
      steps: cycle.steps,
      applied: applied,
      totalDH: totalDH,
      net: net,
      match: match,
      refDH: refDH
    };
  };

  /** Bond enthalpy estimate */
  ThermoModel.prototype.solveBond = function () {
    var rxn = BOND_RXNS[this.bondRxnId] || BOND_RXNS.h2_cl2;
    var broken = 0;
    var formed = 0;
    var brokenLines = [];
    var formedLines = [];
    Object.keys(rxn.broken).forEach(function (b) {
      var e = BOND[b];
      var n = rxn.broken[b];
      if (e == null) return;
      broken += n * e;
      brokenLines.push({ bond: b, n: n, e: e, total: n * e });
    });
    Object.keys(rxn.formed).forEach(function (b) {
      var e = BOND[b];
      var n = rxn.formed[b];
      if (e == null) return;
      formed += n * e;
      formedLines.push({ bond: b, n: n, e: e, total: n * e });
    });
    var dH = broken - formed;
    return {
      mode: "bond",
      name: rxn.name,
      broken: brokenLines,
      formed: formedLines,
      sumBroken: broken,
      sumFormed: formed,
      dH: dH
    };
  };

  ThermoModel.prototype.solve = function () {
    if (this.mode === "formation") return this.solveFormation();
    if (this.mode === "hess") return this.solveHess();
    return this.solveBond();
  };

  ThermoModel.prototype.setCycle = function (id) {
    this.cycleId = id;
    this.multipliers = {};
    var cycle = CYCLES[id];
    if (cycle) {
      cycle.steps.forEach(function (s) {
        this.multipliers[s.id] = 1;
      }, this);
    }
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = ThermoModel;
  }
  global.ThermoModel = ThermoModel;
})(typeof window !== "undefined" ? window : global);
