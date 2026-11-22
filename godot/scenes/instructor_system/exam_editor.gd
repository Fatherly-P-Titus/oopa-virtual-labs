extends Control
## Examination creation and listing; all validation and persistence remain in OopaExamService.

var _title: LineEdit
var _hub: OptionButton
var _lab: OptionButton
var _duration: OptionButton
var _code: LineEdit
var _roster: OptionButton
var _roster_note: Label
var _msg: Label
var _list: VBoxContainer


func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	var content := OopaAdminUI.page(self)
	var top := HBoxContainer.new()
	content.add_child(top)
	var intro := OopaAdminUI.heading(top, "Assessment setup", "Examinations", "Create and review exams available to students in your hub scope.")
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := OopaAdminUI.button("Back to overview", "TertiaryButton")
	back.pressed.connect(func(): SceneRouter.go_instructor_dashboard())
	top.add_child(back)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	content.add_child(split)
	var form_panel := OopaAdminUI.panel(split)
	form_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_panel.size_flags_stretch_ratio = 1.0
	var form_scroll := ScrollContainer.new()
	form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_panel.add_child(form_scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 6)
	form_scroll.add_child(form)
	form.add_child(OopaAdminUI.label("Create examination", 18))
	form.add_child(OopaAdminUI.label("Choose an available lab, duration and eligibility roster.", 11, OopaAdminUI.MUTED))
	_title = _line_input(form, "EXAM TITLE", "e.g. Midterm practical — gas laws")
	form.add_child(OopaAdminUI.label("AUTHORISED HUB", 10, OopaAdminUI.MUTED))
	_hub = OptionButton.new()
	for hub_id in OopaAuthService.new().allowed_hubs(AppState.instructor_session):
		_hub.add_item(hub_id.capitalize())
		_hub.set_item_metadata(_hub.item_count - 1, hub_id)
	_hub.item_selected.connect(func(_index: int): _reload_labs())
	form.add_child(_hub)
	form.add_child(OopaAdminUI.label("AVAILABLE LAB", 10, OopaAdminUI.MUTED))
	_lab = OptionButton.new()
	form.add_child(_lab)
	form.add_child(OopaAdminUI.label("DURATION", 10, OopaAdminUI.MUTED))
	_duration = OptionButton.new()
	for minutes in range(5, 65, 5):
		_duration.add_item("%d minutes" % minutes)
		_duration.set_item_metadata(_duration.item_count - 1, minutes)
	_duration.select(2)
	form.add_child(_duration)
	form.add_child(OopaAdminUI.label("SIX-DIGIT ACCESS CODE", 10, OopaAdminUI.MUTED))
	var code_row := HBoxContainer.new()
	_code = LineEdit.new()
	_code.placeholder_text = "Generate automatically"
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(_code)
	var generate := OopaAdminUI.button("Generate", "SecondaryButton")
	generate.pressed.connect(func(): _code.text = OopaIds.access_code_6())
	code_row.add_child(generate)
	form.add_child(code_row)
	form.add_child(OopaAdminUI.label("ELIGIBILITY ROSTER", 10, OopaAdminUI.MUTED))
	_roster = OptionButton.new()
	_roster.item_selected.connect(func(_index: int): _update_roster_note())
	form.add_child(_roster)
	_roster_note = OopaAdminUI.label("", 10, OopaAdminUI.AMBER)
	_roster_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_roster_note)
	_msg = OopaAdminUI.label("", 11, OopaAdminUI.MUTED)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var create := OopaAdminUI.button("Create and publish", "PrimaryButton")
	create.custom_minimum_size = Vector2(230, 44)
	create.pressed.connect(_on_create)
	var list_panel := OopaAdminUI.panel(split)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 1.15
	var list_body := VBoxContainer.new()
	list_body.add_theme_constant_override("separation", 10)
	list_panel.add_child(list_body)
	list_body.add_child(OopaAdminUI.label("Existing examinations", 18))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 430)
	list_body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_reload_labs()
	_reload_rosters()
	_reload_list()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_msg)
	actions.add_child(create)


func _line_input(parent: Node, caption: String, placeholder: String) -> LineEdit:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	group.add_child(OopaAdminUI.label(caption, 10, OopaAdminUI.MUTED))
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	group.add_child(input)
	parent.add_child(group)
	return input


