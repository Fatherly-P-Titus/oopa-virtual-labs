extends RefCounted
class_name TitrationModel
## Acid–base titration, 1:1 at 25 °C. pH from charge balance.

const KW: float = 1e-14
const VMAX: float = 50.0  # mL burette

const SCENARIOS := {
	"sa_sb": {
		"analyte": "HCl", "titrant": "NaOH", "acid_analyte": true, "weak": false,
		"desc": "Strong acid (flask) + strong base (burette). Equivalence at pH 7.",
	},
	"wa_sb": {
		"analyte": "Ethanoic acid", "titrant": "NaOH", "acid_analyte": true, "weak": true, "K": 1.8e-5,
		"desc": "Weak acid (Ka = 1.8×10⁻⁵) + strong base. Equivalence above pH 7.",
	},
	"sb_sa": {
		"analyte": "NaOH", "titrant": "HCl", "acid_analyte": false, "weak": false,
		"desc": "Strong base (flask) + strong acid (burette). pH falls as acid is added.",
	},
	"wb_sa": {
		"analyte": "Ammonia", "titrant": "HCl", "acid_analyte": false, "weak": true, "K": 1.8e-5,
		"desc": "Weak base (Kb = 1.8×10⁻⁵) + strong acid. Equivalence below pH 7.",
	},
}

const INDICATORS := {
	"none": {"name": "No indicator", "pK": -1.0},
	"methylorange": {"name": "Methyl orange", "pK": 3.7, "lo": 3.1, "hi": 4.4,
		"acid": Color(0.88, 0.24, 0.19), "base": Color(0.96, 0.84, 0.26)},
	"methylred": {"name": "Methyl red", "pK": 5.1, "lo": 4.4, "hi": 6.2,
		"acid": Color(0.90, 0.20, 0.25), "base": Color(0.95, 0.90, 0.30)},
	"bromothymol": {"name": "Bromothymol blue", "pK": 7.0, "lo": 6.0, "hi": 7.6,
		"acid": Color(0.90, 0.75, 0.20), "base": Color(0.20, 0.45, 0.85)},
	"phenolphthalein": {"name": "Phenolphthalein", "pK": 9.4, "lo": 8.2, "hi": 10.0,
		"acid": Color(0.95, 0.95, 0.97), "base": Color(0.95, 0.35, 0.65)},
}

var scenario: String = "sa_sb"
var ca: float = 0.100  # M flask
var cb: float = 0.100  # M burette
var va: float = 25.0   # mL flask
var vb: float = 0.0    # mL titrant added
var indicator: String = "phenolphthalein"
var points: Array = []  # {v, pH}

func scen() -> Dictionary:
	return SCENARIOS.get(scenario, SCENARIOS["sa_sb"])

func veq() -> float:
	return ca * va / maxf(cb, 1e-12)

func ph_at(vb_ml: float) -> float:
	var sc := scen()
	var vt := va + vb_ml
	var A := ca * va / maxf(vt, 1e-12)
	var Bc := cb * vb_ml / maxf(vt, 1e-12)
	if not bool(sc.get("weak", false)):
		var E: float = (A - Bc) if bool(sc.get("acid_analyte", true)) else (Bc - A)
		var s := sqrt(E * E + 4.0 * KW)
		var h: float = (E + s) / 2.0 if E >= 0.0 else (2.0 * KW) / (s - E)
		return -log(maxf(h, 1e-15)) / log(10.0)
	var K: float = float(sc.get("K", 1.8e-5))
	var lo := -1.0
	var hi := 15.0
	for i in range(70):
		var mid := (lo + hi) / 2.0
		var h2 := pow(10.0, -mid)
		var f: float
		if bool(sc.get("acid_analyte", true)):
			f = h2 + Bc - KW / h2 - A * K / (h2 + K)
		else:
			var Kac := KW / K
			f = h2 + A * h2 / (h2 + Kac) - KW / h2 - Bc
		if f > 0.0:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0

func current_ph() -> float:
	return ph_at(vb)

func endpoint_volume(pK: float) -> float:
	var lo := 0.0
	var hi := 2.0 * veq()
	var glo := ph_at(lo) - pK
	var ghi := ph_at(hi) - pK
	if glo * ghi > 0.0:
		return -1.0
	for i in range(60):
		var mid := (lo + hi) / 2.0
		var gm := ph_at(mid) - pK
		if (gm > 0.0) == (glo > 0.0):
			lo = mid
			glo = gm
		else:
			hi = mid
	return (lo + hi) / 2.0

func indicator_frac(pH: float) -> float:
	var ind: Dictionary = INDICATORS.get(indicator, INDICATORS["none"])
	var pK: float = float(ind.get("pK", -1.0))
	if pK < 0.0:
		return 0.0
	return 1.0 / (1.0 + pow(10.0, pK - pH))

func flask_color(pH: float) -> Color:
	var ind: Dictionary = INDICATORS.get(indicator, INDICATORS["none"])
	if float(ind.get("pK", -1.0)) < 0.0:
		return Color(0.88, 0.92, 0.96)
	var a := indicator_frac(pH)
	var ca_col: Color = ind["acid"]
	var cb_col: Color = ind["base"]
	return ca_col.lerp(cb_col, a)

func add_volume(dv: float) -> void:
	vb = clampf(vb + dv, 0.0, VMAX)
	record_point()

func record_point() -> void:
	if points.size() > 0:
		var last: Dictionary = points[-1]
		if absf(float(last.v) - vb) < 1e-9:
			return
	points.append({"v": vb, "pH": current_ph()})

func undo() -> void:
	if points.size() <= 1:
		vb = 0.0
		points.clear()
		record_point()
		return
	points.pop_back()
	vb = float(points[-1].v)

func restart() -> void:
	vb = 0.0
	points.clear()
	record_point()

func theoretical_curve(n: int = 120) -> Array:
	var vmax := minf(VMAX, maxf(veq() * 2.0, 10.0))
	var out: Array = []
	for i in range(n + 1):
		var v := vmax * float(i) / float(n)
		out.append({"v": v, "pH": ph_at(v)})
	return out

func region() -> String:
	var vq := veq()
	if absf(vb - vq) <= 0.05:
		return "At equivalence"
	if vb < vq:
		return "Before equivalence"
	return "After equivalence"
