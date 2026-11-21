extends Control
## Instructor login — Staff ID + hub/admin passcode.

var _staff: LineEdit
var _pass: LineEdit
var _msg: Label
var _busy: bool = false


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
	card.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	style.border_color = Color("#b22222")
	style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var eye := Label.new()
	eye.text = "OOPA VIRTUAL LABS"
	eye.add_theme_color_override("font_color", Color("#b22222"))
	eye.add_theme_font_size_override("font_size", 12)
	v.add_child(eye)

	var title := Label.new()
	title.text = "Instructor Login"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#1b1b1b"))
	v.add_child(title)

	var lead := Label.new()
	lead.text = "Enter your Staff ID and designated passcode."
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.add_theme_font_size_override("font_size", 13)
	lead.add_theme_color_override("font_color", Color("#555555"))
	v.add_child(lead)

	var l1 := Label.new()
	l1.text = "Staff ID"
	l1.add_theme_font_size_override("font_size", 12)
	v.add_child(l1)
	_staff = LineEdit.new()
	_staff.placeholder_text = "e.g. ChemStaff/001"
	_staff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_staff)

	var l2 := Label.new()
	l2.text = "Passcode"
	l2.add_theme_font_size_override("font_size", 12)
	v.add_child(l2)
	_pass = LineEdit.new()
	_pass.placeholder_text = "Passcode"
	_pass.secret = true
	_pass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pass.text_submitted.connect(func(_t): _on_login())
	v.add_child(_pass)

	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_font_size_override("font_size", 12)
	_msg.add_theme_color_override("font_color", Color("#b22222"))
	_msg.text = ""
	v.add_child(_msg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)

	var blogin := Button.new()
	blogin.text = "Sign in"
	blogin.pressed.connect(_on_login)
	row.add_child(blogin)

	var bback := Button.new()
	bback.text = "Back to menu"
	bback.theme_type_variation = &"GhostButton"
	bback.pressed.connect(func(): SceneRouter.go_main_menu())
	row.add_child(bback)

	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("#777777"))
	hint.text = "Admin: AdminStaff/001 · Hub instructors use their own Staff ID."
	v.add_child(hint)


func _on_login() -> void:
	if _busy:
		return
	_busy = true
	var auth := OopaAuthService.new()
	var res: Dictionary = auth.authenticate(_staff.text, _pass.text)
	if not bool(res.get("ok", false)):
		_msg.text = str(res.get("message", "Login failed."))
		_busy = false
		return
	AppState.set_instructor_session(res.get("instructor", {}))
	_msg.text = ""
	SceneRouter.go_instructor_dashboard()
	_busy = false
