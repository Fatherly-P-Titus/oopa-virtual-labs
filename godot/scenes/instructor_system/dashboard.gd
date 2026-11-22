extends Control
## Instructor overview populated only from the local instructor system records.

var _labs_panel: VBoxContainer


func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	var content := OopaAdminUI.page(self)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	scroll.add_child(body)
	var session: Dictionary = AppState.instructor_session
	var top := HBoxContainer.new()
	body.add_child(top)
	var intro := OopaAdminUI.heading(top, "Academic workspace", "Instructor overview", "%s  ·  %s  ·  %s" % [str(session.get("display_name", "")), str(session.get("staff_id", "")), str(session.get("role", "")).capitalize()])
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions := VBoxContainer.new()
	top.add_child(actions)
	var logout := OopaAdminUI.button("Sign out", "SecondaryButton")
	logout.pressed.connect(_on_logout)
	actions.add_child(logout)
	var menu := OopaAdminUI.button("Main menu", "TertiaryButton")
	menu.pressed.connect(func(): SceneRouter.go_main_menu())
	actions.add_child(menu)

	var hubs := OopaAuthService.new().allowed_hubs(session)
	var metrics := VBoxContainer.new()
	metrics.add_theme_constant_override("separation", 12)
	body.add_child(metrics)
	var stats := _collect_metrics(session)
	var metrics_top := HBoxContainer.new()
	metrics_top.add_theme_constant_override("separation", 12)
	metrics.add_child(metrics_top)
	OopaAdminUI.stat_card(metrics_top, "Registered students", str(stats.students), "Unique students in accessible rosters")
	OopaAdminUI.stat_card(metrics_top, "Examinations", str(stats.exams), "Exams in your hub access scope")
	var metrics_bottom := HBoxContainer.new()
	metrics_bottom.add_theme_constant_override("separation", 12)
	metrics.add_child(metrics_bottom)
	OopaAdminUI.stat_card(metrics_bottom, "Awaiting grading", str(stats.pending), "Submitted or expired attempts without a saved grade")
	OopaAdminUI.stat_card(metrics_bottom, "Available labs", str(_count_labs(hubs)), "Published labs in your authorised hubs")

	var section_head := HBoxContainer.new()
	body.add_child(section_head)
	var exam_title := OopaAdminUI.label("Recent examinations", 18)
	exam_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_head.add_child(exam_title)
	var all_exams := OopaAdminUI.button("Manage examinations", "TertiaryButton")
	all_exams.pressed.connect(func(): SceneRouter.go_exam_editor())
	section_head.add_child(all_exams)
	var exam_panel := OopaAdminUI.panel(body)
	var exam_list := VBoxContainer.new()
	exam_list.add_theme_constant_override("separation", 8)
	exam_panel.add_child(exam_list)
	var exams: Array = OopaExamService.new().list_for_session(session)
	exams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("created_at", "")) > str(b.get("created_at", "")))
	if exams.is_empty():
		exam_list.add_child(OopaAdminUI.label("No examinations have been created in your scope.", 13, OopaAdminUI.MUTED))
	else:
		for i in range(mini(3, exams.size())):
			var e: Dictionary = exams[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			exam_list.add_child(row)
			var name := OopaAdminUI.label(str(e.get("title", "Untitled examination")), 14)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name)
			row.add_child(OopaAdminUI.label("%s  ·  %s  ·  %s" % [str(e.get("hub_id", "")).capitalize(), str(e.get("status", "")).capitalize(), str(e.get("created_at", "")).left(10)], 11, OopaAdminUI.MUTED))

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	body.add_child(nav)
	_nav_card(nav, "Student rosters", "Import a roster or maintain its registered students.", "Manage students", func(): SceneRouter.go_roster_manager())
	_nav_card(nav, "Exam management", "Create and review examinations for your authorised labs.", "Open examinations", func(): SceneRouter.go_exam_editor())
	_nav_card(nav, "Grading and results", "Review submitted work, save marks, and export results.", "Open grading", func(): SceneRouter.go_grading())

	var labs_head := OopaAdminUI.label("Laboratory access", 16)
	body.add_child(labs_head)
	_labs_panel = VBoxContainer.new()
	_labs_panel.add_theme_constant_override("separation", 6)
	body.add_child(_labs_panel)
	_show_labs(hubs)


func _collect_metrics(session: Dictionary) -> Dictionary:
	var store := OopaLocalStore.new()
	var rosters: Array = OopaRosterService.new().list_for_session(session)
	var seen: Dictionary = {}
	for roster in rosters:
		for student in roster.get("students", []):
			seen[OopaIds.normalize_matric(str(student.get("matric", "")))] = true
	var exams: Array = OopaExamService.new().list_for_session(session)
	var pending := 0
	for exam in exams:
		for attempt in store.list_attempts(str(exam.get("exam_id", ""))):
			if str(attempt.get("status", "")) not in ["submitted", "expired"]:
				continue
			if store.load_grade(str(exam.get("exam_id", "")), str(attempt.get("matric", ""))).is_empty():
				pending += 1
	return {"students": seen.size(), "exams": exams.size(), "pending": pending}


func _count_labs(hubs: PackedStringArray) -> int:
	return OopaManifestLabs.new().list_available_labs(hubs).size()


func _show_labs(hubs: PackedStringArray) -> void:
	var labs: Array = OopaManifestLabs.new().list_available_labs(hubs)
	if labs.is_empty():
		_labs_panel.add_child(OopaAdminUI.label("No available labs in your authorised hubs.", 12, OopaAdminUI.MUTED))
		return
	for lab in labs:
		var entry := OopaAdminUI.label("%s  /  %s  ·  %s" % [str(lab.get("hub_id", "")).to_upper(), str(lab.get("title", "")), str(lab.get("lab_id", ""))], 11, OopaAdminUI.GRAPHITE)
		_labs_panel.add_child(entry)


func _nav_card(parent: Node, title_text: String, description: String, action: String, callback: Callable) -> void:
	var card := OopaAdminUI.panel(parent)
	card.custom_minimum_size = Vector2(0, 124)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(OopaAdminUI.label(title_text, 16))
	var desc := OopaAdminUI.label(description, 11, OopaAdminUI.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var button := OopaAdminUI.button(action, "TertiaryButton")
	button.pressed.connect(callback)
	v.add_child(button)


func _on_logout() -> void:
	OopaLocalStore.new().append_audit("logout", {"staff_id": str(AppState.instructor_session.get("staff_id", ""))})
	AppState.clear_instructor_session()
	SceneRouter.go_instructor_login()
