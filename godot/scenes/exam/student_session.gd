extends Control
## Focused timed examination UI; timer, autosave cadence and submission service are preserved.

var _exam: Dictionary
var _attempt: Dictionary
var _timer_label: Label
var _status: Label
var _notes: TextEdit
var _question_scroll: ScrollContainer
var _question_nav: GridContainer
var _item_edits: Dictionary = {}
var _item_cards: Dictionary = {}
var _nav_buttons: Dictionary = {}
var _item_order: Array[String] = []
var _remaining := 0.0
var _submitted := false
var _tick_acc := 0.0
var _submit_dialog: ConfirmationDialog
var _submit_button: Button


func _ready() -> void:
	_exam = AppState.current_exam
	_attempt = AppState.current_attempt
	if _exam.is_empty() or _attempt.is_empty() or str(_attempt.get("status", "")) != "in_progress":
		SceneRouter.go_student_exam_entry()
		return
	_remaining = float(_attempt.get("timer_seconds_remaining", int(_exam.get("duration_min", 15)) * 60))
	_build()
	set_process(true)


func _process(delta: float) -> void:
	if _submitted:
		return
	_remaining -= delta
	_tick_acc += delta
	if _tick_acc >= 5.0:
		_tick_acc = 0.0
		var autosave_error := _persist_progress()
		if autosave_error != OK:
			_status.text = "Automatic save failed. Use Save progress and keep this screen open."
			_status.add_theme_color_override("font_color", OopaAdminUI.RED)
	if _remaining <= 0.0:
		_remaining = 0.0
		_update_timer_label()
		_finish("expired")
		return
	_update_timer_label()