func _reload_labs() -> void:
	_lab.clear()
	if _hub.item_count == 0:
		return
	var hub_id := str(_hub.get_item_metadata(_hub.selected))
	for lab in OopaManifestLabs.new().list_available_labs(PackedStringArray([hub_id])):
		_lab.add_item("%s  ·  %s" % [str(lab.get("title", "")), str(lab.get("lab_id", ""))])
		_lab.set_item_metadata(_lab.item_count - 1, str(lab.get("lab_id", "")))


func _reload_rosters() -> void:
	_roster.clear()
	_roster.add_item("No roster selected")
	_roster.set_item_metadata(0, "")
	for roster in OopaRosterService.new().list_for_session(AppState.instructor_session):
		_roster.add_item("%s  ·  %d students" % [str(roster.get("label", "")), (roster.get("students", []) as Array).size()])
		_roster.set_item_metadata(_roster.item_count - 1, str(roster.get("roster_id", "")))
	_update_roster_note()


func _update_roster_note() -> void:
	if _roster.item_count == 0:
		return
	if str(_roster.get_item_metadata(_roster.selected)).is_empty():
		_roster_note.text = "No roster selected. Current eligibility rules will deny all student attempts for this exam."
		_roster_note.add_theme_color_override("font_color", OopaAdminUI.AMBER)
	else:
		_roster_note.text = "Students must appear in the selected roster to start this exam."
		_roster_note.add_theme_color_override("font_color", OopaAdminUI.MUTED)


func _on_create() -> void:
	if _hub.item_count == 0 or _lab.item_count == 0:
		_set_message("No authorised hub or available lab is selected.", "error")
		return
	var result: Dictionary = OopaExamService.new().create_exam(
		AppState.instructor_session,
		_title.text,
		str(_hub.get_item_metadata(_hub.selected)),
		str(_lab.get_item_metadata(_lab.selected)),
		int(_duration.get_item_metadata(_duration.selected)),
		_code.text.strip_edges(),
		str(_roster.get_item_metadata(_roster.selected)),
		[],
		"published"
	)
	if not bool(result.get("ok", false)):
		_set_message(str(result.get("message", "Exam creation failed.")), "error")
		return
	var exam: Dictionary = result.get("exam", {})
	_set_message("Created %s  ·  access code %s" % [str(exam.get("exam_id", "")), str(exam.get("access_code", ""))], "success")
	_title.clear()
	_code.clear()
	_reload_list()


func _reload_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	var exams: Array = OopaExamService.new().list_for_session(AppState.instructor_session)
	if exams.is_empty():
		_list.add_child(OopaAdminUI.label("No examinations have been created in your scope.", 12, OopaAdminUI.MUTED))
		return
	exams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("created_at", "")) > str(b.get("created_at", "")))
	for exam in exams:
		var card := OopaAdminUI.panel(_list)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var line := HBoxContainer.new()
		v.add_child(line)
		var name := OopaAdminUI.label(str(exam.get("title", "Untitled examination")), 15)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name)
		var state := OopaAdminUI.label(str(exam.get("status", "unknown")).to_upper(), 10, OopaAdminUI.TEAL)
		line.add_child(state)
		var meta := OopaAdminUI.label("%s  ·  %s  ·  %s min  ·  code %s" % [str(exam.get("exam_id", "")), str(exam.get("hub_id", "")).capitalize(), str(exam.get("duration_min", "")), str(exam.get("access_code", ""))], 11, OopaAdminUI.MUTED)
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(meta)
		var roster_id := str(exam.get("roster_id", ""))
		v.add_child(OopaAdminUI.label("Eligibility roster: %s" % (roster_id if not roster_id.is_empty() else "none"), 11, OopaAdminUI.MUTED))
		var attempts := OopaLocalStore.new().list_attempts(str(exam.get("exam_id", "")))
		var submitted := 0
		for attempt in attempts:
			if str(attempt.get("status", "")) in ["submitted", "expired"]:
				submitted += 1
		v.add_child(OopaAdminUI.label("%d recorded attempts  ·  %d submitted/expired" % [attempts.size(), submitted], 11, OopaAdminUI.MUTED))


func _set_message(text: String, kind: String) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", OopaAdminUI.RED if kind == "error" else OopaAdminUI.TEAL)
