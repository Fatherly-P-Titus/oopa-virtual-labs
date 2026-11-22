extends Control
## Student exam eligibility gate; entry validation and attempt creation stay in OopaAttemptService.

var _code: LineEdit
var _name: LineEdit
var _matric: LineEdit
var _msg: Label
var _start: Button
var _busy := false


func _ready() -> void:
	var content := OopaAdminUI.page(self, true)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var card := OopaAdminUI.panel(center)
	card.custom_minimum_size = Vector2(480, 0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	card.add_child(body)
	body.add_child(OopaAdminUI.label("SECURE ASSESSMENT  /  OOPA", 11, OopaAdminUI.TEAL))
	body.add_child(OopaAdminUI.label("Join an examination", 27))
	var note := OopaAdminUI.label("Enter the access code provided by your instructor and use the name and matric number on the eligibility roster.", 13, OopaAdminUI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	_code = OopaAdminUI.input_field(body, "EXAM ACCESS CODE", "6-digit code")
	_code.max_length = 6
	_code.text_submitted.connect(func(_text: String): _on_start())
	_name = OopaAdminUI.input_field(body, "FULL NAME", "Name as registered")
	_matric = OopaAdminUI.input_field(body, "MATRIC NUMBER", "e.g. CHEM/2026/001")
	_matric.text_submitted.connect(func(_text: String): _on_start())
	_msg = OopaAdminUI.label("", 12, OopaAdminUI.RED)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_msg)
	_start = OopaAdminUI.button("Validate and start", "PrimaryButton")
	_start.custom_minimum_size.y = 46
	_start.pressed.connect(_on_start)
	body.add_child(_start)
	var back := OopaAdminUI.button("Return to main menu", "TertiaryButton")
	back.pressed.connect(func(): SceneRouter.go_main_menu())
	body.add_child(back)


func _on_start() -> void:
	if _busy:
		return
	_busy = true
	_start.disabled = true
	_start.text = "Checking eligibility…"
	_msg.text = ""
	var result: Dictionary = OopaAttemptService.new().start_attempt(_code.text, _name.text, _matric.text)
	if not bool(result.get("ok", false)):
		_msg.text = str(result.get("message", "Unable to start this examination."))
		_start.disabled = false
		_start.text = "Validate and start"
		_busy = false
		return
	AppState.set_exam_session(result.get("exam", {}), result.get("attempt", {}))
	get_tree().change_scene_to_file("res://scenes/exam/student_session.tscn")
