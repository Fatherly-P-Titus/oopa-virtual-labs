extends Control
## Create / list exams for the logged-in instructor.

var _title: LineEdit
var _hub: OptionButton
var _lab: OptionButton
var _duration: OptionButton
var _code: LineEdit
var _roster: OptionButton
var _msg: Label
var _list: VBoxContainer
var _lab_index: Array = []  # parallel to _lab items metadata


func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_reload_list()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#faf9f8")
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	margin.add_child(split)

	# Left: form
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	split.add_child(form)

	var eye := Label.new()
	eye.text = "EXAM MANAGEMENT"
	eye.add_theme_color_override("font_color", Color("#b22222"))
	form.add_child(eye)
	var title := Label.new()
	title.text = "Create examination"
	title.add_theme_font_size_override("font_size", 24)
	form.add_child(title)

	form.add_child(_lbl("Exam title"))
	_title = LineEdit.new()
	_title.placeholder_text = "e.g. Midterm Practical — Gas Laws"
	form.add_child(_title)

	form.add_child(_lbl("Hub"))
	_hub = OptionButton.new()
	var hubs := OopaAuthService.new().allowed_hubs(AppState.instructor_session)
	for h in hubs:
		_hub.add_item(h)
		_hub.set_item_metadata(_hub.item_count - 1, h)
	_hub.item_selected.connect(func(_i): _reload_labs())
	form.add_child(_hub)

	form.add_child(_lbl("Lab"))
	_lab = OptionButton.new()
	form.add_child(_lab)

	form.add_child(_lbl("Duration (minutes)"))
	_duration = OptionButton.new()
	for m in range(5, 65, 5):
		_duration.add_item("%d min" % m)
		_duration.set_item_metadata(_duration.item_count - 1, m)
	_duration.select(2)  # 15
	form.add_child(_duration)

	form.add_child(_lbl("Access code (6 digits — leave blank to auto-generate)"))
	var code_row := HBoxContainer.new()
	form.add_child(code_row)
	_code = LineEdit.new()
	_code.placeholder_text = "Auto"
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(_code)
	var bgen := Button.new()
	bgen.text = "Generate"
	bgen.pressed.connect(func(): _code.text = OopaIds.access_code_6())
	code_row.add_child(bgen)

	form.add_child(_lbl("Student roster (whitelist)"))
	_roster = OptionButton.new()
	form.add_child(_roster)

	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_color_override("font_color", Color("#b22222"))
	form.add_child(_msg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	form.add_child(row)
	var bsave := Button.new()
	bsave.text = "Create exam"
	bsave.pressed.connect(_on_create)
	row.add_child(bsave)
	var bback := Button.new()
	bback.text = "Dashboard"
	bback.theme_type_variation = &"GhostButton"
	bback.pressed.connect(func(): SceneRouter.go_instructor_dashboard())
	row.add_child(bback)
	var broster := Button.new()
	broster.text = "Manage rosters"
	broster.theme_type_variation = &"GhostButton"
	broster.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/instructor_system/roster_manager.tscn"))
	row.add_child(broster)

	# Right: list
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)
	var lt := Label.new()
	lt.text = "Your exams"
	lt.add_theme_font_size_override("font_size", 18)
	right.add_child(lt)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_reload_labs()
	_reload_rosters()


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 12)
	return l


func _reload_labs() -> void:
	_lab.clear()
	_lab_index.clear()
	if _hub.item_count == 0:
		return
	var hub: String = str(_hub.get_item_metadata(_hub.selected))
	var labs: Array = OopaManifestLabs.new().list_available_labs(PackedStringArray([hub]))
	for lab in labs:
		_lab.add_item("%s (%s)" % [str(lab["title"]), str(lab["lab_id"])])
		_lab.set_item_metadata(_lab.item_count - 1, str(lab["lab_id"]))
		_lab_index.append(lab)


func _reload_rosters() -> void:
	_roster.clear()
	_roster.add_item("— none —")
	_roster.set_item_metadata(0, "")
	for r in OopaRosterService.new().list_for_session(AppState.instructor_session):
		var label: String = "%s (%s)" % [str(r.get("label", "")), str(r.get("roster_id", ""))]
		_roster.add_item(label)
		_roster.set_item_metadata(_roster.item_count - 1, str(r.get("roster_id", "")))


func _on_create() -> void:
	if _hub.item_count == 0 or _lab.item_count == 0:
		_msg.text = "No hub/lab available."
		return
	var hub: String = str(_hub.get_item_metadata(_hub.selected))
	var lab_id: String = str(_lab.get_item_metadata(_lab.selected))
	var dur: int = int(_duration.get_item_metadata(_duration.selected))
	var code: String = _code.text.strip_edges()
	var roster_id: String = str(_roster.get_item_metadata(_roster.selected))
	var svc := OopaExamService.new()
	var res: Dictionary = svc.create_exam(
		AppState.instructor_session, _title.text, hub, lab_id, dur, code, roster_id, [], "published"
	)
	if not bool(res.get("ok", false)):
		_msg.text = str(res.get("message", "Failed"))
		return
	var exam: Dictionary = res.get("exam", {})
	_msg.add_theme_color_override("font_color", Color("#2e7d32"))
	_msg.text = "Created %s · code %s" % [str(exam.get("exam_id", "")), str(exam.get("access_code", ""))]
	_title.text = ""
	_code.text = ""
	_reload_list()


func _reload_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var exams: Array = OopaExamService.new().list_for_session(AppState.instructor_session)
	if exams.is_empty():
		var empty := Label.new()
		empty.text = "No exams yet."
		_list.add_child(empty)
		return
	for e in exams:
		var panel := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color.WHITE
		st.set_border_width_all(1)
		st.border_color = Color("#e0e0e0")
		st.set_corner_radius_all(8)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 10
		st.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", st)
		var v := VBoxContainer.new()
		panel.add_child(v)
		var t := Label.new()
		t.text = str(e.get("title", ""))
		t.add_theme_font_size_override("font_size", 15)
		v.add_child(t)
		var d := Label.new()
		d.text = "%s · lab %s · %d min · code %s · roster %s" % [
			str(e.get("exam_id", "")),
			str(e.get("lab_id", "")),
			int(e.get("duration_min", 0)),
			str(e.get("access_code", "")),
			str(e.get("roster_id", "—")) if str(e.get("roster_id", "")) != "" else "—",
		]
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color("#666666"))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		_list.add_child(panel)
