extends RefCounted
class_name RobotArmModel
## Planar 2R arm — forward & inverse kinematics.

var l1: float = 1.0
var l2: float = 0.75
var theta1: float = 40.0  # degrees
var theta2: float = 50.0
var elbow_up: bool = true


func forward(t1_deg: float = NAN, t2_deg: float = NAN) -> Dictionary:
	var t1d: float = theta1 if is_nan(t1_deg) else t1_deg
	var t2d: float = theta2 if is_nan(t2_deg) else t2_deg
	var t1: float = deg_to_rad(t1d)
	var t2: float = deg_to_rad(t2d)
	var x1: float = l1 * cos(t1)
	var y1: float = l1 * sin(t1)
	var x: float = x1 + l2 * cos(t1 + t2)
	var y: float = y1 + l2 * sin(t1 + t2)
	return {
		"base": Vector2.ZERO,
		"joint": Vector2(x1, y1),
		"end": Vector2(x, y),
		"theta1": t1d,
		"theta2": t2d,
		"reach": Vector2(x, y).length(),
	}


func inverse(x: float, y: float, up: Variant = null) -> Dictionary:
	var use_up: bool = elbow_up if up == null else bool(up)
	var r2: float = x * x + y * y
	var r: float = sqrt(r2)
	var r_max: float = l1 + l2
	var r_min: float = absf(l1 - l2)
	if r > r_max + 1e-6 or r < r_min - 1e-6:
		return {"ok": false, "message": "Target outside workspace (r=%.2f, allowed %.2f…%.2f)." % [r, r_min, r_max]}
	var cos_t2: float = (r2 - l1 * l1 - l2 * l2) / maxf(2.0 * l1 * l2, 1e-12)
	cos_t2 = clampf(cos_t2, -1.0, 1.0)
	var sin_t2: float = sqrt(maxf(0.0, 1.0 - cos_t2 * cos_t2))
	if not use_up:
		sin_t2 = -sin_t2
	var t2: float = atan2(sin_t2, cos_t2)
	var t1: float = atan2(y, x) - atan2(l2 * sin_t2, l1 + l2 * cos_t2)
	return {
		"ok": true,
		"theta1": rad_to_deg(t1),
		"theta2": rad_to_deg(t2),
		"message": "IK solved (%s)." % ("elbow up" if use_up else "elbow down"),
	}


func workspace() -> Dictionary:
	return {"rMin": absf(l1 - l2), "rMax": l1 + l2}


func apply_ik(x: float, y: float) -> Dictionary:
	var res: Dictionary = inverse(x, y)
	if bool(res.get("ok", false)):
		theta1 = float(res.theta1)
		theta2 = float(res.theta2)
	return res


func apply_preset(id: String) -> void:
	match id:
		"reach_out":
			l1 = 1.0
			l2 = 0.8
			theta1 = 20.0
			theta2 = 30.0
			elbow_up = true
		"folded":
			l1 = 1.0
			l2 = 0.75
			theta1 = 80.0
			theta2 = 140.0
			elbow_up = true
		"long_reach":
			l1 = 1.2
			l2 = 1.0
			theta1 = 35.0
			theta2 = 40.0
			elbow_up = true
		"elbow_down":
			l1 = 1.0
			l2 = 0.75
			elbow_up = false
			apply_ik(1.2, 0.4)
		_:
			l1 = 1.0
			l2 = 0.75
			theta1 = 40.0
			theta2 = 50.0
			elbow_up = true
