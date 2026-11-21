extends RefCounted
class_name GasLawsModel
## Ideal gas PV = nRT — web-parity model (kPa, L, K, mol).
## R = 8.314 J/(mol·K); kPa·L = J so units agree.
## Particles are illustration only; pressure is always from the law.

const R: float = 8.314
const V_MIN: float = 2.0
const V_MAX: float = 30.0
const T_MIN: float = 100.0
const T_MAX: float = 800.0
const N_MIN: float = 0.1
const N_MAX: float = 3.0
const MAX_ROWS: int = 12
const PER_MOL: int = 40

enum Law { FREE, BOYLE, CHARLES, GAY_LUSSAC, AVOGADRO }

var law: Law = Law.BOYLE
var n: float = 1.0
var t: float = 300.0
var v: float = 10.0
var p: float = 0.0

## Baseline captured when law is chosen (held constants).
var base_n: float = 1.0
var base_t: float = 300.0
var base_v: float = 10.0
var base_p: float = 0.0

var status_msg: String = ""
var data: Array = []  ## Array of {v, p, t, n}

func _init() -> void:
	recompute()
	snapshot()

func recompute() -> void:
	v = clampf(v, V_MIN, V_MAX)
	t = clampf(t, T_MIN, T_MAX)
	n = clampf(n, N_MIN, N_MAX)
	p = R * n * t / maxf(v, 0.001)

func snapshot() -> void:
	base_n = n
	base_t = t
	base_v = v
	base_p = p

func set_law(new_law: Law) -> void:
	law = new_law
	snapshot()
	data.clear()
	status_msg = ""

func reset_defaults() -> void:
	n = 1.0
	t = 300.0
	v = 10.0
	recompute()
	snapshot()
	data.clear()
	status_msg = ""

## Apply a control change for the active law.
func set_control(key: String, val: float) -> void:
	status_msg = ""
	match law:
		Law.FREE:
			match key:
				"V": v = val
				"T": t = val
				"n": n = val
		Law.BOYLE:
			if key == "V":
				v = val
		Law.GAY_LUSSAC:
			if key == "T":
				t = val
		Law.CHARLES:
			if key == "T":
				# constant P,n: V = nRT / P_base
				var nv := n * R * val / maxf(base_p, 0.001)
				if nv < V_MIN:
					nv = V_MIN
					val = nv * base_p / (n * R)
					status_msg = "The piston is at its lowest position."
				elif nv > V_MAX:
					nv = V_MAX
					val = nv * base_p / (n * R)
					status_msg = "The piston is at its highest position."
				t = val
				v = nv
		Law.AVOGADRO:
			if key == "n":
				var nv2 := val * R * t / maxf(base_p, 0.001)
				if nv2 < V_MIN:
					nv2 = V_MIN
					val = nv2 * base_p / (R * t)
					status_msg = "The piston is at its lowest position."
				elif nv2 > V_MAX:
					nv2 = V_MAX
					val = nv2 * base_p / (R * t)
					status_msg = "The piston is at its highest position."
				n = val
				v = nv2
	recompute()

func is_free(key: String) -> bool:
	match law:
		Law.FREE:
			return key in ["V", "T", "n"]
		Law.BOYLE:
			return key == "V"
		Law.CHARLES, Law.GAY_LUSSAC:
			return key == "T"
		Law.AVOGADRO:
			return key == "n"
	return false

func is_dependent(key: String) -> bool:
	match law:
		Law.CHARLES, Law.AVOGADRO:
			return key == "V"
	return false

func law_id() -> String:
	match law:
		Law.FREE: return "free"
		Law.BOYLE: return "boyle"
		Law.CHARLES: return "charles"
		Law.GAY_LUSSAC: return "gaylussac"
		Law.AVOGADRO: return "avogadro"
	return "free"

