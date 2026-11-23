extends RefCounted
class_name HeatExchangerLMTDModel

enum FlowArrangement { PARALLEL, COUNTER_CURRENT }
const EPS := 1.0e-8

static func calculate(hot_in_k: float, hot_out_k: float, cold_in_k: float, cold_out_k: float, arrangement: int) -> Dictionary:
	for value in [hot_in_k, hot_out_k, cold_in_k, cold_out_k]:
		if not is_finite(value) or value <= 0.0: return _fail("All absolute temperatures must be finite and above 0 K.")
	var d1: float
	var d2: float
	if arrangement == FlowArrangement.PARALLEL:
		d1 = hot_in_k - cold_in_k
		d2 = hot_out_k - cold_out_k
	elif arrangement == FlowArrangement.COUNTER_CURRENT:
		d1 = hot_in_k - cold_out_k
		d2 = hot_out_k - cold_in_k
	else:
		return _fail("Unsupported flow arrangement.")
	if d1 <= 0.0 or d2 <= 0.0: return _fail("Terminal temperature differences must both be positive; the proposed outlets are physically inconsistent for this arrangement.")
	var mean := 0.5 * (d1 + d2) if absf(d1 - d2) <= EPS * maxf(d1, d2) else (d1 - d2) / log(d1 / d2)
	return {"ok": true, "delta_t1_k": d1, "delta_t2_k": d2, "lmtd_k": mean, "assumption": "Steady single-phase operation; correction factor is applied separately for supported multipass shell-and-tube cases."}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
