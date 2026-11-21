extends LabShell
## Robot Arm — planar 2R forward & inverse kinematics.

var model: RobotArmModel = RobotArmModel.new()

var _stage: Control
var _s_t1: HSlider
var _s_t2: HSlider
var _s_l1: HSlider
var _s_l2: HSlider
var _o_t1: Label
var _o_t2: Label
var _o_l1: Label
var _o_l2: Label
var _chk_up: CheckBox
var _r_x: Label
var _r_y: Label
var _r_reach: Label
var _r_ws: Label
var _r_msg: Label

var _fk: Dictionary = {}
var _target: Vector2 = Vector2(1.2, 0.6)
var _has_target: bool = false
var _updating: bool = false
var _px_per_m: float = 120.0
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	lab_title = "Robot Arm"
	lab_eyebrow = "ENGINEERING  /  ROBOT ARM"
	lab_lead = "Planar 2-link arm. Move joint angles (FK) or click the workspace to set a target (IK)."
	field_id = "engineering"
	page_id = "robot_arm"
	back_label = "<- Engineering"
	super._ready()
	_build_stage()
	_build_sidebar()
	_solve_fk()
	set_process_unhandled_input(true)


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "ArmStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "PRESETS")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	sb.add_child(row)
	for item in [["Reach out", "reach_out"], ["Folded", "folded"], ["Long reach", "long_reach"], ["Elbow down", "elbow_down"]]:
		var b := Button.new()
		b.text = str(item[0])
		b.theme_type_variation = &"Chip"
		var id: String = str(item[1])
		b.pressed.connect(func(): _on_preset(id))
		row.add_child(b)

	_add_section(sb, "LINK LENGTHS")
	_o_l1 = Label.new()
	sb.add_child(_o_l1)
	_s_l1 = _slider(sb, 0.3, 1.5, model.l1, 0.05, _on_l1)
	_o_l2 = Label.new()
	sb.add_child(_o_l2)
	_s_l2 = _slider(sb, 0.2, 1.3, model.l2, 0.05, _on_l2)

	_add_section(sb, "FORWARD KINEMATICS")
	_o_t1 = Label.new()
	sb.add_child(_o_t1)
	_s_t1 = _slider(sb, -180.0, 180.0, model.theta1, 1.0, _on_t1)
	_o_t2 = Label.new()
	sb.add_child(_o_t2)
	_s_t2 = _slider(sb, -170.0, 170.0, model.theta2, 1.0, _on_t2)

	_chk_up = CheckBox.new()
	_chk_up.text = "Elbow up (IK)"
	_chk_up.button_pressed = model.elbow_up
	_chk_up.toggled.connect(_on_elbow)
	sb.add_child(_chk_up)

	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.text = "Click in the workspace to set an IK target. Grey rings = reachable range."
	sb.add_child(tip)

	_add_section(sb, "END EFFECTOR")
	_r_x = _stat(sb, "x")
	_r_y = _stat(sb, "y")
	_r_reach = _stat(sb, "Reach r")
	_r_ws = _stat(sb, "Workspace")
	_r_msg = Label.new()
	_r_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_msg.add_theme_font_size_override("font_size", 12)
	sb.add_child(_r_msg)


func _slider(parent: Control, mn: float, mx: float, val: float, step: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb)
	parent.add_child(s)
	return s


