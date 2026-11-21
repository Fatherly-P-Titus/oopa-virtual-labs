extends Control
## Grade one attempt — auto breakdown + manual score + comments.

var _exam: Dictionary
var _attempt: Dictionary
var _manual: SpinBox
var _comments: TextEdit
var _msg: Label
var _auto_label: Label


func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	var eid: String = str(AppState.get_meta("grade_exam_id", ""))
	var aid: String = str(AppState.get_meta("grade_attempt_id", ""))
	_exam = OopaLocalStore.new().load_exam(eid)
	_attempt = OopaLocalStore.new().load_attempt(eid, aid)
	if _exam.is_empty() or _attempt.is_empty():
		SceneRouter.go_instructor_dashboard()
		return
	if not OopaAuthService.new().can_access_hub(AppState.instructor_session, str(_exam.get("hub_id", ""))):
		SceneRouter.go_instructor_dashboard()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


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
	root_v.add_theme_constant_override("separation", 10)
	margin.add_child(root_v)

	var eye := Label.new()
	eye.text = "GRADE ATTEMPT"
	eye.add_theme_color_override("font_color", Color("#b22222"))
	root_v.add_child(eye)
	var title := Label.new()
	title.text = str(_exam.get("title", ""))
	title.add_theme_font_size_override("font_size", 22)
	root_v.add_child(title)
	var who := Label.new()
	who.text = "%s · %s · attempt %s · %s" % [
		str(_attempt.get("name", "")),
		str(_attempt.get("matric", "")),
		str(_attempt.get("attempt_id", "")),
		str(_attempt.get("status", "")),
	]
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.add_theme_font_size_override("font_size", 12)
	who.add_theme_color_override("font_color", Color("#555555"))
	root_v.add_child(who)

	var auto: Dictionary = OopaGradeService.new().auto_score_attempt(_exam, _attempt)
	_auto_label = Label.new()
	_auto_label.text = "Auto-score: %.2f / %.2f" % [float(auto.get("auto_score", 0)), float(auto.get("max_auto", 0))]
	_auto_label.add_theme_font_size_override("font_size", 16)
	root_v.add_child(_auto_label)

	for row in auto.get("breakdown", []):
		var l := Label.new()
		l.text = " · %s [%s]: %.1f / %.1f — %s" % [
			str(row.get("item_id", "")), str(row.get("type", "")),
			float(row.get("points", 0)), float(row.get("max", 0)), str(row.get("note", "")),
		]
		l.add_theme_font_size_override("font_size", 11)
		root_v.add_child(l)

	# Show practical notes
	var notes: String = str(_attempt.get("answers", {}).get("_practical_notes", ""))
	var nl := Label.new()
	nl.text = "Practical notes"
	nl.add_theme_font_size_override("font_size", 14)
	root_v.add_child(nl)
	var notes_box := TextEdit.new()
	notes_box.text = notes
	notes_box.editable = false
	notes_box.custom_minimum_size = Vector2(0, 100)
	root_v.add_child(notes_box)

	var max_man: float = OopaGradeService.new().max_manual(_exam)
	var existing: Dictionary = OopaLocalStore.new().load_grade(str(_exam.get("exam_id", "")), str(_attempt.get("matric", "")))
	var man_init: float = float(existing.get("manual_score", 0.0))

	var ml := Label.new()
	ml.text = "Manual score (0 – %.1f)" % max_man
	root_v.add_child(ml)
	_manual = SpinBox.new()
	_manual.min_value = 0.0
	_manual.max_value = maxf(max_man, 0.01)
	_manual.step = 0.5
	_manual.value = man_init
	root_v.add_child(_manual)

	var cl := Label.new()
	cl.text = "Comments"
	root_v.add_child(cl)
	_comments = TextEdit.new()
	_comments.custom_minimum_size = Vector2(0, 80)
	_comments.text = str(existing.get("comments", ""))
	root_v.add_child(_comments)

	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_v.add_child(_msg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root_v.add_child(row)
	var bsave := Button.new()
	bsave.text = "Save grade"
	bsave.pressed.connect(_on_save)
	row.add_child(bsave)
	var bback := Button.new()
	bback.text = "Back to list"
	bback.theme_type_variation = &"GhostButton"
	bback.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/instructor_system/grading_browser.tscn"))
	row.add_child(bback)


func _on_save() -> void:
	var res: Dictionary = OopaGradeService.new().save_grade_record(
		AppState.instructor_session,
		_exam,
		_attempt,
		float(_manual.value),
		_comments.text
	)
	if not bool(res.get("ok", false)):
		_msg.add_theme_color_override("font_color", Color("#b22222"))
		_msg.text = str(res.get("message", "Failed"))
		return
	var g: Dictionary = res.get("grade", {})
	_msg.add_theme_color_override("font_color", Color("#2e7d32"))
	_msg.text = "Saved · total %.2f / %.2f" % [float(g.get("total", 0)), float(g.get("max_points", 0))]
