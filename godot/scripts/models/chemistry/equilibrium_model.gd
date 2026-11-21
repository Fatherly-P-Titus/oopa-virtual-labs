extends RefCounted
class_name EquilibriumModel
## Kc solvers: isomerization, addition, dimer, Haber.

const REACTIONS := {
	"isom": {
		"id": "isom", "name": "A ⇌ B",
		"species": ["A", "B"], "KcExpr": "[B]/[A]", "thermo": "endo",
	},
	"addition": {
		"id": "addition", "name": "A + B ⇌ C",
		"species": ["A", "B", "C"], "KcExpr": "[C]/([A][B])", "thermo": "exo",
	},
	"dimer": {
		"id": "dimer", "name": "2A ⇌ B",
		"species": ["A", "B"], "KcExpr": "[B]/[A]²", "thermo": "exo",
	},
	"haber": {
		"id": "haber", "name": "N₂ + 3H₂ ⇌ 2NH₃",
		"species": ["N2", "H2", "NH3"], "KcExpr": "[NH₃]²/([N₂][H₂]³)", "thermo": "exo",
		"labels": {"N2": "N₂", "H2": "H₂", "NH3": "NH₃"},
	},
}

var reaction: String = "isom"
var V: float = 1.0  # L
var Kc: float = 4.0
var initial: Dictionary = {"A": 1.0, "B": 0.0, "C": 0.0, "N2": 1.0, "H2": 3.0, "NH3": 0.0}
var T: float = 298.0

func rxn() -> Dictionary:
	return REACTIONS.get(reaction, REACTIONS["isom"])

func label_for(s: String) -> String:
	var r := rxn()
	if r.has("labels") and r["labels"].has(s):
		return str(r["labels"][s])
	return s

func reaction_Q(c: Dictionary) -> float:
	match reaction:
		"isom":
			return c.B / c.A if c.A > 1e-15 else (INF if c.B > 0.0 else 0.0)
		"addition":
			var d: float = c.A * c.B
			return c.C / d if d > 1e-15 else (INF if c.C > 0.0 else 0.0)
		"dimer":
			var a2: float = c.A * c.A
			return c.B / a2 if a2 > 1e-15 else (INF if c.B > 0.0 else 0.0)
		"haber":
			var den: float = c.N2 * pow(c.H2, 3.0)
			return (c.NH3 * c.NH3) / den if den > 1e-15 else (INF if c.NH3 > 0.0 else 0.0)
	return 0.0

func solve() -> Dictionary:
	var r := rxn()
	var vol := maxf(V, 1e-9)
	var K := maxf(Kc, 1e-12)
	var c0: Dictionary = {}
	for s in r["species"]:
		var n0: float = maxf(float(initial.get(s, 0.0)), 0.0)
		c0[s] = n0 / vol
	var result: Dictionary
	match reaction:
		"isom":
			result = _solve_isom(c0, K)
		"addition":
			result = _solve_addition(c0, K)
		"dimer":
			result = _solve_dimer(c0, K)
		_:
			result = _solve_haber(c0, K)
	if not result.get("ok", false):
		return {"ok": false, "message": result.get("message", "Failed"), "conc": c0, "initialConc": c0, "xi": 0.0, "Q": 0.0}
	var conc: Dictionary = result["conc"]
	return {
		"ok": true,
		"message": "Equilibrium solved.",
		"conc": conc,
		"initialConc": c0,
		"xi": result["xi"],
		"Q": reaction_Q(c0),
		"Kc": K,
		"V": vol,
		"rxn": r,
	}

func _solve_isom(c0: Dictionary, K: float) -> Dictionary:
	var x : float = (K * c0.A - c0.B) / (1.0 + K)
	x = clampf(x, -c0.B, c0.A)
	return {"ok": true, "xi": x, "conc": {"A": c0.A - x, "B": c0.B + x}}

