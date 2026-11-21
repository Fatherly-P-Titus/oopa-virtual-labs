extends RefCounted
class_name SimpleMachinesModel
## Lever, incline, pulley, wheel-and-axle — ideal MA + efficiency / friction.

enum Kind { LEVER, INCLINE, PULLEY, WHEEL_AXLE }

var kind: int = Kind.LEVER

# Shared
var load_w: float = 100.0  # N
var eta: float = 1.0       # efficiency 0–1

# Lever
var d_load: float = 0.4    # m load arm
var d_effort: float = 1.2  # m effort arm
var lever_class: int = 1   # 1, 2, or 3

# Incline
var angle_deg: float = 30.0
var mu: float = 0.0        # friction coeff

# Pulley
var strands: int = 2

# Wheel & axle
var R_wheel: float = 0.25  # m
var r_axle: float = 0.05   # m


func set_kind(k: int) -> void:
	kind = k


func apply_preset(id: String) -> void:
	match id:
		"crowbar":
			kind = Kind.LEVER
			lever_class = 1
			load_w = 400.0
			d_load = 0.15
			d_effort = 0.90
			eta = 0.95
		"wheelbarrow":
			kind = Kind.LEVER
			lever_class = 2
			load_w = 250.0
			d_load = 0.35
			d_effort = 0.85
			eta = 0.9
		"ramp":
			kind = Kind.INCLINE
			load_w = 200.0
			angle_deg = 20.0
			mu = 0.15
			eta = 1.0
		"block_tackle":
			kind = Kind.PULLEY
			load_w = 500.0
			strands = 4
			eta = 0.85
		"well_wheel":
			kind = Kind.WHEEL_AXLE
			load_w = 150.0
			R_wheel = 0.30
			r_axle = 0.04
			eta = 0.9
		_:
			kind = Kind.LEVER
			lever_class = 1
			load_w = 100.0
			d_load = 0.4
			d_effort = 1.2
			eta = 1.0


func solve() -> Dictionary:
	match kind:
		Kind.LEVER:
			return lever(load_w, d_load, d_effort, eta, lever_class)
		Kind.INCLINE:
			return incline(load_w, angle_deg, mu, eta)
		Kind.PULLEY:
			return pulley(load_w, strands, eta)
		Kind.WHEEL_AXLE:
			return wheel_axle(load_w, R_wheel, r_axle, eta)
	return {}


static func lever(load_w: float, d_l: float, d_e: float, eta: float = 1.0, klass: int = 1) -> Dictionary:
	d_l = maxf(d_l, 1e-6)
	d_e = maxf(d_e, 1e-6)
	eta = clampf(eta, 0.05, 1.0)
	var ma_ideal := d_e / d_l
	var ma_actual := ma_ideal * eta
	return {
		"type": "lever", "class": klass,
		"loadW": load_w, "dL": d_l, "dE": d_e, "eta": eta,
		"maIdeal": ma_ideal, "maActual": ma_actual,
		"effortIdeal": load_w / ma_ideal,
		"effortActual": load_w / ma_actual,
	}


static func incline(load_w: float, angle_deg: float, mu: float = 0.0, eta: float = 1.0) -> Dictionary:
	var th := deg_to_rad(clampf(angle_deg, 1.0, 80.0))
	mu = maxf(mu, 0.0)
	eta = clampf(eta, 0.05, 1.0)
	var ma_ideal := 1.0 / sin(th)
	var effort_ideal := load_w * sin(th)
	var effort_friction := load_w * (sin(th) + mu * cos(th))
	var effort_actual := effort_friction if mu > 0.0 else effort_ideal / eta
	var ma_actual := load_w / maxf(effort_actual, 1e-9)
	return {
		"type": "incline",
		"loadW": load_w, "angleDeg": angle_deg, "mu": mu, "eta": eta,
		"maIdeal": ma_ideal, "maActual": ma_actual,
		"effortIdeal": effort_ideal, "effortActual": effort_actual,
		"lengthFactor": 1.0 / sin(th),
	}


static func pulley(load_w: float, strands: int, eta: float = 1.0) -> Dictionary:
	var n := maxi(1, strands)
	eta = clampf(eta, 0.05, 1.0)
	var ma_ideal := float(n)
	var ma_actual := float(n) * eta
	return {
		"type": "pulley",
		"loadW": load_w, "strands": n, "eta": eta,
		"maIdeal": ma_ideal, "maActual": ma_actual,
		"effortIdeal": load_w / ma_ideal,
		"effortActual": load_w / ma_actual,
	}


static func wheel_axle(load_w: float, R: float, r: float, eta: float = 1.0) -> Dictionary:
	R = maxf(R, 1e-6)
	r = maxf(r, 1e-6)
	eta = clampf(eta, 0.05, 1.0)
	var ma_ideal := R / r
	var ma_actual := ma_ideal * eta
	return {
		"type": "wheelAxle",
		"loadW": load_w, "R": R, "r": r, "eta": eta,
		"maIdeal": ma_ideal, "maActual": ma_actual,
		"effortIdeal": load_w / ma_ideal,
		"effortActual": load_w / ma_actual,
	}
