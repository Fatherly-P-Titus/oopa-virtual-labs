extends LabShell
## Acid-base titration on LabShell — apparatus (stand + burette + flask), optional pH curve.

var model: TitrationModel = TitrationModel.new()

var _apparatus: Control
var _curve: Control
var _graph_card: PanelContainer
var _btn_graph: Button

var _scen: OptionButton
var _ind: OptionButton
var _desc: Label
var _slider_ca: HSlider
var _slider_cb: HSlider
var _slider_va: HSlider
var _out_ca: Label
var _out_cb: Label
var _out_va: Label
var _chk_theory: CheckButton
var _r_ph: Label
var _r_vb: Label
var _r_veq: Label
var _r_reg: Label
var _keys_hint: Label

var _updating: bool = false
var _graph_visible: bool = false
var _scen_keys: Array = ["sa_sb", "wa_sb", "sb_sa", "wb_sa"]
var _ind_keys: Array = ["none", "methylorange", "methylred", "bromothymol", "phenolphthalein"]

## Drop animation: progress 0..1 while a drop falls from tip into liquid.
var _drop_active: bool = false
var _drop_t: float = 0.0
const DROP_DURATION: float = 0.45


func _ready() -> void:
	lab_title = "Titration"
	lab_eyebrow = "CHEMISTRY  /  TITRATION"
	lab_lead = "Add titrant step by step. Watch the flask colour and optional pH curve through equivalence."
	field_id = "chemistry"
	page_id = "titration"
	back_label = "<- Chemistry"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.restart()
	_refresh()
	set_process_unhandled_input(true)
	set_process(true)
	set_status("Add titrant in steps. Watch pH and flask colour.")


func _build_stage() -> void:
	# Primary stage: apparatus (stand, burette, flask)
	_apparatus = Control.new()
	_apparatus.name = "Apparatus"
	_apparatus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_apparatus)
	_apparatus.draw.connect(Callable(self, "_draw_apparatus"))

	# Graph below apparatus, smaller, hidden by default
	_graph_card = PanelContainer.new()
	_graph_card.theme_type_variation = &"Card"
	_graph_card.custom_minimum_size = Vector2(0, 150)
	_graph_card.visible = false
	_curve = Control.new()
	_curve.custom_minimum_size = Vector2(0, 130)
	_curve.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph_card.add_child(_curve)
	var extra := get_extra()
	if extra:
		extra.add_child(_graph_card)
	_curve.draw.connect(Callable(self, "_draw_curve"))