func _build() -> void:
	var content := OopaAdminUI.page(self, true)
	content.add_theme_constant_override("separation", 14)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	content.add_child(header)
	var id_block := VBoxContainer.new()
	id_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(id_block)
	id_block.add_child(OopaAdminUI.label("ASSESSMENT IN PROGRESS", 10, OopaAdminUI.TEAL))
	id_block.add_child(OopaAdminUI.label(str(_exam.get("title", "Examination")), 22, OopaAdminUI.WHITE))
	id_block.add_child(OopaAdminUI.label("%s  ·  %s  ·  %s" % [str(_exam.get("hub_id", "")).capitalize(), str(_attempt.get("name", "")), str(_attempt.get("matric", ""))], 11, OopaAdminUI.MIST))
	var timer_panel := OopaAdminUI.panel(header, true)
	var timer_stack := VBoxContainer.new()
	timer_stack.add_theme_constant_override("separation", 2)
	timer_panel.add_child(timer_stack)
	timer_stack.add_child(OopaAdminUI.label("TIME REMAINING", 9, OopaAdminUI.MIST))
	_timer_label = OopaAdminUI.label("00:00", 24, OopaAdminUI.TEAL)
	timer_stack.add_child(_timer_label)

	var practical := OopaAdminUI.status(content, "The assessment timer continues while you work in the assigned laboratory. Save progress is also recorded automatically every few seconds.", "info")
	practical.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 14)
	content.add_child(workspace)
	var question_panel := OopaAdminUI.panel(workspace)
	question_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var question_body := VBoxContainer.new()
	question_body.add_theme_constant_override("separation", 10)
	question_panel.add_child(question_body)
	var question_heading := HBoxContainer.new()
	question_body.add_child(question_heading)
	var count: int = (_exam.get("items", []) as Array).size()
	var qtitle := OopaAdminUI.label("Assessment questions" if count > 0 else "Practical response", 16)
	qtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_heading.add_child(qtitle)
	question_heading.add_child(OopaAdminUI.label("%d questions" % count if count > 0 else "Notes only", 11, OopaAdminUI.MUTED))
	_question_scroll = ScrollContainer.new()
	_question_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_question_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_body.add_child(_question_scroll)
	var question_list := VBoxContainer.new()
	question_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_list.add_theme_constant_override("separation", 12)
	_question_scroll.add_child(question_list)
	var items: Array = _exam.get("items", [])
	for index in range(items.size()):
		var item: Dictionary = items[index]
		var iid := str(item.get("item_id", ""))
		_item_order.append(iid)
		var card := OopaAdminUI.panel(question_list)
		_item_cards[iid] = card
		var card_body := VBoxContainer.new()
		card_body.add_theme_constant_override("separation", 8)
		card.add_child(card_body)
		var prompt := str(item.get("prompt", item.get("item_id", "Question")))
		card_body.add_child(OopaAdminUI.label("QUESTION %02d" % (index + 1), 10, OopaAdminUI.TEAL))
		var question_text := OopaAdminUI.label(prompt, 15)
		question_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_body.add_child(question_text)
		card_body.add_child(_build_item(item))
	if items.is_empty():
		question_list.add_child(OopaAdminUI.label("This practical exam has no structured questions. Record your observations below.", 13, OopaAdminUI.MUTED))
	var notes_card := OopaAdminUI.panel(question_list)
	var notes_stack := VBoxContainer.new()
	notes_stack.add_theme_constant_override("separation", 8)
	notes_card.add_child(notes_stack)
	notes_stack.add_child(OopaAdminUI.label("PRACTICAL NOTES", 10, OopaAdminUI.TEAL))
	_notes = TextEdit.new()
	_notes.custom_minimum_size = Vector2(0, 125)
	_notes.placeholder_text = "Record procedure, readings, and conclusions…"
	_notes.text = str(_attempt.get("answers", {}).get("_practical_notes", ""))
	_notes.text_changed.connect(_refresh_navigation)
	notes_stack.add_child(_notes)

	var side := OopaAdminUI.panel(workspace, true)
	side.custom_minimum_size.x = 230
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side_body := VBoxContainer.new()
	side_body.add_theme_constant_override("separation", 10)
	side.add_child(side_body)
	side_body.add_child(OopaAdminUI.label("Question map", 15, OopaAdminUI.WHITE))
	side_body.add_child(OopaAdminUI.label("Current  ·  Answered  ·  Unanswered", 10, OopaAdminUI.MIST))
	_question_nav = GridContainer.new()
	_question_nav.columns = 4
	_question_nav.add_theme_constant_override("h_separation", 5)
	_question_nav.add_theme_constant_override("v_separation", 5)
	side_body.add_child(_question_nav)
	for index in range(_item_order.size()):
		var iid := _item_order[index]
		var nav := OopaAdminUI.button("%02d" % (index + 1), "SecondaryButton")
		nav.custom_minimum_size = Vector2(42, 38)
		nav.pressed.connect(func(): _jump_to_question(iid))
		_question_nav.add_child(nav)
		_nav_buttons[iid] = nav
	var nav_hint := OopaAdminUI.label("Select a number to jump to its question. Review flags are not part of this exam format.", 10, OopaAdminUI.MIST)
	nav_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_body.add_child(nav_hint)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_body.add_child(spacer)
	var save := OopaAdminUI.button("Save progress", "SecondaryButton")
	save.pressed.connect(_on_save)
	side_body.add_child(save)
	_submit_button = OopaAdminUI.button("Submit assessment", "PrimaryButton")
	_submit_button.pressed.connect(_confirm_submission)
	side_body.add_child(_submit_button)
	_status = OopaAdminUI.label("", 11, OopaAdminUI.MIST)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_body.add_child(_status)
	_submit_dialog = ConfirmationDialog.new()
	_submit_dialog.title = "Submit assessment?"
	_submit_dialog.dialog_text = "Submission is final. Continue?"
	_submit_dialog.confirmed.connect(func(): _finish("submitted"))
	add_child(_submit_dialog)
	_update_timer_label()
	_refresh_navigation(_item_order[0] if not _item_order.is_empty() else "")


func _build_item(item: Dictionary) -> Control:
	var iid := str(item.get("item_id", ""))
	var kind := str(item.get("type", "manual"))
	var previous := str(_attempt.get("answers", {}).get(iid, ""))
	if kind == "mcq":
		var options: Array = item.get("payload", {}).get("options", [])
		var picker := OptionButton.new()
		picker.custom_minimum_size.y = 40
		picker.add_item("Choose an answer")
		picker.set_item_metadata(0, "")
		for index in range(options.size()):
			picker.add_item(str(options[index]))
			picker.set_item_metadata(picker.item_count - 1, str(index))
		if previous.is_valid_int():
			var selected := int(previous) + 1
			if selected > 0 and selected < picker.item_count:
				picker.select(selected)
		_item_edits[iid] = picker
		picker.item_selected.connect(func(_index: int): _refresh_navigation())
		return picker
	var answer := LineEdit.new()
	answer.custom_minimum_size.y = 40
	answer.placeholder_text = "Enter your answer"
	answer.text = previous
	_item_edits[iid] = answer
	answer.text_changed.connect(func(_text: String): _refresh_navigation())
	return answer


func _jump_to_question(item_id: String) -> void:
	if not _item_cards.has(item_id):
		return
	var card: Control = _item_cards[item_id]
	_question_scroll.scroll_vertical = int(card.position.y)
	_refresh_navigation(item_id)


