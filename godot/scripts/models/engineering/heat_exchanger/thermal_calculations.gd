extends RefCounted
class_name HeatExchangerThermalCalculations

const EPS := 1.0e-9

static func stream_duty(mass_flow_kg_s: float, cp_j_kg_k: float, inlet_k: float, outlet_k: float) -> Dictionary:
	if mass_flow_kg_s <= 0.0 or cp_j_kg_k <= 0.0 or not _finite_all([mass_flow_kg_s, cp_j_kg_k, inlet_k, outlet_k]):
		return _fail("Mass flow and heat capacity must be finite and positive; temperatures must be finite.")
	return {"ok": true, "q_w": mass_flow_kg_s * cp_j_kg_k * (outlet_k - inlet_k)}


static func energy_balance(hot_loss_w: float, cold_gain_w: float, tolerance_fraction: float = 0.02) -> Dictionary:
	if not _finite_all([hot_loss_w, cold_gain_w, tolerance_fraction]) or hot_loss_w < 0.0 or cold_gain_w < 0.0 or tolerance_fraction < 0.0:
		return _fail("Duties must be finite, non-negative magnitudes and tolerance must be non-negative.")
	var discrepancy := absf(hot_loss_w - cold_gain_w)
	var scale := maxf(maxf(hot_loss_w, cold_gain_w), EPS)
	return {"ok": true, "discrepancy_w": discrepancy, "relative_discrepancy": discrepancy / scale, "balanced": discrepancy / scale <= tolerance_fraction}


static func overall_u_w_m2_k(area_m2: float, film_hot_w_m2_k: float, film_cold_w_m2_k: float, wall_resistance_m2_k_w: float, fouling_hot_m2_k_w: float = 0.0, fouling_cold_m2_k_w: float = 0.0) -> Dictionary:
	var values := [area_m2, film_hot_w_m2_k, film_cold_w_m2_k, wall_resistance_m2_k_w, fouling_hot_m2_k_w, fouling_cold_m2_k_w]
	if not _finite_all(values) or area_m2 <= 0.0 or film_hot_w_m2_k <= 0.0 or film_cold_w_m2_k <= 0.0 or wall_resistance_m2_k_w < 0.0 or fouling_hot_m2_k_w < 0.0 or fouling_cold_m2_k_w < 0.0:
		return _fail("Area and film coefficients must be positive; resistances must be finite and non-negative.")
	var resistance := 1.0 / film_hot_w_m2_k + wall_resistance_m2_k_w + 1.0 / film_cold_w_m2_k + fouling_hot_m2_k_w + fouling_cold_m2_k_w
	return {"ok": true, "u_w_m2_k": 1.0 / resistance, "area_m2": area_m2, "ua_w_k": area_m2 / resistance, "total_resistance_m2_k_w": resistance}


static func duty_from_u_area(u_w_m2_k: float, area_m2: float, lmtd_k: float, correction_factor: float = 1.0) -> Dictionary:
	if not _finite_all([u_w_m2_k, area_m2, lmtd_k, correction_factor]) or u_w_m2_k <= 0.0 or area_m2 <= 0.0 or lmtd_k <= 0.0 or correction_factor <= 0.0 or correction_factor > 1.0:
		return _fail("U, area, LMTD and correction factor must be finite and physically valid (0 < F ≤ 1).")
	return {"ok": true, "q_w": u_w_m2_k * area_m2 * correction_factor * lmtd_k}


static func _finite_all(values: Array) -> bool:
	for value in values:
		if not is_finite(float(value)): return false
	return true

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
