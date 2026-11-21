extends Control
## Timed exam session — hybrid answers + auto-submit on expiry.

var _exam: Dictionary
var _attempt: Dictionary
var _timer_label: Label
var _status: Label
var _notes: TextEdit
var _item_edits: Dictionary = {}  # item_id -> control
var _remaining: float = 0.0
var _submitted: bool = false
var _tick_acc: float = 0.0


func _ready() -> void:
	_exam = AppState.current_exam
	_attempt = AppState.current_attempt
	if _exam.is_empty() or _attempt.is_empty():
		SceneRouter.go_student_exam_entry()
		return
	if str(_attempt.get("status", "")) != "in_progress":
		SceneRouter.go_student_exam_entry()
		return
	_remaining = float(_attempt.get("timer_seconds_remaining", int(_exam.get("duration_min", 15)) * 60))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	set_process(true)


func _process(delta: float) -> void:
	if _submitted:
		return
	_remaining -= delta
	_tick_acc += delta
	if _tick_acc >= 5.0:
		_tick_acc = 0.0
		_persist_progress()
	if _remaining <= 0.0:
		_remaining = 0.0
		_update_timer_label()
		_finish("expired")
		return
	_update_timer_label()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#faf9f8")
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	margin.add_child(root_v)

	var top := HBoxContainer.new()
	root_v.add_child(top)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	var eye := Label.new()
	eye.text = "EXAM IN PROGRESS"
	eye.add_theme_color_override("font_color", Color("#b22222"))
	left.add_child(eye)
	var title := Label.new()
	title.text = str(_exam.get("title", "Examination"))
	title.add_theme_font_size_override("font_size", 22)
	left.add_child(title)
	var meta := Label.new()
	meta.text = "%s · Lab: %s · %s (%s)" % [
		str(_exam.get("exam_id", "")),
		str(_exam.get("lab_id", "")),
		str(_attempt.get("name", "")),
		str(_attempt.get("matric", "")),
	]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color("#555555"))
	left.add_child(meta)

	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.add_theme_color_override("font_color", Color("#b22222"))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_timer_label)

	var lab_hint := Label.new()
	lab_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab_hint.text = "Practical focus: open the assigned lab from the main menu if needed, then record observations here. Timer continues while you work."
	lab_hint.add_theme_font_size_override("font_size", 12)
	lab_hint.add_theme_color_override("font_color", Color("#666666"))
	root_v.add_child(lab_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	root_v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	# Hybrid items from exam (may be empty in M03-created exams)
	var items: Array = _exam.get("items", [])
	if items.is_empty():
		var info := Label.new()
		info.text = "No structured questions on this exam — complete the practical notes below."
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(info)
	else:
		for item in items:
			body.add_child(_build_item(item))

	var nl := Label.new()
	nl.text = "Practical notes / observations"
	nl.add_theme_font_size_override("font_size", 14)
	body.add_child(nl)
	_notes = TextEdit.new()
	_notes.custom_minimum_size = Vector2(0, 120)
	_notes.placeholder_text = "Record procedure, readings, and conclusions…"
	var existing: Variant = _attempt.get("answers", {}).get("_practical_notes", "")
	_notes.text = str(existing)
	body.add_child(_notes)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_v.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root_v.add_child(row)
	var bsave := Button.new()
	bsave.text = "Save progress"
	bsave.theme_type_variation = &"GhostButton"
	bsave.pressed.connect(func(): _persist_progress(); _status.text = "Progress saved.")
	row.add_child(bsave)
	var bsub := Button.new()
	bsub.text = "Submit exam"
	bsub.pressed.connect(func(): _finish("submitted"))
	row.add_child(bsub)

	_update_timer_label()


func _build_item(item: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var prompt := Label.new()
	prompt.text = str(item.get("prompt", item.get("item_id", "Question")))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 13)
	box.add_child(prompt)
	var iid: String = str(item.get("item_id", ""))
	var typ: String = str(item.get("type", "manual"))
	var answers: Dictionary = _attempt.get("answers", {})
	var prev: String = str(answers.get(iid, ""))
	if typ == "mcq":
		var opts: Array = item.get("payload", {}).get("options", [])
		var ob := OptionButton.new()
		ob.add_item("— select —")
		ob.set_item_metadata(0, "")
		for i in range(opts.size()):
			ob.add_item(str(opts[i]))
			ob.set_item_metadata(ob.item_count - 1, str(i))
		if prev != "" and prev.is_valid_int():
			var idx: int = int(prev) + 1
			if idx < ob.item_count:
				ob.select(idx)
		_item_edits[iid] = ob
		box.add_child(ob)
	else:
		var le := LineEdit.new()
		le.placeholder_text = "Answer"
		le.text = prev
		_item_edits[iid] = le
		box.add_child(le)
	return box


func _collect_answers() -> Dictionary:
	var answers: Dictionary = _attempt.get("answers", {}).duplicate(true)
	for iid in _item_edits.keys():
		var ctrl = _item_edits[iid]
		if ctrl is OptionButton:
			var ob: OptionButton = ctrl
			answers[iid] = str(ob.get_item_metadata(ob.selected))
		elif ctrl is LineEdit:
			answers[iid] = (ctrl as LineEdit).text
	if _notes:
		answers["_practical_notes"] = _notes.text
	return answers


func _persist_progress() -> void:
	if _submitted:
		return
	_attempt["answers"] = _collect_answers()
	_attempt["timer_seconds_remaining"] = int(ceil(_remaining))
	OopaAttemptService.new().save_progress(_attempt)
	AppState.current_attempt = _attempt.duplicate(true)


func _update_timer_label() -> void:
	var sec: int = maxi(int(ceil(_remaining)), 0)
	var m: int = int(sec / 60)
	var s: int = sec % 60
	_timer_label.text = "%02d:%02d" % [m, s]
	if sec <= 60:
		_timer_label.add_theme_color_override("font_color", Color("#c62828"))
	elif sec <= 180:
		_timer_label.add_theme_color_override("font_color", Color("#ef6c00"))


func _finish(reason: String) -> void:
	if _submitted:
		return
	_submitted = true
	set_process(false)
	_attempt["answers"] = _collect_answers()
	_attempt["timer_seconds_remaining"] = maxi(int(ceil(_remaining)), 0)
	var res: Dictionary = OopaAttemptService.new().submit_attempt(_attempt, reason)
	_attempt = res.get("attempt", _attempt)
	AppState.current_attempt = _attempt.duplicate(true)
	_status.add_theme_color_override("font_color", Color("#2e7d32"))
	if reason == "expired":
		_status.text = "Time is up — your work was submitted automatically."
	else:
		_status.text = "Exam submitted. You may return to the main menu."
	# Block further edits
	if _notes:
		_notes.editable = false
	for k in _item_edits.keys():
		var ctrl = _item_edits[k]
		if ctrl is LineEdit:
			(ctrl as LineEdit).editable = false
		elif ctrl is OptionButton:
			(ctrl as OptionButton).disabled = true

	var bdone := Button.new()
	bdone.text = "Return to main menu"
	bdone.pressed.connect(func():
		AppState.clear_exam_session()
		SceneRouter.go_main_menu()
	)
	add_child(bdone)
	bdone.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bdone.position = Vector2(size.x * 0.5 - 80, size.y - 48)
