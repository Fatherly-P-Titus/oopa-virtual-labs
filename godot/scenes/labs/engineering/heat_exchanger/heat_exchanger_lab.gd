extends LabShell
## M11 heat-exchanger equipment and model-driven operation workspace.

const SHELL_SCENE := preload("res://scenes/labs/engineering/heat_exchanger/equipment/shell_and_tube_equipment.tscn")
const DOUBLE_PIPE_SCENE := preload("res://scenes/labs/engineering/heat_exchanger/equipment/double_pipe_equipment.tscn")
const Model := preload("res://scripts/models/engineering/heat_exchanger/heat_exchanger_model.gd")
const NTU := preload("res://scripts/models/engineering/heat_exchanger/effectiveness_ntu_model.gd")
const PressureDrop := preload("res://scripts/models/engineering/heat_exchanger/pressure_drop_model.gd")
const Chart := preload("res://scenes/labs/engineering/heat_exchanger/interface/heat_exchanger_chart.gd")

const EXPERIMENTS := [
	{"title": "1 · Flow arrangement", "objective": "Compare parallel and counter-current temperature profiles at the same operating inputs.", "steps": "Select the double-pipe exchanger. Switch between parallel and counter-current flow, then compare the model-derived outlet temperatures and profile endpoints.", "equipment": 1, "arrangement": 0, "inputs": {}},
	{"title": "2 · Flow-rate investigation", "objective": "Observe how each stream's mass flow rate changes heat duty and outlet temperatures.", "steps": "Change one flow rate at a time. Compare the flow-sweep chart and record the duty and outlet response for each stream.", "equipment": 1, "arrangement": 0, "inputs": {"hot_mass_flow_kg_s": 0.2, "cold_mass_flow_kg_s": 0.2}},
	{"title": "3 · Heat-transfer area", "objective": "Investigate how available transfer area affects duty and effectiveness.", "steps": "Start from 6 m², increase area in steps, and compare calculated duty, effectiveness, and NTU.", "equipment": 0, "arrangement": 2, "inputs": {"area_m2": 6.0}},
	{"title": "4 · Fouling investigation", "objective": "Compare clean and fouled performance through the validated fouling resistance model.", "steps": "Start at 0.0015 m²·K/W on both sides. Reduce both resistances toward zero and compare effective U and heat duty.", "equipment": 0, "arrangement": 2, "inputs": {"fouling_hot_m2_k_w": 0.0015, "fouling_cold_m2_k_w": 0.0015}},
	{"title": "5 · Exchanger comparison", "objective": "Compare supported shell-and-tube and double-pipe configurations under matched conditions.", "steps": "Use the same temperatures, flows, area, U, and fouling values. Switch equipment type; save each case and compare the calculated duties in Analysis.", "equipment": 0, "arrangement": 2, "inputs": {"fouling_hot_m2_k_w": 0.0, "fouling_cold_m2_k_w": 0.0}},
	{"title": "6 · Performance troubleshooting", "objective": "Use instruments and model results to identify reduced performance under low flow and increased fouling.", "steps": "Begin at low cold-side flow with elevated fouling. Inspect pressure and outlet readings; change one cause at a time and save the improved case.", "equipment": 1, "arrangement": 1, "inputs": {"cold_mass_flow_kg_s": 0.08, "fouling_hot_m2_k_w": 0.002, "fouling_cold_m2_k_w": 0.002}}
]

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
var _lab_tabs: TabContainer
var _inputs: Dictionary = {}
var _readings: Dictionary = {}
var _result_labels: Dictionary = {}
var _analysis_labels: Dictionary = {}
var _charts: Dictionary = {}
var _saved_cases: Array[Dictionary] = []
var _case_list: VBoxContainer
var _case_count_label: Label
var _experiment_selector: OptionButton
var _experiment_objective: Label
var _experiment_steps: Label
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
	_lab_tabs = TabContainer.new()
	_lab_tabs.name = "HeatExchangerPages"
	_lab_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lab_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_lab_tabs)
	var equipment_page := VBoxContainer.new()
	equipment_page.name = "Equipment"
	equipment_page.add_theme_constant_override("separation", 8)
	_lab_tabs.add_child(equipment_page)
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
		equipment_page.add_child(equipment)
	_double_pipe_equipment.hide()
	_active_equipment = _shell_equipment
	_build_analysis_page()
	_build_experiments_page()

