extends LabShell
## Ecology — two-species competition and niche coexistence.

var model: EcologyModel = EcologyModel.new()

var _stage: Control
var _phase: Control
var _btn_play: Button
var _running: bool = false
var _acc: float = 0.0
const YEARS_PER_SEC: float = 3.0

var _s_r1: HSlider
var _s_r2: HSlider
var _s_k1: HSlider
var _s_k2: HSlider
var _s_a12: HSlider
var _s_a21: HSlider
var _s_x0: HSlider
var _s_y0: HSlider
var _o_r1: Label
var _o_r2: Label
var _o_k1: Label
var _o_k2: Label
var _o_a12: Label
var _o_a21: Label
var _o_x0: Label
var _o_y0: Label
var _r_x: Label
var _r_y: Label
var _r_t: Label
var _r_eq: Label
var _r_ov: Label
var _r_status: Label
var _updating: bool = false
var _x0: float = 20.0
var _y0: float = 20.0


func _ready() -> void:
	lab_title = "Ecology"
	lab_eyebrow = "BIOLOGY  /  ECOLOGY"
	lab_lead = "Two species compete for limited resources. Change niche overlap and carrying capacities — see coexistence or competitive exclusion."
	field_id = "biology"
	page_id = "ecology"
	back_label = "<- Biology"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.apply_preset("coexist")
	_x0 = model.x
	_y0 = model.y
	_sync_sliders()
	_refresh()
	set_process(true)
	set_status("Coexistence preset · press Play.")


