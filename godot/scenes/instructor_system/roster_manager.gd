extends Control
## Instructor roster workspace; storage, IDs, validation and CSV handling remain in services.

var _hub: OptionButton
var _label: LineEdit
var _csv: TextEdit
var _msg: Label
var _list: VBoxContainer
var _table: VBoxContainer
var _active: Dictionary = {}


func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	var content := OopaAdminUI.page(self)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var intro := OopaAdminUI.heading(heading, "Academic records", "Student rosters", "Manage eligibility lists for your authorised hubs.")
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := OopaAdminUI.button("Back to overview", "TertiaryButton")
	back.pressed.connect(func(): SceneRouter.go_instructor_dashboard())
	heading.add_child(back)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	content.add_child(split)
	var left := OopaAdminUI.panel(split)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	var left_body := VBoxContainer.new()
	left_body.add_theme_constant_override("separation", 10)
	left.add_child(left_body)
	left_body.add_child(OopaAdminUI.label("Create or import a roster", 17))
	left_body.add_child(OopaAdminUI.label("CSV columns: S/N, Student Name, Matric Number", 11, OopaAdminUI.MUTED))
	_hub = OptionButton.new()
	for hub_id in OopaAuthService.new().allowed_hubs(AppState.instructor_session):
		_hub.add_item(hub_id.capitalize())
		_hub.set_item_metadata(_hub.item_count - 1, hub_id)
	left_body.add_child(_hub)
	_label = LineEdit.new()
	_label.placeholder_text = "Roster name"
	left_body.add_child(_label)
	_csv = TextEdit.new()
	_csv.custom_minimum_size = Vector2(0, 150)
	_csv.placeholder_text = "1,Ada Okafor,CHEM/2026/001"
	left_body.add_child(_csv)
	var import_btn := OopaAdminUI.button("Import CSV", "PrimaryButton")
	import_btn.pressed.connect(_on_import)
	left_body.add_child(import_btn)
	var empty_btn := OopaAdminUI.button("Create empty roster", "SecondaryButton")
	empty_btn.pressed.connect(_on_empty)
	left_body.add_child(empty_btn)
	_msg = OopaAdminUI.label("", 11, OopaAdminUI.MUTED)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_body.add_child(_msg)
	var right := OopaAdminUI.panel(split)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.25
	var right_body := VBoxContainer.new()
	right_body.add_theme_constant_override("separation", 10)
	right.add_child(right_body)
	right_body.add_child(OopaAdminUI.label("Saved rosters", 17))
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0, 145)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_body.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)
	var rule := HSeparator.new()
	right_body.add_child(rule)
	_table = VBoxContainer.new()
	_table.add_theme_constant_override("separation", 7)
	var edit_scroll := ScrollContainer.new()
	edit_scroll.custom_minimum_size = Vector2(0, 185)
	edit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit_scroll.add_child(_table)
	right_body.add_child(edit_scroll)
	_reload()
	_render_table()


func _on_import() -> void:
	if _hub.item_count == 0:
		_set_message("No authorised hub is available.", "error")
		return
	var hub_id := str(_hub.get_item_metadata(_hub.selected))
	var result: Dictionary = OopaRosterService.new().import_csv_text(AppState.instructor_session, hub_id, _label.text, _csv.text)
	if not bool(result.get("ok", false)):
		_set_message(str(result.get("message", "Import failed.")), "error")
		return
	_active = result.get("roster", {}).duplicate(true)
	_set_message("Roster imported and saved.", "success")
	_csv.clear()
	_reload()
	_render_table()


func _on_empty() -> void:
	if _hub.item_count == 0:
		_set_message("No authorised hub is available.", "error")
		return
	var result: Dictionary = OopaRosterService.new().create_roster(AppState.instructor_session, str(_hub.get_item_metadata(_hub.selected)), _label.text, [], "manual")
	if not bool(result.get("ok", false)):
		_set_message(str(result.get("message", "Could not create roster.")), "error")
		return
	_active = result.get("roster", {}).duplicate(true)
	_set_message("Empty roster created.", "success")
	_reload()
	_render_table()