func _solve_addition(c0: Dictionary, K: float) -> Dictionary:
	var a: float = K
	var b : float = -(K * (c0.A + c0.B) + 1.0)
	var c : float = K * c0.A * c0.B - c0.C
	var disc: float = maxf(0.0, b * b - 4.0 * a * c)
	var x1: float = (-b + sqrt(disc)) / (2.0 * a)
	var x2: float = (-b - sqrt(disc)) / (2.0 * a)
	var xmax: float = minf(float(c0.A), float(c0.B))
	var xmin : float = -c0.C
	var x: float = x1 if (x1 >= xmin - 1e-9 and x1 <= xmax + 1e-9) else x2
	x = clampf(x, xmin, xmax)
	return {"ok": true, "xi": x, "conc": {"A": c0.A - x, "B": c0.B - x, "C": c0.C + x}}

func _solve_dimer(c0: Dictionary, K: float) -> Dictionary:
	var a: float = 4.0 * K
	var b : float = -(4.0 * K * c0.A + 1.0)
	var c : float = K * c0.A * c0.A - c0.B
	var disc: float = maxf(0.0, b * b - 4.0 * a * c)
	var x1: float = (-b + sqrt(disc)) / (2.0 * a)
	var x2: float = (-b - sqrt(disc)) / (2.0 * a)
	var xmax: float = float(c0.A) / 2.0
	var xmin : float = -c0.B
	var x: float = x2 if (x2 >= xmin - 1e-9 and x2 <= xmax + 1e-9) else x1
	x = clampf(x, xmin, xmax)
	return {"ok": true, "xi": x, "conc": {"A": c0.A - 2.0 * x, "B": c0.B + x}}

func _solve_haber(c0: Dictionary, K: float) -> Dictionary:
	var xmax: float = minf(float(c0.N2), float(c0.H2) / 3.0)
	var xmin := float(-c0.NH3) / 2.0
	if xmax < xmin:
		return {"ok": false, "message": "Infeasible initials."}
	var f := func(x: float) -> float:
		var n2: float = c0.N2 - x
		var h2: float = c0.H2 - 3.0 * x
		var nh3: float = c0.NH3 + 2.0 * x
		if n2 <= 0.0 or h2 <= 0.0:
			return 1e15
		return (nh3 * nh3) / (n2 * pow(h2, 3.0)) - K
	var lo: float = xmin + 1e-12
	var hi: float = xmax - 1e-12
	if lo >= hi:
		var x0: float = (xmin + xmax) / 2.0
		return {"ok": true, "xi": x0, "conc": {
			"N2": maxf(0.0, c0.N2 - x0), "H2": maxf(0.0, c0.H2 - 3.0 * x0), "NH3": maxf(0.0, c0.NH3 + 2.0 * x0)
		}}
	var flo: float = f.call(lo)
	var fhi: float = f.call(hi)
	if flo * fhi > 0.0:
		var x_best: float = lo if absf(flo) < absf(fhi) else hi
		return {"ok": true, "xi": x_best, "conc": {
			"N2": maxf(0.0, c0.N2 - x_best), "H2": maxf(0.0, c0.H2 - 3.0 * x_best), "NH3": maxf(0.0, c0.NH3 + 2.0 * x_best)
		}}
	for i in range(60):
		var mid: float = 0.5 * (lo + hi)
		var fm: float = f.call(mid)
		if flo * fm <= 0.0:
			hi = mid
			fhi = fm
		else:
			lo = mid
			flo = fm
	var x: float = 0.5 * (lo + hi)
	return {"ok": true, "xi": x, "conc": {
		"N2": maxf(0.0, c0.N2 - x), "H2": maxf(0.0, c0.H2 - 3.0 * x), "NH3": maxf(0.0, c0.NH3 + 2.0 * x)
	}}

## Narrative Le Chatelier: adjust Kc with temperature direction.
func shift_temperature(delta_t: float) -> void:
	var r := rxn()
	var endo: bool = str(r.get("thermo", "exo")) == "endo"
	# endothermic: higher T → larger Kc; exothermic: higher T → smaller Kc
	var factor := 1.0 + absf(delta_t) / 200.0
	if (delta_t > 0.0 and endo) or (delta_t < 0.0 and not endo):
		Kc *= factor
	else:
		Kc /= factor
	Kc = clampf(Kc, 1e-6, 1e6)
	T = clampf(T + delta_t, 200.0, 800.0)
