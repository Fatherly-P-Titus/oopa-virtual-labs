extends LabShell
## M11 heat-exchanger equipment and model-driven operation workspace.

const SHELL_SCENE := preload("res://scenes/labs/engineering/heat_exchanger/equipment/shell_and_tube_equipment.tscn")
const DOUBLE_PIPE_SCENE := preload("res://scenes/labs/engineering/heat_exchanger/equipment/double_pipe_equipment.tscn")
const Model := preload("res://scripts/models/engineering/heat_exchanger/heat_exchanger_model.gd")
const NTU := preload("res://scripts/models/engineering/heat_exchanger/effectiveness_ntu_model.gd")
const PressureDrop := preload("res://scripts/models/engineering/heat_exchanger/pressure_drop_model.gd")

# Documented representative water properties and equivalent passages for the scoped
# Darcy–Weisbach estimate. These are not detailed exchanger-side hydraulic geometry.
const WATER_DENSITY_KG_M3 := 997.0
const WATER_VISCOSITY_PA_S := 0.00089
const EQUIVALENT_LENGTH_M := 6.0
const EQUIVALENT_DIAMETER_M := 0.012
const EQUIVALENT_AREA_M2 := 0.003
const EQUIVALENT_ROUGHNESS_M := 0.000045
const EQUIVALENT_MINOR_K := 1.5
const DEFAULT_INPUTS := {
	"hot_in_c": 100.0,
	"cold_in_c": 20.0,
	"hot_mass_flow_kg_s": 0.20,
	"cold_mass_flow_kg_s": 0.20,
	"area_m2": 12.0,
	"u_clean_w_m2_k": 500.0,
	"fouling_hot_m2_k_w": 0.0002,
	"fouling_cold_m2_k_w": 0.0002
}

var _shell_equipment: Control
var _double_pipe_equipment: Control
var _active_equipment: Control
var _component_name: Label
var _component_circuit: Label
var _component_description: Label
var _view_status: Label
var _equipment_selector: OptionButton
var _arrangement_selector: OptionButton
var _inputs: Dictionary = {}
var _readings: Dictionary = {}
var _result_labels: Dictionary = {}
var _is_double_pipe := false

func _ready() -> void:
	lab_title = "Heat Exchanger Design & Simulation"
	lab_eyebrow = "ENGINEERING  /  THERMAL SYSTEMS"
	lab_lead = "Operate model-connected shell-and-tube and double-pipe exchangers; inspect representative flow paths and live engineering readings."
	field_id = "engineering"
	page_id = "heat_exchanger"
	back_label = "← Engineering"
	super._ready()
	_build_equipment_workspace()
	_build_sidebar()
	_recalculate()
	set_status("M11.4  ·  MODEL-DRIVEN OPERATION")

func _build_equipment_workspace() -> void:
	var stage := get_stage()
	if stage == null:
		push_error("Heat Exchanger Lab: shared workspace stage is missing")
		return
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_to_stage(layout)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	layout.add_child(toolbar)
	_equipment_selector = OptionButton.new()
	_equipment_selector.name = "EquipmentSelector"
	_equipment_selector.add_item("Shell-and-tube", 0)
	_equipment_selector.add_item("Double-pipe", 1)
	_equipment_selector.item_selected.connect(_on_equipment_type_selected)
	toolbar.add_child(_equipment_selector)
	var reset := Button.new()
	reset.name = "ResetOperatingConditions"
	reset.text = "Reset conditions"
	reset.tooltip_text = "Restore the default heat-exchanger operating and design inputs."
	reset.pressed.connect(_reset_operating_conditions)
	toolbar.add_child(reset)
	_arrangement_selector = OptionButton.new()
	_arrangement_selector.name = "ArrangementSelector"
	_arrangement_selector.add_item("Counter-current", 0)
	_arrangement_selector.add_item("Parallel-flow", 1)
	_arrangement_selector.add_item("One shell pass", 2)
	_arrangement_selector.select(2)
	_arrangement_selector.item_selected.connect(_on_arrangement_selected)
	toolbar.add_child(_arrangement_selector)
	_add_view_button(toolbar, "External", "external")
	_add_view_button(toolbar, "Cutaway", "cutaway")
	_add_view_button(toolbar, "Exploded", "exploded")
	_add_view_button(toolbar, "Flow path", "flow")
	var restore := Button.new()
	restore.text = "Restore assembled"
	restore.tooltip_text = "Return the selected equipment to its assembled external view."
	restore.pressed.connect(_restore_assembled)
	toolbar.add_child(restore)
	_view_status = Label.new()
	_view_status.text = "ONE SHELL PASS  ·  TWO TUBE PASSES  ·  SEGMENTAL BAFFLES"
	_view_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_view_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view_status.add_theme_font_size_override("font_size", 10)
	_view_status.add_theme_color_override("font_color", Color("#718994"))
	toolbar.add_child(_view_status)
	_shell_equipment = SHELL_SCENE.instantiate() as Control
	_shell_equipment.name = "ShellAndTubeEquipment"
	_double_pipe_equipment = DOUBLE_PIPE_SCENE.instantiate() as Control
	_double_pipe_equipment.name = "DoublePipeEquipment"
	for equipment in [_shell_equipment, _double_pipe_equipment]:
		equipment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equipment.size_flags_vertical = Control.SIZE_EXPAND_FILL
		equipment.connect("component_selected", _on_equipment_component_selected)
		equipment.connect("view_mode_changed", _on_view_mode_changed)
		layout.add_child(equipment)
	_double_pipe_equipment.hide()
	_active_equipment = _shell_equipment

