extends RefCounted
class_name HeatExchangerModel

const Thermal = preload("res://scripts/models/engineering/heat_exchanger/thermal_calculations.gd")
const LMTD = preload("res://scripts/models/engineering/heat_exchanger/lmtd_model.gd")
const NTU = preload("res://scripts/models/engineering/heat_exchanger/effectiveness_ntu_model.gd")
const Fouling = preload("res://scripts/models/engineering/heat_exchanger/fouling_model.gd")
const PressureDrop = preload("res://scripts/models/engineering/heat_exchanger/pressure_drop_model.gd")

static func solve_design(inputs: Dictionary) -> Dictionary:
	var required := ["hot_in_k", "cold_in_k", "hot_mass_flow_kg_s", "cold_mass_flow_kg_s", "hot_cp_j_kg_k", "cold_cp_j_kg_k", "area_m2", "u_clean_w_m2_k"]
	for key in required:
		if not inputs.has(key) or not is_finite(float(inputs[key])): return _fail("Missing or non-finite required input: %s." % key)
	var hot_c := float(inputs["hot_mass_flow_kg_s"]) * float(inputs["hot_cp_j_kg_k"])
	var cold_c := float(inputs["cold_mass_flow_kg_s"]) * float(inputs["cold_cp_j_kg_k"])
	var fouling := Fouling.effective_u(float(inputs["u_clean_w_m2_k"]), float(inputs.get("fouling_hot_m2_k_w", 0.0)), float(inputs.get("fouling_cold_m2_k_w", 0.0)))
	if not fouling["ok"]: return fouling
	var arrangement := int(inputs.get("configuration", NTU.Configuration.COUNTER_CURRENT))
	var solution := NTU.solve(float(inputs["hot_in_k"]), float(inputs["cold_in_k"]), hot_c, cold_c, float(fouling["u_effective_w_m2_k"]) * float(inputs["area_m2"]), arrangement)
	if not solution["ok"]: return solution
	var lmtd_result := {"ok": false, "error": "LMTD not evaluated for this configuration."}
	var duty_result := {"ok": true, "q_w": solution["q_w"]}
	if arrangement != NTU.Configuration.SHELL_ONE_PASS:
		var lmtd_flow := LMTD.FlowArrangement.PARALLEL if arrangement == NTU.Configuration.PARALLEL_FLOW else LMTD.FlowArrangement.COUNTER_CURRENT
		lmtd_result = LMTD.calculate(float(inputs["hot_in_k"]), float(solution["hot_out_k"]), float(inputs["cold_in_k"]), float(solution["cold_out_k"]), lmtd_flow)
		if not lmtd_result["ok"]: return lmtd_result
		duty_result = Thermal.duty_from_u_area(float(fouling["u_effective_w_m2_k"]), float(inputs["area_m2"]), float(lmtd_result["lmtd_k"]))
		if not duty_result["ok"]: return duty_result
	var hot_stream := Thermal.stream_duty(float(inputs["hot_mass_flow_kg_s"]), float(inputs["hot_cp_j_kg_k"]), float(inputs["hot_in_k"]), float(solution["hot_out_k"]))
	var cold_stream := Thermal.stream_duty(float(inputs["cold_mass_flow_kg_s"]), float(inputs["cold_cp_j_kg_k"]), float(inputs["cold_in_k"]), float(solution["cold_out_k"]))
	if not hot_stream["ok"]: return hot_stream
	if not cold_stream["ok"]: return cold_stream
	var energy := Thermal.energy_balance(-float(hot_stream["q_w"]), float(cold_stream["q_w"]))
	if not energy["ok"]: return energy
	var output := {"ok": true, "u_effective_w_m2_k": fouling["u_effective_w_m2_k"], "u_clean_w_m2_k": fouling["u_clean_w_m2_k"], "area_m2": float(inputs["area_m2"]), "heat_duty_w": solution["q_w"], "hot_out_k": solution["hot_out_k"], "cold_out_k": solution["cold_out_k"], "ntu": solution["ntu"], "effectiveness": solution["effectiveness"], "q_max_w": solution["q_max_w"], "energy_balance": energy, "assumptions": solution["assumption"]}
	if lmtd_result["ok"]:
		output["lmtd_k"] = lmtd_result["lmtd_k"]
		output["ua_lmtd_duty_w"] = duty_result["q_w"]
	return output

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
