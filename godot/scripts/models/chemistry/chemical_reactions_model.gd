extends RefCounted
class_name ChemicalReactionsModel
## v1 — curated reaction catalogue + stoichiometry / limiting reagent.
## Each reaction: id, type, reactants[{id,coeff}], products[{id,coeff}], note, visual tags.

enum RType { SYNTHESIS, DECOMPOSITION, SINGLE_REPLACEMENT, DOUBLE_REPLACEMENT, COMBUSTION, ACID_BASE, REDOX }

const TYPE_NAMES := {
	RType.SYNTHESIS: "Synthesis",
	RType.DECOMPOSITION: "Decomposition",
	RType.SINGLE_REPLACEMENT: "Single replacement",
	RType.DOUBLE_REPLACEMENT: "Double replacement",
	RType.COMBUSTION: "Combustion",
	RType.ACID_BASE: "Acid–base",
	RType.REDOX: "Redox",
}

## Species display names / formulas
const SPECIES := {
	"H": "H", "O": "O", "N": "N", "C": "C", "S": "S", "P": "P",
	"K": "K", "Ca": "Ca", "Al": "Al", "Ag": "Ag", "Pb": "Pb",
	"Br2": "Br₂", "I2": "I₂", "SO2": "SO₂", "SO3": "SO₃", "NO": "NO", "NO2": "NO₂",
	"H2O2": "H₂O₂", "CO": "CO", "CaOH2": "Ca(OH)₂", "BaCl2": "BaCl₂", "BaSO4": "BaSO₄",

	"H2": "H₂", "O2": "O₂", "N2": "N₂", "Cl2": "Cl₂", "H2O": "H₂O",
	"CO2": "CO₂", "NH3": "NH₃", "CH4": "CH₄", "C2H6": "C₂H₆",
	"Na": "Na", "Cl": "Cl", "NaCl": "NaCl", "Na2SO4": "Na₂SO₄", "FeSO4": "FeSO₄", "Fe": "Fe", "Fe2O3": "Fe₂O₃",
	"Cu": "Cu", "CuSO4": "CuSO₄", "Zn": "Zn", "ZnSO4": "ZnSO₄",
	"AgNO3": "AgNO₃", "AgCl": "AgCl", "NaNO3": "NaNO₃",
	"HCl": "HCl", "NaOH": "NaOH", "CaCO3": "CaCO₃", "CaO": "CaO",
	"H2SO4": "H₂SO₄", "Mg": "Mg", "MgO": "MgO", "KClO3": "KClO₃", "KCl": "KCl",
	"FeCl2": "FeCl₂", "CuCl2": "CuCl₂",
}

var reactions: Array = []
var selected_id: String = "water_synth"
## moles of each reactant id the student provides
var reactant_moles: Dictionary = {}


func _init() -> void:
	_build_catalogue()
	select_reaction(selected_id)


