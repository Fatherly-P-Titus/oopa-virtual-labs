extends LabShell
## Pendulum / spring with phase plot, drive, presets, planet g.

const PENDULUM_3D_SCENE: PackedScene = preload("res://scenes/equipment/pendulum/pendulum_apparatus_3d.tscn")

var model: PendulumSpringsModel = PendulumSpringsModel.new()

var _stage: Control
var _pendulum_3d_container: SubViewportContainer
var _pendulum_3d_view: PendulumApparatus3D
var _mode_row: HBoxContainer
var _slider_len: HSlider
var _slider_theta: HSlider
var _slider_k: HSlider
var _slider_x0: HSlider
var _slider_mass: HSlider
var _slider_damp: HSlider
var _slider_g: HSlider
var _slider_f0: HSlider
var _slider_wd: HSlider
var _out_len: Label
var _out_theta: Label
var _out_k: Label
var _out_x0: Label
var _out_mass: Label
var _out_damp: Label
var _out_g: Label
var _out_f0: Label
var _out_wd: Label
var _chk_drive: CheckButton
var _btn_play: Button
var _r_t: Label
var _r_period: Label
var _r_disp: Label
var _r_vel: Label
var _r_ke: Label
var _r_pe: Label
var _r_tot: Label
var _r_wn: Label
var _keys_hint: Label

var _updating: bool = false
var _playing: bool = false
var _trace: PackedVector2Array = PackedVector2Array()
var _phase: PackedVector2Array = PackedVector2Array()

const PLANETS: Array = [
	{"name": "Moon", "g": 1.62},
	{"name": "Earth", "g": 9.81},
	{"name": "Mars", "g": 3.71},
	{"name": "Jupiter", "g": 24.79},
]

const PRESETS: Array = [
	{"name": "Small θ", "mode": 0, "len": 1.5, "theta": 15.0, "k": 20.0, "x0": 0.3, "mass": 1.0, "damp": 0.0, "g": 9.81, "drive": false, "f0": 0.0, "wd": 4.0},
	{"name": "Large θ", "mode": 0, "len": 1.5, "theta": 70.0, "k": 20.0, "x0": 0.3, "mass": 1.0, "damp": 0.0, "g": 9.81, "drive": false, "f0": 0.0, "wd": 4.0},
	{"name": "Damped", "mode": 0, "len": 1.5, "theta": 40.0, "k": 20.0, "x0": 0.3, "mass": 1.0, "damp": 0.8, "g": 9.81, "drive": false, "f0": 0.0, "wd": 4.0},
	{"name": "Soft spring", "mode": 1, "len": 1.5, "theta": 20.0, "k": 8.0, "x0": 0.4, "mass": 1.0, "damp": 0.0, "g": 9.81, "drive": false, "f0": 0.0, "wd": 2.0},
	{"name": "Resonance", "mode": 1, "len": 1.5, "theta": 20.0, "k": 20.0, "x0": 0.05, "mass": 1.0, "damp": 0.3, "g": 9.81, "drive": true, "f0": 3.0, "wd": -1.0},
]


