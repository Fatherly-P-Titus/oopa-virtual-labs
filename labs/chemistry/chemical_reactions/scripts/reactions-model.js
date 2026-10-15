/**
 * ReactionsModel – element picker + curated synthesis / combination reactions.
 * Educational: products and stoichiometry are chemically realistic.
 */
(function (global) {
  "use strict";

  /** Element metadata. form = how it usually enters a reaction equation. */
  var ELEMENTS = {
    H:  { Z: 1,  name: "Hydrogen", group: 1,  cat: "nonmetal", form: "H2", color: "#e8f5e9" },
    He: { Z: 2,  name: "Helium", group: 18, cat: "noble", form: "He", color: "#f3e5f5" },
    Li: { Z: 3,  name: "Lithium", group: 1,  cat: "metal", form: "Li", color: "#fff3e0" },
    Be: { Z: 4,  name: "Beryllium", group: 2, cat: "metal", form: "Be", color: "#fff3e0" },
    B:  { Z: 5,  name: "Boron", group: 13, cat: "metalloid", form: "B", color: "#e0f7fa" },
    C:  { Z: 6,  name: "Carbon", group: 14, cat: "nonmetal", form: "C", color: "#e8f5e9" },
    N:  { Z: 7,  name: "Nitrogen", group: 15, cat: "nonmetal", form: "N2", color: "#e8f5e9" },
    O:  { Z: 8,  name: "Oxygen", group: 16, cat: "nonmetal", form: "O2", color: "#e8f5e9" },
    F:  { Z: 9,  name: "Fluorine", group: 17, cat: "nonmetal", form: "F2", color: "#e8f5e9" },
    Ne: { Z: 10, name: "Neon", group: 18, cat: "noble", form: "Ne", color: "#f3e5f5" },
    Na: { Z: 11, name: "Sodium", group: 1, cat: "metal", form: "Na", color: "#fff3e0" },
    Mg: { Z: 12, name: "Magnesium", group: 2, cat: "metal", form: "Mg", color: "#fff3e0" },
    Al: { Z: 13, name: "Aluminium", group: 13, cat: "metal", form: "Al", color: "#fff3e0" },
    Si: { Z: 14, name: "Silicon", group: 14, cat: "metalloid", form: "Si", color: "#e0f7fa" },
    P:  { Z: 15, name: "Phosphorus", group: 15, cat: "nonmetal", form: "P", color: "#e8f5e9" },
    S:  { Z: 16, name: "Sulfur", group: 16, cat: "nonmetal", form: "S", color: "#e8f5e9" },
    Cl: { Z: 17, name: "Chlorine", group: 17, cat: "nonmetal", form: "Cl2", color: "#e8f5e9" },
    Ar: { Z: 18, name: "Argon", group: 18, cat: "noble", form: "Ar", color: "#f3e5f5" },
    K:  { Z: 19, name: "Potassium", group: 1, cat: "metal", form: "K", color: "#fff3e0" },
    Ca: { Z: 20, name: "Calcium", group: 2, cat: "metal", form: "Ca", color: "#fff3e0" },
    Fe: { Z: 26, name: "Iron", group: 8, cat: "metal", form: "Fe", color: "#eceff1" },
    Cu: { Z: 29, name: "Copper", group: 11, cat: "metal", form: "Cu", color: "#eceff1" },
    Zn: { Z: 30, name: "Zinc", group: 12, cat: "metal", form: "Zn", color: "#eceff1" },
    Br: { Z: 35, name: "Bromine", group: 17, cat: "nonmetal", form: "Br2", color: "#e8f5e9" },
    I:  { Z: 53, name: "Iodine", group: 17, cat: "nonmetal", form: "I2", color: "#e8f5e9" },
    Ag: { Z: 47, name: "Silver", group: 11, cat: "metal", form: "Ag", color: "#eceff1" },
    Au: { Z: 79, name: "Gold", group: 11, cat: "metal", form: "Au", color: "#fffde7" }
  };

  /**
   * Reaction table. key = sorted element symbols joined by "+" (e.g. "H+N").
   * equation uses molecular forms. type: synthesis | oxidation | halogenation | other
   */
  var REACTIONS = {
    "H+N": {
      equation: "N₂ + 3H₂ → 2NH₃",
      product: "NH₃",
      productName: "Ammonia",
      type: "synthesis",
      notes: "Haber–Bosch process needs high pressure, moderate heat and a catalyst. The product is NH₃ (not NH₂).",
      conditions: "High P, ~400–500 °C, Fe catalyst"
    },
    "H+O": {
      equation: "2H₂ + O₂ → 2H₂O",
      product: "H₂O",
      productName: "Water",
      type: "synthesis",
      notes: "Explosive when mixed and ignited; forms water.",
      conditions: "Spark or flame"
    },
    "F+H": {
      equation: "H₂ + F₂ → 2HF",
      product: "HF",
      productName: "Hydrogen fluoride",
      type: "halogenation",
      notes: "Very exothermic. HF is a dangerous acid in aqueous form.",
      conditions: "Room temperature (vigorous)"
    },
    "Cl+H": {
      equation: "H₂ + Cl₂ → 2HCl",
      product: "HCl",
      productName: "Hydrogen chloride",
      type: "halogenation",
      notes: "Photochemical or thermal chain reaction. HCl(g) dissolves to hydrochloric acid.",
      conditions: "Light or heat"
    },
    "Br+H": {
      equation: "H₂ + Br₂ → 2HBr",
      product: "HBr",
      productName: "Hydrogen bromide",
      type: "halogenation",
      notes: "Less vigorous than Cl₂ or F₂.",
      conditions: "Heat"
    },
    "H+I": {
      equation: "H₂ + I₂ ⇌ 2HI",
      product: "HI",
      productName: "Hydrogen iodide",
      type: "halogenation",
      notes: "Equilibrium reaction; incomplete conversion.",
      conditions: "Heat"
    },
    "C+O": {
      equation: "C + O₂ → CO₂",
      product: "CO₂",
      productName: "Carbon dioxide",
      type: "oxidation",
      notes: "Complete combustion of carbon. Limited O₂ can give CO.",
      conditions: "Heat / flame"
    },
    "C+H": {
      equation: "C + 2H₂ → CH₄",
      product: "CH₄",
      productName: "Methane",
      type: "synthesis",
      notes: "Not a simple lab combination; industrial/geological context. Shown for stoichiometry.",
      conditions: "Special catalysts / extreme conditions"
    },
    "N+O": {
      equation: "N₂ + O₂ → 2NO",
      product: "NO",
      productName: "Nitrogen monoxide",
      type: "oxidation",
      notes: "Endothermic; forms in lightning and engines. Further oxidation gives NO₂.",
      conditions: "Very high T or electric arc"
    },
    "O+P": {
      equation: "4P + 5O₂ → 2P₂O₅",
      product: "P₂O₅",
      productName: "Phosphorus(V) oxide",
      type: "oxidation",
      notes: "White phosphorus ignites readily in air forming the oxide (often written P₄O₁₀).",
      conditions: "Air / heat"
    },
    "O+S": {
      equation: "S + O₂ → SO₂",
      product: "SO₂",
      productName: "Sulfur dioxide",
      type: "oxidation",
      notes: "Further oxidation with catalyst gives SO₃ (contact process).",
      conditions: "Heat"
    },
    "Cl+Na": {
      equation: "2Na + Cl₂ → 2NaCl",
      product: "NaCl",
      productName: "Sodium chloride",
      type: "synthesis",
      notes: "Classic vigorous synthesis of table salt from the elements.",
      conditions: "Heat (exothermic once started)"
    },
    "Na+O": {
      equation: "4Na + O₂ → 2Na₂O",
      product: "Na₂O",
      productName: "Sodium oxide",
      type: "oxidation",
      notes: "In excess air, peroxide Na₂O₂ can form.",
      conditions: "Heat"
    },
    "H+Na": {
      equation: "2Na + H₂ → 2NaH",
      product: "NaH",
      productName: "Sodium hydride",
      type: "synthesis",
      notes: "Ionic hydride; reacts violently with water.",
      conditions: "Heat, H₂ atmosphere"
    },
    "Cl+K": {
      equation: "2K + Cl₂ → 2KCl",
      product: "KCl",
      productName: "Potassium chloride",
      type: "synthesis",
      notes: "Similar to sodium + chlorine.",
      conditions: "Heat"
    },
    "K+O": {
      equation: "4K + O₂ → 2K₂O",
      product: "K₂O",
      productName: "Potassium oxide",
      type: "oxidation",
      notes: "Superoxide KO₂ is common in excess oxygen.",
      conditions: "Heat"
    },
    "Li+O": {
      equation: "4Li + O₂ → 2Li₂O",
      product: "Li₂O",
      productName: "Lithium oxide",
      type: "oxidation",
      notes: "Lithium mainly forms the oxide (not peroxide) in air.",
      conditions: "Heat"
    },
    "Cl+Li": {
      equation: "2Li + Cl₂ → 2LiCl",
      product: "LiCl",
      productName: "Lithium chloride",
      type: "synthesis",
      notes: "Ionic salt.",
      conditions: "Heat"
    },
    "Mg+O": {
      equation: "2Mg + O₂ → 2MgO",
      product: "MgO",
      productName: "Magnesium oxide",
      type: "oxidation",
      notes: "Bright white flame — classic demo.",
      conditions: "Ignition in air"
    },
    "Cl+Mg": {
      equation: "Mg + Cl₂ → MgCl₂",
      product: "MgCl₂",
      productName: "Magnesium chloride",
      type: "synthesis",
      notes: "Ionic salt used in industry.",
      conditions: "Heat"
    },
    "Mg+N": {
      equation: "3Mg + N₂ → Mg₃N₂",
      product: "Mg₃N₂",
      productName: "Magnesium nitride",
      type: "synthesis",
      notes: "Forms when Mg burns in air (alongside MgO).",
      conditions: "High T"
    },
    "Ca+O": {
      equation: "2Ca + O₂ → 2CaO",
      product: "CaO",
      productName: "Calcium oxide (lime)",
      type: "oxidation",
      notes: "Quicklime; reacts with water to form Ca(OH)₂.",
      conditions: "Heat"
    },
    "Ca+Cl": {
      equation: "Ca + Cl₂ → CaCl₂",
      product: "CaCl₂",
      productName: "Calcium chloride",
      type: "synthesis",
      notes: "Hygroscopic salt.",
      conditions: "Heat"
    },
    "Al+O": {
      equation: "4Al + 3O₂ → 2Al₂O₃",
      product: "Al₂O₃",
      productName: "Aluminium oxide",
      type: "oxidation",
      notes: "Protective oxide layer forms readily on aluminium metal.",
      conditions: "Heat / air"
    },
    "Al+Cl": {
      equation: "2Al + 3Cl₂ → 2AlCl₃",
      product: "AlCl₃",
      productName: "Aluminium chloride",
      type: "synthesis",
      notes: "Covalent character; dimerises as Al₂Cl₆ in vapour.",
      conditions: "Heat"
    },
    "Fe+O": {
      equation: "4Fe + 3O₂ → 2Fe₂O₃",
      product: "Fe₂O₃",
      productName: "Iron(III) oxide (rust-related)",
      type: "oxidation",
      notes: "Rusting is more complex (hydrated oxides); this is the simple stoichiometric oxide.",
      conditions: "Heat / moist air (slow)"
    },
    "Cl+Fe": {
      equation: "2Fe + 3Cl₂ → 2FeCl₃",
      product: "FeCl₃",
      productName: "Iron(III) chloride",
      type: "halogenation",
      notes: "With limited Cl₂, FeCl₂ can form.",
      conditions: "Heat"
    },
    "Fe+S": {
      equation: "Fe + S → FeS",
      product: "FeS",
      productName: "Iron(II) sulfide",
      type: "synthesis",
      notes: "Classic school synthesis: mix powders and heat.",
      conditions: "Heat"
    },
    "Cu+O": {
      equation: "2Cu + O₂ → 2CuO",
      product: "CuO",
      productName: "Copper(II) oxide",
      type: "oxidation",
      notes: "Black oxide; Cu₂O (red) forms under limited oxygen.",
      conditions: "Heat"
    },
    "Cl+Cu": {
      equation: "Cu + Cl₂ → CuCl₂",
      product: "CuCl₂",
      productName: "Copper(II) chloride",
      type: "halogenation",
      notes: "Also accessible from copper and HCl/H₂O₂ routes in lab.",
      conditions: "Heat"
    },
    "O+Zn": {
      equation: "2Zn + O₂ → 2ZnO",
      product: "ZnO",
      productName: "Zinc oxide",
      type: "oxidation",
      notes: "White smoke when zinc burns.",
      conditions: "Heat"
    },
    "Cl+Zn": {
      equation: "Zn + Cl₂ → ZnCl₂",
      product: "ZnCl₂",
      productName: "Zinc chloride",
      type: "synthesis",
      notes: "Ionic / polar covalent salt.",
      conditions: "Heat"
    },
    "S+Zn": {
      equation: "Zn + S → ZnS",
      product: "ZnS",
      productName: "Zinc sulfide",
      type: "synthesis",
      notes: "Can be made by heating the elements together.",
      conditions: "Heat"
    },
    "Cl+O": {
      equation: "No simple stable binary oxide from Cl₂ + O₂ under mild conditions",
      product: null,
      productName: null,
      type: "none",
      notes: "Chlorine oxides (Cl₂O, ClO₂, …) exist but need special preparation — not a direct combination product in a basic lab.",
      conditions: "—"
    },
    "C+Cl": {
      equation: "C + 2Cl₂ → CCl₄ (requires forcing conditions)",
      product: "CCl₄",
      productName: "Carbon tetrachloride",
      type: "halogenation",
      notes: "Historically made under severe conditions; not a casual lab mix.",
      conditions: "High T, catalyst"
    },
    "O+Si": {
      equation: "Si + O₂ → SiO₂",
      product: "SiO₂",
      productName: "Silicon dioxide (silica)",
      type: "oxidation",
      notes: "Sand / quartz is SiO₂.",
      conditions: "Heat"
    },
    "Cl+Si": {
      equation: "Si + 2Cl₂ → SiCl₄",
      product: "SiCl₄",
      productName: "Silicon tetrachloride",
      type: "halogenation",
      notes: "Important intermediate in silicon purification.",
      conditions: "Heat"
    },
    "B+O": {
      equation: "4B + 3O₂ → 2B₂O₃",
      product: "B₂O₃",
      productName: "Boron oxide",
      type: "oxidation",
      notes: "Forms a glassy oxide.",
      conditions: "Heat"
    },
    "B+Cl": {
      equation: "2B + 3Cl₂ → 2BCl₃",
      product: "BCl₃",
      productName: "Boron trichloride",
      type: "halogenation",
      notes: "Reactive covalent chloride.",
      conditions: "Heat"
    },
    "Ag+Cl": {
      equation: "2Ag + Cl₂ → 2AgCl",
      product: "AgCl",
      productName: "Silver chloride",
      type: "halogenation",
      notes: "More commonly precipitated from Ag⁺(aq) + Cl⁻(aq). Light-sensitive.",
      conditions: "Heat / light"
    },
    "Ag+O": {
      equation: "Limited direct oxidation; Ag₂O forms under special conditions",
      product: "Ag₂O",
      productName: "Silver oxide",
      type: "oxidation",
      notes: "Silver is relatively unreactive toward O₂ at room temperature.",
      conditions: "Special / electrochemical"
    },
    "Au+O": {
      equation: "No reaction under ordinary conditions",
      product: null,
      productName: null,
      type: "none",
      notes: "Gold does not oxidise in air. That is why it stays shiny.",
      conditions: "—"
    },
    "Au+Cl": {
      equation: "2Au + 3Cl₂ → 2AuCl₃ (requires heat / chlorine)",
      product: "AuCl₃",
      productName: "Gold(III) chloride",
      type: "halogenation",
      notes: "Gold is noble; still reacts with chlorine under the right conditions.",
      conditions: "Heat, Cl₂"
    }
  };

  function keyFor(symbols) {
    return symbols.slice().sort().join("+");
  }

  function ReactionsModel() {
    this.selected = []; // element symbols, max 3
  }

  ReactionsModel.ELEMENTS = ELEMENTS;
  ReactionsModel.REACTIONS = REACTIONS;

  ReactionsModel.prototype.toggle = function (sym) {
    if (!ELEMENTS[sym]) return;
    var i = this.selected.indexOf(sym);
    if (i >= 0) {
      this.selected.splice(i, 1);
      return;
    }
    if (this.selected.length >= 3) return;
    // nobles: allow select but reaction will explain
    this.selected.push(sym);
  };

  ReactionsModel.prototype.clear = function () {
    this.selected = [];
  };

  ReactionsModel.prototype.solve = function () {
    var sel = this.selected.slice();
    if (sel.length === 0) {
      return { status: "empty", message: "Select one or more elements from the periodic table." };
    }
    if (sel.length === 1) {
      var el = ELEMENTS[sel[0]];
      return {
        status: "single",
        elements: sel,
        message: el.name + " alone is not a reaction. Add another element to combine.",
        forms: [el.form]
      };
    }

    // Noble gas check
    var nobles = sel.filter(function (s) { return ELEMENTS[s].cat === "noble"; });
    if (nobles.length) {
      return {
        status: "none",
        elements: sel,
        message: "Noble gases (" + nobles.join(", ") + ") have full valence shells and do not form ordinary compounds under standard conditions.",
        type: "none"
      };
    }

    var k = keyFor(sel);
    var rxn = REACTIONS[k];

    // Try pairwise if 3 selected and no direct 3-body entry
    if (!rxn && sel.length === 3) {
      return {
        status: "none",
        elements: sel,
        message: "No simple three-element combination is tabulated here. Try two elements at a time (e.g. N + H, or Mg + O).",
        type: "none"
      };
    }

    if (!rxn) {
      return {
        status: "none",
        elements: sel,
        message: "No simple stable product is listed for " + sel.join(" + ") + " under ordinary teaching conditions. Many pairs need extreme pressure, temperature, plasma or do not form a stable binary compound.",
        type: "none",
        forms: sel.map(function (s) { return ELEMENTS[s].form; })
      };
    }

    return {
      status: rxn.product ? "reaction" : "none",
      elements: sel,
      equation: rxn.equation,
      product: rxn.product,
      productName: rxn.productName,
      type: rxn.type,
      notes: rxn.notes,
      conditions: rxn.conditions,
      forms: sel.map(function (s) { return ELEMENTS[s].form; })
    };
  };

  /** Ordered list for PT layout (subset we support) */
  ReactionsModel.PT_ORDER = [
    ["H", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "He"],
    ["Li", "Be", "", "", "", "", "", "", "", "", "", "", "B", "C", "N", "O", "F", "Ne"],
    ["Na", "Mg", "", "", "", "", "", "", "", "", "", "", "Al", "Si", "P", "S", "Cl", "Ar"],
    ["K", "Ca", "", "", "", "Fe", "", "Cu", "Zn", "", "", "", "", "", "", "", "Br", ""],
    ["", "", "", "", "", "", "", "Ag", "", "", "", "", "", "", "", "", "I", ""],
    ["", "", "", "", "", "", "", "Au", "", "", "", "", "", "", "", "", "", ""]
  ];

  if (typeof module !== "undefined" && module.exports) {
    module.exports = ReactionsModel;
  }
  global.ReactionsModel = ReactionsModel;
})(typeof window !== "undefined" ? window : global);