func _build_catalogue() -> void:
	reactions = [
		_rx("water_synth", RType.SYNTHESIS, "Make water",
			[{"id": "H2", "c": 2}, {"id": "O2", "c": 1}],
			[{"id": "H2O", "c": 2}],
			"Classic synthesis: hydrogen burns in oxygen.",
			{"gas": true, "heat": true}),
		_rx("ammonia", RType.SYNTHESIS, "Haber — ammonia",
			[{"id": "N2", "c": 1}, {"id": "H2", "c": 3}],
			[{"id": "NH3", "c": 2}],
			"Industrial synthesis of ammonia.",
			{"gas": true}),
		_rx("nacl_synth", RType.SYNTHESIS, "Sodium chloride",
			[{"id": "Na", "c": 2}, {"id": "Cl2", "c": 1}],
			[{"id": "NaCl", "c": 2}],
			"Reactive metal + halogen.",
			{"heat": true}),
		_rx("mgo", RType.SYNTHESIS, "Magnesium oxide",
			[{"id": "Mg", "c": 2}, {"id": "O2", "c": 1}],
			[{"id": "MgO", "c": 2}],
			"Bright burn of magnesium ribbon.",
			{"heat": true}),
		_rx("water_decomp", RType.DECOMPOSITION, "Electrolysis of water",
			[{"id": "H2O", "c": 2}],
			[{"id": "H2", "c": 2}, {"id": "O2", "c": 1}],
			"Decomposition by electricity.",
			{"gas": true}),
		_rx("caco3", RType.DECOMPOSITION, "Heat limestone",
			[{"id": "CaCO3", "c": 1}],
			[{"id": "CaO", "c": 1}, {"id": "CO2", "c": 1}],
			"Thermal decomposition.",
			{"gas": true, "heat": true}),
		_rx("kclo3", RType.DECOMPOSITION, "Potassium chlorate",
			[{"id": "KClO3", "c": 2}],
			[{"id": "KCl", "c": 2}, {"id": "O2", "c": 3}],
			"Oxygen generation demo.",
			{"gas": true, "heat": true}),
		_rx("zn_cuso4", RType.SINGLE_REPLACEMENT, "Zn + CuSO₄",
			[{"id": "Zn", "c": 1}, {"id": "CuSO4", "c": 1}],
			[{"id": "ZnSO4", "c": 1}, {"id": "Cu", "c": 1}],
			"More reactive metal displaces copper.",
			{"color_change": true}),
		_rx("fe_cuso4", RType.SINGLE_REPLACEMENT, "Fe + CuSO₄",
			[{"id": "Fe", "c": 1}, {"id": "CuSO4", "c": 1}],
			[{"id": "FeSO4", "c": 1}, {"id": "Cu", "c": 1}],
			"Iron displaces copper ions from solution.",
			{"color_change": true}),
		_rx("agcl_ppt", RType.DOUBLE_REPLACEMENT, "AgCl precipitate",
			[{"id": "AgNO3", "c": 1}, {"id": "NaCl", "c": 1}],
			[{"id": "AgCl", "c": 1}, {"id": "NaNO3", "c": 1}],
			"White precipitate of silver chloride.",
			{"precipitate": true}),
		_rx("neutralize", RType.ACID_BASE, "Neutralize HCl",
			[{"id": "HCl", "c": 1}, {"id": "NaOH", "c": 1}],
			[{"id": "NaCl", "c": 1}, {"id": "H2O", "c": 1}],
			"Acid + base → salt + water.",
			{"heat": true}),
		_rx("h2so4_naoh", RType.ACID_BASE, "H₂SO₄ + NaOH",
			[{"id": "H2SO4", "c": 1}, {"id": "NaOH", "c": 2}],
			[{"id": "Na2SO4", "c": 1}, {"id": "H2O", "c": 2}],
			"Diprotic acid neutralization.",
			{"heat": true}),
		_rx("methane", RType.COMBUSTION, "Burn methane",
			[{"id": "CH4", "c": 1}, {"id": "O2", "c": 2}],
			[{"id": "CO2", "c": 1}, {"id": "H2O", "c": 2}],
			"Complete combustion of natural gas.",
			{"gas": true, "heat": true}),
		_rx("ethane", RType.COMBUSTION, "Burn ethane",
			[{"id": "C2H6", "c": 2}, {"id": "O2", "c": 7}],
			[{"id": "CO2", "c": 4}, {"id": "H2O", "c": 6}],
			"Complete combustion.",
			{"gas": true, "heat": true}),
		_rx("carbon_burn", RType.COMBUSTION, "Burn carbon",
			[{"id": "C", "c": 1}, {"id": "O2", "c": 1}],
			[{"id": "CO2", "c": 1}],
			"Elemental combustion.",
			{"gas": true, "heat": true}),
		_rx("rust", RType.REDOX, "Rusting (simplified)",
			[{"id": "Fe", "c": 4}, {"id": "O2", "c": 3}],
			[{"id": "Fe2O3", "c": 2}],
			"Oxidation of iron (dry form).",
			{"color_change": true}),
	]


func _rx(id: String, typ: int, title: String, reactants: Array, products: Array, note: String, visual: Dictionary) -> Dictionary:
	return {
		"id": id,
		"type": typ,
		"title": title,
		"reactants": reactants,
		"products": products,
		"note": note,
		"visual": visual,
	}


func reaction_ids() -> Array:
	var ids: Array = []
	for r in reactions:
		ids.append(str(r["id"]))
	return ids


func get_reaction(id: String = "") -> Dictionary:
	var want: String = id if id != "" else selected_id
	for r in reactions:
		if str(r["id"]) == want:
			return r
	return reactions[0] if reactions.size() > 0 else {}


func select_reaction(id: String) -> void:
	selected_id = id
	reactant_moles.clear()
	var rx: Dictionary = get_reaction(id)
	for sp in rx.get("reactants", []):
		reactant_moles[str(sp["id"])] = float(sp["c"]) * 2.0  # default excess-friendly


func set_moles(species_id: String, moles: float) -> void:
	reactant_moles[species_id] = maxf(moles, 0.0)


func formula(species_id: String) -> String:
	return str(SPECIES.get(species_id, species_id))


func type_name(typ: int) -> String:
	return str(TYPE_NAMES.get(typ, "Reaction"))


func equation_string(rx: Dictionary = {}) -> String:
	if rx.is_empty():
		rx = get_reaction()
	var left: PackedStringArray = PackedStringArray()
	var right: PackedStringArray = PackedStringArray()
	for sp in rx.get("reactants", []):
		var c: int = int(sp["c"])
		var f: String = formula(str(sp["id"]))
		left.append(("%d %s" % [c, f]) if c != 1 else f)
	for sp in rx.get("products", []):
		var c2: int = int(sp["c"])
		var f2: String = formula(str(sp["id"]))
		right.append(("%d %s" % [c2, f2]) if c2 != 1 else f2)
	return "%s  →  %s" % [" + ".join(left), " + ".join(right)]


