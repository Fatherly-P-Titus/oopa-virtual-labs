extends LabShell
## Production controller for the digital Boolean circuit laboratory.

const MODEL_SCRIPT := preload("res://scripts/models/engineering/logic_circuit_model.gd")
const CANVAS_SCRIPT := preload("res://labs/engineering/logic_gate_builder/scripts/logic_gate_canvas.gd")

var model: RefCounted
var canvas: Control
var selected_id := -1
var wire_source_id := -1
var status_label: Label
var selected_summary: VBoxContainer
var output_summary: HBoxContainer
var truth_body: GridContainer
var truth_scroll: ScrollContainer
var truth_heading: Label
var _truth_signature := ""
var _dragging_library_kind := ""

func _ready() -> void:
	lab_title = "Logic Gate Builder"
	lab_eyebrow = "ENGINEERING  /  DIGITAL LOGIC"
	lab_lead = "Construct Boolean circuits, trace signal states, and verify outputs with a generated truth table."
	field_id = "engineering"
	page_id = "logic_gate_builder"
	back_label = "← Engineering"
	super._ready()
	model = MODEL_SCRIPT.new()
	model.reset_to_starter()
	_build_workspace()
	_build_properties()
	_build_results()
	model.changed.connect(_on_model_changed)
	_refresh()


func _build_workspace() -> void:
	var stage := get_stage()
	if stage == null:
		push_error("Logic Gate Builder: shared workspace stage is missing")
		return
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8)
	add_to_stage(shell)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	shell.add_child(toolbar)
	_add_button(toolbar, "New", _new_circuit, false)
	_add_button(toolbar, "Starter", _starter_circuit, false)
	_add_button(toolbar, "Half-adder", _half_adder, false)
	_add_button(toolbar, "Evaluate", _evaluate, true)
	_add_button(toolbar, "Truth table", _show_truth_table, true)
	var zoom_out := _add_button(toolbar, "−", func() -> void: canvas.call("zoom_step", -1), false)
	zoom_out.tooltip_text = "Zoom out"
	var zoom_in := _add_button(toolbar, "+", func() -> void: canvas.call("zoom_step", 1), false)
	zoom_in.tooltip_text = "Zoom in"
	var help := Label.new()
	help.text = "Drag a library part onto the board"
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("#718994"))
	help.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(help)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	shell.add_child(body)
	var library := VBoxContainer.new()
	library.add_theme_constant_override("separation", 6)
	var library_scroll := ScrollContainer.new()
	library_scroll.custom_minimum_size.x = 148
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(library_scroll)
	library_scroll.add_child(library)
	library.add_child(_section_label("COMPONENTS"))
	library.add_child(_section_label("INPUTS"))
	_add_library_component(library, "INPUT", "Input switch", "One binary signal source (0 or 1).")
	library.add_child(_section_label("LOGIC GATES"))
	for gate_kind in ["AND", "OR", "NOT", "NAND", "NOR", "XOR", "XNOR"]:
		var gate_inputs := 1 if gate_kind == "NOT" else 2
		var terminals := "one input" if gate_inputs == 1 else "two inputs (A/B)"
		_add_library_component(library, gate_kind, gate_kind + " gate", "%s gate · %s, one output (Y)." % [gate_kind, terminals])
	library.add_child(_section_label("OUTPUTS"))
	_add_library_component(library, "OUTPUT", "Output lamp", "Displays one evaluated input signal.")
	var library_note := Label.new()
	library_note.text = "Click to place or drag onto the board. Connect Y to A/B."
	library_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library_note.add_theme_font_size_override("font_size", 10)
	library_note.add_theme_color_override("font_color", Color("#718994"))
	library.add_child(library_note)
	canvas = CANVAS_SCRIPT.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.connect("component_selected", _on_selected)
	canvas.connect("input_toggled", _on_input_toggled)
	canvas.connect("connect_requested", _on_connect_requested)
	canvas.connect("component_moved", _on_component_moved)
	canvas.connect("component_delete_requested", _on_delete_component)
	canvas.connect("connection_delete_requested", _on_delete_connection)
	canvas.connect("status_requested", _set_status)
	body.add_child(canvas)
	canvas.call("set_model", model)


