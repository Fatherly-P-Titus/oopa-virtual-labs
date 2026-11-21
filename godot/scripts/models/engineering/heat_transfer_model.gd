extends RefCounted
class_name HeatTransferModel
## Steady 1D multilayer wall: conduction through layers + optional surface convection.
## q = (T_hot - T_cold) / R_total   [W/m²]
## R_layer = L / k ,  R_conv = 1 / h

const MATERIALS := {
	"brick": {"name": "Brick", "k": 0.7, "color": Color("#c62828")},
	"concrete": {"name": "Concrete", "k": 1.4, "color": Color("#8d6e63")},
	"wood": {"name": "Wood", "k": 0.15, "color": Color("#6d4c41")},
	"glass": {"name": "Glass", "k": 1.0, "color": Color("#90caf9")},
	"insulation": {"name": "Insulation", "k": 0.04, "color": Color("#fff9c4")},
	"steel": {"name": "Steel", "k": 40.0, "color": Color("#90a4ae")},
	"aluminium": {"name": "Aluminium", "k": 200.0, "color": Color("#b0bec5")},
}

const MAT_KEYS: Array = ["brick", "concrete", "wood", "glass", "insulation", "steel", "aluminium"]

var t_hot: float = 20.0   # indoor / hot side °C
var t_cold: float = -5.0  # outdoor / cold side °C
var h_hot: float = 10.0   # W/m²K indoor film
var h_cold: float = 25.0  # outdoor film (higher wind)
var use_conv: bool = true

## layers: Array of {material: String, L: float metres}
var layers: Array = [
	{"material": "brick", "L": 0.10},
	{"material": "insulation", "L": 0.05},
	{"material": "wood", "L": 0.02},
]


func material_keys() -> Array:
	return MAT_KEYS.duplicate()


func set_layer_count(n: int) -> void:
	n = clampi(n, 1, 4)
	while layers.size() < n:
		layers.append({"material": "insulation", "L": 0.05})
	while layers.size() > n:
		layers.pop_back()


func set_layer_material(i: int, key: String) -> void:
	if i < 0 or i >= layers.size():
		return
	if not MATERIALS.has(key):
		key = "brick"
	layers[i]["material"] = key


func set_layer_thickness(i: int, L_m: float) -> void:
	if i < 0 or i >= layers.size():
		return
	layers[i]["L"] = clampf(L_m, 0.005, 0.50)


func apply_preset(id: String) -> void:
	match id:
		"winter_wall":
			use_conv = true
			t_hot = 21.0
			t_cold = -10.0
			h_hot = 8.0
			h_cold = 30.0
			layers = [
				{"material": "brick", "L": 0.12},
				{"material": "insulation", "L": 0.08},
				{"material": "wood", "L": 0.015},
			]
		"bare_brick":
			use_conv = true
			t_hot = 21.0
			t_cold = -10.0
			h_hot = 8.0
			h_cold = 30.0
			layers = [{"material": "brick", "L": 0.12}]
		"metal_sheet":
			use_conv = true
			t_hot = 40.0
			t_cold = 20.0
			h_hot = 12.0
			h_cold = 20.0
			layers = [{"material": "steel", "L": 0.005}]
		"double_glaze":
			use_conv = true
			t_hot = 20.0
			t_cold = 0.0
			h_hot = 10.0
			h_cold = 25.0
			layers = [
				{"material": "glass", "L": 0.004},
				{"material": "insulation", "L": 0.012},  # air gap approx low-k
				{"material": "glass", "L": 0.004},
			]
		"roof_summer":
			use_conv = true
			t_hot = 55.0  # sun-heated outer as "hot"
			t_cold = 24.0
			h_hot = 15.0
			h_cold = 8.0
			layers = [
				{"material": "steel", "L": 0.001},
				{"material": "insulation", "L": 0.10},
				{"material": "wood", "L": 0.02},
			]
		_:
			use_conv = true
			t_hot = 20.0
			t_cold = -5.0
			h_hot = 10.0
			h_cold = 25.0
			layers = [
				{"material": "brick", "L": 0.10},
				{"material": "insulation", "L": 0.05},
				{"material": "wood", "L": 0.02},
			]


func solve() -> Dictionary:
	var R: Array = []
	var labels: Array = []
	var segments: Array = []  # for drawing: each thermal resistance segment

	if use_conv and h_hot > 0.0:
		var Rh: float = 1.0 / h_hot
		R.append(Rh)
		labels.append("Film (hot)")
		segments.append({"type": "conv", "side": "hot", "R": Rh, "label": "h_hot"})

	var layer_info: Array = []
	for layer in layers:
		var key: String = str(layer.get("material", "brick"))
		var mat: Dictionary = MATERIALS.get(key, MATERIALS["brick"])
		var L: float = float(layer.get("L", 0.05))
		var k: float = maxf(float(mat["k"]), 1e-9)
		var Ri: float = L / k
		R.append(Ri)
		labels.append(str(mat["name"]))
		var info := {
			"material": key,
			"name": str(mat["name"]),
			"k": k,
			"L": L,
			"color": mat["color"],
			"R": Ri,
		}
		layer_info.append(info)
		segments.append({"type": "layer", "R": Ri, "label": str(mat["name"]), "info": info})

	if use_conv and h_cold > 0.0:
		var Rc: float = 1.0 / h_cold
		R.append(Rc)
		labels.append("Film (cold)")
		segments.append({"type": "conv", "side": "cold", "R": Rc, "label": "h_cold"})

	var r_tot := 0.0
	for ri in R:
		r_tot += float(ri)
	var dT := t_hot - t_cold
	var q := dT / maxf(r_tot, 1e-12)  # W/m²

	# Temperature at each interface (length = R.size()+1)
	var T: Array = [t_hot]
	var t := t_hot
	for ri in R:
		t = t - q * float(ri)
		T.append(t)

	# Positions 0..1 for profile (by resistance fraction = proportional drop)
	var x: Array = [0.0]
	var acc := 0.0
	for ri in R:
		acc += float(ri)
		x.append(acc / maxf(r_tot, 1e-12))

	return {
		"R": R,
		"labels": labels,
		"Rtot": r_tot,
		"q": q,
		"dT": dT,
		"T": T,
		"x": x,
		"layers": layer_info,
		"segments": segments,
		"t_hot": t_hot,
		"t_cold": t_cold,
	}
