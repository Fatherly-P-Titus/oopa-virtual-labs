extends Control
## Instructor home — hub-scoped navigation stubs for M03–M05.


func _ready() -> void:
	if not AppState.is_instructor_logged_in():
		SceneRouter.go_instructor_login()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var sess: Dictionary = AppState.instructor_session
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#faf9f8")
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 16)
	margin.add_child(root_v)

	var eye := Label.new()
	eye.text = "INSTRUCTOR SYSTEM"
	eye.add_theme_color_override("font_color", Color("#b22222"))
	eye.add_theme_font_size_override("font_size", 13)
	root_v.add_child(eye)

	var title := Label.new()
	title.text = "Instructor Dashboard"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#1b1b1b"))
	root_v.add_child(title)

	var who := Label.new()
	who.text = "%s  ·  %s  ·  %s" % [
		str(sess.get("display_name", "")),
		str(sess.get("staff_id", "")),
		str(sess.get("role", "")).capitalize(),
	]
	who.add_theme_font_size_override("font_size", 14)
	who.add_theme_color_override("font_color", Color("#444444"))
	root_v.add_child(who)

	var hubs := OopaAuthService.new().allowed_hubs(sess)
	var hub_line := Label.new()
	hub_line.text = "Authorized hubs: " + ", ".join(hubs)
	hub_line.add_theme_font_size_override("font_size", 13)
	hub_line.add_theme_color_override("font_color", Color("#555555"))
	root_v.add_child(hub_line)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	root_v.add_child(grid)

	grid.add_child(_nav_card(
		"Exams",
		"Create and manage examinations for labs in your hubs.",
		"Open exam editor",
		false,
		"res://scenes/instructor_system/exam_editor.tscn"
	))
	grid.add_child(_nav_card(
		"Student registration",
		"Whitelist students via CSV or manual entry.",
		"Open roster manager",
		false,
		"res://scenes/instructor_system/roster_manager.tscn"
	))
	grid.add_child(_nav_card(
		"Grading",
		"Load submissions and record hybrid scores.",
		"Open grading browser",
		false,
		"res://scenes/instructor_system/grading_browser.tscn"
	))
	grid.add_child(_nav_card(
		"Lab catalogue",
		"All available labs you may assign (scope = all labs in your hubs).",
		"%d labs visible" % _count_labs(hubs),
		true,
		""
	))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root_v.add_child(row)

	var blogout := Button.new()
	blogout.text = "Sign out"
	blogout.pressed.connect(_on_logout)
	row.add_child(blogout)

	var bmenu := Button.new()
	bmenu.text = "Main menu"
	bmenu.theme_type_variation = &"GhostButton"
	bmenu.pressed.connect(func(): SceneRouter.go_main_menu())
	row.add_child(bmenu)

	_labs_panel = VBoxContainer.new()
	_labs_panel.add_theme_constant_override("separation", 4)
	root_v.add_child(_labs_panel)
	_show_labs(hubs)


var _labs_panel: VBoxContainer


func _count_labs(hubs: PackedStringArray) -> int:
	return OopaManifestLabs.new().list_available_labs(hubs).size()


func _show_labs(hubs: PackedStringArray) -> void:
	for c in _labs_panel.get_children():
		c.queue_free()
	var hdr := Label.new()
	hdr.text = "Available labs in your scope"
	hdr.theme_type_variation = &"Eyebrow"
	_labs_panel.add_child(hdr)
	var labs: Array = OopaManifestLabs.new().list_available_labs(hubs)
	for lab in labs:
		var l := Label.new()
		l.text = "· [%s] %s (%s)" % [str(lab["hub_id"]), str(lab["title"]), str(lab["lab_id"])]
		l.add_theme_font_size_override("font_size", 12)
		_labs_panel.add_child(l)
	if labs.is_empty():
		var empty := Label.new()
		empty.text = "No available labs found in manifest for your hubs."
		_labs_panel.add_child(empty)


func _nav_card(title: String, body: String, footer: String, accent: bool, scene_path: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 120)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#b22222") if accent else Color.WHITE
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	if not accent:
		style.border_color = Color("#e0e0e0")
		style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color.WHITE if accent else Color("#1b1b1b"))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.9) if accent else Color("#555555"))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(b)
	var f := Label.new()
	f.text = footer
	f.add_theme_font_size_override("font_size", 11)
	f.add_theme_color_override("font_color", Color(1, 1, 1, 0.7) if accent else Color("#888888"))
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(f)
	if scene_path != "":
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var path: String = scene_path
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				get_tree().change_scene_to_file(path)
		)
	return panel


func _on_logout() -> void:
	var store := OopaLocalStore.new()
	store.append_audit("logout", {"staff_id": str(AppState.instructor_session.get("staff_id", ""))})
	AppState.clear_instructor_session()
	SceneRouter.go_instructor_login()
