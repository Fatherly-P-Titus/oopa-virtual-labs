extends RefCounted
class_name ParticleModel
## Kinetic-molecular particle box: many hard spheres, walls + optional pairwise collisions.
## Temperature scales speeds; gravity + elasticity control ideal vs dissipative behaviour.

const BOX: float = 300.0  # world units (= px on stage)
const T_REF: float = 40.0  # °C reference for speed scale
const K_SPEED: float = 2.2  # px/frame-scale at T_REF for typical particle

var count: int = 20
var radius: float = 6.0  # px, 2..14
var temperature: float = 40.0  # °C, 0..100
var gravity: float = 0.0  # px/s², 0..600
var elasticity: float = 1.0  # 0.5..1
var collide_particles: bool = true
var show_trails: bool = false

# particles: Array of {x, y, vx, vy} as Dictionary
var particles: Array = []
var t: float = 0.0
var collision_count: int = 0
var _wall_impulse: float = 0.0  # accumulated |Δp| this window
var _pressure_window: float = 0.0
var wall_pressure: float = 0.0

var avg_speed: float = 0.0
var rms_speed: float = 0.0
var kinetic_energy: float = 0.0
var total_energy: float = 0.0  # KE + PE


func _speed_scale_for_t(temp_c: float) -> float:
	# Characteristic speed ~ sqrt(T_kelvin / T_ref)
	var tk: float = maxf(temp_c + 273.15, 1.0)
	var tref: float = T_REF + 273.15
	return K_SPEED * sqrt(tk / tref) * 60.0  # ~px/s


func rebuild() -> void:
	particles.clear()
	collision_count = 0
	_wall_impulse = 0.0
	_pressure_window = 0.0
	wall_pressure = 0.0
	t = 0.0
	var n: int = clampi(count, 1, 80)
	count = n
	var r: float = clampf(radius, 2.0, 14.0)
	radius = r
	var v_char: float = _speed_scale_for_t(temperature)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var attempts: int = 0
	while particles.size() < n and attempts < n * 40:
		attempts += 1
		var px: float = rng.randf_range(r + 1.0, BOX - r - 1.0)
		var py: float = rng.randf_range(r + 1.0, BOX - r - 1.0)
		var ok: bool = true
		for q in particles:
			var dx: float = px - float(q.x)
			var dy: float = py - float(q.y)
			if dx * dx + dy * dy < (2.0 * r + 1.0) * (2.0 * r + 1.0):
				ok = false
				break
		if not ok:
			continue
		var ang: float = rng.randf() * TAU
		var spd: float = v_char * rng.randf_range(0.6, 1.4)
		particles.append({
			"x": px, "y": py,
			"vx": spd * cos(ang), "vy": spd * sin(ang),
		})
	_update_stats()


func set_temperature(temp_c: float) -> void:
	var old_t: float = temperature
	temperature = clampf(temp_c, 0.0, 100.0)
	if particles.is_empty():
		return
	# Rescale all speeds by sqrt ratio so avg KE tracks T
	var old_k: float = maxf(old_t + 273.15, 1.0)
	var new_k: float = maxf(temperature + 273.15, 1.0)
	var factor: float = sqrt(new_k / old_k)
	for p in particles:
		p.vx = float(p.vx) * factor
		p.vy = float(p.vy) * factor
	_update_stats()


