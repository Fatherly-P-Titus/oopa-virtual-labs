extends Control
## Shared discipline hub. Catalogue and availability come only from the manifest.

@onready var _eyebrow: Label = $Margin/VBox/Eyebrow
@onready var _title: Label = $Margin/VBox/Title
@onready var _subtitle: Label = $Margin/VBox/Subtitle
@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _motif: Control = $Margin/VBox/DisciplineMotif
@onready var _back: Button = $Margin/VBox/Back

const PALETTES := {
	"engineering": {"accent": Color("#16b8a6"), "surface": Color("#132a32"), "index": "ENGINEERING SYSTEMS"},
	"physics": {"accent": Color("#3b82f6"), "surface": Color("#14243b"), "index": "PHYSICAL SYSTEMS"},
	"chemistry": {"accent": Color("#f2a84a"), "surface": Color("#30271e"), "index": "CHEMICAL SYSTEMS"},
	"biology": {"accent": Color("#67c49a"), "surface": Color("#1b3028"), "index": "BIOLOGICAL SYSTEMS"},
}

func _ready() -> void:
	resized.connect(_update_grid_columns)
	_update_grid_columns()
	_build()
	_ensure_jenny()

func _update_grid_columns() -> void:
	if is_instance_valid(_grid):
		_grid.columns = 1 if size.x < 840.0 else 2

func _ensure_jenny() -> void:
	var field_id := AppState.current_field if AppState.current_field != "" else "chemistry"
	JennyService.set_page(field_id)
	if has_node("JennyPanel"):
		$JennyPanel.set_page(field_id)
		return
	var scene := load("res://scenes/common/jenny_panel.tscn")
	if scene:
		var j = scene.instantiate()
		j.name = "JennyPanel"
		j.page_id = field_id
		add_child(j)

func _build() -> void:
	var field_id := AppState.current_field if AppState.current_field != "" else "chemistry"
	if AppState.current_field == "":
		AppState.set_field(field_id)
	var manifest := _load_manifest()
	var field: Dictionary = {}
	for item in manifest.get("fields", []):
		if item is Dictionary and str(item.get("id", "")) == field_id:
			field = item
			break
	if field.is_empty():
		field = {"id": field_id, "title": field_id.capitalize(), "subtitle": "Discipline catalogue", "labs": []}

	var palette: Dictionary = PALETTES.get(field_id, PALETTES.chemistry)
	_eyebrow.text = str(palette.index)
	_eyebrow.add_theme_color_override("font_color", palette.accent)
	_title.text = str(field.get("title", field_id.capitalize()))
	_subtitle.text = str(field.get("subtitle", "Explore the discipline's laboratory catalogue."))
	_motif.discipline = field_id
	_motif.accent = palette.accent
	_motif.queue_redraw()
	_style_back_button(palette.accent)

	var labs: Array = field.get("labs", [])
	var available_count := 0
	for lab in labs:
		if lab is Dictionary and str(lab.get("status", "")) == "available":
			available_count += 1
	$Margin/VBox/CatalogueHeading.text = "LABORATORY CATALOGUE  ·  %d LISTED  ·  %d AVAILABLE" % [labs.size(), available_count]
	for child in _grid.get_children():
		child.queue_free()
	for lab in labs:
		if lab is Dictionary:
			_grid.add_child(_make_lab_card(lab, palette.accent, palette.surface))

func _style_back_button(accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#19263a")
	normal.border_color = Color("#34445a")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = accent
	_back.add_theme_stylebox_override("normal", normal)
	_back.add_theme_stylebox_override("hover", hover)
	_back.add_theme_stylebox_override("pressed", hover)
	_back.add_theme_color_override("font_color", Color("#e9eef5"))
	_back.add_theme_color_override("font_hover_color", Color.WHITE)

func _make_lab_card(lab: Dictionary, accent: Color, surface: Color) -> Button:
	var status := str(lab.get("status", "planned"))
	var available := status == "available"
	var scene_path := str(lab.get("scene", ""))
	var lab_id := str(lab.get("id", ""))
	var card := Button.new()
	card.custom_minimum_size = Vector2(320, 132)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.disabled = not available or scene_path.is_empty()
	card.focus_mode = Control.FOCUS_ALL if not card.disabled else Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not card.disabled else Control.CURSOR_ARROW
	card.add_theme_stylebox_override("normal", _lab_style(surface, accent, false))
	card.add_theme_stylebox_override("hover", _lab_style(Color("#26364d"), accent, true))
	card.add_theme_stylebox_override("pressed", _lab_style(Color("#101827"), accent, true))
	card.add_theme_stylebox_override("focus", _lab_style(surface, accent, true))
	card.add_theme_stylebox_override("disabled", _lab_style(Color("#19263a"), Color("#657386"), false))
	card.add_theme_color_override("font_color", Color.WHITE)
	card.add_theme_color_override("font_disabled_color", Color("#9ba8b7"))
	card.text = ""
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_top = 16
	column.offset_right = -18
	column.offset_bottom = -16
	column.add_theme_constant_override("separation", 7)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var title := Label.new()
	title.text = str(lab.get("title", "Laboratory"))
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_font_override("font", load("res://assets/fonts/Inter-SemiBold.ttf"))
	title.add_theme_color_override("font_color", Color.WHITE if available else Color("#c5ced8"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var description := Label.new()
	description.text = str(lab.get("blurb", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color("#c3cfdb") if available else Color("#8a98a8"))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(description)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(16, 3)
	marker.color = accent if available else Color("#657386")
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(marker)
	var state := Label.new()
	state.text = "AVAILABLE  ·  OPEN" if available else "COMING SOON"
	state.add_theme_font_size_override("font_size", 10)
	state.add_theme_color_override("font_color", accent if available else Color("#9ba8b7"))
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(state)
	if available:
		card.pressed.connect(func() -> void: SceneRouter.open_lab(scene_path, lab_id))
	return card

func _lab_style(fill: Color, accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent if active else Color("#34445a")
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _load_manifest() -> Dictionary:
	var path := "res://data/config/labs_manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _on_back_pressed() -> void:
	SceneRouter.go_main_menu()
