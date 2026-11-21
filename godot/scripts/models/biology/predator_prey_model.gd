extends RefCounted
class_name PredatorPreyModel
## Lotka–Volterra with optional logistic prey limit.
## dx/dt = r x (1 − x/K) − a x y
## dy/dt = e x y − m y   (e = a·b conversion efficiency)
## K >= K_OFF means unlimited food (classic model).

const K_OFF: float = 500.0
const CAP: float = 1e6
const DT: float = 0.01  # years
const HISTORY_MAX: int = 800

var r: float = 0.5       # prey growth
var a: float = 0.01      # predation rate
var b: float = 0.5       # conversion efficiency
var m: float = 0.4       # predator death
var k_food: float = 500.0
var extinction: bool = false

var x: float = 40.0  # prey
var y: float = 20.0  # predators
var t: float = 0.0

var hist_t: Array = []
var hist_x: Array = []
var hist_y: Array = []


func reset(x0: float = 40.0, y0: float = 20.0) -> void:
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
	var cap := 1.0 if k_food >= K_OFF else (1.0 - px / maxf(k_food, 1e-6))
	var eat := a * px * py
	return Vector2(r * px * cap - eat, b * eat - m * py)


func step(dt: float = DT) -> void:
	if x > 0.0 or y > 0.0:
		var k1 := _f(x, y)
		var k2 := _f(x + 0.5 * dt * k1.x, y + 0.5 * dt * k1.y)
		var k3 := _f(x + 0.5 * dt * k2.x, y + 0.5 * dt * k2.y)
		var k4 := _f(x + dt * k3.x, y + dt * k3.y)
		x += dt / 6.0 * (k1.x + 2.0 * k2.x + 2.0 * k3.x + k4.x)
		y += dt / 6.0 * (k1.y + 2.0 * k2.y + 2.0 * k3.y + k4.y)
	x = maxf(x, 0.0)
	y = maxf(y, 0.0)
	if x > CAP:
		x = CAP
	if extinction:
		if x < 1.0:
			x = 0.0
		if y < 1.0:
			y = 0.0
	t += dt
	_record()


func advance(years: float) -> void:
	var steps := int(ceil(years / DT))
	for i in range(steps):
		step(DT)


func equilibrium() -> Variant:
	var xe := m / maxf(a * b, 1e-12)
	var ye: float
	if k_food >= K_OFF:
		ye = r / maxf(a, 1e-12)
	else:
		ye = r / maxf(a, 1e-12) * (1.0 - xe / k_food)
	if ye > 0.0 and xe > 0.0:
		return {"x": xe, "y": ye}
	return null


func status() -> String:
	if x <= 0.0 and y <= 0.0:
		return "Both species have died out."
	if y <= 0.0:
		if k_food >= K_OFF and x > 0.0:
			return "Predators gone. Prey grow without limit."
		return "Predators gone. Prey settle at the food limit."
	if x <= 0.0:
		return "Prey gone. Predators will starve."
	return "Both species are surviving."


func theoretical_period() -> float:
	if r <= 0.0 or m <= 0.0:
		return INF
	return TAU / sqrt(r * m)


func apply_preset(id: String) -> void:
	match id:
		"classic":
			r = 0.5; a = 0.01; b = 0.5; m = 0.4
			k_food = K_OFF; extinction = false
			reset(40.0, 20.0)
		"cycles":
			r = 1.0; a = 0.02; b = 0.5; m = 0.5
			k_food = K_OFF; extinction = false
			reset(30.0, 15.0)
		"limited":
			r = 0.8; a = 0.015; b = 0.45; m = 0.35
			k_food = 80.0; extinction = false
			reset(25.0, 12.0)
		"extinction":
			r = 0.4; a = 0.05; b = 0.3; m = 0.6
			k_food = 60.0; extinction = true
			reset(15.0, 25.0)
		_:
			r = 0.5; a = 0.01; b = 0.5; m = 0.4
			k_food = K_OFF; extinction = false
			reset(40.0, 20.0)