func _add_section(sb: VBoxContainer, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"Eyebrow"
	sb.add_child(l)


func _stat(sb: VBoxContainer, title: String) -> Label:
	var c := Label.new()
	c.text = title
	c.add_theme_font_size_override("font_size", 11)
	sb.add_child(c)
	var v := Label.new()
	v.theme_type_variation = &"StatValue"
	v.text = "—"
	sb.add_child(v)
	return v


func _on_preset(id: String) -> void:
	model.apply_preset(id)
	_updating = true
	_s_l1.value = model.l1
	_s_l2.value = model.l2
	_s_t1.value = model.theta1
	_s_t2.value = model.theta2
	_chk_up.button_pressed = model.elbow_up
	_updating = false
	_has_target = false
	_solve_fk()
	set_status("Preset: %s" % id)


func _on_l1(v: float) -> void:
	if _updating: return
	model.l1 = v
	_solve_fk()


func _on_l2(v: float) -> void:
	if _updating: return
	model.l2 = v
	_solve_fk()


func _on_t1(v: float) -> void:
	if _updating: return
	model.theta1 = v
	_has_target = false
	_solve_fk()


func _on_t2(v: float) -> void:
	if _updating: return
	model.theta2 = v
	_has_target = false
	_solve_fk()


func _on_elbow(on: bool) -> void:
	model.elbow_up = on
	if _has_target:
		_try_ik(_target)
	else:
		_solve_fk()


func _solve_fk() -> void:
	_fk = model.forward()
	_refresh_readouts("FK")
	if _stage:
		_stage.queue_redraw()


func _try_ik(p: Vector2) -> void:
	var res: Dictionary = model.apply_ik(p.x, p.y)
	_r_msg.text = str(res.get("message", ""))
	if bool(res.get("ok", false)):
		_updating = true
		_s_t1.value = model.theta1
		_s_t2.value = model.theta2
		_updating = false
		_fk = model.forward()
		_refresh_readouts("IK")
		set_status("IK · θ₁=%.1f° θ₂=%.1f°" % [model.theta1, model.theta2])
	else:
		set_status(str(res.get("message", "IK failed")))
	if _stage:
		_stage.queue_redraw()


func _refresh_readouts(mode: String) -> void:
	_o_l1.text = "L₁ = %.2f m" % model.l1
	_o_l2.text = "L₂ = %.2f m" % model.l2
	_o_t1.text = "θ₁ = %.1f°" % model.theta1
	_o_t2.text = "θ₂ = %.1f°" % model.theta2
	var end: Vector2 = _fk.get("end", Vector2.ZERO)
	_r_x.text = "%.3f m" % end.x
	_r_y.text = "%.3f m" % end.y
	_r_reach.text = "%.3f m" % float(_fk.get("reach", 0.0))
	var ws: Dictionary = model.workspace()
	_r_ws.text = "%.2f … %.2f m" % [float(ws.rMin), float(ws.rMax)]
	if mode == "FK":
		_r_msg.text = "Forward kinematics from joint angles."


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = _screen_to_world(event.position)
		_target = p
		_has_target = true
		_try_ik(p)
		_stage.accept_event()


func _screen_to_world(pos: Vector2) -> Vector2:
	_update_view_params()
	return Vector2((pos.x - _origin.x) / _px_per_m, -(pos.y - _origin.y) / _px_per_m)


func _world_to_screen(w: Vector2) -> Vector2:
	return Vector2(_origin.x + w.x * _px_per_m, _origin.y - w.y * _px_per_m)


func _update_view_params() -> void:
	if _stage == null:
		return
	var sz: Vector2 = _stage.size
	var ws: Dictionary = model.workspace()
	var rmax: float = maxf(float(ws.rMax), 0.5)
	_px_per_m = minf(sz.x, sz.y) * 0.42 / rmax
	_origin = Vector2(sz.x * 0.42, sz.y * 0.55)


func _draw_stage() -> void:
	if _stage == null:
		return
	var c := _stage
	var sz: Vector2 = c.size
	if sz.x < 20.0 or sz.y < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#10141a"))
	_update_view_params()
	var ws: Dictionary = model.workspace()
	var rmin: float = float(ws.rMin)
	var rmax: float = float(ws.rMax)

	# Workspace rings
	c.draw_arc(_origin, rmax * _px_per_m, 0.0, TAU, 64, Color("#37474f"), 2.0, true)
	if rmin > 0.02:
		c.draw_arc(_origin, rmin * _px_per_m, 0.0, TAU, 48, Color("#455a64"), 1.5, true)
	# Axes
	c.draw_line(_origin + Vector2(-20, 0), _origin + Vector2(rmax * _px_per_m + 20, 0), Color("#263238"), 1.0)
	c.draw_line(_origin + Vector2(0, 20), _origin + Vector2(0, -rmax * _px_per_m - 20), Color("#263238"), 1.0)
	c.draw_string(ThemeDB.fallback_font, _origin + Vector2(8, -8), "y", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#78909c"))
	c.draw_string(ThemeDB.fallback_font, _origin + Vector2(rmax * _px_per_m + 4, 14), "x", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#78909c"))

	# Target
	if _has_target:
		var ts: Vector2 = _world_to_screen(_target)
		c.draw_circle(ts, 7.0, Color("#ffeb3b", 0.35))
		c.draw_arc(ts, 8.0, 0.0, TAU, 24, Color("#ffeb3b"), 2.0, true)
		c.draw_string(ThemeDB.fallback_font, ts + Vector2(10, -8), "target", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#fff59d"))

	# Arm
	if _fk.is_empty():
		_fk = model.forward()
	var j: Vector2 = _world_to_screen(_fk.get("joint", Vector2.ZERO))
	var e: Vector2 = _world_to_screen(_fk.get("end", Vector2.ZERO))
	# links
	c.draw_line(_origin, j, Color("#90caf9"), 8.0)
	c.draw_line(j, e, Color("#64b5f6"), 7.0)
	# joints
	c.draw_circle(_origin, 10.0, Color("#b22222"))
	c.draw_circle(_origin, 10.0, Color("#ef9a9a"), false, 2.0)
	c.draw_circle(j, 8.0, Color("#ff8a65"))
	c.draw_circle(e, 7.0, Color("#66bb6a"))
	c.draw_circle(e, 7.0, Color("#c8e6c9"), false, 2.0)

	c.draw_string(ThemeDB.fallback_font, _origin + Vector2(-28, 28), "base", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ef9a9a"))
	c.draw_string(ThemeDB.fallback_font, j + Vector2(10, -10), "elbow", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffccbc"))
	c.draw_string(ThemeDB.fallback_font, e + Vector2(10, 4), "end", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a5d6a7"))

	c.draw_string(ThemeDB.fallback_font, Vector2(16, 22), "θ₁=%.1f°  θ₂=%.1f°  ·  click to IK" % [model.theta1, model.theta2], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))
