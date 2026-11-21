extends RefCounted
class_name BuffersModel
## Weak acid (quadratic), buffer (Henderson–Hasselbalch + capacity), strong acid/base.

const ACIDS := {
	"acetic": {"name": "Acetic acid", "Ka": 1.8e-5, "formula": "CH₃COOH"},
	"formic": {"name": "Formic acid", "Ka": 1.8e-4, "formula": "HCOOH"},
	"benzoic": {"name": "Benzoic acid", "Ka": 6.3e-5, "formula": "C₆H₅COOH"},
	"hydrofluoric": {"name": "Hydrofluoric acid", "Ka": 6.8e-4, "formula": "HF"},
	"hypochlorous": {"name": "Hypochlorous acid", "Ka": 3.0e-8, "formula": "HClO"},
	"custom": {"name": "Custom", "Ka": 1.0e-5, "formula": "HA"},
}

enum Mode { WEAK, BUFFER, STRONG }

var mode: Mode = Mode.WEAK
var acid_key: String = "acetic"
var ka: float = 1.8e-5
var c_ha: float = 0.1  # analytical HA
var c_a: float = 0.1   # analytical A-
var c_strong: float = 0.1
var strong_is_acid: bool = true
var add_acid: float = 0.0  # mol/L strong acid added to buffer
var add_base: float = 0.0

func set_acid(key: String) -> void:
	acid_key = key
	if ACIDS.has(key) and key != "custom":
		ka = float(ACIDS[key]["Ka"])

func acid_name() -> String:
	if ACIDS.has(acid_key):
		return str(ACIDS[acid_key]["name"])
	return "Acetic acid"

func acid_formula() -> String:
	if ACIDS.has(acid_key):
		return str(ACIDS[acid_key]["formula"])
	return "HA"

func pKa() -> float:
	return -log(maxf(ka, 1e-20)) / log(10.0)

func weak_acid_h() -> float:
	# x² + Ka x - Ka F = 0
	var f := c_ha
	var x := (-ka + sqrt(ka * ka + 4.0 * ka * f)) / 2.0
	return maxf(x, 1e-12)

func buffer_h() -> Dictionary:
	var ha := c_ha + add_acid - add_base
	var a := c_a - add_acid + add_base
	if ha < 0.0 or a < 0.0:
		if ha < 0.0:
			var excess_oh := -ha
			var h := 1e-14 / maxf(excess_oh, 1e-15)
			return {"H": h, "HA": 0.0, "A": a + ha + excess_oh, "broken": true, "pH": -log(h) / log(10.0)}
		var excess_h := -a
		return {"H": excess_h, "HA": ha + a + excess_h, "A": 0.0, "broken": true, "pH": -log(maxf(excess_h, 1e-15)) / log(10.0)}
	if ha < 1e-12 and a < 1e-12:
		return {"H": 1e-7, "HA": 0.0, "A": 0.0, "broken": true, "pH": 7.0}
	var ratio := a / maxf(ha, 1e-15)
	var ph := pKa() + log(maxf(ratio, 1e-15)) / log(10.0)
	var h := pow(10.0, -ph)
	return {"H": h, "HA": ha, "A": a, "broken": false, "pH": ph}

func strong_h() -> float:
	if strong_is_acid:
		return maxf(c_strong, 1e-12)
	var oh := maxf(c_strong, 1e-12)
	return 1e-14 / oh

func solve() -> Dictionary:
	var h: float
	var ph: float
	var extra: Dictionary = {}
	match mode:
		Mode.WEAK:
			h = weak_acid_h()
			ph = -log(h) / log(10.0)
			extra = {
				"HA": maxf(0.0, c_ha - h),
				"A": h,
				"alpha": h / maxf(c_ha, 1e-15),
				"broken": false,
			}
		Mode.BUFFER:
			var b := buffer_h()
			h = float(b["H"])
			ph = float(b.get("pH", -log(h) / log(10.0)))
			extra = {
				"HA": float(b["HA"]),
				"A": float(b["A"]),
				"broken": bool(b["broken"]),
			}
		Mode.STRONG:
			h = strong_h()
			ph = -log(h) / log(10.0)
			extra = {"broken": false, "strong_acid": strong_is_acid}
	ph = clampf(ph, -1.0, 15.0)
	return {
		"H": h,
		"pH": ph,
		"pOH": 14.0 - ph,
		"pKa": pKa(),
		"Ka": ka,
		"mode": mode,
		"acid_name": acid_name(),
		"formula": acid_formula(),
		"extra": extra,
	}
