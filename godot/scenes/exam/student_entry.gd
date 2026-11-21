extends Control
## Student exam gate — access code + name + matric.


var _code: LineEdit
var _name: LineEdit
var _matric: LineEdit
var _msg: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#faf9f8")
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color("#b22222")
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var eye := Label.new()
	eye.text = "STUDENT EXAMINATION"
	eye.add_theme_color_override("font_color", Color("#b22222"))
	eye.add_theme_font_size_override("font_size", 12)
	v.add_child(eye)
	var title := Label.new()
	title.text = "Enter exam"
	title.add_theme_font_size_override("font_size", 26)
	v.add_child(title)
	var lead := Label.new()
	lead.text = "Provide the 6-digit access code from your instructor, then your name and matric number as registered."
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.add_theme_font_size_override("font_size", 13)
	lead.add_theme_color_override("font_color", Color("#555555"))
	v.add_child(lead)

	v.add_child(_lbl("Exam access code"))
	_code = LineEdit.new()
	_code.placeholder_text = "6-digit code"
	v.add_child(_code)
	v.add_child(_lbl("Full name"))
	_name = LineEdit.new()
	_name.placeholder_text = "As on the class list"
	v.add_child(_name)
	v.add_child(_lbl("Matric number"))
	_matric = LineEdit.new()
	_matric.placeholder_text = "e.g. CHEM/2024/001"
	_matric.text_submitted.connect(func(_t): _on_start())
	v.add_child(_matric)

	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_color_override("font_color", Color("#b22222"))
	v.add_child(_msg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var b := Button.new()
	b.text = "Start exam"
	b.pressed.connect(_on_start)
	row.add_child(b)
	var bback := Button.new()
	bback.text = "Main menu"
	bback.theme_type_variation = &"GhostButton"
	bback.pressed.connect(func(): SceneRouter.go_main_menu())
	row.add_child(bback)


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 12)
	return l


func _on_start() -> void:
	var res: Dictionary = OopaAttemptService.new().start_attempt(_code.text, _name.text, _matric.text)
	if not bool(res.get("ok", false)):
		_msg.text = str(res.get("message", "Cannot start"))
		return
	AppState.set_exam_session(res.get("exam", {}), res.get("attempt", {}))
	get_tree().change_scene_to_file("res://scenes/exam/student_session.tscn")
