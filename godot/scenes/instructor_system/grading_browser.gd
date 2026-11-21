extends Control
## Pick exam → list attempts → open detail / export CSV.

var _exam_ob: OptionButton
var _list: VBoxContainer
var _msg: Label
var _exams: Array = []


func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_load_exams()


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
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	margin.add_child(root_v)

	var eye := Label.new()
	eye.text = "GRADING"
	eye.add_theme_color_override("font_color", Color("#b22222"))
	root_v.add_child(eye)
	var title := Label.new()
	title.text = "Exam results"
	title.add_theme_font_size_override("font_size", 24)
	root_v.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root_v.add_child(row)
	row.add_child(_lbl("Exam"))
	_exam_ob = OptionButton.new()
	_exam_ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exam_ob.item_selected.connect(func(_i): _reload_attempts())
	row.add_child(_exam_ob)
	var bref := Button.new()
	bref.text = "Refresh"
	bref.pressed.connect(_reload_attempts)
	row.add_child(bref)
	var bexp := Button.new()
	bexp.text = "Export CSV"
	bexp.pressed.connect(_on_export)
	row.add_child(bexp)
	var bback := Button.new()
	bback.text = "Dashboard"
	bback.theme_type_variation = &"GhostButton"
	bback.pressed.connect(func(): SceneRouter.go_instructor_dashboard())
	row.add_child(bback)

	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_v.add_child(_msg)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	root_v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 12)
	return l


func _load_exams() -> void:
	_exam_ob.clear()
	_exams = OopaGradeService.new().list_exams_for_session(AppState.instructor_session)
	if _exams.is_empty():
		_exam_ob.add_item("No exams")
		_msg.text = "No exams in your scope. Create one under Exam management."
		return
	for e in _exams:
		_exam_ob.add_item("%s (%s)" % [str(e.get("title", "")), str(e.get("exam_id", ""))])
		_exam_ob.set_item_metadata(_exam_ob.item_count - 1, str(e.get("exam_id", "")))
	_reload_attempts()


func _current_exam_id() -> String:
	if _exam_ob.item_count == 0:
		return ""
	return str(_exam_ob.get_item_metadata(_exam_ob.selected))


func _reload_attempts() -> void:
	for c in _list.get_children():
		c.queue_free()
	var eid: String = _current_exam_id()
	if eid.is_empty() or _exams.is_empty():
		return
	var attempts: Array = OopaGradeService.new().list_attempts(eid)
	if attempts.is_empty():
		var empty := Label.new()
		empty.text = "No attempts submitted yet for this exam."
		_list.add_child(empty)
		return
	var store := OopaLocalStore.new()
	for a in attempts:
		var matric: String = str(a.get("matric", ""))
		var g: Dictionary = store.load_grade(eid, matric)
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
		var row := HBoxContainer.new()
		panel.add_child(row)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var t := Label.new()
		t.text = "%s · %s" % [str(a.get("name", "")), matric]
		t.add_theme_font_size_override("font_size", 14)
		v.add_child(t)
		var d := Label.new()
		var score_txt := "not graded"
		if not g.is_empty():
			score_txt = "total %.1f / %.1f (auto %.1f + manual %.1f)" % [
				float(g.get("total", 0)), float(g.get("max_points", 0)),
				float(g.get("auto_score", 0)), float(g.get("manual_score", 0)),
			]
		d.text = "status: %s · submitted: %s · %s" % [
			str(a.get("status", "")), str(a.get("submitted_at", "—")), score_txt
		]
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color("#666666"))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		var b := Button.new()
		b.text = "Grade"
		var aid: String = str(a.get("attempt_id", ""))
		var exam_id: String = eid
		b.pressed.connect(func(): _open_detail(exam_id, aid))
		row.add_child(b)
		_list.add_child(panel)


func _open_detail(exam_id: String, attempt_id: String) -> void:
	AppState.set_meta("grade_exam_id", exam_id)
	AppState.set_meta("grade_attempt_id", attempt_id)
	get_tree().change_scene_to_file("res://scenes/instructor_system/grading_detail.tscn")


func _on_export() -> void:
	var eid: String = _current_exam_id()
	if eid.is_empty():
		return
	var res: Dictionary = OopaGradeService.new().export_results_csv(eid)
	if bool(res.get("ok", false)):
		_msg.add_theme_color_override("font_color", Color("#2e7d32"))
		_msg.text = "CSV written to %s" % str(res.get("message", ""))
	else:
		_msg.add_theme_color_override("font_color", Color("#b22222"))
		_msg.text = str(res.get("message", "Export failed"))
