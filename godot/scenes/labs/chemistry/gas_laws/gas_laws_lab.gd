extends LabShell
## Gas Laws lab - ideal gas PV = nRT on LabShell.
## Chamber + particles, graph, law chips, sliders, readouts, data table.

const UPL: float = 9.0

var model: GasLawsModel = GasLawsModel.new()

var _chamber: Control
var _graph: Control

var _law_row: HBoxContainer
var _desc: Label
var _hold: Label
var _slider_v: HSlider
var _slider_t: HSlider
var _slider_n: HSlider
var _out_v: Label
var _out_t: Label
var _out_n: Label
var _btn_record: Button
var _btn_clear: Button
var _btn_reset: Button
var _btn_pause: Button
var _slider_density: HSlider
var _out_density: Label
var _r_p: Label
var _r_patm: Label
var _r_const: Label
var _table: VBoxContainer
var _keys_hint: Label

var _particles: Array = []
var _vd: float = 10.0
var _pd: float = 0.0
var _paused: bool = false
var _updating: bool = false
var _particle_target: int = 30  ## density control (default 30)

var _law_order: Array = [
	GasLawsModel.Law.FREE,
	GasLawsModel.Law.BOYLE,
	GasLawsModel.Law.CHARLES,
	GasLawsModel.Law.GAY_LUSSAC,
	GasLawsModel.Law.AVOGADRO,
]
var _law_names: Array = ["Free", "Boyle", "Charles", "Gay-Lussac", "Avogadro"]


func _ready() -> void:
	lab_title = "Gas Laws"
	lab_eyebrow = "CHEMISTRY  /  GAS LAWS"
	lab_lead = "Explore Boyle, Charles, Gay-Lussac and Avogadro. Change V, T or n and watch pressure respond."
	field_id = "chemistry"
	page_id = "gas_laws"
	back_label = "<- Chemistry"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.set_law(GasLawsModel.Law.BOYLE)
	_vd = model.v
	_pd = model.p
	_sync_particles(true)
	_refresh_ui()
	set_process_unhandled_input(true)


func _build_stage() -> void:
	_chamber = Control.new()
	_chamber.name = "Chamber"
	_chamber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_chamber)
	_chamber.draw.connect(Callable(self, "_draw_chamber"))

	var graph_card := PanelContainer.new()
	graph_card.theme_type_variation = &"Card"
	graph_card.custom_minimum_size = Vector2(0, 180)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(0, 160)
	_graph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_card.add_child(_graph)
	var extra := get_extra()
	if extra:
		extra.add_child(graph_card)
	_graph.draw.connect(Callable(self, "_draw_graph"))


func _build_sidebar() -> void:
	var sb := get_sidebar()
	if sb == null:
		push_error("GasLaws: sidebar missing")
		return

	_add_section(sb, "LAW")
	_law_row = HBoxContainer.new()
	_law_row.add_theme_constant_override("separation", 6)
	sb.add_child(_law_row)
	for i in _law_order.size():
		var b := Button.new()
		b.text = str(_law_names[i])
		b.theme_type_variation = &"Chip"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var law_val: int = _law_order[i]
		b.pressed.connect(_on_law.bind(law_val))
		_law_row.add_child(b)

	_desc = Label.new()
	_desc.theme_type_variation = &"Muted"
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sb.add_child(_desc)

	_hold = Label.new()
	_hold.theme_type_variation = &"Hint"
	_hold.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sb.add_child(_hold)

	_add_section(sb, "CONTROLS")
	_out_v = Label.new()
	_out_v.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_v)
	_slider_v = _make_slider(GasLawsModel.V_MIN, GasLawsModel.V_MAX, 0.1, _on_v)
	sb.add_child(_slider_v)

	_out_t = Label.new()
	_out_t.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_t)
	_slider_t = _make_slider(GasLawsModel.T_MIN, GasLawsModel.T_MAX, 1.0, _on_t)
	sb.add_child(_slider_t)

	_out_n = Label.new()
	_out_n.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_n)
	_slider_n = _make_slider(GasLawsModel.N_MIN, GasLawsModel.N_MAX, 0.05, _on_n)
	sb.add_child(_slider_n)

	_add_section(sb, "PARTICLES")
	_out_density = Label.new()
	_out_density.theme_type_variation = &"CtlLabel"
	_out_density.text = "Density = 30 particles"
	sb.add_child(_out_density)
	_slider_density = _make_slider(8.0, 120.0, 1.0, _on_density)
	_slider_density.value = float(_particle_target)
	sb.add_child(_slider_density)

	_btn_pause = Button.new()
	_btn_pause.text = "Pause particles"
	_btn_pause.theme_type_variation = &"GhostButton"
	_btn_pause.pressed.connect(_on_pause_toggle)
	sb.add_child(_btn_pause)

	_add_section(sb, "ACTIONS")
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_btn_record = Button.new()
	_btn_record.text = "Record"
	_btn_record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_record.pressed.connect(_on_record)
	actions.add_child(_btn_record)
	_btn_clear = Button.new()
	_btn_clear.text = "Clear"
	_btn_clear.theme_type_variation = &"GhostButton"
	_btn_clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_clear.pressed.connect(_on_clear)
	actions.add_child(_btn_clear)
	_btn_reset = Button.new()
	_btn_reset.text = "Reset"
	_btn_reset.theme_type_variation = &"GhostButton"
	_btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_reset.pressed.connect(_on_reset)
	actions.add_child(_btn_reset)
	sb.add_child(actions)

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: 1-5 laws · Space pause · R record · C clear · 0 reset · [ ] nudge free control · Esc back"
	sb.add_child(_keys_hint)

	_add_section(sb, "READOUTS")
	_r_p = _stat_row(sb, "P")
	_r_patm = _stat_row(sb, "P (atm)")
	_r_const = _stat_row(sb, "Constant")

	_add_section(sb, "DATA TABLE")
	_table = VBoxContainer.new()
	_table.add_theme_constant_override("separation", 4)
	sb.add_child(_table)


