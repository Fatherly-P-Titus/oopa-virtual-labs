extends RefCounted
class_name PendulumSpringsModel
## Simple pendulum OR mass–spring with optional damping and spring drive F0 cos(ωd t).

enum Mode { PENDULUM, SPRING }

var mode: int = Mode.PENDULUM

var mass: float = 1.0
var g: float = 9.81
var damping: float = 0.0

# Pendulum
var length: float = 1.5
var theta0: float = 0.4
var theta: float = 0.4
var omega: float = 0.0

# Spring
var k: float = 20.0
var x0: float = 0.3
var x: float = 0.3
var v: float = 0.0

# Drive (spring only): F = F0 * cos(ωd * t)
var drive_on: bool = false
var drive_f0: float = 2.0   # N
var drive_omega: float = 4.0  # rad/s

var t: float = 0.0

const DT: float = 1.0 / 120.0


func reset() -> void:
	t = 0.0
	if mode == Mode.PENDULUM:
		theta = theta0
		omega = 0.0
	else:
		x = x0
		v = 0.0


func natural_omega() -> float:
	if mode == Mode.PENDULUM:
		return sqrt(maxf(g, 1e-6) / maxf(length, 1e-6))
	return sqrt(maxf(k, 1e-6) / maxf(mass, 1e-6))


func period() -> float:
	return TAU / maxf(natural_omega(), 1e-6)


func energy() -> Dictionary:
	if mode == Mode.PENDULUM:
		var ke: float = 0.5 * mass * (length * omega) * (length * omega)
		var pe: float = mass * g * length * (1.0 - cos(theta))
		return {"ke": ke, "pe": pe, "total": ke + pe}
	var ke2: float = 0.5 * mass * v * v
	var pe2: float = 0.5 * k * x * x
	return {"ke": ke2, "pe": pe2, "total": ke2 + pe2}


func step(dt: float = DT) -> void:
	if mode == Mode.PENDULUM:
		_step_pendulum(dt)
	else:
		_step_spring(dt)
	t += dt


func _step_pendulum(dt: float) -> void:
	var b: float = damping
	var a1: float = -(g / maxf(length, 1e-6)) * sin(theta) - (b / maxf(mass, 1e-6)) * omega
	var o1: float = omega
	var o2: float = omega + a1 * dt
	var t2: float = theta + o1 * dt
	var a2: float = -(g / maxf(length, 1e-6)) * sin(t2) - (b / maxf(mass, 1e-6)) * o2
	omega += 0.5 * (a1 + a2) * dt
	theta += 0.5 * (o1 + o2) * dt
	while theta > PI:
		theta -= TAU
	while theta < -PI:
		theta += TAU


func _step_spring(dt: float) -> void:
	var b: float = damping
	var drive: float = 0.0
	if drive_on:
		drive = drive_f0 * cos(drive_omega * t)
	var a1: float = -(k / maxf(mass, 1e-6)) * x - (b / maxf(mass, 1e-6)) * v + drive / maxf(mass, 1e-6)
	var v1: float = v
	var v2: float = v + a1 * dt
	var x2: float = x + v1 * dt
	var drive2: float = drive_f0 * cos(drive_omega * (t + dt)) if drive_on else 0.0
	var a2: float = -(k / maxf(mass, 1e-6)) * x2 - (b / maxf(mass, 1e-6)) * v2 + drive2 / maxf(mass, 1e-6)
	v += 0.5 * (a1 + a2) * dt
	x += 0.5 * (v1 + v2) * dt


func advance(seconds: float) -> void:
	var n: int = int(ceil(seconds / DT))
	for i in range(n):
		step(DT)


func bob_position() -> Vector2:
	if mode == Mode.PENDULUM:
		return Vector2(length * sin(theta), -length * cos(theta))
	return Vector2(x, 0.0)


func phase_point() -> Vector2:
	## Returns (displacement, velocity) for phase plot
	if mode == Mode.PENDULUM:
		return Vector2(theta, omega)
	return Vector2(x, v)