func _process(delta: float) -> void:
	if not _running:
		return
	_acc += delta * YEARS_PER_SEC
	var guard: int = 0
	while _acc >= model.DT and guard < 50:
		_acc -= model.DT
		guard += 1
		model.step(model.DT)
	_refresh()


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "TimeSeries"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_time"))

	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size = Vector2(0, 190)
	_phase = Control.new()
	_phase.custom_minimum_size = Vector2(0, 170)
	_phase.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_phase)
	var extra := get_extra()
	if extra:
		extra.add_child(card)
	_phase.draw.connect(Callable(self, "_draw_phase"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "PRESETS")
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	sb.add_child(prow)
	for item in [["Coexist", "coexist"], ["A wins", "exclusion_a"], ["B wins", "exclusion_b"], ["Identical niches", "identical"]]:
		var b := Button.new()
		b.text = str(item[0])
		b.theme_type_variation = &"Chip"
		var id: String = str(item[1])
		b.pressed.connect(func(): _on_preset(id))
		prow.add_child(b)

	_add_section(sb, "TRANSPORT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	sb.add_child(row)
	_btn_play = Button.new()
	_btn_play.text = "Play"
	_btn_play.pressed.connect(_on_play)
	row.add_child(_btn_play)
	var bs := Button.new()
	bs.text = "Step"
	bs.theme_type_variation = &"GhostButton"
	bs.pressed.connect(_on_step)
	row.add_child(bs)
	var br := Button.new()
	br.text = "Reset"
	br.theme_type_variation = &"GhostButton"
	br.pressed.connect(_on_reset)
	row.add_child(br)

	_add_section(sb, "SPECIES A")
	_o_r1 = Label.new(); sb.add_child(_o_r1)
	_s_r1 = _slider(sb, 0.1, 2.5, model.r1, 0.05, _on_r1)
	_o_k1 = Label.new(); sb.add_child(_o_k1)
	_s_k1 = _slider(sb, 20.0, 150.0, model.k1, 1.0, _on_k1)
	_o_a12 = Label.new(); sb.add_child(_o_a12)
	_s_a12 = _slider(sb, 0.0, 1.5, model.a12, 0.05, _on_a12)

	_add_section(sb, "SPECIES B")
	_o_r2 = Label.new(); sb.add_child(_o_r2)
	_s_r2 = _slider(sb, 0.1, 2.5, model.r2, 0.05, _on_r2)
	_o_k2 = Label.new(); sb.add_child(_o_k2)
	_s_k2 = _slider(sb, 20.0, 150.0, model.k2, 1.0, _on_k2)
	_o_a21 = Label.new(); sb.add_child(_o_a21)
	_s_a21 = _slider(sb, 0.0, 1.5, model.a21, 0.05, _on_a21)

	_add_section(sb, "INITIAL")
	_o_x0 = Label.new(); sb.add_child(_o_x0)
	_s_x0 = _slider(sb, 1.0, 100.0, _x0, 1.0, _on_x0)
	_o_y0 = Label.new(); sb.add_child(_o_y0)
	_s_y0 = _slider(sb, 1.0, 100.0, _y0, 1.0, _on_y0)

	_add_section(sb, "READOUTS")
	_r_t = _stat(sb, "Time")
	_r_x = _stat(sb, "Species A (x)")
	_r_y = _stat(sb, "Species B (y)")
	_r_eq = _stat(sb, "Equilibrium")
	_r_ov = _stat(sb, "Niche overlap proxy")
	_r_status = Label.new()
	_r_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_status.add_theme_font_size_override("font_size", 12)
	sb.add_child(_r_status)

	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.text = "α12 = effect of B on A. High α means strong competition (similar niches). Low α → niche partitioning → coexistence."
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
	_running = false
	_btn_play.text = "Play"
	model.apply_preset(id)
	_x0 = model.x
	_y0 = model.y
	_sync_sliders()
	_refresh()
	set_status("Preset: %s" % id)


func _sync_sliders() -> void:
	_updating = true
	_s_r1.value = model.r1
	_s_r2.value = model.r2
	_s_k1.value = model.k1
	_s_k2.value = model.k2
	_s_a12.value = model.a12
	_s_a21.value = model.a21
	_s_x0.value = _x0
	_s_y0.value = _y0
	_updating = false


func _on_play() -> void:
	_running = not _running
	_btn_play.text = "Pause" if _running else "Play"
	set_status("Running…" if _running else "Paused")


func _on_step() -> void:
	_running = false
	_btn_play.text = "Play"
	model.advance(0.5)
	_refresh()


func _on_reset() -> void:
	_running = false
	_btn_play.text = "Play"
	model.reset(_x0, _y0)
	_refresh()
	set_status("Reset")


func _on_r1(v: float) -> void:
	if _updating: return
	model.r1 = v
	_refresh()


func _on_r2(v: float) -> void:
	if _updating: return
	model.r2 = v
	_refresh()


func _on_k1(v: float) -> void:
	if _updating: return
	model.k1 = v
	_refresh()


func _on_k2(v: float) -> void:
	if _updating: return
	model.k2 = v
	_refresh()


func _on_a12(v: float) -> void:
	if _updating: return
	model.a12 = v
	_refresh()


func _on_a21(v: float) -> void:
	if _updating: return
	model.a21 = v
	_refresh()


func _on_x0(v: float) -> void:
	if _updating: return
	_x0 = v


func _on_y0(v: float) -> void:
	if _updating: return
	_y0 = v


func _refresh() -> void:
	_o_r1.text = "Growth r₁ = %.2f" % model.r1
	_o_r2.text = "Growth r₂ = %.2f" % model.r2
	_o_k1.text = "Carrying K₁ = %.0f" % model.k1
	_o_k2.text = "Carrying K₂ = %.0f" % model.k2
	_o_a12.text = "Competition α₁₂ (B→A) = %.2f" % model.a12
	_o_a21.text = "Competition α₂₁ (A→B) = %.2f" % model.a21
	_o_x0.text = "Initial A = %.0f" % _x0
	_o_y0.text = "Initial B = %.0f" % _y0
	_r_t.text = "%.2f" % model.t
	_r_x.text = "%.2f" % model.x
	_r_y.text = "%.2f" % model.y
	var eq: Dictionary = model.equilibrium()
	if bool(eq.get("ok", false)):
		_r_eq.text = "x*=%.1f y*=%.1f (%s)" % [float(eq["x"]), float(eq["y"]), str(eq["mode"])]
	else:
		_r_eq.text = str(eq.get("mode", "—"))
	_r_ov.text = "%.2f" % model.niche_overlap()
	_r_status.text = model.status()
	set_status("t=%.1f · A=%.1f B=%.1f · %s" % [model.t, model.x, model.y, model.status()])
	if _stage:
		_stage.queue_redraw()
	if _phase:
		_phase.queue_redraw()


func _draw_time() -> void:
	if _stage == null:
		return
	var c := _stage
	var sz: Vector2 = c.size
	if sz.x < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#101418"))
	var pad := 36.0
	var plot := Rect2(pad, 22.0, sz.x - pad * 2.0, sz.y - 50.0)
	c.draw_rect(plot, Color("#1a1e24"))
	c.draw_string(ThemeDB.fallback_font, Vector2(pad, 16.0), "Time series — A (teal) · B (violet)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b0bec5"))

	var hx: Array = model.hist_x
	var hy: Array = model.hist_y
	var ht: Array = model.hist_t
	if hx.size() < 2:
		return
	var vmax: float = 1.0
	for v in hx:
		vmax = maxf(vmax, float(v))
	for v in hy:
		vmax = maxf(vmax, float(v))
	var t0: float = float(ht[0])
	var t1: float = maxf(float(ht[ht.size() - 1]), t0 + 1e-6)
	var px := PackedVector2Array()
	var py := PackedVector2Array()
	for i in range(hx.size()):
		var u: float = (float(ht[i]) - t0) / (t1 - t0)
		var xp: float = plot.position.x + u * plot.size.x
		px.append(Vector2(xp, plot.position.y + (1.0 - float(hx[i]) / vmax) * plot.size.y))
		py.append(Vector2(xp, plot.position.y + (1.0 - float(hy[i]) / vmax) * plot.size.y))
	c.draw_polyline(px, Color("#26a69a"), 2.0, true)
	c.draw_polyline(py, Color("#7e57c2"), 2.0, true)


func _draw_phase() -> void:
	if _phase == null:
		return
	var c := _phase
	var sz: Vector2 = c.size
	if sz.x < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#121418"))
	var pad := 36.0
	var plot := Rect2(pad, 18.0, sz.x - pad * 2.0, sz.y - 40.0)
	c.draw_rect(plot, Color("#1a1e24"))
	c.draw_string(ThemeDB.fallback_font, Vector2(pad, 12.0), "Phase plane — x (A) vs y (B)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	var hx: Array = model.hist_x
	var hy: Array = model.hist_y
	if hx.size() < 2:
		return
	var xmax: float = maxf(model.k1, 1.0) * 1.15
	var ymax: float = maxf(model.k2, 1.0) * 1.15
	for v in hx:
		xmax = maxf(xmax, float(v) * 1.05)
	for v in hy:
		ymax = maxf(ymax, float(v) * 1.05)

	# Zero-growth isoclines: x + α12 y = K1  and  y + α21 x = K2
	var iso1 := PackedVector2Array()
	var iso2 := PackedVector2Array()
	for i in range(40):
		var yy: float = ymax * float(i) / 39.0
		var xx1: float = model.k1 - model.a12 * yy
		if xx1 >= 0.0:
			iso1.append(Vector2(plot.position.x + (xx1 / xmax) * plot.size.x, plot.position.y + (1.0 - yy / ymax) * plot.size.y))
		var xx: float = xmax * float(i) / 39.0
		var yy2: float = model.k2 - model.a21 * xx
		if yy2 >= 0.0:
			iso2.append(Vector2(plot.position.x + (xx / xmax) * plot.size.x, plot.position.y + (1.0 - yy2 / ymax) * plot.size.y))
	if iso1.size() >= 2:
		c.draw_polyline(iso1, Color("#26a69a", 0.55), 1.5, true)
	if iso2.size() >= 2:
		c.draw_polyline(iso2, Color("#7e57c2", 0.55), 1.5, true)

	var pts := PackedVector2Array()
	for i in range(hx.size()):
		pts.append(Vector2(
			plot.position.x + (float(hx[i]) / xmax) * plot.size.x,
			plot.position.y + (1.0 - float(hy[i]) / ymax) * plot.size.y
		))
	c.draw_polyline(pts, Color("#90caf9"), 1.5, true)
	c.draw_circle(pts[pts.size() - 1], 4.0, Color("#e53935"))

	var eq: Dictionary = model.equilibrium()
	if bool(eq.get("ok", false)):
		var ex: float = plot.position.x + (float(eq["x"]) / xmax) * plot.size.x
		var ey: float = plot.position.y + (1.0 - float(eq["y"]) / ymax) * plot.size.y
		c.draw_circle(Vector2(ex, ey), 5.0, Color("#ffeb3b"))
