extends RefCounted
class_name WaveModel
## Two coherent point sources — interference field.
## Instantaneous: A1*sin(k*r1-ωt)*f1 + A2*sin(k*r2-ωt+φ)*f2
## Time-average intensity ~ A1²f1² + A2²f2² + 2 A1 A2 f1 f2 cos(k(r2-r1)+φ)

var freq: float = 1.0
var wavelength: float = 40.0
var amp1: float = 1.0
var amp2: float = 1.0
var phase2: float = 0.0
var sep: float = 80.0
var speed: float = 40.0
var double_source: bool = true
var time_average: bool = false
var time_scale: float = 1.0  # 0.25 slow-mo .. 1.0 normal

var t: float = 0.0
var playing: bool = true

var box_w: float = 400.0
var box_h: float = 300.0
var screen_x: float = 360.0  # detector line x in world


func k() -> float:
	return TAU / maxf(wavelength, 1.0)


func omega() -> float:
	return TAU * freq


func sync_speed() -> void:
	speed = freq * wavelength


func set_wavelength(lam: float) -> void:
	wavelength = clampf(lam, 10.0, 120.0)
	sync_speed()


func set_freq(f: float) -> void:
	freq = clampf(f, 0.2, 4.0)
	sync_speed()


func source_pos(which: int) -> Vector2:
	var cx: float = box_w * 0.5
	var cy: float = box_h * 0.5
	var half: float = sep * 0.5
	if which == 1:
		return Vector2(cx - half, cy)
	return Vector2(cx + half, cy)


func _falloff(r: float) -> float:
	return 1.0 / sqrt(maxf(r, 8.0))


func field_at(p: Vector2) -> float:
	## Instantaneous displacement (or signed field)
	var s1: Vector2 = source_pos(1)
	var r1: float = p.distance_to(s1)
	var kk: float = k()
	var ww: float = omega()
	var f1: float = _falloff(r1)
	var a1: float = amp1 * sin(kk * r1 - ww * t) * f1 * 12.0
	if not double_source or amp2 <= 1e-6:
		return a1
	var s2: Vector2 = source_pos(2)
	var r2: float = p.distance_to(s2)
	var f2: float = _falloff(r2)
	var a2: float = amp2 * sin(kk * r2 - ww * t + phase2) * f2 * 12.0
	return a1 + a2


func intensity_at(p: Vector2) -> float:
	## Time-averaged intensity proxy (always ≥ 0)
	var s1: Vector2 = source_pos(1)
	var r1: float = p.distance_to(s1)
	var f1: float = _falloff(r1)
	var A1: float = amp1 * f1
	if not double_source or amp2 <= 1e-6:
		return A1 * A1 * 80.0
	var s2: Vector2 = source_pos(2)
	var r2: float = p.distance_to(s2)
	var f2: float = _falloff(r2)
	var A2: float = amp2 * f2
	var delta: float = k() * (r2 - r1) + phase2
	return (A1 * A1 + A2 * A2 + 2.0 * A1 * A2 * cos(delta)) * 80.0


func sample_at(p: Vector2) -> float:
	if time_average:
		return intensity_at(p)
	return field_at(p)


func path_diff_at(p: Vector2) -> float:
	if not double_source:
		return 0.0
	return p.distance_to(source_pos(2)) - p.distance_to(source_pos(1))


func fringe_order(p: Vector2) -> float:
	return path_diff_at(p) / maxf(wavelength, 1.0)


func screen_intensity_profile(samples: int = 80) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(samples)
	for i in samples:
		var y: float = (float(i) + 0.5) / float(samples) * box_h
		out[i] = intensity_at(Vector2(screen_x, y))
	return out


func theoretical_fringe_spacing() -> float:
	## Approx Δy at screen distance L from midpoint for small angle: λ L / d
	var mid: Vector2 = (source_pos(1) + source_pos(2)) * 0.5
	var L: float = absf(screen_x - mid.x)
	return wavelength * L / maxf(sep, 1.0)


func step(dt: float) -> void:
	if playing:
		t += dt * time_scale