func _ready() -> void:
	lab_title = "Pendulum & Springs"
	lab_eyebrow = "PHYSICS  /  PENDULUM & SPRINGS"
	lab_lead = "SHM, phase space, damping, and driven spring resonance."
	field_id = "physics"
	page_id = "pendulum_springs"
	back_label = "<- Physics"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.mode = PendulumSpringsModel.Mode.PENDULUM
	model.reset()
	_refresh_ui()
	set_process(true)
	set_process_unhandled_input(true)
	set_status("Play to see the phase orbit. Try Resonance preset on Spring.")


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "OscStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))

	_pendulum_3d_container = SubViewportContainer.new()
	_pendulum_3d_container.name = "Pendulum3DViewport"
	_pendulum_3d_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pendulum_3d_container.anchor_right = 0.64
	_pendulum_3d_container.offset_left = 8.0
	_pendulum_3d_container.offset_top = 8.0
	_pendulum_3d_container.offset_right = -4.0
	_pendulum_3d_container.offset_bottom = -8.0
	_pendulum_3d_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pendulum_3d_container.stretch = true
	_stage.add_child(_pendulum_3d_container)

	var viewport := SubViewport.new()
	viewport.name = "Pendulum3DSubViewport"
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pendulum_3d_container.add_child(viewport)
	_pendulum_3d_view = PENDULUM_3D_SCENE.instantiate() as PendulumApparatus3D
	viewport.add_child(_pendulum_3d_view)
	_pendulum_3d_container.visible = false


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "MODE")
	_mode_row = HBoxContainer.new()
	_mode_row.add_theme_constant_override("separation", 6)
	sb.add_child(_mode_row)
	for item in [["Pendulum", 0], ["Spring", 1]]:
		var b := Button.new()
		b.text = str(item[0])
		b.theme_type_variation = &"Chip"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m: int = int(item[1])
		b.pressed.connect(_on_mode.bind(m))
		_mode_row.add_child(b)

	_add_section(sb, "PRESETS")
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 4)
	sb.add_child(pr)
	var pr2 := HBoxContainer.new()
	pr2.add_theme_constant_override("separation", 4)
	sb.add_child(pr2)
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		var b2 := Button.new()
		b2.text = str(p["name"])
		b2.theme_type_variation = &"Chip"
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		b2.pressed.connect(_on_preset.bind(idx))
		if i < 3:
			pr.add_child(b2)
		else:
			pr2.add_child(b2)

	_add_section(sb, "PLANET g")
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 4)
	sb.add_child(grow)
	for planet in PLANETS:
		var pb := Button.new()
		pb.text = str(planet["name"])
		pb.theme_type_variation = &"Chip"
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gv: float = float(planet["g"])
		pb.pressed.connect(_on_planet.bind(gv))
		grow.add_child(pb)

	_add_section(sb, "PENDULUM")
	_out_len = Label.new()
	_out_len.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_len)
	_slider_len = _make_slider(0.5, 3.0, 0.05, _on_param)
	sb.add_child(_slider_len)
	_out_theta = Label.new()
	_out_theta.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_theta)
	_slider_theta = _make_slider(5.0, 80.0, 1.0, _on_param)
	sb.add_child(_slider_theta)

	_add_section(sb, "SPRING")
	_out_k = Label.new()
	_out_k.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_k)
	_slider_k = _make_slider(5.0, 80.0, 1.0, _on_param)
	sb.add_child(_slider_k)
	_out_x0 = Label.new()
	_out_x0.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_x0)
	_slider_x0 = _make_slider(0.05, 0.8, 0.01, _on_param)
	sb.add_child(_slider_x0)

	_add_section(sb, "DRIVE (spring)")
	_chk_drive = CheckButton.new()
	_chk_drive.text = "Forced oscillation"
	_chk_drive.toggled.connect(_on_drive)
	sb.add_child(_chk_drive)
	_out_f0 = Label.new()
	_out_f0.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_f0)
	_slider_f0 = _make_slider(0.0, 10.0, 0.1, _on_param)
	sb.add_child(_slider_f0)
	_out_wd = Label.new()
	_out_wd.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_wd)
	_slider_wd = _make_slider(0.5, 15.0, 0.1, _on_param)
	sb.add_child(_slider_wd)

	_add_section(sb, "SHARED")
	_out_mass = Label.new()
	_out_mass.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_mass)
	_slider_mass = _make_slider(0.2, 5.0, 0.1, _on_param)
	sb.add_child(_slider_mass)
	_out_damp = Label.new()
	_out_damp.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_damp)
	_slider_damp = _make_slider(0.0, 2.0, 0.05, _on_param)
	sb.add_child(_slider_damp)
	_out_g = Label.new()
	_out_g.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_g)
	_slider_g = _make_slider(0.5, 30.0, 0.1, _on_param)
	sb.add_child(_slider_g)

	_add_section(sb, "TIME")
	_btn_play = Button.new()
	_btn_play.text = "Play"
	_btn_play.pressed.connect(_on_play)
	sb.add_child(_btn_play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var rst := Button.new()
	rst.text = "Reset"
	rst.theme_type_variation = &"GhostButton"
	rst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rst.pressed.connect(_on_reset)
	row.add_child(rst)
	var step := Button.new()
	step.text = "+0.05 s"
	step.theme_type_variation = &"GhostButton"
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.pressed.connect(_on_step)
	row.add_child(step)
	sb.add_child(row)

	_add_section(sb, "READOUTS")
	_r_t = _stat_row(sb, "t")
	_r_period = _stat_row(sb, "T natural")
	_r_wn = _stat_row(sb, "ω0")
	_r_disp = _stat_row(sb, "Displacement")
	_r_vel = _stat_row(sb, "Velocity")
	_r_ke = _stat_row(sb, "KE")
	_r_pe = _stat_row(sb, "PE")
	_r_tot = _stat_row(sb, "Total E")

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: 1/2 mode · Space play · R reset · Esc back"
	sb.add_child(_keys_hint)


func _add_section(sb: VBoxContainer, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(3, 16)
	marker.color = Color("#16B8A6")
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"PanelTitle"
	l.uppercase = true
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	sb.add_child(row)


func _make_slider(mn: float, mx: float, step: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value_changed.connect(cb)
	return s


func _stat_row(sb: VBoxContainer, key: String) -> Label:
	var card := PanelContainer.new()
	card.theme_type_variation = &"MetricCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var k := Label.new()
	k.text = key
	k.theme_type_variation = &"StatLabel"
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := Label.new()
	v.theme_type_variation = &"StatValue"
	v.add_theme_font_size_override("font_size", 14)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	card.add_child(row)
	sb.add_child(card)
	return v


func _process(delta: float) -> void:
	if not _playing:
		return
	model.advance(delta)
	_sample()
	_refresh_live()


func _sample() -> void:
	_trace.append(model.bob_position())
	if _trace.size() > 200:
		_trace = _trace.slice(_trace.size() - 180)
	_phase.append(model.phase_point())
	if _phase.size() > 400:
		_phase = _phase.slice(_phase.size() - 360)


func _on_mode(m: int) -> void:
	model.mode = m
	model.reset()
	_trace.clear()
	_phase.clear()
	_playing = false
	_update_play_btn()
	_refresh_ui()


func _on_preset(idx: int) -> void:
	if idx < 0 or idx >= PRESETS.size():
		return
	var p: Dictionary = PRESETS[idx]
	model.mode = int(p["mode"])
	model.length = float(p["len"])
	model.theta0 = deg_to_rad(float(p["theta"]))
	model.k = float(p["k"])
	model.x0 = float(p["x0"])
	model.mass = float(p["mass"])
	model.damping = float(p["damp"])
	model.g = float(p["g"])
	model.drive_on = bool(p["drive"])
	model.drive_f0 = float(p["f0"])
	var wd: float = float(p["wd"])
	if wd < 0.0:
		# Resonance: drive at natural frequency
		model.drive_omega = model.natural_omega()
	else:
		model.drive_omega = wd
	model.reset()
	_trace.clear()
	_phase.clear()
	_playing = true
	_update_play_btn()
	_refresh_ui()
	set_status("Preset: %s" % str(p["name"]))


func _on_planet(gv: float) -> void:
	model.g = gv
	model.reset()
	_trace.clear()
	_phase.clear()
	_playing = false
	_update_play_btn()
	_refresh_ui()
	set_status("g = %.2f m/s²" % gv)


func _on_param(_v: float = 0.0) -> void:
	if _updating:
		return
	_read_sliders()
	model.reset()
	_trace.clear()
	_phase.clear()
	_playing = false
	_update_play_btn()
	_refresh_ui()


func _on_drive(pressed: bool) -> void:
	model.drive_on = pressed
	_refresh_ui()


func _read_sliders() -> void:
	if _slider_len == null:
		return
	model.length = _slider_len.value
	model.theta0 = deg_to_rad(_slider_theta.value)
	model.k = _slider_k.value
	model.x0 = _slider_x0.value
	model.mass = _slider_mass.value
	model.damping = _slider_damp.value
	model.g = _slider_g.value
	model.drive_f0 = _slider_f0.value
	model.drive_omega = _slider_wd.value


func _on_play() -> void:
	_playing = not _playing
	if _playing and model.t > 40.0:
		model.reset()
		_trace.clear()
		_phase.clear()
	_update_play_btn()


func _update_play_btn() -> void:
	if _btn_play:
		_btn_play.text = "Pause" if _playing else "Play"


func _on_reset() -> void:
	_read_sliders()
	model.reset()
	_trace.clear()
	_phase.clear()
	_playing = false
	_update_play_btn()
	_refresh_ui()


func _on_step() -> void:
	_playing = false
	_update_play_btn()
	model.advance(0.05)
	_sample()
	_refresh_live()


func _refresh_ui() -> void:
	if _slider_len == null:
		return
	_updating = true
	_slider_len.value = model.length
	_slider_theta.value = rad_to_deg(model.theta0)
	_slider_k.value = model.k
	_slider_x0.value = model.x0
	_slider_mass.value = model.mass
	_slider_damp.value = model.damping
	_slider_g.value = model.g
	_slider_f0.value = model.drive_f0
	_slider_wd.value = model.drive_omega
	_chk_drive.button_pressed = model.drive_on
	_updating = false

	_out_len.text = "Length = %.2f m" % model.length
	_out_theta.text = "Angle0 = %.0f deg" % rad_to_deg(model.theta0)
	_out_k.text = "k = %.1f N/m" % model.k
	_out_x0.text = "x0 = %.2f m" % model.x0
	_out_mass.text = "Mass = %.2f kg" % model.mass
	_out_damp.text = "Damping = %.2f" % model.damping
	_out_g.text = "g = %.2f m/s2" % model.g
	_out_f0.text = "F0 = %.1f N" % model.drive_f0
	_out_wd.text = "ωd = %.2f rad/s" % model.drive_omega

	var is_p: bool = model.mode == PendulumSpringsModel.Mode.PENDULUM
	_slider_len.editable = is_p
	_slider_theta.editable = is_p
	_slider_k.editable = not is_p
	_slider_x0.editable = not is_p
	_slider_g.editable = is_p
	_chk_drive.disabled = is_p
	_slider_f0.editable = not is_p and model.drive_on
	_slider_wd.editable = not is_p and model.drive_on
	_slider_len.modulate = Color.WHITE if is_p else Color(1, 1, 1, 0.35)
	_slider_theta.modulate = Color.WHITE if is_p else Color(1, 1, 1, 0.35)
	_slider_k.modulate = Color.WHITE if not is_p else Color(1, 1, 1, 0.35)
	_slider_x0.modulate = Color.WHITE if not is_p else Color(1, 1, 1, 0.35)
	_slider_g.modulate = Color.WHITE if is_p else Color(1, 1, 1, 0.35)
	_slider_f0.modulate = Color.WHITE if _slider_f0.editable else Color(1, 1, 1, 0.35)
	_slider_wd.modulate = Color.WHITE if _slider_wd.editable else Color(1, 1, 1, 0.35)

	for i in _mode_row.get_child_count():
		var b: Button = _mode_row.get_child(i) as Button
		if b:
			b.theme_type_variation = &"ChipActive" if i == model.mode else &"Chip"

	_refresh_live()


func _refresh_live() -> void:
	var e: Dictionary = model.energy()
	_r_t.text = "%.2f s" % model.t
	_r_period.text = "%.3f s" % model.period()
	_r_wn.text = "%.2f rad/s" % model.natural_omega()
	if model.mode == PendulumSpringsModel.Mode.PENDULUM:
		_r_disp.text = "%.2f deg" % rad_to_deg(model.theta)
		_r_vel.text = "%.2f rad/s" % model.omega
	else:
		_r_disp.text = "%.3f m" % model.x
		_r_vel.text = "%.3f m/s" % model.v
	_r_ke.text = "%.3f J" % float(e.ke)
	_r_pe.text = "%.3f J" % float(e.pe)
	_r_tot.text = "%.3f J" % float(e.total)
	var name: String = "Pendulum" if model.mode == PendulumSpringsModel.Mode.PENDULUM else "Spring"
	var extra: String = ""
	if model.mode == PendulumSpringsModel.Mode.SPRING and model.drive_on:
		extra = " · drive ωd=%.2f" % model.drive_omega
	set_status("%s · t=%.2f · T≈%.3f%s" % [name, model.t, model.period(), extra])
	if _pendulum_3d_container != null:
		var show_3d: bool = model.mode == PendulumSpringsModel.Mode.PENDULUM
		_pendulum_3d_container.visible = show_3d
		if show_3d and _pendulum_3d_view != null:
			_pendulum_3d_view.set_model_state(model.length, model.theta)
	if _stage:
		_stage.queue_redraw()


func _draw_stage() -> void:
	if _stage == null:
		return
	var c: Control = _stage
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#0d1b2a"), true)

	# Left: apparatus · Right: phase plot · Far right: energy bars
	var phase_w: float = minf(w * 0.32, 220.0)
	var bar_w: float = 56.0
	var main_w: float = w - phase_w - bar_w - 16.0

	var e: Dictionary = model.energy()
	var etot: float = maxf(float(e.total), 1e-6)
	var bar_x: float = w - 52.0
	var bar_top: float = 36.0
	var bar_h: float = h * 0.5
	var ke_h: float = (float(e.ke) / etot) * bar_h
	var pe_h: float = (float(e.pe) / etot) * bar_h
	c.draw_string(ThemeDB.fallback_font, Vector2(bar_x - 10.0, 24.0), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))
	c.draw_rect(Rect2(bar_x, bar_top + bar_h - ke_h, 16.0, ke_h), Color("#42a5f5"), true)
	c.draw_rect(Rect2(bar_x + 20.0, bar_top + bar_h - pe_h, 16.0, pe_h), Color("#ffeb3b"), true)
	c.draw_rect(Rect2(bar_x, bar_top, 16.0, bar_h), Color("#37474f"), false, 1.0)
	c.draw_rect(Rect2(bar_x + 20.0, bar_top, 16.0, bar_h), Color("#37474f"), false, 1.0)

	if model.mode == PendulumSpringsModel.Mode.PENDULUM:
		if _pendulum_3d_container == null:
			_draw_pendulum(c, main_w, h)
	else:
		_draw_spring(c, main_w, h)

	_draw_phase(c, main_w + 8.0, 28.0, phase_w - 8.0, h * 0.7)


func _draw_phase(c: Control, ox: float, oy: float, pw: float, ph: float) -> void:
	c.draw_rect(Rect2(ox, oy, pw, ph), Color("#1a1a1a"), true)
	c.draw_rect(Rect2(ox, oy, pw, ph), Color("#37474f"), false, 1.0)
	var label: String = "Phase: θ vs ω" if model.mode == PendulumSpringsModel.Mode.PENDULUM else "Phase: x vs v"
	c.draw_string(ThemeDB.fallback_font, Vector2(ox + 6.0, oy + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	# Axes through centre
	var cx: float = ox + pw * 0.5
	var cy: float = oy + ph * 0.5
	c.draw_line(Vector2(ox + 8.0, cy), Vector2(ox + pw - 8.0, cy), Color("#455a64"), 1.0)
	c.draw_line(Vector2(cx, oy + 20.0), Vector2(cx, oy + ph - 8.0), Color("#455a64"), 1.0)

	if _phase.size() < 2:
		return
	# Auto-scale
	var max_x: float = 0.1
	var max_v: float = 0.1
	for p in _phase:
		max_x = maxf(max_x, absf(p.x))
		max_v = maxf(max_v, absf(p.y))
	max_x *= 1.15
	max_v *= 1.15
	var pts := PackedVector2Array()
	for p in _phase:
		var sx: float = cx + (p.x / max_x) * (pw * 0.42)
		var sy: float = cy - (p.y / max_v) * (ph * 0.38)
		pts.append(Vector2(sx, sy))
	c.draw_polyline(pts, Color("#66bb6a"), 1.5, true)
	# Current point
	var cur: Vector2 = model.phase_point()
	var cpx: float = cx + (cur.x / max_x) * (pw * 0.42)
	var cpy: float = cy - (cur.y / max_v) * (ph * 0.38)
	c.draw_circle(Vector2(cpx, cpy), 4.0, Color("#ef5350"))


func _draw_pendulum(c: Control, w: float, h: float) -> void:
	var pivot := Vector2(w * 0.48, h * 0.12)
	var scale: float = minf(w, h) * 0.28 / maxf(model.length, 0.5)
	var bob: Vector2 = model.bob_position()
	var bob_s := Vector2(pivot.x + bob.x * scale, pivot.y - bob.y * scale)
	c.draw_circle(pivot, 6.0, Color("#90a4ae"))
	c.draw_line(Vector2(pivot.x - 30.0, pivot.y), Vector2(pivot.x + 30.0, pivot.y), Color("#546e7a"), 4.0)
	if _trace.size() >= 2:
		var pts := PackedVector2Array()
		for p in _trace:
			pts.append(Vector2(pivot.x + p.x * scale, pivot.y - p.y * scale))
		c.draw_polyline(pts, Color(0.4, 0.7, 1.0, 0.35), 1.5, true)
	c.draw_line(pivot, bob_s, Color("#eceff1"), 3.0)
	c.draw_circle(bob_s, 14.0, Color("#ef5350"))
	c.draw_circle(bob_s, 14.0, Color("#ffcdd2"), false, 2.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(16.0, 22.0), "Simple pendulum", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))
	c.draw_string(ThemeDB.fallback_font, Vector2(16.0, 40.0), "θ = %.1f°" % rad_to_deg(model.theta), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#90caf9"))


func _draw_spring(c: Control, w: float, h: float) -> void:
	var y: float = h * 0.42
	var left: float = w * 0.08
	var eq: float = w * 0.38
	var scale: float = (w * 0.32) / 0.8
	var mass_x: float = eq + model.x * scale
	c.draw_rect(Rect2(left - 14.0, y - 36.0, 14.0, 72.0), Color("#546e7a"), true)
	c.draw_line(Vector2(eq, y - 45.0), Vector2(eq, y + 45.0), Color("#37474f"), 1.0)
	var coils: int = 12
	var pts := PackedVector2Array()
	pts.append(Vector2(left, y))
	for i in range(1, coils):
		var tt: float = float(i) / float(coils)
		var sx: float = lerpf(left, mass_x - 16.0, tt)
		var sy: float = y + (8.0 if i % 2 == 0 else -8.0)
		pts.append(Vector2(sx, sy))
	pts.append(Vector2(mass_x - 16.0, y))
	c.draw_polyline(pts, Color("#90caf9"), 2.0, true)
	c.draw_rect(Rect2(mass_x - 16.0, y - 16.0, 32.0, 32.0), Color("#ef5350"), true)
	c.draw_rect(Rect2(mass_x - 16.0, y - 16.0, 32.0, 32.0), Color("#ffcdd2"), false, 2.0)
	if model.drive_on:
		c.draw_string(ThemeDB.fallback_font, Vector2(16.0, 22.0), "Driven mass–spring", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffa726"))
	else:
		c.draw_string(ThemeDB.fallback_font, Vector2(16.0, 22.0), "Mass–spring", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))
	c.draw_string(ThemeDB.fallback_font, Vector2(16.0, 40.0), "x = %.3f m" % model.x, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#90caf9"))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_1:
			_on_mode(PendulumSpringsModel.Mode.PENDULUM)
			get_viewport().set_input_as_handled()
		KEY_2:
			_on_mode(PendulumSpringsModel.Mode.SPRING)
			get_viewport().set_input_as_handled()
		KEY_SPACE:
			_on_play()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_reset()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
