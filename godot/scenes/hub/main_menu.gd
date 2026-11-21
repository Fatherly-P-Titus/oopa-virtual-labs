extends Control
## Main dashboard. Discipline and lab counts are always read from the manifest.

@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _subtitle: Label = $Margin/VBox/Subtitle

const PALETTES := {
	"engineering": {"accent": Color("#16b8a6"), "tint": Color("#142e35"), "index": "01"},
	"physics": {"accent": Color("#3b82f6"), "tint": Color("#182b49"), "index": "02"},
	"chemistry": {"accent": Color("#f2a84a"), "tint": Color("#352b22"), "index": "03"},
	"biology": {"accent": Color("#67c49a"), "tint": Color("#1e352e"), "index": "04"},
}

func _ready() -> void:
	resized.connect(_update_grid_columns)
	_update_grid_columns()
	JennyService.set_page("main_menu")
	_ensure_jenny()
	_load_manifest()
	_build_cards()
	_add_platform_actions()

func _update_grid_columns() -> void:
	if is_instance_valid(_grid):
		_grid.columns = 1 if size.x < 840.0 else 2

func _ensure_jenny() -> void:
	if has_node("JennyPanel"):
		return
	var scene := load("res://scenes/common/jenny_panel.tscn")
	if scene:
		var j = scene.instantiate()
		j.name = "JennyPanel"
		j.page_id = "main_menu"
		add_child(j)

func _load_manifest() -> void:
	var path := "res://data/config/labs_manifest.json"
	if not FileAccess.file_exists(path):
		_subtitle.text = "The laboratory catalogue is unavailable."
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_manifest = parsed

var _manifest: Dictionary = {}

func _build_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var fields: Array = _manifest.get("fields", [])
	for field in fields:
		if field is Dictionary:
			_grid.add_child(_make_field_card(field))
	if fields.is_empty():
		_subtitle.text = "No laboratory fields are currently listed."

func _make_field_card(field: Dictionary) -> Button:
	var field_id := str(field.get("id", ""))
	var palette: Dictionary = PALETTES.get(field_id, {"accent": Color("#16b8a6"), "tint": Color("#19263a"), "index": "—"})
	var labs: Array = field.get("labs", [])
	var available := 0
	for lab in labs:
		if lab is Dictionary and str(lab.get("status", "")) == "available":
			available += 1

	var card := Button.new()
	card.custom_minimum_size = Vector2(320, 176)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("normal", _card_style(Color("#19263a"), palette.accent, false))
	card.add_theme_stylebox_override("hover", _card_style(Color("#26364d"), palette.accent, true))
	card.add_theme_stylebox_override("pressed", _card_style(Color("#101827"), palette.accent, true))
	card.add_theme_stylebox_override("focus", _card_style(Color("#19263a"), palette.accent, true))
	card.add_theme_stylebox_override("disabled", _card_style(Color("#19263a"), Color("#607080"), false))
	card.add_theme_color_override("font_color", Color.WHITE)
	card.add_theme_color_override("font_hover_color", Color.WHITE)
	card.add_theme_color_override("font_pressed_color", Color.WHITE)
	card.text = ""

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 22
	column.offset_top = 18
	column.offset_right = -20
	column.offset_bottom = -18
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var discipline_index := Label.new()
	discipline_index.text = str(palette.index)
	discipline_index.add_theme_color_override("font_color", palette.accent)
	discipline_index.add_theme_font_size_override("font_size", 12)
	discipline_index.add_theme_font_override("font", load("res://assets/fonts/Inter-Bold.ttf"))
	top.add_child(discipline_index)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var arrow := Label.new()
	arrow.text = "OPEN  ↗"
	arrow.add_theme_color_override("font_color", Color("#aebdcb"))
	arrow.add_theme_font_size_override("font_size", 10)
	top.add_child(arrow)

	var title := Label.new()
	title.text = str(field.get("title", "Discipline"))
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_font_override("font", load("res://assets/fonts/Inter-Bold.ttf"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var description := Label.new()
	description.text = str(field.get("subtitle", "Explore the discipline's laboratory catalogue."))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("#c3cfdb"))
	description.add_theme_font_size_override("font_size", 13)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(description)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	var accent_rule := ColorRect.new()
	accent_rule.custom_minimum_size = Vector2(18, 3)
	accent_rule.color = palette.accent
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(accent_rule)
	var count := Label.new()
	count.text = "%d laboratories  ·  %d available" % [labs.size(), available]
	count.add_theme_color_override("font_color", Color("#e3eaf1"))
	count.add_theme_font_size_override("font_size", 11)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(count)

	card.pressed.connect(func() -> void: SceneRouter.go_field(field_id))
	return card

func _card_style(fill: Color, accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 3
	style.border_color = accent
	style.set_corner_radius_all(14)
	style.content_margin_left = 22 if not active else 23
	style.content_margin_right = 20 if not active else 19
	style.content_margin_top = 18 if not active else 17
	style.content_margin_bottom = 18 if not active else 17
	return style

func _add_platform_actions() -> void:
	var vbox: VBoxContainer = $Margin/VBox
	if vbox.has_node("PlatformActions"):
		return
	var row := HBoxContainer.new()
	row.name = "PlatformActions"
	row.add_theme_constant_override("separation", 12)
	var instructor := Button.new()
	instructor.text = "Instructor access"
	instructor.theme_type_variation = &"PrimaryButton"
	instructor.pressed.connect(func() -> void: SceneRouter.go_instructor_login())
	row.add_child(instructor)
	var student := Button.new()
	student.text = "Student examination"
	student.theme_type_variation = &"SecondaryButton"
	student.pressed.connect(func() -> void: SceneRouter.go_student_exam_entry())
	row.add_child(student)
	vbox.add_child(row)
	vbox.move_child(row, mini(4, vbox.get_child_count() - 1))
