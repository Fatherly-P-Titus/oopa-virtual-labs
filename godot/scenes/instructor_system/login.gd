extends Control
## Instructor login — visual redesign; authentication remains in OopaAuthService.

var _staff: LineEdit
var _pass: LineEdit
var _msg: Label
var _login_button: Button
var _busy := false


func _ready() -> void:
	var content := OopaAdminUI.page(self, true)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var card := OopaAdminUI.panel(center)
	card.custom_minimum_size = Vector2(440, 0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	card.add_child(body)
	var brand := OopaAdminUI.label("OOPA  /  VIRTUAL LABS", 11, OopaAdminUI.TEAL)
	body.add_child(brand)
	var title := OopaAdminUI.label("Instructor sign in", 28)
	body.add_child(title)
	var subtitle := OopaAdminUI.label("Use your assigned staff credentials to access your authorised academic workspace.", 13, OopaAdminUI.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(subtitle)
	_staff = OopaAdminUI.input_field(body, "STAFF ID", "e.g. ChemStaff/001")
	_pass = OopaAdminUI.input_field(body, "PASSCODE", "Enter your passcode", true)
	_pass.text_submitted.connect(func(_text: String): _on_login())
	_msg = OopaAdminUI.label("", 12, OopaAdminUI.RED)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_msg)
	_login_button = OopaAdminUI.button("Sign in", "PrimaryButton")
	_login_button.custom_minimum_size.y = 46
	_login_button.pressed.connect(_on_login)
	body.add_child(_login_button)
	var back := OopaAdminUI.button("Back to main menu", "TertiaryButton")
	back.pressed.connect(func(): SceneRouter.go_main_menu())
	body.add_child(back)
	var note := OopaAdminUI.label("Access is limited to the hubs assigned to your account.", 11, OopaAdminUI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	_staff.grab_focus()


func _on_login() -> void:
	if _busy:
		return
	_busy = true
	_login_button.disabled = true
	_login_button.text = "Checking credentials…"
	_msg.text = ""
	var res: Dictionary = OopaAuthService.new().authenticate(_staff.text, _pass.text)
	if not bool(res.get("ok", false)):
		_msg.text = str(res.get("message", "Sign in failed. Check your details and try again."))
		_login_button.disabled = false
		_login_button.text = "Sign in"
		_busy = false
		return
	AppState.set_instructor_session(res.get("instructor", {}))
	_pass.clear()
	SceneRouter.go_instructor_dashboard()
	_busy = false