func _add_section(sb: VBoxContainer, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(3, 16)
	marker.color = Color("#F2A84A")
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
	_vd = lerpf(_vd, model.v, minf(1.0, delta * 8.0))
	_pd = lerpf(_pd, model.p, minf(1.0, delta * 8.0))
	if not _paused:
		_step_particles(delta)
	if _chamber:
		_chamber.queue_redraw()


func _on_law(law_val: int) -> void:
	model.set_law(law_val as GasLawsModel.Law)
	_sync_particles(true)
	_refresh_ui()


func _on_v(val: float) -> void:
	if _updating:
		return
	model.set_control("V", val)
	_sync_particles(false)
	_refresh_ui()


func _on_t(val: float) -> void:
	if _updating:
		return
	model.set_control("T", val)
	_sync_particles(false)
	_refresh_ui()


func _on_n(val: float) -> void:
	if _updating:
		return
	model.set_control("n", val)
	_sync_particles(true)
	_refresh_ui()


func _on_density(val: float) -> void:
	if _updating:
		return
	_particle_target = int(round(val))
	_sync_particles(false)
	_refresh_ui()


func _on_pause_toggle() -> void:
	_paused = not _paused
	_update_pause_button()
	set_status("Particles paused" if _paused else "%s  ·  PV = nRT" % model.law_title())


func _update_pause_button() -> void:
	if _btn_pause == null:
		return
	_btn_pause.text = "Resume particles" if _paused else "Pause particles"
	_btn_pause.theme_type_variation = &"ChipActive" if _paused else &"GhostButton"


func _on_record() -> void:
	model.record_point()
	_refresh_ui()


func _on_clear() -> void:
	model.data.clear()
	_refresh_ui()


func _on_reset() -> void:
	model.reset_defaults()
	model.set_law(model.law)
	_vd = model.v
	_pd = model.p
	_sync_particles(true)
	_refresh_ui()


func _refresh_ui() -> void:
	if _slider_v == null:
		return
	_updating = true
	_slider_v.value = model.v
	_slider_t.value = model.t
	_slider_n.value = model.n
	_updating = false

	_slider_v.editable = model.is_free("V")
	_slider_t.editable = model.is_free("T")
	_slider_n.editable = model.is_free("n")
	_slider_v.modulate = Color.WHITE if model.is_free("V") else Color(1, 1, 1, 0.45)
	_slider_t.modulate = Color.WHITE if model.is_free("T") else Color(1, 1, 1, 0.45)
	_slider_n.modulate = Color.WHITE if model.is_free("n") else Color(1, 1, 1, 0.45)

	_out_v.text = "Volume V = %.1f L%s" % [model.v, " (dependent)" if model.is_dependent("V") else ""]
	_out_t.text = "Temperature T = %.0f K" % model.t
	_out_n.text = "Amount n = %.2f mol" % model.n
	if _out_density:
		_out_density.text = "Density = %d particles" % _particle_target
	if _slider_density and not _updating:
		_updating = true
		_slider_density.value = float(_particle_target)
		_updating = false
	_update_pause_button()

	_desc.text = model.law_desc()
	_hold.text = model.hold_note()

	_r_p.text = "%.1f kPa" % model.p
	_r_patm.text = "%.3f atm" % model.p_atm()
	_r_const.text = "%s = %s %s" % [model.const_label(), _format_significant(model.law_constant(), 3), model.const_unit()]

	for i in _law_row.get_child_count():
		var b: Button = _law_row.get_child(i) as Button
		if b:
			b.theme_type_variation = &"ChipActive" if _law_order[i] == model.law else &"Chip"

	_rebuild_table()
	if model.status_msg != "":
		set_status(model.status_msg)
	else:
		set_status("%s  ·  PV = nRT" % model.law_title())
	if _graph:
		_graph.queue_redraw()
	if _chamber:
		_chamber.queue_redraw()


func _rebuild_table() -> void:
	for c in _table.get_children():
		c.queue_free()
	if model.data.is_empty():
		var empty := Label.new()
		empty.text = "No points yet - press Record."
		empty.theme_type_variation = &"Muted"
		_table.add_child(empty)
		return
	var header := Label.new()
	header.text = "V    P      T     n    const"
	header.theme_type_variation = &"Hint"
	_table.add_child(header)
	for row in model.data:
		var line := Label.new()
		var cval: float = model.law_constant(row)
		line.text = "%.1f  %.0f  %.0f  %.2f  %.3g" % [
			float(row.v), float(row.p), float(row.t), float(row.n), cval
		]
		line.theme_type_variation = &"Muted"
		_table.add_child(line)


func _wanted_particles() -> int:
	return clampi(_particle_target, 8, 120)


func _sync_particles(force: bool) -> void:
	var want: int = _wanted_particles()
	while _particles.size() < want:
		_particles.append(_spawn_particle())
	while _particles.size() > want:
		_particles.pop_back()
	if force:
		for i in _particles.size():
			_particles[i] = _spawn_particle()
	else:
		var target: float = _particle_speed()
		for i in _particles.size():
			var p: Dictionary = _particles[i]
			var cur: float = sqrt(float(p.vx) * float(p.vx) + float(p.vy) * float(p.vy))
			if cur > 0.01:
				var s: float = target / cur
				p.vx = float(p.vx) * s
				p.vy = float(p.vy) * s
			else:
				var ang: float = randf() * TAU
				p.vx = cos(ang) * target
				p.vy = sin(ang) * target
			_particles[i] = p


func _particle_speed() -> float:
	return 0.25 + (model.t / 800.0) * 1.5


func _spawn_particle() -> Dictionary:
	var speed: float = _particle_speed()
	var ang: float = randf() * TAU
	return {
		"x": randf_range(0.08, 0.92),
		"y": randf_range(0.08, 0.92),
		"vx": cos(ang) * speed,
		"vy": sin(ang) * speed,
	}


func _step_particles(delta: float) -> void:
	var vol_boost: float = 1.0 + (GasLawsModel.V_MAX - model.v) / GasLawsModel.V_MAX * 0.35
	for i in _particles.size():
		var p: Dictionary = _particles[i]
		p.x = float(p.x) + float(p.vx) * delta * vol_boost
		p.y = float(p.y) + float(p.vy) * delta * vol_boost
		if float(p.x) < 0.04 or float(p.x) > 0.96:
			p.vx = -float(p.vx)
			p.x = clampf(float(p.x), 0.04, 0.96)
		if float(p.y) < 0.04 or float(p.y) > 0.96:
			p.vy = -float(p.vy)
			p.y = clampf(float(p.y), 0.04, 0.96)
		_particles[i] = p


func _draw_chamber() -> void:
	if _chamber == null:
		return
	var c: Control = _chamber
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#161616"), true)

	var cyl_w: float = minf(w * 0.55, 220.0)
	var cyl_x: float = w * 0.32 - cyl_w * 0.5
	var base_y: float = h - 28.0
	var max_gas: float = base_y - 48.0
	var gas_h: float = clampf(_vd * UPL, 36.0, max_gas)
	var top_y: float = base_y - gas_h

	var chamber_rect := Rect2(cyl_x, top_y, cyl_w, gas_h)
	c.draw_rect(Rect2(chamber_rect.position + Vector2(5.0, 6.0), chamber_rect.size), Color(0.0, 0.0, 0.0, 0.28), true)
	c.draw_rect(Rect2(cyl_x - 3.0, top_y - 6.0, cyl_w + 6.0, gas_h + 12.0), Color("#455a64"), false, 3.0)
	c.draw_rect(chamber_rect, Color("#0d1b2a"), true)
	c.draw_rect(Rect2(cyl_x + 3.0, top_y + 3.0, 7.0, gas_h - 6.0), Color(0.63, 0.82, 0.92, 0.18), true)
	c.draw_rect(Rect2(cyl_x + cyl_w - 10.0, top_y + 3.0, 6.0, gas_h - 6.0), Color(0.63, 0.82, 0.92, 0.08), true)

	var pr: float = 5.0
	var pcol := Color("#90caf9")
	for p in _particles:
		var px: float = cyl_x + 8.0 + float(p.x) * (cyl_w - 16.0)
		var py: float = top_y + 6.0 + float(p.y) * (gas_h - 12.0)
		c.draw_circle(Vector2(px, py), pr, pcol)

	c.draw_rect(Rect2(cyl_x - 8.0, top_y - 16.0, cyl_w + 16.0, 16.0), Color("#607d8b"), true)
	c.draw_rect(Rect2(cyl_x - 8.0, top_y - 16.0, cyl_w + 16.0, 11.0), Color("#cfd8dc"), true)
	c.draw_line(Vector2(cyl_x - 6.0, top_y - 14.0), Vector2(cyl_x + cyl_w + 6.0, top_y - 14.0), Color.WHITE, 1.5)
	c.draw_rect(Rect2(cyl_x - 8.0, top_y - 16.0, cyl_w + 16.0, 16.0), Color("#90a4ae"), false, 1.5)
	c.draw_line(
		Vector2(cyl_x + cyl_w * 0.5, top_y - 14.0),
		Vector2(cyl_x + cyl_w * 0.5, top_y - 36.0),
		Color("#90a4ae"), 4.0
	)

	var gx: float = w * 0.78
	var gy: float = h * 0.40
	var gr: float = minf(56.0, w * 0.09)
	c.draw_circle(Vector2(gx, gy), gr, Color("#37474f"), false, 3.0)
	c.draw_circle(Vector2(gx, gy), gr - 6.0, Color("#263238"), true)
	for tick in range(9):
		var tick_angle: float = -PI * 0.75 + float(tick) / 8.0 * PI * 1.5
		var tick_outer := Vector2(gx, gy) + Vector2(cos(tick_angle), sin(tick_angle)) * (gr - 8.0)
		var tick_inner := Vector2(gx, gy) + Vector2(cos(tick_angle), sin(tick_angle)) * (gr - 14.0)
		c.draw_line(tick_inner, tick_outer, Color("#b0bec5"), 1.0)
	var ang: float = -PI * 0.75 + clampf(_pd / 400.0, 0.0, 1.0) * (PI * 1.5)
	c.draw_line(
		Vector2(gx, gy),
		Vector2(gx + cos(ang) * (gr - 10.0), gy + sin(ang) * (gr - 10.0)),
		Color("#ef5350"), 3.0
	)
	c.draw_circle(Vector2(gx, gy), 4.0, Color("#ef5350"))
	c.draw_string(
		ThemeDB.fallback_font,
		Vector2(gx - 32.0, gy + gr + 18.0),
		"%.0f kPa" % _pd,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5")
	)
	c.draw_string(
		ThemeDB.fallback_font,
		Vector2(14, 22),
		"V ~ %.1f L" % _vd,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b0bec5")
	)


func _draw_graph() -> void:
	if _graph == null:
		return
	var c: Control = _graph
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#faf9f8"), true)
	var axes: Dictionary = model.graph_axes()
	var pad_l: float = 44.0
	var pad_b: float = 28.0
	var pad_t: float = 20.0
	var pad_r: float = 16.0
	var pw: float = w - pad_l - pad_r
	var ph: float = h - pad_t - pad_b
	c.draw_line(Vector2(pad_l, pad_t), Vector2(pad_l, pad_t + ph), Color("#cccccc"), 1.0)
	c.draw_line(Vector2(pad_l, pad_t + ph), Vector2(pad_l + pw, pad_t + ph), Color("#cccccc"), 1.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(pad_l, 14), str(axes.yl), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#666666"))
	c.draw_string(ThemeDB.fallback_font, Vector2(pad_l + pw * 0.35, h - 8), str(axes.xl), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#666666"))

	if model.data.is_empty():
		c.draw_string(ThemeDB.fallback_font, Vector2(pad_l + 8, pad_t + ph * 0.5), "Record points to plot", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#999999"))
		return

	var xk: String = str(axes.x)
	var yk: String = str(axes.y)
	var xmin: float = INF
	var xmax: float = -INF
	var ymin: float = INF
	var ymax: float = -INF
	for row in model.data:
		var xv: float = float(row[xk])
		var yv: float = float(row[yk])
		xmin = minf(xmin, xv)
		xmax = maxf(xmax, xv)
		ymin = minf(ymin, yv)
		ymax = maxf(ymax, yv)
	if is_equal_approx(xmin, xmax):
		xmax = xmin + 1.0
	if is_equal_approx(ymin, ymax):
		ymax = ymin + 1.0
	var xpad: float = (xmax - xmin) * 0.08
	var ypad: float = (ymax - ymin) * 0.08
	xmin -= xpad
	xmax += xpad
	ymin -= ypad
	ymax += ypad

	var pts := PackedVector2Array()
	for row in model.data:
		var xv2: float = float(row[xk])
		var yv2: float = float(row[yk])
		var px: float = pad_l + (xv2 - xmin) / (xmax - xmin) * pw
		var py: float = pad_t + ph - (yv2 - ymin) / (ymax - ymin) * ph
		pts.append(Vector2(px, py))
		c.draw_circle(Vector2(px, py), 4.0, Color("#b22222"))
	if pts.size() >= 2:
		c.draw_polyline(pts, Color("#b22222"), 1.5, true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_SPACE:
			_on_pause_toggle()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_record()
			get_viewport().set_input_as_handled()
		KEY_C:
			_on_clear()
			get_viewport().set_input_as_handled()
		KEY_0, KEY_HOME:
			_on_reset()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
		KEY_1:
			_on_law(int(GasLawsModel.Law.FREE))
			get_viewport().set_input_as_handled()
		KEY_2:
			_on_law(int(GasLawsModel.Law.BOYLE))
			get_viewport().set_input_as_handled()
		KEY_3:
			_on_law(int(GasLawsModel.Law.CHARLES))
			get_viewport().set_input_as_handled()
		KEY_4:
			_on_law(int(GasLawsModel.Law.GAY_LUSSAC))
			get_viewport().set_input_as_handled()
		KEY_5:
			_on_law(int(GasLawsModel.Law.AVOGADRO))
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT, KEY_MINUS:
			_nudge_free(-1)
			get_viewport().set_input_as_handled()
		KEY_BRACKETRIGHT, KEY_EQUAL:
			_nudge_free(1)
			get_viewport().set_input_as_handled()
		KEY_UP:
			_nudge_free(1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_nudge_free(-1)
			get_viewport().set_input_as_handled()


func _nudge_free(dir: int) -> void:
	## Nudge the free control for the active law by a small step.
	match model.law:
		GasLawsModel.Law.FREE, GasLawsModel.Law.BOYLE:
			model.set_control("V", model.v + dir * 0.5)
		GasLawsModel.Law.CHARLES, GasLawsModel.Law.GAY_LUSSAC:
			model.set_control("T", model.t + dir * 10.0)
		GasLawsModel.Law.AVOGADRO:
			model.set_control("n", model.n + dir * 0.05)
	_sync_particles(false)
	_refresh_ui()


func _format_significant(value: float, digits: int) -> String:
	if not is_finite(value):
		return str(value)
	if value == 0.0:
		return "0"
	var exponent := floori(log(absf(value)) / log(10.0))
	if exponent >= digits or exponent < -4:
		return _format_scientific(value, digits - 1)
	var rounded := String.num(value, maxi(0, digits - 1 - exponent)).to_float()
	var rounded_exponent := floori(log(absf(rounded)) / log(10.0)) if rounded != 0.0 else exponent
	if rounded_exponent >= digits or rounded_exponent < -4:
		return _format_scientific(value, digits - 1)
	return String.num(value, maxi(0, digits - 1 - rounded_exponent))


func _format_scientific(value: float, decimals: int) -> String:
	var exponent := floori(log(absf(value)) / log(10.0))
	var mantissa := value / pow(10.0, float(exponent))
	var rounded := String.num(mantissa, decimals).to_float()
	if absf(rounded) >= 10.0:
		mantissa /= 10.0
		exponent += 1
	var exponent_sign := "+" if exponent >= 0 else "-"
	return "%se%s%s" % [String.num(mantissa, decimals), exponent_sign, str(absi(exponent)).pad_zeros(2)]
