extends RefCounted
class_name EcologyModel
## Two-species Lotka–Volterra competition (Gause / niche theory).
## dx/dt = r1 x (1 − (x + α12 y)/K1)
## dy/dt = r2 y (1 − (y + α21 x)/K2)
## Coexistence when each inhibits itself more than the other (α12 α21 < 1, with K balance).

const DT: float = 0.02
const HISTORY_MAX: int = 700
const CAP: float = 1e5

var r1: float = 1.0
var r2: float = 1.0
var k1: float = 80.0
var k2: float = 80.0
var a12: float = 0.6   # effect of species 2 on 1
var a21: float = 0.6   # effect of species 1 on 2

var x: float = 20.0  # species A
var y: float = 20.0  # species B
var t: float = 0.0

var hist_t: Array = []
var hist_x: Array = []
var hist_y: Array = []


func reset(x0: float = 20.0, y0: float = 20.0) -> void:
	x = x0
	y = y0
	t = 0.0
	hist_t.clear()
	hist_x.clear()
	hist_y.clear()
	_record()


func _record() -> void:
	hist_t.append(t)
	hist_x.append(x)
	hist_y.append(y)
	if hist_t.size() > HISTORY_MAX:
		hist_t.remove_at(0)
		hist_x.remove_at(0)
		hist_y.remove_at(0)


func _f(px: float, py: float) -> Vector2:
	var g1: float = 1.0 - (px + a12 * py) / maxf(k1, 1e-6)
	var g2: float = 1.0 - (py + a21 * px) / maxf(k2, 1e-6)
	return Vector2(r1 * px * g1, r2 * py * g2)


func step(dt: float = DT) -> void:
	var k1v := _f(x, y)
	var k2v := _f(x + 0.5 * dt * k1v.x, y + 0.5 * dt * k1v.y)
	var k3v := _f(x + 0.5 * dt * k2v.x, y + 0.5 * dt * k2v.y)
	var k4v := _f(x + dt * k3v.x, y + dt * k3v.y)
	x += dt / 6.0 * (k1v.x + 2.0 * k2v.x + 2.0 * k3v.x + k4v.x)
	y += dt / 6.0 * (k1v.y + 2.0 * k2v.y + 2.0 * k3v.y + k4v.y)
	x = clampf(x, 0.0, CAP)
	y = clampf(y, 0.0, CAP)
	t += dt
	_record()


func advance(years: float) -> void:
	var steps: int = int(ceil(years / DT))
	for i in range(steps):
		step(DT)


func equilibrium() -> Dictionary:
	## Analytic interior eq when denominators allow.
	var den: float = 1.0 - a12 * a21
	if absf(den) < 1e-9:
		return {"ok": false, "x": 0.0, "y": 0.0, "mode": "degenerate"}
	var xe: float = (k1 - a12 * k2) / den
	var ye: float = (k2 - a21 * k1) / den
	if xe > 0.0 and ye > 0.0:
		return {"ok": true, "x": xe, "y": ye, "mode": "coexistence"}
	# Boundary outcomes
	if xe <= 0.0 and ye > 0.0:
		return {"ok": true, "x": 0.0, "y": k2, "mode": "B wins"}
	if ye <= 0.0 and xe > 0.0:
		return {"ok": true, "x": k1, "y": 0.0, "mode": "A wins"}
	return {"ok": false, "x": 0.0, "y": 0.0, "mode": "unstable / both lose"}


func niche_overlap() -> float:
	## Simple proxy: geometric mean of competition coeffs (0 = no overlap, 1 = identical)
	return clampf(sqrt(maxf(a12, 0.0) * maxf(a21, 0.0)), 0.0, 2.0)


func status() -> String:
	var eq: Dictionary = equilibrium()
	var mode: String = str(eq.get("mode", "?"))
	if x < 0.5 and y < 0.5:
		return "Both populations near zero."
	if x < 0.5:
		return "Species A excluded — B dominates."
	if y < 0.5:
		return "Species B excluded — A dominates."
	if mode == "coexistence":
		return "Coexistence expected (stable interior equilibrium)."
	return "Competition in progress · predicted: %s" % mode


func apply_preset(id: String) -> void:
	match id:
		"coexist":
			r1 = 1.0; r2 = 1.0
			k1 = 90.0; k2 = 90.0
			a12 = 0.4; a21 = 0.4
			reset(25.0, 25.0)
		"exclusion_a":
			r1 = 1.2; r2 = 1.0
			k1 = 100.0; k2 = 70.0
			a12 = 0.3; a21 = 1.1
			reset(20.0, 30.0)
		"exclusion_b":
			r1 = 1.0; r2 = 1.2
			k1 = 70.0; k2 = 100.0
			a12 = 1.1; a21 = 0.3
			reset(30.0, 20.0)
		"identical":
			r1 = 1.0; r2 = 1.0
			k1 = 80.0; k2 = 80.0
			a12 = 1.0; a21 = 1.0
			reset(50.0, 20.0)
		"asymmetric":
			r1 = 0.8; r2 = 1.1
			k1 = 100.0; k2 = 60.0
			a12 = 0.7; a21 = 0.5
			reset(15.0, 15.0)
		_:
			r1 = 1.0; r2 = 1.0
			k1 = 80.0; k2 = 80.0
			a12 = 0.6; a21 = 0.6
			reset(20.0, 20.0)