func _build_analysis_page() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Analysis"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lab_tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var heading := Label.new()
	heading.text = "ENGINEERING RESULTS & ANALYSIS"
	heading.add_theme_font_size_override("font_size", 16)
	content.add_child(heading)
	var note := Label.new()
	note.text = "All readings and plotted points are recalculated from the active M11 model inputs. Endpoint profiles are linear illustrations, not local temperature fields."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color("#91a5ad"))
	content.add_child(note)
	var metrics := GridContainer.new()
	metrics.columns = 3
	metrics.add_theme_constant_override("h_separation", 8)
	metrics.add_theme_constant_override("v_separation", 8)
	content.add_child(metrics)
	_add_analysis_metric(metrics, "duty", "HEAT DUTY", "—")
	_add_analysis_metric(metrics, "outlets", "HOT / COLD OUTLET", "—")
	_add_analysis_metric(metrics, "lmtd", "LMTD", "—")
	_add_analysis_metric(metrics, "u_effective", "EFFECTIVE U", "—")
	_add_analysis_metric(metrics, "ntu", "EFFECTIVENESS / NTU", "—")
	_add_analysis_metric(metrics, "fouling", "FOULING DUTY IMPACT", "—")
	_add_analysis_metric(metrics, "area", "HEAT-TRANSFER AREA", "—")
	_add_analysis_metric(metrics, "pressure", "EQUIVALENT ΔP · HOT / COLD", "—")
	_add_analysis_metric(metrics, "balance", "ENERGY BALANCE DISCREPANCY", "—")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	_add_chart(grid, "temperature", "Temperature profiles", Vector2(340, 240))
	_add_chart(grid, "flow", "Heat duty vs flow", Vector2(340, 240))
	_add_chart(grid, "fouling", "Heat duty vs fouling", Vector2(340, 240))
	_add_chart(grid, "comparison", "Performance comparison", Vector2(340, 240))
	var case_header := HBoxContainer.new()
	content.add_child(case_header)
	var case_title := Label.new()
	case_title.text = "SESSION COMPARISON CASES"
	case_title.add_theme_font_size_override("font_size", 11)
	case_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	case_header.add_child(case_title)
	_case_count_label = Label.new()
	_case_count_label.text = "0 / 4 saved"
	_case_count_label.add_theme_font_size_override("font_size", 10)
	case_header.add_child(_case_count_label)
	var case_actions := HBoxContainer.new()
	var save_case := Button.new()
	save_case.name = "SaveComparisonCase"
	save_case.text = "Save current case"
	save_case.pressed.connect(_save_comparison_case)
	case_actions.add_child(save_case)
	var clear_cases := Button.new()
	clear_cases.text = "Clear saved cases"
	clear_cases.pressed.connect(_clear_comparison_cases)
	case_actions.add_child(clear_cases)
	content.add_child(case_actions)
	_case_list = VBoxContainer.new()
	_case_list.add_theme_constant_override("separation", 3)
	content.add_child(_case_list)
	var principle := Label.new()
	principle.text = "MODEL NOTES\nQ = ε·Cmin·(Th,in − Tc,in) by the supported E–NTU configuration. Fouling lowers Ueff through added thermal resistance. A shell-and-tube one-shell-pass result uses the supported shell relation; LMTD is intentionally omitted for that configuration. Double-pipe LMTD is calculated only when its terminal differences are positive."
	principle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	principle.add_theme_font_size_override("font_size", 10)
	principle.add_theme_color_override("font_color", Color("#b5c7cb"))
	content.add_child(principle)

