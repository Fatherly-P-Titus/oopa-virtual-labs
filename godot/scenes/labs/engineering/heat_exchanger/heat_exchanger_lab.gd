extends LabShell
## Shared-shell controller for the M11 heat exchanger laboratory.

const EQUIPMENT_SCENE := preload("res://scenes/labs/engineering/heat_exchanger/equipment/shell_and_tube_equipment.tscn")

var _equipment: Control
var _component_name: Label
var _component_circuit: Label
var _component_description: Label
var _view_status: Label

func _ready() -> void:
	lab_title = "Heat Exchanger Design & Simulation"
	lab_eyebrow = "ENGINEERING  /  THERMAL SYSTEMS"
	lab_lead = "Investigate shell-and-tube and double-pipe heat exchangers through model-driven operation and engineering analysis."
	field_id = "engineering"
	page_id = "heat_exchanger"
	back_label = "← Engineering"
	super._ready()
	_build_equipment_workspace()
	_build_equipment_inspector()
	_build_equipment_legend()
	set_status("M11.3A  ·  SHELL-AND-TUBE EQUIPMENT")


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
	_add_view_button(toolbar, "External", "external")
	_add_view_button(toolbar, "Cutaway", "cutaway")
	_add_view_button(toolbar, "Exploded", "exploded")
	var restore := Button.new()
	restore.text = "Restore assembled"
	restore.tooltip_text = "Return all components to the assembled external view."
	restore.pressed.connect(func() -> void: _equipment.call("restore_assembled"))
	toolbar.add_child(restore)
	_view_status = Label.new()
	_view_status.text = "ONE SHELL PASS  ·  TWO TUBE PASSES  ·  SEGMENTAL BAFFLES"
	_view_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_view_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view_status.add_theme_font_size_override("font_size", 10)
	_view_status.add_theme_color_override("font_color", Color("#718994"))
	toolbar.add_child(_view_status)
	_equipment = EQUIPMENT_SCENE.instantiate()
	_equipment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment.connect("component_selected", _on_equipment_component_selected)
	_equipment.connect("view_mode_changed", _on_view_mode_changed)
	layout.add_child(_equipment)


func _build_equipment_inspector() -> void:
	var sidebar := get_sidebar()
	if sidebar == null: return
	sidebar.add_theme_constant_override("separation", 10)
	var header := Label.new()
	header.text = "EQUIPMENT INSPECTOR"
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color("#718994"))
	sidebar.add_child(header)
	_component_name = Label.new()
	_component_name.text = "Pressure shell"
	_component_name.add_theme_font_size_override("font_size", 20)
	sidebar.add_child(_component_name)
	_component_circuit = Label.new()
	_component_circuit.text = "Shell side"
	_component_circuit.add_theme_color_override("font_color", Color("#4da6d5"))
	sidebar.add_child(_component_circuit)
	_component_description = Label.new()
	_component_description.text = "Select an exchanger component to inspect its role."
	_component_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(_component_description)
	var separator := HSeparator.new()
	sidebar.add_child(separator)
	var config := Label.new()
	config.text = "SELECTED CONFIGURATION\n1 shell pass · 2 tube passes\nSegmental baffles · horizontal shell"
	config.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	config.add_theme_font_size_override("font_size", 12)
	sidebar.add_child(config)
	var note := Label.new()
	note.text = "Representative educational geometry. Live temperatures, flows and pressures are not connected in M11.3."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color("#c7954b"))
	sidebar.add_child(note)
	_on_equipment_component_selected("shell")


func _build_equipment_legend() -> void:
	var extra := get_extra()
	if extra == null: return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = "PATHWAY KEY"
	title.add_theme_font_size_override("font_size", 10)
	row.add_child(title)
	_add_legend_item(row, Color("#ef795f"), "Tube-side pass (representative)")
	_add_legend_item(row, Color("#48a8e8"), "Shell-side cross-flow (representative)")
	var disclaimer := Label.new()
	disclaimer.text = "Illustrative flow paths · no CFD"
	disclaimer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	disclaimer.add_theme_font_size_override("font_size", 10)
	disclaimer.add_theme_color_override("font_color", Color("#718994"))
	row.add_child(disclaimer)
	extra.add_child(row)


func _add_view_button(parent: HBoxContainer, label: String, mode: String) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(func() -> void: _equipment.call("set_view_mode", mode))
	parent.add_child(button)


func _add_legend_item(parent: HBoxContainer, tint: Color, text_value: String) -> void:
	var marker := ColorRect.new()
	marker.color = tint
	marker.custom_minimum_size = Vector2(16, 4)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(marker)
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 10)
	parent.add_child(label)


func _on_equipment_component_selected(component_id: String) -> void:
	if _equipment == null or _component_name == null: return
	var info: Dictionary = _equipment.call("component_info", component_id)
	_component_name.text = str(info.get("name", "Component"))
	_component_circuit.text = str(info.get("fluid", "Equipment"))
	_component_description.text = str(info.get("description", ""))


func _on_view_mode_changed(mode: String) -> void:
	if _view_status == null: return
	_view_status.text = "%s  ·  ONE SHELL PASS / TWO TUBE PASSES" % mode.to_upper()
