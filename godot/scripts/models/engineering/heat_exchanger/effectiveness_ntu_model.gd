extends RefCounted
class_name HeatExchangerEffectivenessNTU

enum Configuration { COUNTER_CURRENT, PARALLEL_FLOW, SHELL_ONE_PASS }
const EPS := 1.0e-10

static func solve(hot_in_k: float, cold_in_k: float, hot_capacity_w_k: float, cold_capacity_w_k: float, ua_w_k: float, configuration: int = Configuration.COUNTER_CURRENT) -> Dictionary:
	for value in [hot_in_k, cold_in_k, hot_capacity_w_k, cold_capacity_w_k, ua_w_k]:
		if not is_finite(value): return _fail("Inputs must be finite.")
	if hot_in_k <= cold_in_k or cold_in_k <= 0.0 or hot_capacity_w_k <= 0.0 or cold_capacity_w_k <= 0.0 or ua_w_k <= 0.0:
		return _fail("Require hot inlet > cold inlet > 0 K and positive capacity rates and UA.")
	var c_min := minf(hot_capacity_w_k, cold_capacity_w_k)
	var c_max := maxf(hot_capacity_w_k, cold_capacity_w_k)
	var ratio := c_min / c_max
	var ntu := ua_w_k / c_min
	var effectiveness := 0.0
	match configuration:
		Configuration.COUNTER_CURRENT:
			if absf(ratio - 1.0) < EPS: effectiveness = ntu / (1.0 + ntu)
			else:
				var exponential := exp(-ntu * (1.0 - ratio))
				effectiveness = (1.0 - exponential) / (1.0 - ratio * exponential)
		Configuration.PARALLEL_FLOW:
			effectiveness = (1.0 - exp(-ntu * (1.0 + ratio))) / (1.0 + ratio)
		Configuration.SHELL_ONE_PASS:
			var root := sqrt(1.0 + ratio * ratio)
			var e := exp(-ntu * root)
			effectiveness = 2.0 / (1.0 + ratio + root * (1.0 + e) / maxf(1.0 - e, EPS))
		_:
			return _fail("Unsupported effectiveness configuration.")
	var q_max := c_min * (hot_in_k - cold_in_k)
	var q := clampf(effectiveness, 0.0, 1.0) * q_max
	return {"ok": true, "c_min_w_k": c_min, "c_max_w_k": c_max, "capacity_ratio": ratio, "ntu": ntu, "effectiveness": effectiveness, "q_max_w": q_max, "q_w": q, "hot_out_k": hot_in_k - q / hot_capacity_w_k, "cold_out_k": cold_in_k + q / cold_capacity_w_k, "configuration": configuration, "assumption": "Steady, adiabatic, single-phase streams with constant heat-capacity rates. Shell equation assumes one shell pass and the standard ideal shell-side relation."}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
