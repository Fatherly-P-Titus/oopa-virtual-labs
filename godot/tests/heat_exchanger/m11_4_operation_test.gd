extends SceneTree

const LAB_SCENE := "res://scenes/labs/engineering/heat_exchanger/heat_exchanger_lab.tscn"
var failures: Array[String] = []

func _initialize() -> void:
	print("Starting M11.4 interaction check")
	call_deferred("_run")

func _run() -> void:
	print("Loading interactive Heat Exchanger scene")
	var packed := load(LAB_SCENE) as PackedScene
	_expect(packed != null, "The heat-exchanger laboratory scene must load.")
	if packed == null:
		_finish()
		return
	var lab := packed.instantiate()
	root.add_child(lab)
	await process_frame
	var equipment_selector := lab.find_child("EquipmentSelector", true, false) as OptionButton
	var arrangement_selector := lab.find_child("ArrangementSelector", true, false) as OptionButton
	var double_pipe := lab.find_child("DoublePipeEquipment", true, false)
	var duty := lab.find_child("heat_duty", true, false) as Label
	var hot_flow := lab.find_child("hot_mass_flow_kg_s", true, false) as SpinBox
	var reset_button := lab.find_child("ResetOperatingConditions", true, false) as Button
	_expect(equipment_selector != null and arrangement_selector != null and double_pipe != null and duty != null and hot_flow != null and reset_button != null, "Operation controls, equipment, and model readouts must be present.")
	if equipment_selector == null or arrangement_selector == null or double_pipe == null or duty == null or hot_flow == null or reset_button == null:
		lab.queue_free()
		_finish()
		return
	_expect(duty.text.contains("kW"), "Initial heat duty must come from a valid model calculation.")
	var initial_duty := duty.text
	equipment_selector.select(1)
	equipment_selector.item_selected.emit(1)
	await process_frame
	_expect(bool(lab.get("_is_double_pipe")), "Selecting double-pipe must switch equipment presentation.")
	arrangement_selector.select(1)
	arrangement_selector.item_selected.emit(1)
	await process_frame
	var parallel_baseline_duty := duty.text
	_expect(bool(double_pipe.get("parallel_flow")), "Parallel-flow selection must update the equipment pathways.")
	_expect(str(double_pipe.call("_component_at", Vector2(286, 150))) == "cold_inlet", "Parallel-flow cold inlet must be placed at the inlet end.")
	hot_flow.value = 0.35
	await process_frame
	_expect(duty.text != initial_duty, "Changing a flow input must recalculate the displayed heat duty.")
	reset_button.emit_signal("pressed")
	await process_frame
	_expect(is_equal_approx(hot_flow.value, 0.20) and duty.text == parallel_baseline_duty, "Reset conditions must restore default inputs and recalculate for the current equipment arrangement.")
	double_pipe.call("set_view_mode", "cutaway")
	await create_timer(0.5).timeout
	_expect(float(double_pipe.get("cutaway_progress")) > 0.9, "The double-pipe cutaway transition must complete.")
	arrangement_selector.select(0)
	arrangement_selector.item_selected.emit(0)
	await process_frame
	_expect(not bool(double_pipe.get("parallel_flow")), "Counter-current selection must update the equipment pathways.")
	_expect(str(double_pipe.call("_component_at", Vector2(828, 150))) == "cold_inlet", "Counter-current cold inlet must move to the opposite end.")
	double_pipe.call("restore_assembled")
	await create_timer(0.5).timeout
	_expect(float(double_pipe.get("cutaway_progress")) < 0.1, "Restore must return the double-pipe view to assembled external mode.")
	equipment_selector.select(0)
	equipment_selector.item_selected.emit(0)
	await process_frame
	_expect(not bool(lab.get("_is_double_pipe")), "Selecting shell-and-tube must restore its operation model configuration.")
	var shell := lab.find_child("ShellAndTubeEquipment", true, false)
	_expect(shell != null and float(shell.get("operating_state").get("heat_duty_w", 0.0)) > 0.0, "Shell-and-tube equipment must receive current model results.")
	lab.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: M11.4 operating controls, model readings, flow arrangements, equipment state, and view transitions")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