func _add_analysis_metric(parent: GridContainer, key: String, title: String, initial_value: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 56)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 9)
	heading.add_theme_color_override("font_color", Color("#8298a1"))
	column.add_child(heading)
	var value := Label.new()
	value.name = key
	value.text = initial_value
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", Color("#e1ebed"))
	column.add_child(value)
	_analysis_labels[key] = value
	parent.add_child(panel)

func _add_chart(parent: GridContainer, key: String, title: String, minimum: Vector2) -> void:
	var chart: Control = Chart.new()
	chart.name = "%sChart" % key.capitalize()
	chart.custom_minimum_size = minimum
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_charts[key] = chart
	parent.add_child(chart)

func _build_experiments_page() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Experiments"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lab_tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var heading := Label.new()
	heading.text = "GUIDED ENGINEERING INVESTIGATIONS"
	heading.add_theme_font_size_override("font_size", 16)
	content.add_child(heading)
	var instruction := Label.new()
	instruction.text = "Choose an investigation to load a reproducible starting condition. The operating controls remain editable; record results by saving a comparison case on the Analysis tab."
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_font_size_override("font_size", 11)
	content.add_child(instruction)
	_experiment_selector = OptionButton.new()
	_experiment_selector.name = "ExperimentSelector"
	for experiment in EXPERIMENTS: _experiment_selector.add_item(str(experiment["title"]))
	_experiment_selector.item_selected.connect(_on_experiment_selected)
	content.add_child(_experiment_selector)
	_experiment_objective = Label.new()
	_experiment_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_experiment_objective.add_theme_font_size_override("font_size", 14)
	content.add_child(_experiment_objective)
	_experiment_steps = Label.new()
	_experiment_steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_experiment_steps.add_theme_font_size_override("font_size", 11)
	content.add_child(_experiment_steps)
	var measurable := Label.new()
	measurable.text = "MEASURE AND COMPARE\nRecord heat duty (kW), hot/cold outlet temperatures (°C), effective U (W/m²K), effectiveness, NTU, and the equivalent hot/cold pressure estimates (kPa). On the comparison case chart, keep configurations and operating inputs visible when interpreting differences."
	measurable.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	measurable.add_theme_font_size_override("font_size", 11)
	measurable.add_theme_color_override("font_color", Color("#a9bdc3"))
	content.add_child(measurable)
	var actions := HBoxContainer.new()
	var apply := Button.new()
	apply.name = "ApplyExperimentSetup"
	apply.text = "Load starting conditions"
	apply.pressed.connect(_apply_experiment_setup)
	actions.add_child(apply)
	var analysis_button := Button.new()
	analysis_button.text = "Open analysis"
	analysis_button.pressed.connect(func() -> void: _lab_tabs.current_tab = 1)
	actions.add_child(analysis_button)
	content.add_child(actions)
	_on_experiment_selected(0)

func _on_experiment_selected(index: int) -> void:
	if index < 0 or index >= EXPERIMENTS.size(): return
	var experiment: Dictionary = EXPERIMENTS[index]
	_experiment_objective.text = "OBJECTIVE\n" + str(experiment["objective"])
	_experiment_steps.text = "PROCEDURE\n" + str(experiment["steps"])

func _apply_experiment_setup() -> void:
	if _experiment_selector == null: return
	var experiment: Dictionary = EXPERIMENTS[_experiment_selector.selected]
	_equipment_selector.select(int(experiment["equipment"]))
	_on_equipment_type_selected(int(experiment["equipment"]))
	_arrangement_selector.select(int(experiment["arrangement"]))
	_on_arrangement_selected(int(experiment["arrangement"]))
	var values: Dictionary = experiment.get("inputs", {})
	for key in values:
		if _inputs.has(key):
			_inputs[key].set_block_signals(true)
			_inputs[key].value = float(values[key])
			_inputs[key].set_block_signals(false)
	_recalculate()
	_lab_tabs.current_tab = 0

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
			_inputs[key].set_block_signals(true)
			_inputs[key].value = float(DEFAULT_INPUTS[key])
			_inputs[key].set_block_signals(false)
	_recalculate()