func _add_library_component(parent: VBoxContainer, kind: String, label: String, tooltip: String) -> void:
	var drag_button := Button.new()
	drag_button.text = label
	drag_button.custom_minimum_size.y = 34
	drag_button.tooltip_text = tooltip
	drag_button.button_down.connect(func() -> void: _dragging_library_kind = kind)
	drag_button.pressed.connect(func() -> void:
		if canvas != null:
			var center: Vector2 = canvas.call("add_position")
			_add_component(kind, center)
	)
	parent.add_child(drag_button)


func _input(event: InputEvent) -> void:
	if _dragging_library_kind.is_empty(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var kind := _dragging_library_kind
		_dragging_library_kind = ""
		if canvas != null and Rect2(canvas.global_position, canvas.size).has_point(get_global_mouse_position()):
			var local := get_global_mouse_position() - canvas.global_position
			var position: Vector2 = canvas.call("screen_to_world", local)
			_add_component(kind, position)


func _build_properties() -> void:
	var side := get_sidebar()
	if side == null:
		push_error("Logic Gate Builder: shared properties panel is missing")
		return
	side.add_theme_constant_override("separation", 9)
	side.add_child(_section_label("INSPECTOR"))
	selected_summary = VBoxContainer.new()
	selected_summary.add_theme_constant_override("separation", 8)
	side.add_child(selected_summary)
	var separator := HSeparator.new()
	side.add_child(separator)
	side.add_child(_section_label("CIRCUIT ACTIONS"))
	_add_button(side, "Delete selected  ·  Del", _delete_selected, false)
	_add_button(side, "Reset to starter", _starter_circuit, false)
	var guidance := Label.new()
	guidance.text = "Choose a component to inspect it. Input switches can be toggled directly on the board. Select a wire and press Delete to remove it."
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance.add_theme_font_size_override("font_size", 11)
	guidance.add_theme_color_override("font_color", Color("#718994"))
	side.add_child(guidance)


func _build_results() -> void:
	var extra := get_extra()
	if extra == null: return
	var card := PanelContainer.new()
	card.theme_type_variation = &"ScientificCard"
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	card.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var heading := _section_label("LIVE OUTPUTS")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	status_label = Label.new()
	status_label.text = "READY"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color("#2ABCA7"))
	header.add_child(status_label)
	output_summary = HBoxContainer.new()
	output_summary.add_theme_constant_override("separation", 8)
	content.add_child(output_summary)
	var separator := HSeparator.new()
	content.add_child(separator)
	var table_header := HBoxContainer.new()
	content.add_child(table_header)
	truth_heading = _section_label("TRUTH TABLE")
	truth_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_header.add_child(truth_heading)
	var hint := Label.new()
	hint.text = "Generated from current inputs and circuit"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("#718994"))
	table_header.add_child(hint)
	truth_scroll = ScrollContainer.new()
	truth_scroll.custom_minimum_size.y = 94
	truth_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(truth_scroll)
	truth_body = GridContainer.new()
	truth_body.columns = 2
	truth_body.add_theme_constant_override("h_separation", 10)
	truth_body.add_theme_constant_override("v_separation", 3)
	truth_scroll.add_child(truth_body)
	extra.add_child(card)


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#718994"))
	return label