func step(dt: float) -> void:
	if particles.is_empty() or dt <= 0.0:
		return
	var r: float = radius
	var e: float = clampf(elasticity, 0.5, 1.0)
	var g: float = gravity

	# Integrate
	for p in particles:
		p.vy = float(p.vy) + g * dt
		p.x = float(p.x) + float(p.vx) * dt
		p.y = float(p.y) + float(p.vy) * dt

	# Wall collisions
	for p in particles:
		var hit: bool = false
		if float(p.x) < r:
			p.x = r
			var dv: float = absf(float(p.vx)) * (1.0 + e)
			_wall_impulse += dv  # mass=1
			p.vx = absf(float(p.vx)) * e
			hit = true
		elif float(p.x) > BOX - r:
			p.x = BOX - r
			var dv2: float = absf(float(p.vx)) * (1.0 + e)
			_wall_impulse += dv2
			p.vx = -absf(float(p.vx)) * e
			hit = true
		if float(p.y) < r:
			p.y = r
			var dv3: float = absf(float(p.vy)) * (1.0 + e)
			_wall_impulse += dv3
			p.vy = absf(float(p.vy)) * e
			hit = true
		elif float(p.y) > BOX - r:
			p.y = BOX - r
			var dv4: float = absf(float(p.vy)) * (1.0 + e)
			_wall_impulse += dv4
			p.vy = -absf(float(p.vy)) * e
			hit = true
		if hit:
			collision_count += 1

	# Particle–particle collisions
	if collide_particles:
		var n: int = particles.size()
		for i in range(n):
			for j in range(i + 1, n):
				var a: Dictionary = particles[i]
				var b: Dictionary = particles[j]
				var dx: float = float(b.x) - float(a.x)
				var dy: float = float(b.y) - float(a.y)
				var dist2: float = dx * dx + dy * dy
				var min_d: float = 2.0 * r
				if dist2 >= min_d * min_d or dist2 < 1e-8:
					continue
				var dist: float = sqrt(dist2)
				var nx: float = dx / dist
				var ny: float = dy / dist
				# Relative velocity along normal
				var dvx: float = float(a.vx) - float(b.vx)
				var dvy: float = float(a.vy) - float(b.vy)
				var vn: float = dvx * nx + dvy * ny
				if vn <= 0.0:
					continue  # separating
				# Equal mass impulse with restitution e
				var j_imp: float = (1.0 + e) * vn / 2.0
				a.vx = float(a.vx) - j_imp * nx
				a.vy = float(a.vy) - j_imp * ny
				b.vx = float(b.vx) + j_imp * nx
				b.vy = float(b.vy) + j_imp * ny
				# Separate overlap
				var overlap: float = min_d - dist
				a.x = float(a.x) - nx * overlap * 0.5
				a.y = float(a.y) - ny * overlap * 0.5
				b.x = float(b.x) + nx * overlap * 0.5
				b.y = float(b.y) + ny * overlap * 0.5
				collision_count += 1

	t += dt
	_pressure_window += dt
	if _pressure_window >= 0.25:
		# P ~ impulse / (time * wall length); wall length = 4*BOX
		wall_pressure = _wall_impulse / maxf(_pressure_window * 4.0 * BOX, 1e-6)
		_wall_impulse = 0.0
		_pressure_window = 0.0
	_update_stats()


func _update_stats() -> void:
	var n: int = particles.size()
	if n == 0:
		avg_speed = 0.0
		rms_speed = 0.0
		kinetic_energy = 0.0
		total_energy = 0.0
		return
	var sum_s: float = 0.0
	var sum_s2: float = 0.0
	var ke: float = 0.0
	var pe: float = 0.0
	for p in particles:
		var vx: float = float(p.vx)
		var vy: float = float(p.vy)
		var s2: float = vx * vx + vy * vy
		var s: float = sqrt(s2)
		sum_s += s
		sum_s2 += s2
		ke += 0.5 * s2  # mass = 1
		# PE reference: bottom of box
		pe += gravity * float(p.y)
	avg_speed = sum_s / float(n)
	rms_speed = sqrt(sum_s2 / float(n))
	kinetic_energy = ke
	total_energy = ke + pe


func energy_band(speed: float) -> int:
	## 0 idle, 1 very slow, 2 slow, 3 fast, 4 very fast
	var ref: float = _speed_scale_for_t(temperature)
	var ratio: float = speed / maxf(ref, 1.0)
	if ratio < 0.15:
		return 0
	if ratio < 0.45:
		return 1
	if ratio < 0.85:
		return 2
	if ratio < 1.35:
		return 3
	return 4