func _refresh_navigation(current_id: String = "") -> void:
	for iid in _item_order:
		var control: Control = _item_edits[iid]
		var answered := false
		if control is OptionButton:
			answered = str((control as OptionButton).get_item_metadata((control as OptionButton).selected)) != ""
		elif control is LineEdit:
			answered = not (control as LineEdit).text.strip_edges().is_empty()
		var nav: Button = _nav_buttons[iid]
		var number := _item_order.find(iid) + 1
		nav.text = ("✓ " if answered else "· ") + "%02d" % number
		nav.theme_type_variation = &"PrimaryButton" if iid == current_id else (&"TertiaryButton" if answered else &"SecondaryButton")


func _collect_answers() -> Dictionary:
	var answers: Dictionary = _attempt.get("answers", {}).duplicate(true)
	for iid in _item_edits:
		var control = _item_edits[iid]
		if control is OptionButton:
			answers[iid] = str((control as OptionButton).get_item_metadata((control as OptionButton).selected))
		elif control is LineEdit:
			answers[iid] = (control as LineEdit).text
	if _notes:
		answers["_practical_notes"] = _notes.text
	return answers


func _persist_progress() -> Error:
	if _submitted:
		return ERR_UNAVAILABLE
	_attempt["answers"] = _collect_answers()
	_attempt["timer_seconds_remaining"] = int(ceil(_remaining))
	var err: Error = OopaAttemptService.new().save_progress(_attempt)
	if err == OK:
		AppState.current_attempt = _attempt.duplicate(true)
	return err


func _on_save() -> void:
	var err := _persist_progress()
	if err == OK:
		_status.text = "Progress saved to this device."
		_status.add_theme_color_override("font_color", OopaAdminUI.TEAL)
	else:
		_status.text = "Progress could not be saved. Keep this screen open and try again."
		_status.add_theme_color_override("font_color", OopaAdminUI.RED)


func _update_timer_label() -> void:
	var seconds := maxi(int(ceil(_remaining)), 0)
	_timer_label.text = "%02d:%02d" % [int(seconds / 60), seconds % 60]
	var color := OopaAdminUI.TEAL
	if seconds <= 60:
		color = OopaAdminUI.RED
	elif seconds <= 180:
		color = OopaAdminUI.AMBER
	_timer_label.add_theme_color_override("font_color", color)


func _confirm_submission() -> void:
	if _submitted:
		return
	var unanswered := 0
	for iid in _item_order:
		var control: Control = _item_edits[iid]
		if control is OptionButton:
			if str((control as OptionButton).get_item_metadata((control as OptionButton).selected)).is_empty():
				unanswered += 1
		elif control is LineEdit and (control as LineEdit).text.strip_edges().is_empty():
			unanswered += 1
	_submit_dialog.dialog_text = ("%d question(s) have no answer. " % unanswered if unanswered > 0 else "") + "Submission is final. Continue?"
	_submit_dialog.popup_centered()


func _finish(reason: String) -> void:
	if _submitted:
		return
	_submitted = true
	set_process(false)
	_attempt["answers"] = _collect_answers()
	_attempt["timer_seconds_remaining"] = maxi(int(ceil(_remaining)), 0)
	var result: Dictionary = OopaAttemptService.new().submit_attempt(_attempt, reason)
	_attempt = result.get("attempt", _attempt)
	AppState.current_attempt = _attempt.duplicate(true)
	if not bool(result.get("ok", false)):
		_status.text = "The submission could not be confirmed as saved. Keep this screen open and contact your instructor."
		_status.add_theme_color_override("font_color", OopaAdminUI.RED)
		_submitted = false
		_submit_button.disabled = false
		_submit_button.text = "Retry submission"
		if reason != "expired":
			set_process(true)
		return
	else:
		_status.text = "Time expired; your work was submitted automatically." if reason == "expired" else "Assessment submitted and saved on this device."
		_status.add_theme_color_override("font_color", OopaAdminUI.TEAL)
	for control in _item_edits.values():
		if control is LineEdit:
			(control as LineEdit).editable = false
		elif control is OptionButton:
			(control as OptionButton).disabled = true
	_notes.editable = false
	_submit_button.disabled = true
	var done := OopaAdminUI.button("Return to main menu", "TertiaryButton")
	done.pressed.connect(func(): AppState.clear_exam_session(); SceneRouter.go_main_menu())
	_status.get_parent().add_child(done)
