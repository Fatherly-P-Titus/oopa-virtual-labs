extends LabShell
## Predator–Prey — Lotka–Volterra time series + phase portrait.

var model: PredatorPreyModel = PredatorPreyModel.new()

var _stage: Control
var _phase: Control
var _btn_play: Button
var _running: bool = false
var _acc: float = 0.0
const YEARS_PER_SEC: float = 2.5

var _s_r: HSlider
var _s_a: HSlider
var _s_b: HSlider
var _s_m: HSlider
var _s_k: HSlider
var _s_x0: HSlider
var _s_y0: HSlider
var _o_r: Label
var _o_a: Label
var _o_b: Label
var _o_m: Label
var _o_k: Label
var _o_x0: Label
var _o_y0: Label
var _chk_ext: CheckBox
var _r_x: Label
var _r_y: Label
var _r_t: Label
var _r_eq: Label
var _r_per: Label
var _r_status: Label
var _updating: bool = false
var _x0: float = 40.0
var _y0: float = 20.0


func _ready() -> void:
	lab_title = "Predator–Prey"
	lab_eyebrow = "BIOLOGY  /  PREDATOR–PREY"
	lab_lead = "Lotka–Volterra cycles. Change growth, predation and carrying capacity — watch time series and the phase portrait."
	field_id = "biology"
	page_id = "predator_prey"
	back_label = "<- Biology"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.apply_preset("classic")
	_sync_sliders()
	_refresh()
	set_process(true)
	set_status("Classic LV · press Play to integrate.")


func _process(delta: float) -> void:
	if not _running:
		return
	_acc += delta * YEARS_PER_SEC
	var guard: int = 0
	while _acc >= model.DT and guard < 40:
		_acc -= model.DT
		guard += 1
		model.step(model.DT)
	_refresh()


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "TimeSeries"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.custom_minimum_size = Vector2(0, 220)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_time"))

	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size = Vector2(0, 200)
	_phase = Control.new()
	_phase.custom_minimum_size = Vector2(0, 180)
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
	for item in [["Classic", "classic"], ["Strong cycles", "cycles"], ["Food limit", "limited"], ["Extinction", "extinction"]]:
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

	_add_section(sb, "PARAMETERS")
	_o_r = Label.new(); sb.add_child(_o_r)
	_s_r = _slider(sb, 0.05, 2.0, model.r, 0.01, _on_r)
	_o_a = Label.new(); sb.add_child(_o_a)
	_s_a = _slider(sb, 0.001, 0.08, model.a, 0.001, _on_a)
	_o_b = Label.new(); sb.add_child(_o_b)
	_s_b = _slider(sb, 0.05, 1.0, model.b, 0.01, _on_b)
	_o_m = Label.new(); sb.add_child(_o_m)
	_s_m = _slider(sb, 0.05, 1.5, model.m, 0.01, _on_m)
	_o_k = Label.new(); sb.add_child(_o_k)
	_s_k = _slider(sb, 20.0, 500.0, minf(model.k_food, 500.0), 5.0, _on_k)

	_chk_ext = CheckBox.new()
	_chk_ext.text = "Extinction floor (wipe if N < 1)"
	_chk_ext.button_pressed = model.extinction
	_chk_ext.toggled.connect(_on_ext)
	sb.add_child(_chk_ext)

	_add_section(sb, "INITIAL CONDITIONS")
	_o_x0 = Label.new(); sb.add_child(_o_x0)
	_s_x0 = _slider(sb, 1.0, 120.0, _x0, 1.0, _on_x0)
	_o_y0 = Label.new(); sb.add_child(_o_y0)
	_s_y0 = _slider(sb, 1.0, 80.0, _y0, 1.0, _on_y0)

	_add_section(sb, "READOUTS")
	_r_t = _stat(sb, "Time t")
	_r_x = _stat(sb, "Prey x")
	_r_y = _stat(sb, "Predators y")
	_r_eq = _stat(sb, "Equilibrium")
	_r_per = _stat(sb, "Period ≈")
	_r_status = Label.new()
	_r_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_status.add_theme_font_size_override("font_size", 12)
	sb.add_child(_r_status)

	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.text = "Green = prey, orange = predators. Phase plot is x vs y. K=500 means no food limit."
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
	_s_r.value = model.r
	_s_a.value = model.a
	_s_b.value = model.b
	_s_m.value = model.m
	_s_k.value = minf(model.k_food, 500.0)
	_s_x0.value = _x0
	_s_y0.value = _y0
	_chk_ext.button_pressed = model.extinction
	_updating = false


func _on_play() -> void:
	_running = not _running
	_btn_play.text = "Pause" if _running else "Play"
	set_status("Running…" if _running else "Paused")


func _on_step() -> void:
	_running = false
	_btn_play.text = "Play"
	model.advance(0.25)
	_refresh()


func _on_reset() -> void:
	_running = false
	_btn_play.text = "Play"
	model.reset(_x0, _y0)
	_refresh()
	set_status("Reset to x₀=%.0f y₀=%.0f" % [_x0, _y0])