func _build_sidebar() -> void:
	var sb := get_sidebar()
	if sb == null:
		push_error("Titration: sidebar missing")
		return

	_add_section(sb, "SCENARIO")
	_scen = OptionButton.new()
	_scen.item_selected.connect(_on_scen)
	sb.add_child(_scen)
	_desc = Label.new()
	_desc.theme_type_variation = &"Muted"
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sb.add_child(_desc)

	_add_section(sb, "INDICATOR")
	_ind = OptionButton.new()
	_ind.item_selected.connect(_on_ind)
	sb.add_child(_ind)

	_add_section(sb, "CONCENTRATIONS")
	_out_ca = Label.new()
	_out_ca.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_ca)
	_slider_ca = _make_slider(0.01, 1.0, 0.01, _on_param)
	sb.add_child(_slider_ca)

	_out_cb = Label.new()
	_out_cb.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_cb)
	_slider_cb = _make_slider(0.01, 1.0, 0.01, _on_param)
	sb.add_child(_slider_cb)

	_out_va = Label.new()
	_out_va.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_va)
	_slider_va = _make_slider(5.0, 50.0, 0.5, _on_param)
	sb.add_child(_slider_va)

	_add_section(sb, "ADD TITRANT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for dv in [0.5, 1.0, 5.0]:
		var b := Button.new()
		b.text = "+%.1f mL" % dv
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var step: float = dv
		b.pressed.connect(_on_add.bind(step))
		row.add_child(b)
	sb.add_child(row)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	var undo := Button.new()
	undo.text = "Undo"
	undo.theme_type_variation = &"GhostButton"
	undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo.pressed.connect(_on_undo)
	row2.add_child(undo)
	var rst := Button.new()
	rst.text = "Restart"
	rst.theme_type_variation = &"GhostButton"
	rst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rst.pressed.connect(_on_restart)
	row2.add_child(rst)
	sb.add_child(row2)

	_add_section(sb, "GRAPH")
	_btn_graph = Button.new()
	_btn_graph.text = "Show graph"
	_btn_graph.theme_type_variation = &"GhostButton"
	_btn_graph.pressed.connect(_on_toggle_graph)
	sb.add_child(_btn_graph)

	_chk_theory = CheckButton.new()
	_chk_theory.text = "Show theoretical curve"
	_chk_theory.button_pressed = true
	_chk_theory.toggled.connect(_on_theory)
	sb.add_child(_chk_theory)

	_add_section(sb, "READOUTS")
	_r_ph = _stat_row(sb, "pH")
	_r_vb = _stat_row(sb, "Vb")
	_r_veq = _stat_row(sb, "Veq")
	_r_reg = _stat_row(sb, "Region")

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: A/S/D add 0.5/1/5 mL · U undo · R restart · G graph · T theory · Esc back"
	sb.add_child(_keys_hint)

	_wire_options()


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


func _wire_options() -> void:
	_scen.clear()
	for k in _scen_keys:
		var s: Dictionary = TitrationModel.SCENARIOS[k]
		_scen.add_item("%s <- %s" % [str(s.analyte), str(s.titrant)])
	_scen.select(0)
	_ind.clear()
	for k in _ind_keys:
		_ind.add_item(str(TitrationModel.INDICATORS[k]["name"]))
	_ind.select(4)


func _process(delta: float) -> void:
	if _drop_active:
		_drop_t += delta / DROP_DURATION
		if _drop_t >= 1.0:
			_drop_t = 1.0
			_drop_active = false
		if _apparatus:
			_apparatus.queue_redraw()


func _on_scen(idx: int) -> void:
	if idx < 0 or idx >= _scen_keys.size():
		return
	model.scenario = str(_scen_keys[idx])
	model.restart()
	_refresh()


func _on_ind(idx: int) -> void:
	if idx < 0 or idx >= _ind_keys.size():
		return
	model.indicator = str(_ind_keys[idx])
	_refresh()


func _on_param(_v: float = 0.0) -> void:
	if _updating:
		return
	model.ca = _slider_ca.value
	model.cb = _slider_cb.value
	model.va = _slider_va.value
	model.restart()
	_refresh()


func _on_add(dv: float) -> void:
	var remaining: float = TitrationModel.VMAX - model.vb
	if remaining <= 1e-6:
		set_status("Burette empty (0.0 mL left). Restart or adjust volumes.")
		return
	var actual: float = minf(dv, remaining)
	model.add_volume(actual)
	_start_drop()
	_refresh()
	if actual < dv - 1e-6:
		set_status("Only %.1f mL left in burette — added that amount." % actual)


func _start_drop() -> void:
	_drop_active = true
	_drop_t = 0.0
	if _apparatus:
		_apparatus.queue_redraw()


func _on_undo() -> void:
	model.undo()
	_refresh()


func _on_restart() -> void:
	model.restart()
	_drop_active = false
	_drop_t = 0.0
	_refresh()


func _on_toggle_graph() -> void:
	_graph_visible = not _graph_visible
	if _graph_card:
		_graph_card.visible = _graph_visible
	if _btn_graph:
		_btn_graph.text = "Hide graph" if _graph_visible else "Show graph"
	if _graph_visible and _curve:
		_curve.queue_redraw()


func _on_theory(_pressed: bool) -> void:
	if _curve and _graph_visible:
		_curve.queue_redraw()


func _refresh() -> void:
	if _slider_ca == null:
		return
	_updating = true
	_slider_ca.value = model.ca
	_slider_cb.value = model.cb
	_slider_va.value = model.va
	_updating = false

	_out_ca.text = "Analyte Ca = %.3f M" % model.ca
	_out_cb.text = "Titrant Cb = %.3f M" % model.cb
	_out_va.text = "Flask Va = %.1f mL" % model.va

	var ph: float = model.current_ph()
	_r_ph.text = "%.2f" % ph
	_r_vb.text = "%.2f mL" % model.vb
	_r_veq.text = "%.2f mL" % model.veq()
	_r_reg.text = model.region()
	_desc.text = str(model.scen().get("desc", ""))

	var msg := ""
	if model.veq() > TitrationModel.VMAX:
		msg = "Veq ~%.0f mL exceeds burette (50 mL) - raise Cb or lower Va." % model.veq()
	elif absf(model.vb - model.veq()) <= 0.05 and model.vb > 0.0:
		msg = "Near equivalence (Veq = %.2f mL)." % model.veq()
	else:
		msg = "Vb = %.2f mL · left %.1f mL · pH = %.2f · %s" % [
			model.vb, _burette_remaining(), ph, model.region()
		]
	set_status(msg)

	if _apparatus:
		_apparatus.queue_redraw()
	if _curve and _graph_visible:
		_curve.queue_redraw()



func _burette_remaining() -> float:
	return maxf(0.0, TitrationModel.VMAX - model.vb)


func _base_flask_color() -> Color:
	## Untitrated analyte look (before indicator dominates).
	match model.scenario:
		"sa_sb":
			return Color("#f0f8ff")  # alice blue — clear strong acid
		"wa_sb":
			return Color("#fff8e7")  # warm pale — ethanoic acid
		"sb_sa":
			return Color("#f5f5f5")  # near-clear strong base
		"wb_sa":
			return Color("#eef6ff")  # very pale blue — ammonia
		_:
			return Color("#f0f8ff")


func _display_flask_color(ph: float) -> Color:
	## Blend base analyte colour into indicator colour through the transition window.
	var base: Color = _base_flask_color()
	var ind: Dictionary = TitrationModel.INDICATORS.get(model.indicator, {})
	var pK: float = float(ind.get("pK", -1.0))
	if pK < 0.0:
		return base
	var lo: float = float(ind.get("lo", pK - 1.0))
	var hi: float = float(ind.get("hi", pK + 1.0))
	# Smooth 0→1 across [lo, hi]
	var t: float = clampf((ph - lo) / maxf(hi - lo, 0.05), 0.0, 1.0)
	# Ease so change starts subtle then fills in
	t = t * t * (3.0 - 2.0 * t)
	var acid_c: Color = ind["acid"]
	var base_c: Color = ind["base"]
	# Early: mostly analyte base tint mixed with acid form of indicator
	var early: Color = base.lerp(acid_c, 0.35)
	var late: Color = base_c
	return early.lerp(late, t)


# ---------------------------------------------------------------------------
# Apparatus: clamp stand + burette centred above half-filled flask
# ---------------------------------------------------------------------------
func _draw_apparatus() -> void:
	if _apparatus == null:
		return
	var c: Control = _apparatus
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return

	# Lab bench background
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#eceff1"), true)
	# Bench surface
	var bench_y: float = h * 0.88
	c.draw_rect(Rect2(0, bench_y, w, h - bench_y), Color("#8d6e63"), true)
	c.draw_line(Vector2(0, bench_y), Vector2(w, bench_y), Color("#6d4c41"), 2.0)

	# Centre line for apparatus stack
	var cx: float = w * 0.50

	# --- Clamp stand (base + upright + clamp) ---
	var stand_x: float = cx - 90.0
	# Base plate
	c.draw_rect(Rect2(stand_x - 36, bench_y - 10, 72, 12), Color("#546e7a"), true)
	c.draw_rect(Rect2(stand_x - 36, bench_y - 10, 72, 12), Color("#37474f"), false, 1.5)
	# Upright rod
	var rod_top: float = h * 0.08
	c.draw_rect(Rect2(stand_x - 4, rod_top, 8, bench_y - 10 - rod_top), Color("#78909c"), true)
	c.draw_rect(Rect2(stand_x - 4, rod_top, 8, bench_y - 10 - rod_top), Color("#546e7a"), false, 1.0)
	# Clamp arm (horizontal) holding burette
	var clamp_y: float = h * 0.22
	c.draw_rect(Rect2(stand_x + 4, clamp_y - 5, 70, 10), Color("#607d8b"), true)
	# Clamp jaws around burette
	c.draw_rect(Rect2(cx - 18, clamp_y - 12, 36, 8), Color("#455a64"), true)
	c.draw_rect(Rect2(cx - 18, clamp_y + 4, 36, 8), Color("#455a64"), true)

	# --- Burette (centred on cx, tip into flask neck) ---
	var bur_w: float = 18.0
	var bur_top: float = h * 0.10
	var bur_body_h: float = h * 0.38
	var tip_y: float = bur_top + bur_body_h + 28.0  # tip / nozzle end

	# Glass tube
	c.draw_rect(Rect2(cx - bur_w * 0.5, bur_top, bur_w, bur_body_h), Color("#e3f2fd"), true)
	c.draw_rect(Rect2(cx - bur_w * 0.5, bur_top, bur_w, bur_body_h), Color("#1565c0"), false, 2.0)
	c.draw_line(Vector2(cx - bur_w * 0.5 + 4.0, bur_top + 4.0), Vector2(cx - bur_w * 0.5 + 4.0, bur_top + bur_body_h - 3.0), Color(1.0, 1.0, 1.0, 0.8), 2.0)
	c.draw_line(Vector2(cx + bur_w * 0.5 - 3.0, bur_top + 5.0), Vector2(cx + bur_w * 0.5 - 3.0, bur_top + bur_body_h - 4.0), Color(0.25, 0.46, 0.62, 0.36), 1.0)
	# Volume graduations
	for i in 6:
		var gy: float = bur_top + 12.0 + float(i) * (bur_body_h - 24.0) / 5.0
		c.draw_line(Vector2(cx + bur_w * 0.5 - 1, gy), Vector2(cx + bur_w * 0.5 + 6, gy), Color("#1565c0"), 1.0)
	# Finite titrant: starts full (50 mL), depletes with each addition
	var remaining: float = _burette_remaining()
	var fill_frac: float = remaining / TitrationModel.VMAX
	var liquid_h: float = fill_frac * (bur_body_h - 16.0)
	if liquid_h > 2.0:
		c.draw_rect(
			Rect2(cx - bur_w * 0.5 + 2, bur_top + bur_body_h - liquid_h - 4, bur_w - 4, liquid_h),
			Color(0.30, 0.60, 0.95, 0.65), true
		)
	# Stopcock
	var cock_y: float = bur_top + bur_body_h
	c.draw_rect(Rect2(cx - 14, cock_y, 28, 8), Color("#37474f"), true)
	c.draw_circle(Vector2(cx + 16, cock_y + 4), 5.0, Color("#546e7a"))
	# Tip / nozzle (tapers into flask neck)
	c.draw_line(Vector2(cx, cock_y + 8), Vector2(cx, tip_y), Color("#1565c0"), 2.5)
	c.draw_circle(Vector2(cx, tip_y), 3.0, Color("#1565c0"))

	c.draw_string(ThemeDB.fallback_font, Vector2(cx + 22, bur_top + 14), "Burette", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#1565c0"))
	c.draw_string(ThemeDB.fallback_font, Vector2(cx + 22, bur_top + 30), "Left: %.1f mL" % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#0d47a1"))
	c.draw_string(ThemeDB.fallback_font, Vector2(cx + 22, bur_top + 46), "Used: %.1f mL" % model.vb, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#546e7a"))

	# --- Erlenmeyer flask (half-filled), tip enters neck ---
	var flask_bottom: float = bench_y - 6.0
	var neck_top: float = tip_y - 8.0  # tip sits partway into neck
	var neck_w: float = 22.0
	var body_top: float = neck_top + 28.0
	var body_half_w: float = 52.0

	# Neck
	c.draw_rect(Rect2(cx - neck_w * 0.5, neck_top, neck_w, body_top - neck_top), Color("#cfd8dc"), false, 2.0)
	c.draw_line(Vector2(cx - neck_w * 0.5 + 3.0, neck_top + 3.0), Vector2(cx - neck_w * 0.5 + 3.0, body_top - 2.0), Color(1.0, 1.0, 1.0, 0.7), 1.5)
	# Body outline (trapezoid / cone)
	var body_pts := PackedVector2Array([
		Vector2(cx - neck_w * 0.5, body_top),
		Vector2(cx + neck_w * 0.5, body_top),
		Vector2(cx + body_half_w, flask_bottom),
		Vector2(cx - body_half_w, flask_bottom),
	])
	# Liquid: half-filled; colour from analyte base tint -> indicator through transition
	var ph: float = model.current_ph()
	var col: Color = _display_flask_color(ph)
	var liquid_top: float = body_top + (flask_bottom - body_top) * 0.42
	var t_liq: float = (liquid_top - body_top) / maxf(flask_bottom - body_top, 1.0)
	var half_at_liq: float = neck_w * 0.5 + (body_half_w - neck_w * 0.5) * t_liq
	var liquid_pts := PackedVector2Array([
		Vector2(cx - half_at_liq, liquid_top),
		Vector2(cx + half_at_liq, liquid_top),
		Vector2(cx + body_half_w, flask_bottom),
		Vector2(cx - body_half_w, flask_bottom),
	])
	c.draw_colored_polygon(liquid_pts, col)
	c.draw_line(Vector2(cx - half_at_liq + 4.0, liquid_top + 1.0), Vector2(cx + half_at_liq - 4.0, liquid_top + 1.0), Color(1.0, 1.0, 1.0, 0.55), 1.2)

	# Full flask outline as one closed path — equal stroke on all sides
	var stroke := Color("#1b1b1b")
	var sw: float = 2.5
	var outline := PackedVector2Array([
		Vector2(cx - neck_w * 0.5, neck_top),
		Vector2(cx + neck_w * 0.5, neck_top),
		Vector2(cx + neck_w * 0.5, body_top),
		Vector2(cx + body_half_w, flask_bottom),
		Vector2(cx - body_half_w, flask_bottom),
		Vector2(cx - neck_w * 0.5, body_top),
		Vector2(cx - neck_w * 0.5, neck_top),
	])
	c.draw_polyline(outline, stroke, sw, true)

	c.draw_string(ThemeDB.fallback_font, Vector2(cx - body_half_w, flask_bottom + 16), "Flask pH %.2f" % ph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#333333"))
	c.draw_string(ThemeDB.fallback_font, Vector2(12, 18), str(model.scen().get("analyte", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#37474f"))
	c.draw_string(ThemeDB.fallback_font, Vector2(12, 36), model.region(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#607d8b"))

	# --- Falling drop when adding titrant ---
	if _drop_active:
		var drop_y: float = lerpf(tip_y, liquid_top, clampf(_drop_t, 0.0, 1.0))
		var drop_r: float = 4.5 if _drop_t < 0.9 else 3.0
		c.draw_circle(Vector2(cx, drop_y), drop_r, Color(0.4, 0.7, 1.0, 0.9))
		# Small trail
		if _drop_t > 0.15:
			c.draw_circle(Vector2(cx, drop_y - 10.0), 2.0, Color(0.4, 0.7, 1.0, 0.35))


# ---------------------------------------------------------------------------
# pH curve (optional, smaller card below apparatus)
# ---------------------------------------------------------------------------
func _draw_curve() -> void:
	if _curve == null:
		return
	var c: Control = _curve
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#161616"), true)

	var pad_l: float = 40.0
	var pad_r: float = 12.0
	var pad_t: float = 22.0
	var pad_b: float = 24.0
	var pw: float = w - pad_l - pad_r
	var phh: float = h - pad_t - pad_b
	var vmax: float = minf(TitrationModel.VMAX, maxf(model.veq() * 2.0, 15.0))
	var grid := Color("#37474f")

	c.draw_line(Vector2(pad_l, pad_t), Vector2(pad_l, pad_t + phh), grid, 1.0)
	c.draw_line(Vector2(pad_l, pad_t + phh), Vector2(pad_l + pw, pad_t + phh), grid, 1.0)
	for tick in [0, 7, 14]:
		var y: float = pad_t + phh - float(tick) / 14.0 * phh
		c.draw_line(Vector2(pad_l - 4, y), Vector2(pad_l, y), grid, 1.0)
		c.draw_string(ThemeDB.fallback_font, Vector2(6, y + 4), str(tick), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#78909c"))

	var ind: Dictionary = TitrationModel.INDICATORS.get(model.indicator, {})
	if float(ind.get("pK", -1.0)) > 0.0:
		var lo: float = float(ind.get("lo", float(ind.pK) - 1.0))
		var hi: float = float(ind.get("hi", float(ind.pK) + 1.0))
		var y1: float = pad_t + phh - hi / 14.0 * phh
		var y2: float = pad_t + phh - lo / 14.0 * phh
		c.draw_rect(Rect2(pad_l, y1, pw, maxf(2.0, y2 - y1)), Color(0.698, 0.133, 0.133, 0.18), true)

	if _chk_theory and _chk_theory.button_pressed:
		var theo: Array = model.theoretical_curve()
		var pts := PackedVector2Array()
		for p in theo:
			pts.append(Vector2(pad_l + float(p.v) / vmax * pw, pad_t + phh - float(p.pH) / 14.0 * phh))
		if pts.size() >= 2:
			c.draw_polyline(pts, Color(0.7, 0.7, 0.7, 0.4), 1.5, true)

	var veq: float = model.veq()
	if veq < vmax:
		var vx: float = pad_l + veq / vmax * pw
		c.draw_line(Vector2(vx, pad_t), Vector2(vx, pad_t + phh), Color(0.698, 0.133, 0.133, 0.45), 1.5)

	var pts2 := PackedVector2Array()
	for p in model.points:
		var x2: float = pad_l + float(p.v) / vmax * pw
		var y2: float = pad_t + phh - float(p.pH) / 14.0 * phh
		pts2.append(Vector2(x2, y2))
		c.draw_circle(Vector2(x2, y2), 3.5, Color("#ef5350"))
	if pts2.size() >= 2:
		c.draw_polyline(pts2, Color("#ef5350"), 2.0, true)

	c.draw_string(ThemeDB.fallback_font, Vector2(pad_l, 14), "pH vs Vb", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b0bec5"))
	c.draw_string(ThemeDB.fallback_font, Vector2(pad_l + pw * 0.4, h - 8), "Vb (mL)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#78909c"))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_A:
			_on_add(0.5)
			get_viewport().set_input_as_handled()
		KEY_S:
			_on_add(1.0)
			get_viewport().set_input_as_handled()
		KEY_D:
			_on_add(5.0)
			get_viewport().set_input_as_handled()
		KEY_U:
			_on_undo()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_restart()
			get_viewport().set_input_as_handled()
		KEY_G:
			_on_toggle_graph()
			get_viewport().set_input_as_handled()
		KEY_T:
			if _chk_theory:
				_chk_theory.button_pressed = not _chk_theory.button_pressed
				_on_theory(_chk_theory.button_pressed)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