func solve() -> Dictionary:
	var rx: Dictionary = get_reaction()
	var reactants: Array = rx.get("reactants", [])
	var products: Array = rx.get("products", [])
	if reactants.is_empty():
		return {"ok": false, "message": "No reaction selected."}

	# Extent limited by scarce reactant
	var extents: Array = []
	for sp in reactants:
		var sid: String = str(sp["id"])
		var need: float = float(sp["c"])
		var have: float = float(reactant_moles.get(sid, 0.0))
		extents.append(have / maxf(need, 1e-12))
	var extent: float = extents[0]
	var limiting: String = str(reactants[0]["id"])
	for i in range(extents.size()):
		if float(extents[i]) < extent:
			extent = float(extents[i])
			limiting = str(reactants[i]["id"])
	extent = maxf(extent, 0.0)

	var consumed: Dictionary = {}
	var leftover: Dictionary = {}
	for sp in reactants:
		var sid: String = str(sp["id"])
		var use: float = float(sp["c"]) * extent
		var have: float = float(reactant_moles.get(sid, 0.0))
		consumed[sid] = use
		leftover[sid] = maxf(have - use, 0.0)

	var produced: Dictionary = {}
	for sp in products:
		var sid: String = str(sp["id"])
		produced[sid] = float(sp["c"]) * extent

	var theoretical: Dictionary = produced.duplicate()
	# 100% yield in v1 (yield slider can scale later)
	var yield_frac: float = 1.0
	var actual: Dictionary = {}
	for k in produced.keys():
		actual[k] = float(produced[k]) * yield_frac

	return {
		"ok": true,
		"extent": extent,
		"limiting": limiting,
		"limiting_name": formula(limiting),
		"consumed": consumed,
		"leftover": leftover,
		"produced": actual,
		"theoretical": theoretical,
		"equation": equation_string(rx),
		"type": int(rx.get("type", 0)),
		"type_name": type_name(int(rx.get("type", 0))),
		"title": str(rx.get("title", "")),
		"note": str(rx.get("note", "")),
		"visual": rx.get("visual", {}),
	}


func find_by_reactant_pair(a: String, b: String) -> String:
	## Builder helper: first catalogue reaction that uses both species (order free).
	for r in reactions:
		var ids: Array = []
		for sp in r.get("reactants", []):
			ids.append(str(sp["id"]))
		if ids.has(a) and ids.has(b):
			return str(r["id"])
		if b == "" and ids.size() == 1 and ids.has(a):
			return str(r["id"])
	return ""


func all_species_ids() -> Array:
	var ids: Array = SPECIES.keys()
	ids.sort()
	return ids


func match_reactants(selected: Array) -> Dictionary:
	## Free-mix: selected is Array of species id strings (1–3).
	## Returns {matched: bool, reaction_id, message, candidates: Array}
	var want: Dictionary = {}
	for s in selected:
		var sid: String = str(s)
		if sid == "" or sid == "—":
			continue
		want[sid] = true
	if want.is_empty():
		return {"matched": false, "reaction_id": "", "message": "Select at least one reactant.", "candidates": []}

	var candidates: Array = []
	for r in reactions:
		var ids: Array = []
		for sp in r.get("reactants", []):
			ids.append(str(sp["id"]))
		# Exact set match (order-independent)
		if ids.size() != want.size():
			continue
		var ok: bool = true
		for id in ids:
			if not want.has(id):
				ok = false
				break
		if ok:
			candidates.append(str(r["id"]))

	if candidates.size() == 1:
		return {
			"matched": true,
			"reaction_id": str(candidates[0]),
			"message": "Matched catalogue reaction.",
			"candidates": candidates,
		}
	if candidates.size() > 1:
		return {
			"matched": true,
			"reaction_id": str(candidates[0]),
			"message": "Multiple matches — loaded first: %s" % str(candidates[0]),
			"candidates": candidates,
		}

	# Partial: all selected appear among reactants (and reaction may need more)
	var partial: Array = []
	for r in reactions:
		var ids2: Array = []
		for sp in r.get("reactants", []):
			ids2.append(str(sp["id"]))
		var all_in: bool = true
		for sid2 in want.keys():
			if not ids2.has(sid2):
				all_in = false
				break
		if all_in and ids2.size() > want.size():
			partial.append(str(r["id"]))

	if partial.size() > 0:
		return {
			"matched": false,
			"reaction_id": "",
			"message": "No complete match. These reactions need more reactants: %s" % ", ".join(partial),
			"candidates": partial,
		}

	return {
		"matched": false,
		"reaction_id": "",
		"message": "No reaction under standard catalogue conditions for this mix.",
		"candidates": [],
	}