func _add_button(parent: Control, label: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if primary:
		button.theme_type_variation = &"PrimaryButton"
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _refresh() -> void:
	if model == null: return
	var result: Dictionary = model.evaluate()
	if canvas != null:
		canvas.call("set_model", model)
		canvas.call("set_view_state", selected_id, wire_source_id, result)
	_update_status(result)
	_update_outputs(result)
	_update_inspector(result)
	if not _truth_signature.is_empty() and _truth_signature != _circuit_signature():
		_clear_truth_table()


func _update_status(result: Dictionary) -> void:
	if status_label == null: return
	if not result["errors"].is_empty():
		status_label.text = "CIRCUIT ERROR"
		status_label.add_theme_color_override("font_color", Color("#F26B6B"))
	elif not result["complete"]:
		status_label.text = "INCOMPLETE  ·  UNKNOWN SIGNALS"
		status_label.add_theme_color_override("font_color", Color("#E8A93C"))
	else:
		status_label.text = "VALID  ·  COMPLETE"
		status_label.add_theme_color_override("font_color", Color("#2ABCA7"))


func _update_outputs(result: Dictionary) -> void:
	if output_summary == null: return
	for child in output_summary.get_children(): child.queue_free()
	var output_count := 0
	for item in model.components():
		if str(item["kind"]) != MODEL_SCRIPT.OUTPUT: continue
		output_count += 1
		var value := int(result["values"].get(int(item["id"]), MODEL_SCRIPT.UNKNOWN))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(142, 44)
		var label := Label.new()
		label.text = "%s   %s" % [str(item["label"]), model.signal_text(value)]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", _state_color(value))
		card.add_child(label)
		output_summary.add_child(card)
	if output_count == 0:
		var empty := Label.new()
		empty.text = "Add an output lamp to inspect a circuit result."
		empty.add_theme_color_override("font_color", Color("#718994"))
		output_summary.add_child(empty)
	if truth_body != null and truth_body.get_child_count() == 0:
		_show_empty_table("Choose Truth table to generate rows for this circuit.")


func _update_inspector(result: Dictionary) -> void:
	if selected_summary == null: return
	for child in selected_summary.get_children(): child.queue_free()
	var item: Dictionary = model.component(selected_id)
	if item.is_empty():
		var empty := Label.new()
		empty.text = "Nothing selected"
		empty.add_theme_color_override("font_color", Color("#718994"))
		selected_summary.add_child(empty)
		return
	var name := Label.new()
	name.text = str(item["label"]) + "  ·  " + str(item["kind"])
	name.add_theme_font_size_override("font_size", 17)
	selected_summary.add_child(name)
	var kind := str(item["kind"])
	if MODEL_SCRIPT.GATES.has(kind):
		var desc := Label.new()
		desc.text = model.gate_description(kind)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", Color("#718994"))
		selected_summary.add_child(desc)
		var expression := Label.new()
		expression.text = "Expression\n" + model.boolean_expression(selected_id)
		expression.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		selected_summary.add_child(expression)
	if kind == MODEL_SCRIPT.INPUT:
		var value := Label.new()
		value.text = "Current input: " + ("HIGH · 1" if bool(item["value"]) else "LOW · 0")
		selected_summary.add_child(value)
	if kind == MODEL_SCRIPT.OUTPUT or MODEL_SCRIPT.GATES.has(kind):
		var value := Label.new()
		value.text = "Current signal: " + model.signal_text(int(result["values"].get(selected_id, MODEL_SCRIPT.UNKNOWN)))
		selected_summary.add_child(value)
	var rename := LineEdit.new()
	rename.text = str(item["label"])
	rename.placeholder_text = "Component label"
	rename.text_submitted.connect(func(text: String) -> void:
		if model.set_component_label(selected_id, text): _set_status("Component renamed.")
	)
	selected_summary.add_child(rename)
	if kind == "INPUT":
		_add_button(selected_summary, "Toggle input", func() -> void: model.toggle_input(selected_id), true)
	for warning in result["warnings"]:
		var warning_label := Label.new()
		warning_label.text = str(warning)
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning_label.add_theme_color_override("font_color", Color("#E8A93C"))
		selected_summary.add_child(warning_label)


func _add_component(kind: String, position: Vector2) -> void:
	position = (position / 32.0).round() * 32.0
	var id: int = model.add_component(kind, position)
	if id >= 0:
		selected_id = id
		_set_status("Added %s." % kind.to_lower())
		_refresh()


func _on_selected(id: int) -> void:
	selected_id = id
	_refresh()


func _on_model_changed() -> void:
	_refresh()


func _on_input_toggled(id: int) -> void:
	model.toggle_input(id)
	_set_status("Input toggled. Outputs update from the current circuit.")


func _on_connect_requested(source_id: int, target_id: int, input_port: int) -> void:
	var result: Dictionary = model.connect_components(source_id, target_id, input_port)
	_set_status(str(result.get("message", "Connection rejected.")))
	_refresh()


func _on_component_moved(_id: int, _position: Vector2) -> void:
	_set_status("Component position updated.")


func _on_delete_component(id: int) -> void:
	model.remove_component(id)
	if selected_id == id: selected_id = -1
	_set_status("Component and attached wires removed.")
	_refresh()


func _on_delete_connection(index: int) -> void:
	if model.remove_connection(index):
		_set_status("Wire removed.")
		_refresh()


func _delete_selected() -> void:
	if selected_id >= 0: _on_delete_component(selected_id)
	else: _set_status("Select a component or wire to delete.")


func _new_circuit() -> void:
	model.clear()
	selected_id = -1
	_set_status("New empty circuit. Add inputs, gates, and outputs.")
	_clear_truth_table()


func _starter_circuit() -> void:
	model.reset_to_starter()
	selected_id = -1
	_set_status("Starter AND circuit loaded.")
	_clear_truth_table()


func _half_adder() -> void:
	model.load_half_adder()
	selected_id = -1
	_set_status("Half-adder example loaded. SUM uses XOR; CARRY uses AND.")
	_clear_truth_table()


func _evaluate() -> void:
	var result: Dictionary = model.evaluate()
	_refresh()
	if result["valid"] and result["complete"]:
		_set_status("Circuit evaluated successfully.")
	elif not result["errors"].is_empty():
		_set_status("Evaluation error: " + "; ".join(result["errors"]))
	else:
		_set_status("Circuit is incomplete. Unknown signals are shown as ? until all ports are connected.")


func _show_truth_table() -> void:
	if truth_body == null: return
	for child in truth_body.get_children(): child.queue_free()
	var result: Dictionary = model.generate_truth_table()
	if not result["ok"]:
		_truth_signature = ""
		_show_empty_table(str(result["message"]))
		_set_status(str(result["message"]))
		return
	var inputs: Array[Dictionary] = result["inputs"]
	var outputs: Array[Dictionary] = result["outputs"]
	_truth_signature = _circuit_signature()
	truth_body.columns = inputs.size() + outputs.size()
	truth_heading.text = "TRUTH TABLE  ·  %d ROWS" % result["rows"].size()
	for item in inputs:
		_add_table_cell(str(item["label"]), true)
	for item in outputs:
		_add_table_cell(str(item["label"]), true)
	for row in result["rows"]:
		for value in row["inputs"]: _add_table_cell("1" if int(value) == MODEL_SCRIPT.HIGH else "0", false)
		for value in row["outputs"]: _add_table_cell(model.signal_text(int(value)), false)
	_set_status("Truth table generated for %d input combinations." % result["rows"].size())


func _add_table_cell(text: String, header: bool) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 58
	label.add_theme_font_size_override("font_size", 11 if not header else 10)
	label.add_theme_color_override("font_color", Color("#718994") if header else Color("#D8E7E9"))
	truth_body.add_child(label)


func _show_empty_table(message: String) -> void:
	if truth_body == null: return
	for child in truth_body.get_children(): child.queue_free()
	truth_body.columns = 1
	truth_heading.text = "TRUTH TABLE"
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#718994"))
	truth_body.add_child(label)


func _clear_truth_table() -> void:
	_truth_signature = ""
	_show_empty_table("Choose Truth table to generate rows for this circuit.")


func _circuit_signature() -> String:
	var parts: PackedStringArray = []
	for item in model.components():
		parts.append("%d:%s:%s" % [int(item["id"]), str(item["kind"]), str(item["label"])])
	for wire in model.connections():
		parts.append("%d>%d:%d" % [int(wire["from"]), int(wire["to"]), int(wire["input"])])
	return "|".join(parts)


func _set_status(message: String) -> void:
	set_status(message)


func _state_color(value: int) -> Color:
	match value:
		MODEL_SCRIPT.LOW: return Color("#91A4AB")
		MODEL_SCRIPT.HIGH: return Color("#2ABCA7")
		MODEL_SCRIPT.ERROR: return Color("#F26B6B")
		_: return Color("#E8A93C")
