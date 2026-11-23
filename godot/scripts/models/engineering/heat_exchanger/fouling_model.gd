extends RefCounted
class_name HeatExchangerFouling

static func effective_u(clean_u_w_m2_k: float, hot_resistance_m2_k_w: float = 0.0, cold_resistance_m2_k_w: float = 0.0) -> Dictionary:
	for value in [clean_u_w_m2_k, hot_resistance_m2_k_w, cold_resistance_m2_k_w]:
		if not is_finite(value): return _fail("Fouling inputs must be finite.")
	if clean_u_w_m2_k <= 0.0 or hot_resistance_m2_k_w < 0.0 or cold_resistance_m2_k_w < 0.0:
		return _fail("Clean U must be positive and fouling resistances non-negative.")
	var u := 1.0 / (1.0 / clean_u_w_m2_k + hot_resistance_m2_k_w + cold_resistance_m2_k_w)
	return {"ok": true, "u_clean_w_m2_k": clean_u_w_m2_k, "u_effective_w_m2_k": u, "reduction_fraction": 1.0 - u / clean_u_w_m2_k}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