func _on_r(v: float) -> void:
	if _updating: return
	model.r = v
	_refresh()


func _on_a(v: float) -> void:
	if _updating: return
	model.a = v
	_refresh()


func _on_b(v: float) -> void:
	if _updating: return
	model.b = v
	_refresh()


func _on_m(v: float) -> void:
	if _updating: return
	model.m = v
	_refresh()


func _on_k(v: float) -> void:
	if _updating: return
	model.k_food = v
	_refresh()


func _on_x0(v: float) -> void:
	if _updating: return
	_x0 = v


func _on_y0(v: float) -> void:
	if _updating: return
	_y0 = v


func _on_ext(on: bool) -> void:
	model.extinction = on
	_refresh()


func _refresh() -> void:
	_o_r.text = "Prey growth r = %.2f" % model.r
	_o_a.text = "Predation a = %.3f" % model.a
	_o_b.text = "Efficiency b = %.2f" % model.b
	_o_m.text = "Predator death m = %.2f" % model.m
	if model.k_food >= PredatorPreyModel.K_OFF - 1.0:
		_o_k.text = "Food limit K = none (classic)"
	else:
		_o_k.text = "Food limit K = %.0f" % model.k_food
	_o_x0.text = "Initial prey x₀ = %.0f" % _x0
	_o_y0.text = "Initial predators y₀ = %.0f" % _y0
	_r_t.text = "%.2f yr" % model.t
	_r_x.text = "%.2f" % model.x
	_r_y.text = "%.2f" % model.y
	var eq: Variant = model.equilibrium()
	if eq == null:
		_r_eq.text = "none / unstable"
	else:
		_r_eq.text = "x*=%.1f  y*=%.1f" % [float(eq["x"]), float(eq["y"])]
	var per: float = model.theoretical_period()
	_r_per.text = ("%.2f yr" % per) if is_finite(per) else "—"
	_r_status.text = model.status()
	set_status("t=%.1f · prey %.1f · pred %.1f · %s" % [model.t, model.x, model.y, model.status()])
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
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#121418"))
	var pad := 36.0
	var plot := Rect2(pad, 20.0, sz.x - pad * 2.0, sz.y - 48.0)
	c.draw_rect(plot, Color("#1a1e24"))
	c.draw_string(ThemeDB.fallback_font, Vector2(pad, 14.0), "Time series — prey (green) · predators (orange)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b0bec5"))

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
	var t1: float = float(ht[ht.size() - 1])
	var dt: float = maxf(t1 - t0, 1e-6)
	var px := PackedVector2Array()
	var py := PackedVector2Array()
	for i in range(hx.size()):
		var u: float = (float(ht[i]) - t0) / dt
		var xpix: float = plot.position.x + u * plot.size.x
		px.append(Vector2(xpix, plot.position.y + (1.0 - float(hx[i]) / vmax) * plot.size.y))
		py.append(Vector2(xpix, plot.position.y + (1.0 - float(hy[i]) / vmax) * plot.size.y))
	c.draw_polyline(px, Color("#66bb6a"), 2.0, true)
	c.draw_polyline(py, Color("#ff9800"), 2.0, true)
	c.draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, plot.end.y + 16.0), "t=%.1f → %.1f yr" % [t0, t1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#90a4ae"))


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
	c.draw_string(ThemeDB.fallback_font, Vector2(pad, 12.0), "Phase portrait — x (prey) vs y (predators)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	var hx: Array = model.hist_x
	var hy: Array = model.hist_y
	if hx.size() < 2:
		return
	var xmax: float = 1.0
	var ymax: float = 1.0
	for v in hx:
		xmax = maxf(xmax, float(v))
	for v in hy:
		ymax = maxf(ymax, float(v))
	xmax *= 1.1
	ymax *= 1.1
	var pts := PackedVector2Array()
	for i in range(hx.size()):
		var px: float = plot.position.x + (float(hx[i]) / xmax) * plot.size.x
		var py: float = plot.position.y + (1.0 - float(hy[i]) / ymax) * plot.size.y
		pts.append(Vector2(px, py))
	c.draw_polyline(pts, Color("#90caf9"), 1.5, true)
	# current point
	var cur := pts[pts.size() - 1]
	c.draw_circle(cur, 4.0, Color("#e53935"))
	# equilibrium
	var eq: Variant = model.equilibrium()
	if eq != null:
		var ex: float = plot.position.x + (float(eq["x"]) / xmax) * plot.size.x
		var ey: float = plot.position.y + (1.0 - float(eq["y"]) / ymax) * plot.size.y
		c.draw_circle(Vector2(ex, ey), 5.0, Color("#ffeb3b", 0.8))
		c.draw_string(ThemeDB.fallback_font, Vector2(ex + 6, ey - 4), "eq", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#fff59d"))
	c.draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, plot.end.y + 14.0), "x →", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#90a4ae"))
