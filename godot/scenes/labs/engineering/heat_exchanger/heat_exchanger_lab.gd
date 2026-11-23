extends LabShell
## M11.1 route scaffold. Scientific calculations and equipment behavior are added in later phases.

func _ready() -> void:
	lab_title = "Heat Exchanger Design & Simulation"
	lab_eyebrow = "ENGINEERING  /  THERMAL SYSTEMS"
	lab_lead = "Investigate shell-and-tube and double-pipe heat exchangers through model-driven operation and engineering analysis."
	field_id = "engineering"
	page_id = "heat_exchanger"
	back_label = "← Engineering"
	super._ready()
	_build_foundation_view()
	set_status("M11.1 FOUNDATION  ·  ROUTE READY")


func _build_foundation_view() -> void:
	var stage := get_stage()
	if stage == null:
		push_error("Heat Exchanger Lab: shared workspace stage is missing")
		return
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_to_stage(center)
	var card := PanelContainer.new()
	card.theme_type_variation = &"ScientificCard"
	card.custom_minimum_size = Vector2(560, 250)
	center.add_child(card)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 28)
	margins.add_theme_constant_override("margin_right", 28)
	margins.add_theme_constant_override("margin_top", 24)
	margins.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margins.add_child(content)
	var eyebrow := Label.new()
	eyebrow.text = "M11.1  /  PROJECT FOUNDATION"
	eyebrow.theme_type_variation = &"Eyebrow"
	eyebrow.add_theme_color_override("font_color", Color("#16b8a6"))
	content.add_child(eyebrow)
	var heading := Label.new()
	heading.text = "Heat Exchanger Laboratory"
	heading.theme_type_variation = &"H2"
	content.add_child(heading)
	var description := Label.new()
	description.text = "The Engineering route, shared laboratory shell, and isolated project architecture are established."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	var divider := HSeparator.new()
	content.add_child(divider)
	var phase := Label.new()
	phase.text = "Next: validated thermal models, followed by interactive 2.5D equipment, instrumentation, and analysis."
	phase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase.add_theme_color_override("font_color", Color("#718994"))
	content.add_child(phase)
	var notice := Label.new()
	notice.text = "This foundation preview does not yet calculate or simulate exchanger performance."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", 11)
	notice.add_theme_color_override("font_color", Color("#D49A43"))
	content.add_child(notice)