func _build_sidebar() -> void:
	var sidebar := get_sidebar()
	if sidebar == null: return
	sidebar.add_theme_constant_override("separation", 10)
	_add_section_header(sidebar, "OPERATING CONDITIONS")
	_add_spin_input(sidebar, "hot_in_c", "Hot inlet · °C", 1.0, 500.0, 0.1, 1, 100.0)
	_add_spin_input(sidebar, "cold_in_c", "Cold inlet · °C", 0.0, 499.0, 0.1, 1, 20.0)
	_add_spin_input(sidebar, "hot_mass_flow_kg_s", "Hot flow · kg/s", 0.01, 20.0, 0.01, 2, 0.20)
	_add_spin_input(sidebar, "cold_mass_flow_kg_s", "Cold flow · kg/s", 0.01, 20.0, 0.01, 2, 0.20)
	_add_spin_input(sidebar, "area_m2", "Transfer area · m²", 0.1, 1000.0, 0.1, 1, 12.0)
	_add_spin_input(sidebar, "u_clean_w_m2_k", "Clean U · W/m²K", 1.0, 5000.0, 1.0, 0, 500.0)
	_add_spin_input(sidebar, "fouling_hot_m2_k_w", "Hot fouling · m²K/W", 0.0, 0.1, 0.0001, 4, 0.0002)
	_add_spin_input(sidebar, "fouling_cold_m2_k_w", "Cold fouling · m²K/W", 0.0, 0.1, 0.0001, 4, 0.0002)
	_add_section_header(sidebar, "LIVE MODEL READINGS")
	_add_reading(sidebar, "heat_duty", "Heat duty", "—")
	_add_reading(sidebar, "outlets", "Outlet temperatures", "—")
	_add_reading(sidebar, "thermal", "Ueff [W/m²K] · ε · NTU", "—")
	_add_reading(sidebar, "pressure", "Equivalent ΔP · hot / cold", "—")
	_add_reading(sidebar, "flow", "Flow rates · hot / cold", "—")
	_add_reading(sidebar, "balance", "Energy balance", "—")
	var assumptions := Label.new()
	assumptions.text = "Steady, adiabatic, single-phase model; water heat capacity is assumed constant at 4180 J/(kg·K). In shell mode, hot flow is represented in the two-pass tube circuit and cold flow on the one-pass shell side. The model uses the supported ideal one-shell-pass E–NTU relation. Pressure drop uses water properties and one equivalent straight passage per stream; it is not a detailed exchanger rating. Flow and colour cues are representative, not CFD."
	assumptions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	assumptions.add_theme_font_size_override("font_size", 10)
	assumptions.add_theme_color_override("font_color", Color("#9cabb1"))
	sidebar.add_child(assumptions)
	var inspector_header := HSeparator.new()
	sidebar.add_child(inspector_header)
	_add_section_header(sidebar, "EQUIPMENT INSPECTOR")
	_component_name = Label.new()
	_component_name.text = "Pressure shell"
	_component_name.add_theme_font_size_override("font_size", 18)
	sidebar.add_child(_component_name)
	_component_circuit = Label.new()
	_component_circuit.text = "Shell side"
	_component_circuit.add_theme_color_override("font_color", Color("#4da6d5"))
	sidebar.add_child(_component_circuit)
	_component_description = Label.new()
	_component_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(_component_description)
	_on_equipment_component_selected("shell")