func _reload() -> void:
	for child in _list.get_children():
		child.queue_free()
	var rosters := OopaRosterService.new().list_for_session(AppState.instructor_session)
	if rosters.is_empty():
		_list.add_child(OopaAdminUI.label("No rosters available in your hub scope.", 12, OopaAdminUI.MUTED))
		return
	for roster in rosters:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_list.add_child(row)
		var info := OopaAdminUI.label("%s  ·  %d students" % [str(roster.get("label", "Roster")), (roster.get("students", []) as Array).size()], 12)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var edit := OopaAdminUI.button("Open", "TertiaryButton")
		var record: Dictionary = roster
		edit.pressed.connect(func(): _select_roster(record))
		row.add_child(edit)
		var delete := OopaAdminUI.button("Delete", "DestructiveButton")
		delete.pressed.connect(func(): _delete_roster(str(record.get("roster_id", ""))))
		row.add_child(delete)


func _delete_roster(roster_id: String) -> void:
	var result: Dictionary = OopaRosterService.new().delete_roster(AppState.instructor_session, roster_id)
	if not bool(result.get("ok", false)):
		_set_message(str(result.get("message", "Delete failed.")), "error")
		return
	_active = {}
	_set_message("Roster deleted.", "success")
	_reload()
	_render_table()


func _select_roster(roster: Dictionary) -> void:
	_active = roster.duplicate(true)
	_render_table()


func _render_table() -> void:
	for child in _table.get_children():
		child.queue_free()
	if _active.is_empty():
		_table.add_child(OopaAdminUI.label("Choose a roster to edit its student list.", 12, OopaAdminUI.MUTED))
		return
	_table.add_child(OopaAdminUI.label("%s  ·  %d students" % [str(_active.get("label", "Roster")), (_active.get("students", []) as Array).size()], 14))
	var students: Array = _active.get("students", [])
	for student in students:
		var row := HBoxContainer.new()
		_table.add_child(row)
		var identity := OopaAdminUI.label("%s  ·  %s" % [str(student.get("name", "")), str(student.get("matric", ""))], 12)
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(identity)
		var remove := OopaAdminUI.button("Remove", "TertiaryButton")
		var matric := str(student.get("matric", ""))
		remove.pressed.connect(func(): _remove_student(matric))
		row.add_child(remove)
	var add_row := HBoxContainer.new()
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Student name"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(name_input)
	var matric_input := LineEdit.new()
	matric_input.placeholder_text = "Matric number"
	matric_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(matric_input)
	var add := OopaAdminUI.button("Add", "SecondaryButton")
	add.pressed.connect(func(): _add_student(name_input.text, matric_input.text))
	add_row.add_child(add)
	_table.add_child(add_row)
	var save := OopaAdminUI.button("Save roster", "PrimaryButton")
	save.pressed.connect(_save_active)
	_table.add_child(save)


func _remove_student(matric: String) -> void:
	var normalized := OopaIds.normalize_matric(matric)
	var kept: Array = []
	for student in _active.get("students", []):
		if OopaIds.normalize_matric(str(student.get("matric", ""))) != normalized:
			kept.append(student)
	_active["students"] = kept
	_render_table()


func _add_student(student_name: String, matric: String) -> void:
	if student_name.strip_edges().is_empty() or matric.strip_edges().is_empty():
		_set_message("Enter both a name and matric number.", "error")
		return
	var students: Array = _active.get("students", [])
	students.append(OopaSchemas.student_row(students.size() + 1, student_name, matric))
	_active["students"] = students
	_render_table()


func _save_active() -> void:
	var result: Dictionary = OopaRosterService.new().save_roster(AppState.instructor_session, _active)
	if not bool(result.get("ok", false)):
		_set_message(str(result.get("message", "Save failed.")), "error")
		return
	_active = result.get("roster", _active)
	_set_message("Roster saved. JSON data and CSV mirror updated.", "success")
	_reload()
	_render_table()


func _set_message(text: String, kind: String) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", OopaAdminUI.RED if kind == "error" else OopaAdminUI.TEAL)
