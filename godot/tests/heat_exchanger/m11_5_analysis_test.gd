extends SceneTree

const LAB_SCENE := "res://scenes/labs/engineering/heat_exchanger/heat_exchanger_lab.tscn"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var chart_script := load("res://scenes/labs/engineering/heat_exchanger/interface/heat_exchanger_chart.gd")
	_expect(chart_script != null and chart_script.can_instantiate(), "The analysis chart script must compile and load.")
	if chart_script == null or not chart_script.can_instantiate():
		_finish()
		return
	var packed := load(LAB_SCENE) as PackedScene
	_expect(packed != null, "Heat Exchanger scene must load for the M11.5 analysis check.")
	if packed == null:
		_finish()
		return
	if packed == null:
		_finish()
		return
	var lab := packed.instantiate()
	root.add_child(lab)
	await process_frame
	var charts: Dictionary = lab.get("_charts")
	_expect(charts.size() == 4, "Analysis must build the four required model-derived charts.")
	if charts.size() != 4:
		_finish()
		return
	var temperature: Array = charts["temperature"].call("chart_series")
	var flow: Array = charts["flow"].call("chart_series")
	var fouling: Array = charts["fouling"].call("chart_series")
	var comparison: Array = charts["comparison"].call("chart_series")
	_expect(temperature.size() == 2 and temperature[0]["values"].size() == 11, "Temperature profiles must use calculated outlet endpoints.")
	_expect(flow.size() == 2 and flow[0]["values"].size() == 11 and flow[1]["values"].size() == 11, "Both stream flow sweeps must be model-solved.")
	_expect(fouling.size() == 1 and fouling[0]["values"].size() == 11, "Fouling response must use model-solved sample points.")
	_expect(comparison.size() == 1 and comparison[0]["values"].size() == 2, "The baseline comparison must include both equipment configurations.")
	var saved_count := lab.get("_saved_cases") as Array
	var save_button := lab.find_child("SaveComparisonCase", true, false) as Button
	_expect(save_button != null, "A session comparison case save control must be available.")
	if save_button != null:
		save_button.emit_signal("pressed")
		await process_frame
		var compared: Array = charts["comparison"].call("chart_series")
		_expect(saved_count.size() == 1 and compared.size() == 2, "Saving a case must add a live model-backed comparison series.")
	var baseline_duty := float((lab.get("_readings") as Dictionary)["heat_duty_w"])
	var fouling_input := lab.find_child("fouling_hot_m2_k_w", true, false) as SpinBox
	if fouling_input != null:
		fouling_input.value = 0.004
		var fouling_cold := lab.find_child("fouling_cold_m2_k_w", true, false) as SpinBox
		fouling_cold.value = 0.004
		await process_frame
		var changed_duty := float((lab.get("_readings") as Dictionary)["heat_duty_w"])
		_expect(changed_duty < baseline_duty, "Increasing fouling must lower the calculated duty.")
	var experiment_selector := lab.find_child("ExperimentSelector", true, false) as OptionButton
	var apply_experiment := lab.find_child("ApplyExperimentSetup", true, false) as Button
	_expect(experiment_selector != null and apply_experiment != null, "The guided experiment chooser and setup control must be available.")
	if experiment_selector != null and apply_experiment != null:
		experiment_selector.select(3)
		experiment_selector.item_selected.emit(3)
		apply_experiment.emit_signal("pressed")
		await process_frame
		var hot_fouling := lab.find_child("fouling_hot_m2_k_w", true, false) as SpinBox
		_expect(is_equal_approx(hot_fouling.value, 0.0015), "The fouling activity must load its documented starting condition.")
	var cold_inlet := lab.find_child("cold_in_c", true, false) as SpinBox
	if cold_inlet != null:
		cold_inlet.value = 120.0
		await process_frame
		_expect(str(lab.get("_result_labels")["heat_duty"].text) == "INVALID", "Invalid temperature ordering must show an explicit invalid state.")
	lab.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: M11.5 model-derived results, four charts, saved comparisons, fouling response, guided setup, and invalid-input handling")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