func _add_section_header(parent: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#718994"))
	parent.add_child(label)

func _add_spin_input(parent: VBoxContainer, key: String, label_text: String, min_value: float, max_value: float, step_value: float, decimals: int, initial_value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.name = key
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step_value
	spin.value = initial_value
	spin.rounded = false
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.custom_minimum_size.x = 104
	spin.get_line_edit().add_theme_font_size_override("font_size", 11)
	spin.value_changed.connect(_recalculate)
	_inputs[key] = spin
	row.add_child(spin)
	parent.add_child(row)

func _add_reading(parent: VBoxContainer, key: String, caption: String, initial_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)
	var value := Label.new()
	value.name = key
	value.text = initial_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", Color("#d4e1e4"))
	row.add_child(value)
	_result_labels[key] = value
	parent.add_child(row)

func _add_view_button(parent: HBoxContainer, label: String, mode: String) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(func() -> void: _set_active_view(mode))
	parent.add_child(button)

func _on_equipment_type_selected(index: int) -> void:
	_is_double_pipe = index == 1
	_shell_equipment.visible = not _is_double_pipe
	_double_pipe_equipment.visible = _is_double_pipe
	_active_equipment = _double_pipe_equipment if _is_double_pipe else _shell_equipment
	if _is_double_pipe and _arrangement_selector.selected == 2:
		_arrangement_selector.select(0)
	if not _is_double_pipe:
		_arrangement_selector.select(2)
	_refresh_equipment_state()
	_on_equipment_component_selected("outer_pipe" if _is_double_pipe else "shell")
	_on_arrangement_selected(_arrangement_selector.selected)

func _on_arrangement_selected(_index: int) -> void:
	if _arrangement_selector == null: return
	var selection := _arrangement_selector.selected
	_arrangement_selector.set_item_disabled(2, _is_double_pipe)
	if _is_double_pipe and selection == 2:
		_arrangement_selector.select(0)
		selection = 0
	elif not _is_double_pipe and selection != 2:
		_arrangement_selector.select(2)
		selection = 2
	if _view_status != null:
		_view_status.text = "ONE SHELL PASS · TWO TUBE PASSES · SEGMENTAL BAFFLES" if not _is_double_pipe else ("DOUBLE-PIPE · PARALLEL FLOW" if selection == 1 else "DOUBLE-PIPE · COUNTER-CURRENT FLOW")
	_recalculate()

func _set_active_view(mode: String) -> void:
	if _active_equipment == null: return
	if _is_double_pipe:
		_active_equipment.call("set_view_mode", mode if mode in ["external", "cutaway", "flow"] else "cutaway")
	else:
		_active_equipment.call("set_view_mode", "cutaway" if mode == "flow" else mode)

func _restore_assembled() -> void:
	if _active_equipment != null:
		_active_equipment.call("restore_assembled")

func _reset_operating_conditions() -> void:
	for key in DEFAULT_INPUTS:
		if _inputs.has(key):
			_inputs[key].value = float(DEFAULT_INPUTS[key])
	_recalculate()

func _recalculate(_value: float = 0.0) -> void:
	if _inputs.is_empty(): return
	var configuration := NTU.Configuration.SHELL_ONE_PASS
	if _is_double_pipe:
		configuration = NTU.Configuration.PARALLEL_FLOW if _arrangement_selector.selected == 1 else NTU.Configuration.COUNTER_CURRENT
	var inputs := {
		"hot_in_k": float(_inputs["hot_in_c"].value) + 273.15,
		"cold_in_k": float(_inputs["cold_in_c"].value) + 273.15,
		"hot_mass_flow_kg_s": float(_inputs["hot_mass_flow_kg_s"].value),
		"cold_mass_flow_kg_s": float(_inputs["cold_mass_flow_kg_s"].value),
		"hot_cp_j_kg_k": 4180.0,
		"cold_cp_j_kg_k": 4180.0,
		"area_m2": float(_inputs["area_m2"].value),
		"u_clean_w_m2_k": float(_inputs["u_clean_w_m2_k"].value),
		"fouling_hot_m2_k_w": float(_inputs["fouling_hot_m2_k_w"].value),
		"fouling_cold_m2_k_w": float(_inputs["fouling_cold_m2_k_w"].value),
		"configuration": configuration
	}
	var result: Dictionary = Model.solve_design(inputs)
	if not result.get("ok", false):
		_readings = {}
		_set_reading("heat_duty", "INVALID")
		_set_reading("outlets", "INVALID")
		_set_reading("thermal", "INVALID")
		_set_reading("pressure", "—")
		_set_reading("flow", "—")
		_set_reading("balance", str(result.get("error", "Invalid operating conditions.")))
		_refresh_equipment_state()
		set_status("MODEL INPUT ERROR  ·  %s" % str(result.get("error", "Check operating conditions.")))
		return
	_readings = inputs.duplicate(true)
	_readings.merge(result, true)
	var pressure_hot: Dictionary = PressureDrop.calculate(float(inputs["hot_mass_flow_kg_s"]), WATER_DENSITY_KG_M3, WATER_VISCOSITY_PA_S, EQUIVALENT_LENGTH_M, EQUIVALENT_DIAMETER_M, EQUIVALENT_AREA_M2, EQUIVALENT_ROUGHNESS_M, EQUIVALENT_MINOR_K)
	var pressure_cold: Dictionary = PressureDrop.calculate(float(inputs["cold_mass_flow_kg_s"]), WATER_DENSITY_KG_M3, WATER_VISCOSITY_PA_S, EQUIVALENT_LENGTH_M, EQUIVALENT_DIAMETER_M, EQUIVALENT_AREA_M2, EQUIVALENT_ROUGHNESS_M, EQUIVALENT_MINOR_K)
	_readings["hot_pressure_drop_pa"] = pressure_hot.get("total_drop_pa", 0.0)
	_readings["cold_pressure_drop_pa"] = pressure_cold.get("total_drop_pa", 0.0)
	_set_reading("heat_duty", "%.2f kW" % (float(result["heat_duty_w"]) / 1000.0))
	_set_reading("outlets", "%.1f / %.1f °C" % [float(result["hot_out_k"]) - 273.15, float(result["cold_out_k"]) - 273.15])
	_set_reading("thermal", "%.1f · %.3f · %.2f" % [float(result["u_effective_w_m2_k"]), float(result["effectiveness"]), float(result["ntu"])])
	_set_reading("pressure", "%.2f / %.2f kPa" % [float(pressure_hot.get("total_drop_pa", 0.0)) / 1000.0, float(pressure_cold.get("total_drop_pa", 0.0)) / 1000.0])
	_set_reading("flow", "%.2f / %.2f kg/s" % [float(inputs["hot_mass_flow_kg_s"]), float(inputs["cold_mass_flow_kg_s"])])
	var balance: Dictionary = result.get("energy_balance", {})
	_set_reading("balance", "%.4f%% discrepancy" % (float(balance.get("relative_discrepancy", 0.0)) * 100.0))
	_refresh_equipment_state()
	set_status("MODEL UPDATED  ·  %s  ·  %s" % ["DOUBLE-PIPE" if _is_double_pipe else "SHELL-AND-TUBE", "PARALLEL" if _is_double_pipe and configuration == NTU.Configuration.PARALLEL_FLOW else ("COUNTER-CURRENT" if _is_double_pipe else "ONE SHELL PASS")])

func _refresh_equipment_state() -> void:
	if _shell_equipment != null:
		_shell_equipment.call("set_operating_state", _readings)
	if _double_pipe_equipment != null:
		var is_parallel := _is_double_pipe and _arrangement_selector.selected == 1
		_double_pipe_equipment.call("set_operating_state", _readings, is_parallel)

func _set_reading(key: String, text_value: String) -> void:
	if _result_labels.has(key):
		_result_labels[key].text = text_value

func _on_equipment_component_selected(component_id: String) -> void:
	if _active_equipment == null or _component_name == null: return
	var info: Dictionary = _active_equipment.call("component_info", component_id)
	_component_name.text = str(info.get("name", "Component"))
	_component_circuit.text = str(info.get("fluid", "Equipment"))
	_component_description.text = str(info.get("description", ""))

func _on_view_mode_changed(mode: String) -> void:
	if _view_status == null: return
	_view_status.text = "%s  ·  %s" % [mode.to_upper(), "DOUBLE-PIPE" if _is_double_pipe else "ONE SHELL PASS / TWO TUBE PASSES"]
