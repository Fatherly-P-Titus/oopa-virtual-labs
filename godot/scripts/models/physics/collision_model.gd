extends RefCounted
class_name CollisionModel
## 1D or 2D two-body collisions with coefficient of restitution e.
## Elastic e=1, inelastic e<1, perfectly inelastic e=0.

enum Dim { D1, D2 }

var dim: int = Dim.D1
var e: float = 1.0  # restitution 0..1
var m1: float = 2.0
var m2: float = 1.0

# Positions / velocities (2D vectors; in 1D use x only, y=0)
var x1: float = 80.0
var y1: float = 150.0
var x2: float = 220.0
var y2: float = 150.0
var vx1: float = 40.0
var vy1: float = 0.0
var vx2: float = -10.0
var vy2: float = 0.0

var r1: float = 18.0
var r2: float = 14.0

var t: float = 0.0
var collided: bool = false
var collision_count: int = 0
var box_w: float = 400.0
var box_h: float = 300.0

# Initial snapshot for reset
var _ix1: float = 80.0
var _iy1: float = 150.0
var _ix2: float = 220.0
var _iy2: float = 150.0
var _ivx1: float = 40.0
var _ivy1: float = 0.0
var _ivx2: float = -10.0
var _ivy2: float = 0.0

const DT: float = 1.0 / 120.0


func snapshot_initials() -> void:
	_ix1 = x1
	_iy1 = y1
	_ix2 = x2
	_iy2 = y2
	_ivx1 = vx1
	_ivy1 = vy1
	_ivx2 = vx2
	_ivy2 = vy2


func reset() -> void:
	x1 = _ix1
	y1 = _iy1
	x2 = _ix2
	y2 = _iy2
	vx1 = _ivx1
	vy1 = _ivy1
	vx2 = _ivx2
	vy2 = _ivy2
	t = 0.0
	collided = false
	collision_count = 0
	if dim == Dim.D1:
		y1 = box_h * 0.5
		y2 = box_h * 0.5
		vy1 = 0.0
		vy2 = 0.0
		_ivy1 = 0.0
		_ivy2 = 0.0


func ke() -> float:
	return 0.5 * m1 * (vx1 * vx1 + vy1 * vy1) + 0.5 * m2 * (vx2 * vx2 + vy2 * vy2)


func momentum() -> Vector2:
	return Vector2(m1 * vx1 + m2 * vx2, m1 * vy1 + m2 * vy2)


func step(dt: float = DT) -> void:
	x1 += vx1 * dt
	y1 += vy1 * dt
	x2 += vx2 * dt
	y2 += vy2 * dt
	if dim == Dim.D1:
		y1 = box_h * 0.5
		y2 = box_h * 0.5
		vy1 = 0.0
		vy2 = 0.0
	_walls(1)
	_walls(2)
	_pair_collision()
	t += dt


func _walls(which: int) -> void:
	var r: float = r1 if which == 1 else r2
	var x: float = x1 if which == 1 else x2
	var y: float = y1 if which == 1 else y2
	var vx: float = vx1 if which == 1 else vx2
	var vy: float = vy1 if which == 1 else vy2
	var hit: bool = false
	if x < r:
		x = r
		vx = absf(vx) * e
		hit = true
	elif x > box_w - r:
		x = box_w - r
		vx = -absf(vx) * e
		hit = true
	if dim == Dim.D2:
		if y < r:
			y = r
			vy = absf(vy) * e
			hit = true
		elif y > box_h - r:
			y = box_h - r
			vy = -absf(vy) * e
			hit = true
	if which == 1:
		x1 = x
		y1 = y
		vx1 = vx
		vy1 = vy
	else:
		x2 = x
		y2 = y
		vx2 = vx
		vy2 = vy
	if hit:
		collision_count += 1


func _pair_collision() -> void:
	var dx: float = x2 - x1
	var dy: float = 0.0 if dim == Dim.D1 else (y2 - y1)
	var dist2: float = dx * dx + dy * dy
	var min_d: float = r1 + r2
	if dist2 >= min_d * min_d or dist2 < 1e-10:
		return
	var dist: float = sqrt(dist2)
	var nx: float = dx / dist
	var ny: float = dy / dist
	# Relative velocity along normal
	var dvx: float = vx1 - vx2
	var dvy: float = vy1 - vy2
	var vn: float = dvx * nx + dvy * ny
	if vn <= 0.0:
		return  # separating
	# Impulse for unequal mass + restitution e
	var inv_m: float = 1.0 / maxf(m1, 1e-9) + 1.0 / maxf(m2, 1e-9)
	var j: float = -(1.0 + e) * vn / inv_m
	var jx: float = j * nx
	var jy: float = j * ny
	vx1 += jx / m1
	vy1 += jy / m1
	vx2 -= jx / m2
	vy2 -= jy / m2
	# Separate overlap
	var overlap: float = min_d - dist
	var f1: float = m2 / (m1 + m2)
	var f2: float = m1 / (m1 + m2)
	x1 -= nx * overlap * f1
	y1 -= ny * overlap * f1
	x2 += nx * overlap * f2
	y2 += ny * overlap * f2
	if dim == Dim.D1:
		y1 = box_h * 0.5
		y2 = box_h * 0.5
		vy1 = 0.0
		vy2 = 0.0
	collided = true
	collision_count += 1


func advance(seconds: float) -> void:
	var n: int = int(ceil(seconds / DT))
	for i in range(n):
		step(DT)


func setup_1d_defaults() -> void:
	dim = Dim.D1
	m1 = 2.0
	m2 = 1.0
	r1 = 20.0
	r2 = 14.0
	x1 = 60.0
	x2 = 280.0
	y1 = box_h * 0.5
	y2 = box_h * 0.5
	vx1 = 50.0
	vx2 = -20.0
	vy1 = 0.0
	vy2 = 0.0
	e = 1.0
	snapshot_initials()
	reset()


func setup_2d_defaults() -> void:
	dim = Dim.D2
	m1 = 2.0
	m2 = 1.5
	r1 = 18.0
	r2 = 16.0
	x1 = 100.0
	y1 = 80.0
	x2 = 280.0
	y2 = 200.0
	vx1 = 35.0
	vy1 = 25.0
	vx2 = -20.0
	vy2 = -15.0
	e = 1.0
	snapshot_initials()
	reset()
