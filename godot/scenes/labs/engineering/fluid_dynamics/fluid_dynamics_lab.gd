extends LabShell
## Fluid Dynamics — continuity + Bernoulli in a pipe / venturi.

var model: FluidDynamicsModel = FluidDynamicsModel.new()

var _stage: Control
var _graph: Control

var _s_d1: HSlider
var _s_d2: HSlider
var _s_q: HSlider
var _s_p1: HSlider
var _s_z2: HSlider
var _s_f: HSlider
var _s_L: HSlider
var _o_d1: Label
var _o_d2: Label
var _o_q: Label
var _o_p1: Label
var _o_z2: Label
var _o_f: Label
var _o_L: Label

var _r_v1: Label
var _r_v2: Label
var _r_p2: Label
var _r_dp: Label
var _r_hl: Label
var _r_re: Label

var _result: Dictionary = {}
var _updating: bool = false
var _flow_t: float = 0.0


func _ready() -> void:
	lab_title = "Fluid Dynamics"
	lab_eyebrow = "ENGINEERING  /  FLUID DYNAMICS"
	lab_lead = "Continuity and Bernoulli along a pipe. Narrow the throat — speed rises, pressure falls."
	field_id = "engineering"
	page_id = "fluid_dynamics"
	back_label = "<- Engineering"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.apply_preset("venturi")
	_sync_sliders_from_model()
	_solve_and_refresh()
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	_flow_t += delta
	if _stage:
		_stage.queue_redraw()


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "PipeStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))

	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size = Vector2(0, 150)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(0, 130)
	_graph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_graph)
	var extra := get_extra()
	if extra:
		extra.add_child(card)
	_graph.draw.connect(Callable(self, "_draw_graph"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "PRESETS")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	sb.add_child(row)
	for item in [["Venturi", "venturi"], ["Pipe loss", "pipe_loss"], ["Uphill", "uphill"], ["Nozzle", "nozzle"]]:
		var b := Button.new()
		b.text = str(item[0])
		b.theme_type_variation = &"Chip"
		var id: String = str(item[1])
		b.pressed.connect(func(): _on_preset(id))
		row.add_child(b)

	_add_section(sb, "GEOMETRY & FLOW")
	_o_d1 = Label.new()
	sb.add_child(_o_d1)
	_s_d1 = _slider(sb, 0.02, 0.15, model.d1, 0.005, _on_d1)

	_o_d2 = Label.new()
	sb.add_child(_o_d2)
	_s_d2 = _slider(sb, 0.015, 0.15, model.d2, 0.005, _on_d2)

	_o_q = Label.new()
	sb.add_child(_o_q)
	_s_q = _slider(sb, 0.0005, 0.02, model.q, 0.0005, _on_q)

	_o_p1 = Label.new()
	sb.add_child(_o_p1)
	_s_p1 = _slider(sb, 50.0, 400.0, model.p1 / 1000.0, 5.0, _on_p1)  # kPa

	_o_z2 = Label.new()
	sb.add_child(_o_z2)
	_s_z2 = _slider(sb, -2.0, 10.0, model.z2, 0.1, _on_z2)

	_add_section(sb, "FRICTION")
	_o_f = Label.new()
	sb.add_child(_o_f)
	_s_f = _slider(sb, 0.0, 0.08, model.f, 0.001, _on_f)

	_o_L = Label.new()
	sb.add_child(_o_L)
	_s_L = _slider(sb, 0.2, 30.0, model.length, 0.2, _on_L)

	_add_section(sb, "READOUTS")
	_r_v1 = _stat(sb, "v₁ (inlet)")
	_r_v2 = _stat(sb, "v₂ (section 2)")
	_r_p2 = _stat(sb, "p₂")
	_r_dp = _stat(sb, "Δp = p₁−p₂")
	_r_hl = _stat(sb, "Head loss h_L")
	_r_re = _stat(sb, "Reynolds Re₂")

	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.text = "A₁v₁ = A₂v₂. Faster flow in a narrower section → lower static pressure (Bernoulli)."
	sb.add_child(tip)


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
	_sync_sliders_from_model()
	_solve_and_refresh()
	set_status("Preset: %s" % id)


func _sync_sliders_from_model() -> void:
	_updating = true
	_s_d1.value = model.d1
	_s_d2.value = model.d2
	_s_q.value = model.q
	_s_p1.value = model.p1 / 1000.0
	_s_z2.value = model.z2
	_s_f.value = model.f
	_s_L.value = model.length
	_updating = false


func _on_d1(v: float) -> void:
	if _updating: return
	model.d1 = v
	_solve_and_refresh()


func _on_d2(v: float) -> void:
	if _updating: return
	model.d2 = v
	_solve_and_refresh()


func _on_q(v: float) -> void:
	if _updating: return
	model.q = v
	_solve_and_refresh()


func _on_p1(v: float) -> void:
	if _updating: return
	model.p1 = v * 1000.0
	_solve_and_refresh()


func _on_z2(v: float) -> void:
	if _updating: return
	model.z2 = v
	_solve_and_refresh()


func _on_f(v: float) -> void:
	if _updating: return
	model.f = v
	_solve_and_refresh()


func _on_L(v: float) -> void:
	if _updating: return
	model.length = v
	_solve_and_refresh()


func _solve_and_refresh() -> void:
	_result = model.solve()
	_o_d1.text = "D₁ (inlet) = %.0f mm" % (model.d1 * 1000.0)
	_o_d2.text = "D₂ (throat) = %.0f mm" % (model.d2 * 1000.0)
	_o_q.text = "Q = %.2f L/s" % (model.q * 1000.0)
	_o_p1.text = "p₁ = %.0f kPa" % (model.p1 / 1000.0)
	_o_z2.text = "z₂ elevation = %.1f m" % model.z2
	_o_f.text = "Friction f = %.3f" % model.f
	_o_L.text = "Length L = %.1f m" % model.length

	_r_v1.text = "%.2f m/s" % float(_result.get("v1", 0.0))
	_r_v2.text = "%.2f m/s" % float(_result.get("v2", 0.0))
	_r_p2.text = "%.1f kPa" % (float(_result.get("p2", 0.0)) / 1000.0)
	_r_dp.text = "%.1f kPa" % (float(_result.get("dp", 0.0)) / 1000.0)
	_r_hl.text = "%.3f m" % float(_result.get("hL", 0.0))
	_r_re.text = "%.0f" % float(_result.get("Re2", 0.0))

	var v2: float = float(_result.get("v2", 0.0))
	var p2: float = float(_result.get("p2", 0.0))
	set_status("Continuity + Bernoulli · v₂=%.2f m/s · p₂=%.1f kPa" % [v2, p2 / 1000.0])
	if _stage:
		_stage.queue_redraw()
	if _graph:
		_graph.queue_redraw()


func _draw_stage() -> void:
	if _stage == null or _result.is_empty():
		return
	var c := _stage
	var sz: Vector2 = c.size
	if sz.x < 20.0 or sz.y < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#12161c"))

	var d1: float = float(_result.get("d1", model.d1))
	var d2: float = float(_result.get("d2", model.d2))
	var z1: float = float(_result.get("z1", 0.0))
	var z2: float = float(_result.get("z2", 0.0))
	var v1: float = float(_result.get("v1", 0.0))
	var v2: float = float(_result.get("v2", 0.0))
	var p1: float = float(_result.get("p1", 0.0))
	var p2: float = float(_result.get("p2", 0.0))

	# Pipe centerline path left → right with optional rise
	var pad := 40.0
	var x0 := pad
	var x1 := sz.x * 0.38
	var x2 := sz.x * 0.62
	var x3 := sz.x - pad
	var y_base := sz.y * 0.55
	var y1 := y_base - z1 * 12.0
	var y2 := y_base - z2 * 12.0

	# Diameters → half-height scale
	var scale_d := 900.0
	var r1 := clampf(d1 * scale_d * 0.5, 12.0, 55.0)
	var r2 := clampf(d2 * scale_d * 0.5, 8.0, 55.0)

	# Outer pipe polygon (top and bottom)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var samples := 40
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var x: float
		var y: float
		var r: float
		if t < 0.35:
			var u: float = t / 0.35
			x = lerpf(x0, x1, u)
			y = y1
			r = r1
		elif t < 0.65:
			var u2: float = (t - 0.35) / 0.30
			x = lerpf(x1, x2, u2)
			y = lerpf(y1, y2, u2)
			r = lerpf(r1, r2, u2)
		else:
			var u3: float = (t - 0.65) / 0.35
			x = lerpf(x2, x3, u3)
			y = y2
			r = r2
		top.append(Vector2(x, y - r))
		bot.append(Vector2(x, y + r))

	# Fill pipe body
	var poly := PackedVector2Array()
	for p in top:
		poly.append(p)
	for i in range(bot.size() - 1, -1, -1):
		poly.append(bot[i])
	c.draw_colored_polygon(poly, Color("#1e3a5f"))
	c.draw_polyline(top, Color("#90caf9"), 2.0, true)
	c.draw_polyline(bot, Color("#90caf9"), 2.0, true)

	# Flow particles along centerline
	var n_part := 14
	for i in range(n_part):
		var u: float = fmod(_flow_t * 0.25 + float(i) / float(n_part), 1.0)
		var x: float
		var y: float
		var r: float
		var spd: float
		if u < 0.35:
			var t1: float = u / 0.35
			x = lerpf(x0, x1, t1)
			y = y1
			r = r1
			spd = v1
		elif u < 0.65:
			var t2: float = (u - 0.35) / 0.30
			x = lerpf(x1, x2, t2)
			y = lerpf(y1, y2, t2)
			r = lerpf(r1, r2, t2)
			spd = lerpf(v1, v2, t2)
		else:
			var t3: float = (u - 0.65) / 0.35
			x = lerpf(x2, x3, t3)
			y = y2
			r = r2
			spd = v2
		var pr: float = clampf(3.0 + spd * 0.4, 3.0, 8.0)
		c.draw_circle(Vector2(x, y), pr, Color("#4fc3f7", 0.85))

	# Station labels
	c.draw_string(ThemeDB.fallback_font, Vector2(x0, y1 - r1 - 18.0), "①  D=%.0f mm" % (d1 * 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#eceff1"))
	c.draw_string(ThemeDB.fallback_font, Vector2(x0, y1 - r1 - 4.0), "p=%.0f kPa  v=%.2f m/s" % [p1 / 1000.0, v1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))
	c.draw_string(ThemeDB.fallback_font, Vector2(x2 - 20.0, y2 - r2 - 18.0), "②  D=%.0f mm" % (d2 * 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#eceff1"))
	c.draw_string(ThemeDB.fallback_font, Vector2(x2 - 20.0, y2 - r2 - 4.0), "p=%.0f kPa  v=%.2f m/s" % [p2 / 1000.0, v2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	# Pressure bars at stations
	_draw_p_bar(c, Vector2(x0 + 10.0, y1 + r1 + 28.0), p1, "p₁")
	_draw_p_bar(c, Vector2(x2 + 10.0, y2 + r2 + 28.0), p2, "p₂")


func _draw_p_bar(c: Control, origin: Vector2, p: float, label: String) -> void:
	var h: float = clampf((p / 1000.0) / 400.0 * 60.0, 4.0, 70.0)
	c.draw_rect(Rect2(origin.x, origin.y - h, 14.0, h), Color("#ef6c00"))
	c.draw_string(ThemeDB.fallback_font, Vector2(origin.x + 18.0, origin.y - h + 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffcc80"))


func _draw_graph() -> void:
	if _graph == null or _result.is_empty():
		return
	var c := _graph
	var sz: Vector2 = c.size
	if sz.x < 10.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#121214"))
	var pad := 30.0
	var plot := Rect2(pad, 18.0, sz.x - pad * 2.0, sz.y - 40.0)
	c.draw_rect(plot, Color("#1a1a1e"))
	c.draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, 12.0), "Along pipe: velocity (cyan) & pressure (orange)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	var v1: float = float(_result.get("v1", 0.0))
	var v2: float = float(_result.get("v2", 0.0))
	var p1: float = float(_result.get("p1", 0.0)) / 1000.0
	var p2: float = float(_result.get("p2", 0.0)) / 1000.0
	var vmax: float = maxf(maxf(v1, v2), 0.1)
	var pmax: float = maxf(maxf(p1, p2), 1.0)

	# Sample piecewise profile
	var vpts := PackedVector2Array()
	var ppts := PackedVector2Array()
	for i in range(41):
		var t: float = float(i) / 40.0
		var vv: float
		var pp: float
		if t < 0.35:
			vv = v1
			pp = p1
		elif t < 0.65:
			var u: float = (t - 0.35) / 0.30
			vv = lerpf(v1, v2, u)
			pp = lerpf(p1, p2, u)
		else:
			vv = v2
			pp = p2
		var px: float = plot.position.x + t * plot.size.x
		vpts.append(Vector2(px, plot.position.y + (1.0 - vv / vmax) * plot.size.y))
		ppts.append(Vector2(px, plot.position.y + (1.0 - pp / pmax) * plot.size.y))
	if vpts.size() >= 2:
		c.draw_polyline(vpts, Color("#4fc3f7"), 2.0, true)
	if ppts.size() >= 2:
		c.draw_polyline(ppts, Color("#ff9800"), 2.0, true)
	c.draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, plot.end.y + 14.0), "① inlet", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#90a4ae"))
	c.draw_string(ThemeDB.fallback_font, Vector2(plot.end.x - 50.0, plot.end.y + 14.0), "② section", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#90a4ae"))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_on_preset("venturi")
			get_viewport().set_input_as_handled()
