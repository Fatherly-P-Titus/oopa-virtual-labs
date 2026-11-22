extends Control
## Manual marking view; all scoring math, permissions and record writes remain in OopaGradeService.

var _exam: Dictionary
var _attempt: Dictionary
var _manual: SpinBox
var _comments: TextEdit
var _msg: Label


func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	var exam_id := str(AppState.get_meta("grade_exam_id", ""))
	var attempt_id := str(AppState.get_meta("grade_attempt_id", ""))
	_exam = OopaLocalStore.new().load_exam(exam_id)
	_attempt = OopaLocalStore.new().load_attempt(exam_id, attempt_id)
	if _exam.is_empty() or _attempt.is_empty() or not OopaAuthService.new().can_access_hub(AppState.instructor_session, str(_exam.get("hub_id", ""))):
		SceneRouter.go_instructor_dashboard()
		return
	var content := OopaAdminUI.page(self)
	var header := HBoxContainer.new()
	content.add_child(header)
	var intro := OopaAdminUI.heading(header, "Assessment review", "Submission details", str(_exam.get("title", "")))
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := OopaAdminUI.button("Back to submissions", "TertiaryButton")
	back.pressed.connect(func(): SceneRouter.go_grading())
	header.add_child(back)
	var identity := OopaAdminUI.panel(content, true)
	var ident_row := HBoxContainer.new()
	ident_row.add_theme_constant_override("separation", 20)
	identity.add_child(ident_row)
	var person := VBoxContainer.new()
	person.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ident_row.add_child(person)
	person.add_child(OopaAdminUI.label(str(_attempt.get("name", "")), 18, OopaAdminUI.WHITE))
	person.add_child(OopaAdminUI.label("%s  ·  %s  ·  attempt %s" % [str(_attempt.get("matric", "")), str(_attempt.get("status", "")).to_upper(), str(_attempt.get("attempt_id", ""))], 11, OopaAdminUI.MIST))
	ident_row.add_child(OopaAdminUI.label("Submitted  %s" % str(_attempt.get("submitted_at", "—")), 11, OopaAdminUI.MIST))
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 14)
	content.add_child(workspace)
	var answers_panel := OopaAdminUI.panel(workspace)
	answers_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answers_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var answers_body := VBoxContainer.new()
	answers_body.add_theme_constant_override("separation", 8)
	answers_panel.add_child(answers_body)
	answers_body.add_child(OopaAdminUI.label("Student responses", 16))
	var response_scroll := ScrollContainer.new()
	response_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	answers_body.add_child(response_scroll)
	var response_list := VBoxContainer.new()
	response_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	response_list.add_theme_constant_override("separation", 8)
	response_scroll.add_child(response_list)
	var answers: Dictionary = _attempt.get("answers", {})
	var items: Array = _exam.get("items", [])
	if items.is_empty():
		response_list.add_child(OopaAdminUI.label("No structured question records. Review the practical response.", 12, OopaAdminUI.MUTED))
	for index in range(items.size()):
		var item: Dictionary = items[index]
		var iid := str(item.get("item_id", ""))
		var response := str(answers.get(iid, ""))
		var card := OopaAdminUI.panel(response_list)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 5)
		card.add_child(v)
		v.add_child(OopaAdminUI.label("QUESTION %02d  ·  %s  ·  %.1f points" % [index + 1, str(item.get("type", "manual")).to_upper(), float(item.get("max_points", 0))], 10, OopaAdminUI.TEAL))
		var prompt := OopaAdminUI.label(str(item.get("prompt", iid)), 13)
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(prompt)
		var response_label := OopaAdminUI.label("Response: %s" % (response if not response.is_empty() else "No answer recorded"), 12, OopaAdminUI.GRAPHITE)
		response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(response_label)
		var expected := _expected_answer(item)
		if not expected.is_empty():
			var key := OopaAdminUI.label("Configured key: %s" % expected, 11, OopaAdminUI.MUTED)
			key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(key)
		var auto := OopaGradeService.new().auto_score_attempt(_exam, _attempt)
		for row in auto.get("breakdown", []):
			if str(row.get("item_id", "")) == iid:
				v.add_child(OopaAdminUI.label("Auto-score: %.1f / %.1f  ·  %s" % [float(row.get("points", 0)), float(row.get("max", 0)), str(row.get("note", ""))], 10, OopaAdminUI.MUTED))
				break
	var notes := str(answers.get("_practical_notes", ""))
	var notes_card := OopaAdminUI.panel(response_list)
	var notes_body := VBoxContainer.new()
	notes_body.add_theme_constant_override("separation", 6)
	notes_card.add_child(notes_body)
	notes_body.add_child(OopaAdminUI.label("PRACTICAL NOTES", 10, OopaAdminUI.TEAL))
	var notes_text := OopaAdminUI.label(notes if not notes.is_empty() else "No notes recorded.", 12)
	notes_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes_body.add_child(notes_text)
	var grade_panel := OopaAdminUI.panel(workspace)
	grade_panel.custom_minimum_size.x = 300
	grade_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grade_body := VBoxContainer.new()
	grade_body.add_theme_constant_override("separation", 10)
	grade_panel.add_child(grade_body)
	grade_body.add_child(OopaAdminUI.label("Marking summary", 17))
	var auto_score := OopaGradeService.new().auto_score_attempt(_exam, _attempt)
	grade_body.add_child(OopaAdminUI.label("Auto-score", 10, OopaAdminUI.MUTED))
	grade_body.add_child(OopaAdminUI.label("%.2f / %.2f" % [float(auto_score.get("auto_score", 0)), float(auto_score.get("max_auto", 0))], 22, OopaAdminUI.BLUE))
	var max_manual := OopaGradeService.new().max_manual(_exam)
	var existing: Dictionary = OopaLocalStore.new().load_grade(str(_exam.get("exam_id", "")), str(_attempt.get("matric", "")))
	grade_body.add_child(OopaAdminUI.label("MANUAL MARK  ·  MAX %.1f" % max_manual, 10, OopaAdminUI.MUTED))
	_manual = SpinBox.new()
	_manual.min_value = 0.0
	_manual.max_value = maxf(max_manual, 0.01)
	_manual.step = 0.5
	_manual.value = float(existing.get("manual_score", 0.0))
	grade_body.add_child(_manual)
	grade_body.add_child(OopaAdminUI.label("INSTRUCTOR FEEDBACK", 10, OopaAdminUI.MUTED))
	_comments = TextEdit.new()
	_comments.custom_minimum_size = Vector2(0, 130)
	_comments.placeholder_text = "Feedback for this attempt"
	_comments.text = str(existing.get("comments", ""))
	grade_body.add_child(_comments)
	grade_body.add_child(OopaAdminUI.label("Total and maximum are calculated by the existing grading service when saved.", 10, OopaAdminUI.MUTED))
	_msg = OopaAdminUI.label("", 11, OopaAdminUI.MUTED)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grade_body.add_child(_msg)
	var save := OopaAdminUI.button("Save grade", "PrimaryButton")
	save.custom_minimum_size.y = 44
	save.pressed.connect(_on_save)
	grade_body.add_child(save)


