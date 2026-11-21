extends Control
## Field hub — same visual language as Main Menu (large title + fire-brick cards).

@onready var _eyebrow: Label = $Margin/VBox/Eyebrow
@onready var _title: Label = $Margin/VBox/Title
@onready var _subtitle: Label = $Margin/VBox/Subtitle
@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid

const FIREBRICK := Color("#b22222")
const FIREBRICK_HOVER := Color("#9a1c1c")
const FIREBRICK_MUTED := Color("#7a3030")
const TITLE_ON_CARD := Color(1, 1, 1, 1)
const MUTED_ON_CARD := Color(1, 1, 1, 0.88)

func _ready() -> void:
	_style_back_button()
	_build()
	_ensure_jenny()

func _ensure_jenny() -> void:
	var fid := AppState.current_field if AppState.current_field != "" else "chemistry"
	JennyService.set_page(fid)
	if has_node("JennyPanel"):
		$JennyPanel.set_page(fid)
		return
	var scene := load("res://scenes/common/jenny_panel.tscn")
	if scene:
		var j = scene.instantiate()
		j.name = "JennyPanel"
		j.page_id = fid
		add_child(j)

func _style_back_button() -> void:
	var back: Button = $Margin/VBox/Back
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0)
	s.set_border_width_all(1)
	s.border_color = Color("#ded8d5")
	s.set_corner_radius_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	var h := s.duplicate()
	h.border_color = FIREBRICK
	h.bg_color = Color.WHITE
	back.add_theme_stylebox_override("normal", s)
	back.add_theme_stylebox_override("hover", h)
	back.add_theme_stylebox_override("pressed", h)
	back.add_theme_color_override("font_color", Color("#1b1b1b"))
	back.add_theme_color_override("font_hover_color", Color("#1b1b1b"))
	if ResourceLoader.exists("res://assets/fonts/Inter-SemiBold.ttf"):
		back.add_theme_font_override("font", load("res://assets/fonts/Inter-SemiBold.ttf"))

func _build() -> void:
	var field_id := AppState.current_field
	if field_id == "":
		field_id = "chemistry"
		AppState.set_field(field_id)
	var manifest := _load_manifest()
	var field: Dictionary = {}
	for f in manifest.get("fields", []):
		if str(f.get("id", "")) == field_id:
			field = f
			break

	_eyebrow.text = "OOPA VIRTUAL LABS  ·  LABORATORY"
	_title.text = str(field.get("title", field_id))
	_subtitle.text = str(field.get("subtitle", ""))

	# Title typography parity with Main Menu
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color("#1b1b1b"))
	if ResourceLoader.exists("res://assets/fonts/Inter-Bold.ttf"):
		_title.add_theme_font_override("font", load("res://assets/fonts/Inter-Bold.ttf"))

	_eyebrow.add_theme_font_size_override("font_size", 14)
	_eyebrow.add_theme_color_override("font_color", FIREBRICK)
	if ResourceLoader.exists("res://assets/fonts/Inter-SemiBold.ttf"):
		_eyebrow.add_theme_font_override("font", load("res://assets/fonts/Inter-SemiBold.ttf"))

	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.add_theme_color_override("font_color", Color("#666666"))

	for c in _grid.get_children():
		c.queue_free()
	for lab in field.get("labs", []):
		_grid.add_child(_make_lab_card(lab))

func _make_lab_card(lab: Dictionary) -> PanelContainer:
	var status := str(lab.get("status", "planned"))
	var available := status == "available"
	var scene_path := str(lab.get("scene", ""))
	var lab_id := str(lab.get("id", ""))
	var title := str(lab.get("title", "?"))
	var blurb := str(lab.get("blurb", ""))
	var status_line := "Available · Open to run" if available else "Coming soon · Planned"

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 140)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW

	var style_n := StyleBoxFlat.new()
	style_n.bg_color = FIREBRICK if available else FIREBRICK_MUTED
	style_n.set_corner_radius_all(12)
	style_n.content_margin_left = 20
	style_n.content_margin_right = 20
	style_n.content_margin_top = 18
	style_n.content_margin_bottom = 18

	var style_h := style_n.duplicate()
	style_h.bg_color = FIREBRICK_HOVER if available else FIREBRICK_MUTED
	style_h.set_border_width_all(2)
	style_h.border_color = Color(1, 1, 1, 0.4 if available else 0.15)
	style_h.content_margin_left = 18
	style_h.content_margin_right = 18
	style_h.content_margin_top = 16
	style_h.content_margin_bottom = 16

	panel.add_theme_stylebox_override("panel", style_n)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	var title_l := Label.new()
	title_l.text = title
	title_l.add_theme_font_size_override("font_size", 22)
	title_l.add_theme_color_override("font_color", TITLE_ON_CARD)
	if ResourceLoader.exists("res://assets/fonts/Inter-Bold.ttf"):
		title_l.add_theme_font_override("font", load("res://assets/fonts/Inter-Bold.ttf"))
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title_l)

	var blurb_l := Label.new()
	blurb_l.text = blurb
	blurb_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_l.add_theme_font_size_override("font_size", 13)
	blurb_l.add_theme_color_override("font_color", MUTED_ON_CARD)
	blurb_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(blurb_l)

	var status_l := Label.new()
	status_l.text = status_line
	status_l.add_theme_font_size_override("font_size", 12)
	status_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	status_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(status_l)

	if available and scene_path != "":
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				SceneRouter.open_lab(scene_path, lab_id)
		)
		panel.mouse_entered.connect(func() -> void:
			panel.add_theme_stylebox_override("panel", style_h)
		)
		panel.mouse_exited.connect(func() -> void:
			panel.add_theme_stylebox_override("panel", style_n)
		)
	else:
		panel.modulate = Color(1, 1, 1, 0.85)

	return panel

func _load_manifest() -> Dictionary:
	var path := "res://data/config/labs_manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

func _on_back_pressed() -> void:
	SceneRouter.go_main_menu()