func law_title() -> String:
	match law:
		Law.FREE: return "Free play"
		Law.BOYLE: return "Boyle’s law"
		Law.CHARLES: return "Charles’s law"
		Law.GAY_LUSSAC: return "Gay-Lussac’s law"
		Law.AVOGADRO: return "Avogadro’s law"
	return ""

func law_desc() -> String:
	match law:
		Law.FREE:
			return "Change volume, temperature and amount together. Pressure always follows PV = nRT."
		Law.BOYLE:
			return "At constant T and n, pressure is inversely proportional to volume. Move the piston — P × V stays the same."
		Law.CHARLES:
			return "At constant P and n, volume is proportional to temperature (K). Heat the gas and the piston rises. V ÷ T stays the same."
		Law.GAY_LUSSAC:
			return "At constant V and n, pressure is proportional to temperature (K). Piston locked — P ÷ T stays the same."
		Law.AVOGADRO:
			return "At constant P and T, volume is proportional to amount of gas. Add gas and the piston rises. V ÷ n stays the same."
	return ""

func hold_note() -> String:
	match law:
		Law.FREE: return "Nothing is held constant"
		Law.BOYLE: return "Held constant: temperature, amount of gas"
		Law.CHARLES: return "Held constant: pressure, amount of gas"
		Law.GAY_LUSSAC: return "Held constant: volume, amount of gas"
		Law.AVOGADRO: return "Held constant: pressure, temperature"
	return ""

func const_label() -> String:
	match law:
		Law.FREE: return "P × V ÷ (n × T)"
		Law.BOYLE: return "P × V"
		Law.CHARLES: return "V ÷ T"
		Law.GAY_LUSSAC: return "P ÷ T"
		Law.AVOGADRO: return "V ÷ n"
	return ""

func const_unit() -> String:
	match law:
		Law.FREE: return "J/(mol·K)"
		Law.BOYLE: return "kPa·L"
		Law.CHARLES: return "L/K"
		Law.GAY_LUSSAC: return "kPa/K"
		Law.AVOGADRO: return "L/mol"
	return ""

func law_constant(row: Dictionary = {}) -> float:
	var vv: float = float(row.get("v", v))
	var pp: float = float(row.get("p", p))
	var tt: float = float(row.get("t", t))
	var nn: float = float(row.get("n", n))
	match law:
		Law.FREE:
			return pp * vv / maxf(nn * tt, 0.001)
		Law.BOYLE:
			return pp * vv
		Law.CHARLES:
			return vv / maxf(tt, 0.001)
		Law.GAY_LUSSAC:
			return pp / maxf(tt, 0.001)
		Law.AVOGADRO:
			return vv / maxf(nn, 0.001)
	return 0.0

func graph_axes() -> Dictionary:
	## Returns {x_key, y_key, x_label, y_label}
	match law:
		Law.FREE, Law.BOYLE:
			return {"x": "v", "y": "p", "xl": "Volume (L)", "yl": "Pressure (kPa)"}
		Law.CHARLES:
			return {"x": "t", "y": "v", "xl": "Temperature (K)", "yl": "Volume (L)"}
		Law.GAY_LUSSAC:
			return {"x": "t", "y": "p", "xl": "Temperature (K)", "yl": "Pressure (kPa)"}
		Law.AVOGADRO:
			return {"x": "n", "y": "v", "xl": "Amount (mol)", "yl": "Volume (L)"}
	return {"x": "v", "y": "p", "xl": "V", "yl": "P"}

func record_point() -> void:
	if data.size() >= MAX_ROWS:
		data.pop_front()
	data.append({"v": v, "p": p, "t": t, "n": n})

func particle_count() -> int:
	return maxi(4, int(round(n * float(PER_MOL))))

func p_atm() -> float:
	return p / 101.325

func summary() -> Dictionary:
	return {
		"v": v, "p": p, "t": t, "n": n,
		"p_atm": p_atm(),
		"const": law_constant(),
		"law": law_id(),
	}
