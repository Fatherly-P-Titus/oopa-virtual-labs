extends RefCounted
class_name ProjectileModel
## Projectile with gravity, optional quadratic drag + wind, bounce & roll.

const DT: float = 1.0 / 240.0
const REST_SPEED: float = 0.4  # m/s — below this, roll/stop

var v0: float = 25.0      # m/s
var angle_deg: float = 45.0
var h0: float = 0.0       # m
var g: float = 9.81
var c_drag: float = 0.0   # kg/m  (½ρCdA)
var wind: float = 0.0     # m/s  (+ = to the right)
var mass: float = 1.0     # kg
var e_bounce: float = 0.0 # coefficient of restitution
var mu: float = 0.3       # friction while rolling / impact

# state
var x: float = 0.0
var y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var t: float = 0.0
var max_y: float = 0.0
var resting: bool = false
var rolling: bool = false
var landings: Array = []  # {x, t}
var reason: String = ""

func ideal() -> Dictionary:
	var r := deg_to_rad(angle_deg)
	var ivx := v0 * cos(r)
	var ivy := v0 * sin(r)
	var disc := ivy * ivy + 2.0 * g * h0
	var T := (ivy + sqrt(maxf(0.0, disc))) / maxf(g, 1e-9)
	var R := ivx * T
	var H := h0 + (ivy * ivy / (2.0 * g) if ivy > 0.0 else 0.0)
	return {"vx": ivx, "vy": ivy, "T": T, "R": R, "H": H}

func reset() -> void:
	var id := ideal()
	x = 0.0
	y = h0
	vx = id.vx
	vy = id.vy
	t = 0.0
	max_y = h0
	resting = false
	rolling = false
	landings.clear()
	reason = ""
	if h0 <= 0.0 and id.vy <= 1e-9:
		resting = true
		rolling = true

func _accel(pvx: float, pvy: float) -> Vector2:
	if rolling or resting:
		return Vector2(-signf(pvx) * mu * g if absf(pvx) > 1e-6 else 0.0, 0.0)
	var rx := pvx - wind
	var k := (c_drag / maxf(mass, 1e-6)) * sqrt(rx * rx + pvy * pvy)
	return Vector2(-k * rx, -g - k * pvy)

func step(dt: float = DT) -> void:
	if resting:
		return
	if rolling:
		# decelerate on ground
		var ax := -signf(vx) * mu * g if absf(vx) > 1e-6 else 0.0
		vx += ax * dt
		if absf(vx) < REST_SPEED * 0.25 or signf(vx) != signf(vx - ax * dt) and absf(vx) < REST_SPEED:
			vx = 0.0
			resting = true
			reason = "rest"
		x += vx * dt
		y = 0.0
		t += dt
		return

	# RK4
	var a1 := _accel(vx, vy)
	var a2 := _accel(vx + 0.5 * dt * a1.x, vy + 0.5 * dt * a1.y)
	var a3 := _accel(vx + 0.5 * dt * a2.x, vy + 0.5 * dt * a2.y)
	var a4 := _accel(vx + dt * a3.x, vy + dt * a3.y)
	var nx := x + dt * vx + dt * dt / 6.0 * (a1.x + a2.x + a3.x)
	var ny := y + dt * vy + dt * dt / 6.0 * (a1.y + a2.y + a3.y)
	var nvx := vx + dt / 6.0 * (a1.x + 2.0 * a2.x + 2.0 * a3.x + a4.x)
	var nvy := vy + dt / 6.0 * (a1.y + 2.0 * a2.y + 2.0 * a3.y + a4.y)

	# ground impact interpolation
	if ny < 0.0 and y >= 0.0:
		var frac := y / maxf(y - ny, 1e-12)
		frac = clampf(frac, 0.0, 1.0)
		x = x + (nx - x) * frac
		y = 0.0
		vx = nvx
		vy = nvy
		t += dt * frac
		landings.append({"x": x, "t": t})
		vy = -e_bounce * vy
		vx = (1.0 - mu) * vx
		if absf(vy) < REST_SPEED:
			rolling = true
			vy = 0.0
			if absf(vx) < REST_SPEED:
				vx = 0.0
				resting = true
				reason = "rest"
		return

	x = nx
	y = maxf(ny, 0.0)
	vx = nvx
	vy = nvy
	t += dt
	max_y = maxf(max_y, y)
	if t > 180.0:
		resting = true
		reason = "limit"

func advance(seconds: float) -> void:
	var n := int(ceil(seconds / DT))
	for i in range(n):
		if resting:
			break
		step(DT)

func speed() -> float:
	return sqrt(vx * vx + vy * vy)

func ke() -> float:
	return 0.5 * mass * (vx * vx + vy * vy)

func pe() -> float:
	return mass * g * y