func _recalculate(_value: float = 0.0) -> void:
	if _inputs.is_empty(): return
	var inputs := _collect_inputs()
	var configuration := int(inputs["configuration"])
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
		_refresh_analysis_invalid(str(result.get("error", "Invalid operating conditions.")))
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
	_refresh_analysis(inputs, result)
	set_status("MODEL UPDATED  ·  %s  ·  %s" % ["DOUBLE-PIPE" if _is_double_pipe else "SHELL-AND-TUBE", "PARALLEL" if _is_double_pipe and configuration == NTU.Configuration.PARALLEL_FLOW else ("COUNTER-CURRENT" if _is_double_pipe else "ONE SHELL PASS")])

func _collect_inputs() -> Dictionary:
	var configuration := NTU.Configuration.SHELL_ONE_PASS
	if _is_double_pipe:
		configuration = NTU.Configuration.PARALLEL_FLOW if _arrangement_selector.selected == 1 else NTU.Configuration.COUNTER_CURRENT
	return {
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

func _refresh_analysis(inputs: Dictionary, result: Dictionary) -> void:
	if _charts.is_empty(): return
	_analysis_labels["duty"].text = "%.2f kW" % (float(result["heat_duty_w"]) / 1000.0)
	_analysis_labels["outlets"].text = "%.1f / %.1f °C" % [float(result["hot_out_k"]) - 273.15, float(result["cold_out_k"]) - 273.15]
	_analysis_labels["lmtd"].text = "%.2f K" % float(result["lmtd_k"]) if result.has("lmtd_k") else "Not evaluated · shell E–NTU"
	_analysis_labels["u_effective"].text = "%.1f W/m²K" % float(result["u_effective_w_m2_k"])
	_analysis_labels["ntu"].text = "%.3f · %.2f" % [float(result["effectiveness"]), float(result["ntu"])]
	_analysis_labels["area"].text = "%.2f m²" % float(result["area_m2"])
	_analysis_labels["pressure"].text = "%.2f / %.2f kPa" % [float(_readings.get("hot_pressure_drop_pa", 0.0)) / 1000.0, float(_readings.get("cold_pressure_drop_pa", 0.0)) / 1000.0]
	var balance: Dictionary = result.get("energy_balance", {})
	_analysis_labels["balance"].text = "%.4f%%" % (float(balance.get("relative_discrepancy", 0.0)) * 100.0)
	var clean_inputs := inputs.duplicate(true)
	clean_inputs["fouling_hot_m2_k_w"] = 0.0
	clean_inputs["fouling_cold_m2_k_w"] = 0.0
	var clean_result: Dictionary = Model.solve_design(clean_inputs)
	var fouling_impact := 0.0
	if clean_result.get("ok", false) and float(clean_result["heat_duty_w"]) > 0.0:
		fouling_impact = maxf(0.0, 1.0 - float(result["heat_duty_w"]) / float(clean_result["heat_duty_w"])) * 100.0
	_analysis_labels["fouling"].text = "%.1f%% duty reduction vs clean" % fouling_impact
	_refresh_temperature_chart(inputs, result)
	_refresh_flow_chart(inputs)
	_refresh_fouling_chart(inputs)
	_refresh_comparison_chart(inputs)
	_refresh_case_list()

func _refresh_analysis_invalid(message: String) -> void:
	if _charts.is_empty(): return
	for key in _analysis_labels: _analysis_labels[key].text = "INVALID"
	for key in _charts:
		if key == "comparison":
			var no_categories: Array[String] = []
			_charts[key].call("set_bar_chart", "Performance comparison", "Invalid inputs · no results plotted", "Duty · kW", no_categories, [])
		else:
			_charts[key].call("set_line_chart", key.capitalize(), message, "", "", [])
	if _case_count_label != null: _case_count_label.text = "%d / 4 saved" % _saved_cases.size()

func _refresh_temperature_chart(inputs: Dictionary, result: Dictionary) -> void:
	var hot_values: Array[Vector2] = []
	var cold_values: Array[Vector2] = []
	var counter_current := int(inputs["configuration"]) != NTU.Configuration.PARALLEL_FLOW
	for i in range(11):
		var fraction := float(i) / 10.0
		hot_values.append(Vector2(fraction, lerpf(float(inputs["hot_in_k"]), float(result["hot_out_k"]), fraction) - 273.15))
		var cold_fraction := 1.0 - fraction if counter_current else fraction
		cold_values.append(Vector2(fraction, lerpf(float(inputs["cold_in_k"]), float(result["cold_out_k"]), cold_fraction) - 273.15))
	var suffix := "parallel flow"
	if int(inputs["configuration"]) == NTU.Configuration.COUNTER_CURRENT:
		suffix = "counter-current flow"
	elif int(inputs["configuration"]) == NTU.Configuration.SHELL_ONE_PASS:
		suffix = "one-shell-pass endpoint illustration; shell crossflow not resolved"
	_charts["temperature"].call("set_line_chart", "Temperature profiles", "Model-derived endpoints · linear illustration · %s" % suffix, "Normalized exchanger length", "Temperature · °C", [
		{"label": "Hot stream", "color": Color("#ef795f"), "values": hot_values},
		{"label": "Cold stream", "color": Color("#55a9db"), "values": cold_values}
	])

func _refresh_flow_chart(inputs: Dictionary) -> void:
	var hot_values: Array[Vector2] = []
	var cold_values: Array[Vector2] = []
	for i in range(11):
		var multiplier := lerpf(0.5, 1.5, float(i) / 10.0)
		var hot_case := inputs.duplicate(true)
		hot_case["hot_mass_flow_kg_s"] = clampf(float(inputs["hot_mass_flow_kg_s"]) * multiplier, 0.01, 20.0)
		var hot_result: Dictionary = Model.solve_design(hot_case)
		if hot_result.get("ok", false): hot_values.append(Vector2(multiplier, float(hot_result["heat_duty_w"]) / 1000.0))
		var cold_case := inputs.duplicate(true)
		cold_case["cold_mass_flow_kg_s"] = clampf(float(inputs["cold_mass_flow_kg_s"]) * multiplier, 0.01, 20.0)
		var cold_result: Dictionary = Model.solve_design(cold_case)
		if cold_result.get("ok", false): cold_values.append(Vector2(multiplier, float(cold_result["heat_duty_w"]) / 1000.0))
	_charts["flow"].call("set_line_chart", "Heat duty vs flow", "Vary one stream at a time · other stream held at current input", "Flow multiplier · × baseline", "Duty · kW", [
		{"label": "Hot flow", "color": Color("#ef795f"), "values": hot_values},
		{"label": "Cold flow", "color": Color("#55a9db"), "values": cold_values}
	])

func _refresh_fouling_chart(inputs: Dictionary) -> void:
	var values: Array[Vector2] = []
	var max_total := minf(0.01, maxf(0.002, 2.0 * (float(inputs["fouling_hot_m2_k_w"]) + float(inputs["fouling_cold_m2_k_w"]))))
	for i in range(11):
		var total := max_total * float(i) / 10.0
		var fouled := inputs.duplicate(true)
		fouled["fouling_hot_m2_k_w"] = total * 0.5
		fouled["fouling_cold_m2_k_w"] = total * 0.5
		var result: Dictionary = Model.solve_design(fouled)
		if result.get("ok", false): values.append(Vector2(total, float(result["heat_duty_w"]) / 1000.0))
	_charts["fouling"].call("set_line_chart", "Heat duty vs fouling resistance", "Hot and cold fouling resistance varied equally", "Total fouling resistance · m²K/W", "Duty · kW", [
		{"label": "Model heat duty", "color": Color("#d5ad63"), "values": values}
	])

func _refresh_comparison_chart(current_inputs: Dictionary) -> void:
	var series: Array = []
	var colors := [Color("#61b5e8"), Color("#ef795f"), Color("#91c98c"), Color("#c18ada"), Color("#d5ad63")]
	var scenarios: Array[Dictionary] = [{"label": "Current", "inputs": current_inputs, "arrangement": _arrangement_selector.selected}]
	for saved_case in _saved_cases:
		scenarios.append(saved_case)
	for i in range(scenarios.size()):
		var item: Dictionary = scenarios[i]
		var scenario_inputs: Dictionary = item["inputs"]
		var shell_case := scenario_inputs.duplicate(true)
		shell_case["configuration"] = NTU.Configuration.SHELL_ONE_PASS
		var pipe_case := scenario_inputs.duplicate(true)
		var saved_arrangement := int(item.get("arrangement", 0))
		pipe_case["configuration"] = NTU.Configuration.PARALLEL_FLOW if saved_arrangement == 1 else NTU.Configuration.COUNTER_CURRENT
		var shell_result: Dictionary = Model.solve_design(shell_case)
		var pipe_result: Dictionary = Model.solve_design(pipe_case)
		if shell_result.get("ok", false) and pipe_result.get("ok", false):
			series.append({"label": str(item["label"]), "color": colors[i % colors.size()], "values": [float(shell_result["heat_duty_w"]) / 1000.0, float(pipe_result["heat_duty_w"]) / 1000.0]})
	var categories: Array[String] = ["Shell · 1 shell pass", "Double · selected arrangement"]
	_charts["comparison"].call("set_bar_chart", "Exchanger performance comparison", "Matched input conditions per saved case · supported configuration per equipment", "Heat duty · kW", categories, series)

func _save_comparison_case() -> void:
	if _readings.is_empty():
		set_status("SAVE CASE FAILED  ·  correct invalid operating conditions first")
		return
	if _saved_cases.size() >= 4:
		set_status("COMPARISON LIMIT  ·  clear saved cases to add another")
		return
	var config_label := "Shell · one pass" if not _is_double_pipe else ("Double · parallel" if _arrangement_selector.selected == 1 else "Double · counter-current")
	_saved_cases.append({"label": "Case %d · %s" % [_saved_cases.size() + 1, config_label], "inputs": _collect_inputs(), "arrangement": _arrangement_selector.selected})
	_refresh_analysis(_collect_inputs(), _readings)
	set_status("SAVED COMPARISON CASE  ·  %d / 4" % _saved_cases.size())

func _clear_comparison_cases() -> void:
	_saved_cases.clear()
	_refresh_case_list()
	if not _readings.is_empty(): _refresh_comparison_chart(_collect_inputs())
	set_status("SESSION COMPARISON CASES CLEARED")

func _refresh_case_list() -> void:
	if _case_list == null: return
	for child in _case_list.get_children():
		_case_list.remove_child(child)
		child.queue_free()
	for saved_case in _saved_cases:
		var case_inputs: Dictionary = saved_case["inputs"]
		var result: Dictionary = Model.solve_design(case_inputs)
		var row := Label.new()
		row.text = "%s  ·  %.2f kW" % [str(saved_case["label"]), float(result.get("heat_duty_w", 0.0)) / 1000.0] if result.get("ok", false) else "%s  ·  invalid" % str(saved_case["label"])
		row.add_theme_font_size_override("font_size", 10)
		_case_list.add_child(row)
	if _case_count_label != null: _case_count_label.text = "%d / 4 saved" % _saved_cases.size()

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
