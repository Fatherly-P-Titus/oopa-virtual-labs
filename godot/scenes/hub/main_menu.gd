extends Control
## Main menu — field cards from labs_manifest.json

@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _subtitle: Label = $Margin/VBox/Subtitle

const FIREBRICK := Color("#b22222")
const FIREBRICK_HOVER := Color("#9a1c1c")
const TITLE_ON_CARD := Color(1, 1, 1, 1)
const MUTED_ON_CARD := Color(1, 1, 1, 0.88)

var _manifest: Dictionary = {}

func _ready() -> void:
	JennyService.set_page("main_menu")
	_ensure_jenny()
	_load_manifest()
	_build_cards()
	_add_platform_actions()

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
		_subtitle.text = "Missing labs_manifest.json"
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_manifest = parsed

func _build_cards() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for field in _manifest.get("fields", []):
		_grid.add_child(_make_field_card(field))

func _make_field_card(field: Dictionary) -> PanelContainer:
	var title := str(field.get("title", "?"))
	var subtitle := str(field.get("subtitle", ""))
	var labs: Array = field.get("labs", [])
	var available := 0
	for lab in labs:
		if str(lab.get("status", "")) == "available":
			available += 1
	var count_line := "%d project%s" % [labs.size(), "" if labs.size() == 1 else "s"]
	if available > 0:
		count_line += " · %d available" % available
	else:
		count_line += " · coming soon"

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 132)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var style_n := StyleBoxFlat.new()
	style_n.bg_color = FIREBRICK
	style_n.set_corner_radius_all(12)
	style_n.content_margin_left = 20
	style_n.content_margin_right = 20
	style_n.content_margin_top = 18
	style_n.content_margin_bottom = 18

	var style_h := style_n.duplicate()
	style_h.bg_color = FIREBRICK_HOVER
	style_h.set_border_width_all(2)
	style_h.border_color = Color(1, 1, 1, 0.4)
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

	var sub_l := Label.new()
	sub_l.text = subtitle
	sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_l.add_theme_font_size_override("font_size", 13)
	sub_l.add_theme_color_override("font_color", MUTED_ON_CARD)
	sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub_l)

	var count_l := Label.new()
	count_l.text = count_line
	count_l.add_theme_font_size_override("font_size", 12)
	count_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(count_l)

	var id := str(field.get("id", ""))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_field_pressed(id)
	)
	panel.mouse_entered.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", style_h)
	)
	panel.mouse_exited.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", style_n)
	)
	return panel

func _on_field_pressed(field_id: String) -> void:
	SceneRouter.go_field(field_id)



func _add_platform_actions() -> void:
	var vbox: VBoxContainer = $Margin/VBox
	if vbox == null:
		return
	if vbox.has_node("PlatformActions"):
		return
	var row := HBoxContainer.new()
	row.name = "PlatformActions"
	row.add_theme_constant_override("separation", 10)
	var bi := Button.new()
	bi.text = "Instructor Login"
	bi.pressed.connect(func(): SceneRouter.go_instructor_login())
	row.add_child(bi)
	var bs := Button.new()
	bs.text = "Student Exam"
	bs.theme_type_variation = &"GhostButton"
	bs.pressed.connect(func(): SceneRouter.go_student_exam_entry())
	row.add_child(bs)
	# Place after subtitle if possible
	var insert_at: int = mini(3, vbox.get_child_count())
	vbox.add_child(row)
	vbox.move_child(row, insert_at)
