extends Control
## Exam submission browser and CSV export; records and calculations remain service-owned.

var _exam_ob: OptionButton
var _list: VBoxContainer
var _msg: Label
var _exams: Array = []
func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	var content := OopaAdminUI.page(self)
	var header := HBoxContainer.new()
	content.add_child(header)
	var intro := OopaAdminUI.heading(header, "Assessment review", "Grading and results", "Review attempts, record manual marks, and export the existing result set.")
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := OopaAdminUI.button("Back to overview", "TertiaryButton")
	back.pressed.connect(func(): SceneRouter.go_instructor_dashboard())
	header.add_child(back)
	var controls := OopaAdminUI.panel(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	controls.add_child(row)
	row.add_child(OopaAdminUI.label("EXAMINATION", 10, OopaAdminUI.MUTED))
	_exam_ob = OptionButton.new()
	_exam_ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exam_ob.item_selected.connect(func(_index: int): _reload_attempts())
	row.add_child(_exam_ob)
	var refresh := OopaAdminUI.button("Refresh", "SecondaryButton")
	refresh.pressed.connect(_reload_attempts)
	row.add_child(refresh)
	var export := OopaAdminUI.button("Export CSV", "PrimaryButton")
	export.pressed.connect(_on_export)
	row.add_child(export)
	_msg = OopaAdminUI.label("", 11, OopaAdminUI.MUTED)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_msg)
	var panel := OopaAdminUI.panel(content)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	body.add_child(OopaAdminUI.label("Examination attempts", 17))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_load_exams()


func _load_exams() -> void:
	_exam_ob.clear()
	_exams = OopaGradeService.new().list_exams_for_session(AppState.instructor_session)
	if _exams.is_empty():
		_exam_ob.add_item("No examinations")
		_exam_ob.set_item_metadata(0, "")
		_msg.text = "No examinations are available in your hub scope."
		var empty := OopaAdminUI.label("Create an examination before reviewing results.", 12, OopaAdminUI.MUTED)
		_list.add_child(empty)
		return
	for exam in _exams:
		_exam_ob.add_item("%s  ·  %s" % [str(exam.get("title", "")), str(exam.get("exam_id", ""))])
		_exam_ob.set_item_metadata(_exam_ob.item_count - 1, str(exam.get("exam_id", "")))
	_reload_attempts()


func _current_exam_id() -> String:
	if _exam_ob.item_count == 0:
		return ""
	return str(_exam_ob.get_item_metadata(_exam_ob.selected))


func _reload_attempts() -> void:
	for child in _list.get_children():
		child.queue_free()
	var exam_id := _current_exam_id()
	if exam_id.is_empty() or _exams.is_empty():
		return
	var attempts := OopaGradeService.new().list_attempts(exam_id)
	if attempts.is_empty():
		_list.add_child(OopaAdminUI.label("No attempts have been recorded for this examination.", 12, OopaAdminUI.MUTED))
		return
	var store := OopaLocalStore.new()
	for attempt in attempts:
		var matric := str(attempt.get("matric", ""))
		var grade: Dictionary = store.load_grade(exam_id, matric)
		var card := OopaAdminUI.panel(_list)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 5)
		row.add_child(details)
		details.add_child(OopaAdminUI.label("%s  ·  %s" % [str(attempt.get("name", "")), matric], 14))
		var status := str(attempt.get("status", "unknown")).to_upper()
		var score := "Awaiting manual grade"
		if not grade.is_empty():
			score = "%.1f / %.1f total  ·  auto %.1f  +  manual %.1f" % [float(grade.get("total", 0)), float(grade.get("max_points", 0)), float(grade.get("auto_score", 0)), float(grade.get("manual_score", 0))]
		details.add_child(OopaAdminUI.label("%s  ·  submitted %s" % [status, str(attempt.get("submitted_at", "—"))], 10, OopaAdminUI.MUTED))
		details.add_child(OopaAdminUI.label(score, 11, OopaAdminUI.GRAPHITE))
		var grade_btn := OopaAdminUI.button("Review grade", "SecondaryButton")
		var attempt_id := str(attempt.get("attempt_id", ""))
		grade_btn.pressed.connect(func(): _open_detail(exam_id, attempt_id))
		row.add_child(grade_btn)


func _open_detail(exam_id: String, attempt_id: String) -> void:
	AppState.set_meta("grade_exam_id", exam_id)
	AppState.set_meta("grade_attempt_id", attempt_id)
	get_tree().change_scene_to_file("res://scenes/instructor_system/grading_detail.tscn")


func _on_export() -> void:
	var exam_id := _current_exam_id()
	if exam_id.is_empty():
		return
	var result: Dictionary = OopaGradeService.new().export_results_csv(exam_id)
	if bool(result.get("ok", false)):
		_msg.text = "CSV saved locally: %s" % str(result.get("message", ""))
		_msg.add_theme_color_override("font_color", OopaAdminUI.TEAL)
	else:
		_msg.text = str(result.get("message", "Export failed."))
		_msg.add_theme_color_override("font_color", OopaAdminUI.RED)
