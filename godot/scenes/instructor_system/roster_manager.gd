extends Control
## Create, import CSV, edit, delete student whitelists.

var _hub: OptionButton
var _label: LineEdit
var _csv: TextEdit
var _msg: Label
var _list: VBoxContainer
var _active: Dictionary = {}
var _table: VBoxContainer


func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_reload()


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
	eye.text = "STUDENT REGISTRATION"
	eye.add_theme_color_override("font_color", Color("#b22222"))
	root_v.add_child(eye)
	var title := Label.new()
	title.text = "Whitelist (exam eligibility)"
	title.add_theme_font_size_override("font_size", 24)
	root_v.add_child(title)

	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", 12)
	root_v.add_child(form)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	form.add_child(left)

	left.add_child(_lbl("Hub"))
	_hub = OptionButton.new()
	for h in OopaAuthService.new().allowed_hubs(AppState.instructor_session):
		_hub.add_item(h)
		_hub.set_item_metadata(_hub.item_count - 1, h)
	left.add_child(_hub)

	left.add_child(_lbl("List label"))
	_label = LineEdit.new()
	_label.placeholder_text = "e.g. CHEM101 2026 Cohort"
	left.add_child(_label)

	left.add_child(_lbl("Paste CSV (S/N, Student Name, Matric Number)"))
	_csv = TextEdit.new()
	_csv.custom_minimum_size = Vector2(0, 140)
	_csv.placeholder_text = "S/N,Student Name,Matric Number\n1,Ada Okafor,CHEM/2024/001"
	left.add_child(_csv)

	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_color_override("font_color", Color("#b22222"))
	left.add_child(_msg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	left.add_child(row)
	var bimp := Button.new()
	bimp.text = "Import CSV → new list"
	bimp.pressed.connect(_on_import)
	row.add_child(bimp)
	var bempty := Button.new()
	bempty.text = "Create empty list"
	bempty.theme_type_variation = &"GhostButton"
	bempty.pressed.connect(_on_empty)
	row.add_child(bempty)
	var bback := Button.new()
	bback.text = "Dashboard"
	bback.theme_type_variation = &"GhostButton"
	bback.pressed.connect(func(): SceneRouter.go_instructor_dashboard())
	row.add_child(bback)
	var bexam := Button.new()
	bexam.text = "Exam editor"
	bexam.theme_type_variation = &"GhostButton"
	bexam.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/instructor_system/exam_editor.tscn"))
	row.add_child(bexam)

	# Existing lists
	var lt := Label.new()
	lt.text = "Saved lists"
	lt.add_theme_font_size_override("font_size", 16)
	root_v.add_child(lt)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var et := Label.new()
	et.text = "Selected list editor"
	et.add_theme_font_size_override("font_size", 16)
	root_v.add_child(et)
	_table = VBoxContainer.new()
	_table.add_theme_constant_override("separation", 4)
	root_v.add_child(_table)


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 12)
	return l


func _on_import() -> void:
	if _hub.item_count == 0:
		_msg.text = "No hub."
		return
	var hub: String = str(_hub.get_item_metadata(_hub.selected))
	var res: Dictionary = OopaRosterService.new().import_csv_text(
		AppState.instructor_session, hub, _label.text, _csv.text
	)
	if not bool(res.get("ok", false)):
		_msg.text = str(res.get("message", "Import failed"))
		return
	_msg.add_theme_color_override("font_color", Color("#2e7d32"))
	_msg.text = "Imported %s" % str(res.get("roster", {}).get("roster_id", ""))
	_reload()


func _on_empty() -> void:
	if _hub.item_count == 0:
		return
	var hub: String = str(_hub.get_item_metadata(_hub.selected))
	var res: Dictionary = OopaRosterService.new().create_roster(
		AppState.instructor_session, hub, _label.text, [], "manual"
	)
	if not bool(res.get("ok", false)):
		_msg.text = str(res.get("message", "Failed"))
		return
	_msg.text = "Created empty list"
	_reload()
	_select_roster(res.get("roster", {}))


func _reload() -> void:
	for c in _list.get_children():
		c.queue_free()
	for r in OopaRosterService.new().list_for_session(AppState.instructor_session):
		var row := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text = "%s · %s · %d students" % [
			str(r.get("label", "")), str(r.get("roster_id", "")), (r.get("students", []) as Array).size()
		]
		row.add_child(l)
		var b := Button.new()
		b.text = "Edit"
		var roster: Dictionary = r
		b.pressed.connect(func(): _select_roster(roster))
		row.add_child(b)
		var bd := Button.new()
		bd.text = "Delete"
		bd.theme_type_variation = &"GhostButton"
		bd.pressed.connect(func(): _delete_roster(str(roster.get("roster_id", ""))))
		row.add_child(bd)
		_list.add_child(row)


func _delete_roster(rid: String) -> void:
	OopaRosterService.new().delete_roster(AppState.instructor_session, rid)
	_active = {}
	_reload()
	_render_table()


func _select_roster(roster: Dictionary) -> void:
	_active = roster.duplicate(true)
	_render_table()


func _render_table() -> void:
	for c in _table.get_children():
		c.queue_free()
	if _active.is_empty():
		var e := Label.new()
		e.text = "Select a list to edit."
		_table.add_child(e)
		return
	var hdr := Label.new()
	hdr.text = "Editing %s" % str(_active.get("roster_id", ""))
	_table.add_child(hdr)
	for s in _active.get("students", []):
		var row := HBoxContainer.new()
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text = "%s · %s · %s" % [str(s.get("sn", "")), str(s.get("name", "")), str(s.get("matric", ""))]
		row.add_child(l)
		var bm := Button.new()
		bm.text = "Remove"
		bm.theme_type_variation = &"GhostButton"
		var matric: String = str(s.get("matric", ""))
		bm.pressed.connect(func(): _remove_student(matric))
		row.add_child(bm)
		_table.add_child(row)
	var add_row := HBoxContainer.new()
	var name_e := LineEdit.new()
	name_e.placeholder_text = "Name"
	name_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(name_e)
	var mat_e := LineEdit.new()
	mat_e.placeholder_text = "Matric"
	mat_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(mat_e)
	var ba := Button.new()
	ba.text = "Add student"
	ba.pressed.connect(func(): _add_student(name_e.text, mat_e.text))
	add_row.add_child(ba)
	_table.add_child(add_row)
	var bs := Button.new()
	bs.text = "Save list"
	bs.pressed.connect(_save_active)
	_table.add_child(bs)


func _remove_student(matric: String) -> void:
	var m: String = OopaIds.normalize_matric(matric)
	var kept: Array = []
	for s in _active.get("students", []):
		if OopaIds.normalize_matric(str(s.get("matric", ""))) != m:
			kept.append(s)
	_active["students"] = kept
	_render_table()


func _add_student(name: String, matric: String) -> void:
	if name.strip_edges().is_empty() or matric.strip_edges().is_empty():
		_msg.text = "Name and matric required"
		return
	var students: Array = _active.get("students", [])
	var sn: int = students.size() + 1
	students.append(OopaSchemas.student_row(sn, name, matric))
	_active["students"] = students
	_render_table()


func _save_active() -> void:
	var res: Dictionary = OopaRosterService.new().save_roster(AppState.instructor_session, _active)
	if not bool(res.get("ok", false)):
		_msg.text = str(res.get("message", "Save failed"))
		return
	_active = res.get("roster", _active)
	_msg.add_theme_color_override("font_color", Color("#2e7d32"))
	_msg.text = "List saved (JSON + CSV mirror)"
	_reload()