func _expected_answer(item: Dictionary) -> String:
	var payload: Dictionary = item.get("payload", {})
	match str(item.get("type", "")):
		"mcq":
			var index_value := str(payload.get("correct_index", payload.get("correct", "")))
			var options: Array = payload.get("options", [])
			if index_value.is_valid_float():
				var index_number := float(index_value)
				if is_equal_approx(index_number, floorf(index_number)) and int(index_number) >= 0 and int(index_number) < options.size():
					return str(options[int(index_number)])
			return index_value
		"numeric":
			return str(payload.get("value", ""))
		"short_text":
			return str(payload.get("answer", ""))
	return ""


func _on_save() -> void:
	var result: Dictionary = OopaGradeService.new().save_grade_record(AppState.instructor_session, _exam, _attempt, float(_manual.value), _comments.text)
	if not bool(result.get("ok", false)):
		_msg.text = str(result.get("message", "Grade could not be saved."))
		_msg.add_theme_color_override("font_color", OopaAdminUI.RED)
		return
	var grade: Dictionary = result.get("grade", {})
	_msg.text = "Saved  ·  %.2f / %.2f" % [float(grade.get("total", 0)), float(grade.get("max_points", 0))]
	_msg.add_theme_color_override("font_color", OopaAdminUI.TEAL)
