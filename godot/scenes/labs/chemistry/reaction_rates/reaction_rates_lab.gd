extends LabShell
## Reaction rates A -> products on LabShell. Order 0/1/2 + optional Arrhenius + compare series.

var model: ReactionRatesModel = ReactionRatesModel.new()

var _plot: Control
var _order_row: HBoxContainer
var _slider_a0: HSlider
var _slider_k: HSlider
var _slider_t: HSlider
var _slider_ea: HSlider
var _slider_t2: HSlider
var _slider_k2: HSlider
var _out_a0: Label
var _out_k: Label
var _out_t: Label
var _out_ea: Label
var _out_t2: Label
var _out_k2: Label
var _chk_arrh: CheckButton
var _chk_compare: CheckButton
var _btn_play: Button
var _r_a: Label
var _r_rate: Label
var _r_hl: Label
var _r_k: Label
var _r_a2: Label
var _r_hl2: Label
var _keys_hint: Label

var _updating: bool = false
var _playing: bool = false
var _time: float = 0.0
var _series: Array = []
var _series2: Array = []
var _compare: bool = false
var _t2: float = 320.0
var _k2: float = 0.10


func _ready() -> void:
	lab_title = "Reaction Rates"
	lab_eyebrow = "CHEMISTRY  /  REACTION RATES"
	lab_lead = "Zero-, first- and second-order kinetics. Overlay a second run to compare T or k."
	field_id = "chemistry"
	page_id = "reaction_rates"
	back_label = "<- Chemistry"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.set_order(1)
	_rebuild_series()
	_refresh()
	set_process_unhandled_input(true)
	set_process(true)
	set_status("Press Play. Enable Compare to overlay a second series.")


func _build_stage() -> void:
	_plot = Control.new()
	_plot.name = "RatePlot"
	_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_plot)
	_plot.draw.connect(Callable(self, "_draw_plot"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		push_error("ReactionRates: sidebar missing")
		return

	_add_section(sb, "ORDER")
	_order_row = HBoxContainer.new()
	_order_row.add_theme_constant_override("separation", 6)
	sb.add_child(_order_row)
	for n in [0, 1, 2]:
		var b := Button.new()
		b.text = ["0", "1", "2"][n]
		b.theme_type_variation = &"Chip"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var order_n: int = n
		b.pressed.connect(_on_order.bind(order_n))
		_order_row.add_child(b)

	_add_section(sb, "PARAMETERS (RUN 1)")
	_out_a0 = Label.new()
	_out_a0.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_a0)
	_slider_a0 = _make_slider(0.1, 2.0, 0.05, _on_param)
	sb.add_child(_slider_a0)

	_out_k = Label.new()
	_out_k.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_k)
	_slider_k = _make_slider(0.005, 0.3, 0.005, _on_param)
	sb.add_child(_slider_k)

	_chk_arrh = CheckButton.new()
	_chk_arrh.text = "Use Arrhenius (T, Ea)"
	_chk_arrh.toggled.connect(_on_arrhenius)
	sb.add_child(_chk_arrh)

	_out_t = Label.new()
	_out_t.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_t)
	_slider_t = _make_slider(250.0, 400.0, 1.0, _on_param)
	sb.add_child(_slider_t)

	_out_ea = Label.new()
	_out_ea.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_ea)
	_slider_ea = _make_slider(20_000.0, 100_000.0, 1000.0, _on_param)
	sb.add_child(_slider_ea)

	_add_section(sb, "COMPARE (RUN 2)")
	_chk_compare = CheckButton.new()
	_chk_compare.text = "Overlay second series"
	_chk_compare.toggled.connect(_on_compare)
	sb.add_child(_chk_compare)

	_out_t2 = Label.new()
	_out_t2.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_t2)
	_slider_t2 = _make_slider(250.0, 400.0, 1.0, _on_param2)
	sb.add_child(_slider_t2)

	_out_k2 = Label.new()
	_out_k2.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_k2)
	_slider_k2 = _make_slider(0.005, 0.3, 0.005, _on_param2)
	sb.add_child(_slider_k2)

	_add_section(sb, "TIME")
	_btn_play = Button.new()
	_btn_play.text = "Play"
	_btn_play.pressed.connect(_on_play)
	sb.add_child(_btn_play)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var reset := Button.new()
	reset.text = "t = 0"
	reset.theme_type_variation = &"GhostButton"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_on_reset_time)
	row.add_child(reset)
	var step := Button.new()
	step.text = "+0.5 s"
	step.theme_type_variation = &"GhostButton"
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.pressed.connect(_on_step)
	row.add_child(step)
	sb.add_child(row)

	_add_section(sb, "READOUTS")
	_r_a = _stat_row(sb, "[A]₁")
	_r_rate = _stat_row(sb, "Rate₁")
	_r_hl = _stat_row(sb, "t½₁")
	_r_k = _stat_row(sb, "k₁")
	_r_a2 = _stat_row(sb, "[A]₂")
	_r_hl2 = _stat_row(sb, "t½₂")

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: 0/1/2 order · Space play · C compare · R reset · Esc back"
	sb.add_child(_keys_hint)


func _add_section(sb: VBoxContainer, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(3, 16)
	marker.color = Color("#3B82F6")
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
	_time += delta
	var tmax: float = _plot_t_max()
	if _time >= tmax:
		_time = tmax
		_playing = false
		_update_play_btn()
	_refresh_live()


func _on_order(n: int) -> void:
	model.set_order(n)
	_time = 0.0
	_rebuild_series()
	_refresh()


func _on_param(_v: float = 0.0) -> void:
	if _updating:
		return
	model.a0 = _slider_a0.value
	model.k = _slider_k.value
	model.t_kelvin = _slider_t.value
	model.ea = _slider_ea.value
	if model.use_arrhenius:
		model.calibrate_arrhenius()
	_rebuild_series()
	_refresh()


func _on_param2(_v: float = 0.0) -> void:
	if _updating:
		return
	_t2 = _slider_t2.value
	_k2 = _slider_k2.value
	_rebuild_series()
	_refresh()


func _on_arrhenius(pressed: bool) -> void:
	model.use_arrhenius = pressed
	if pressed:
		model.calibrate_arrhenius()
	_rebuild_series()
	_refresh()


func _on_compare(pressed: bool) -> void:
	_compare = pressed
	_rebuild_series()
	_refresh()


func _on_play() -> void:
	_playing = not _playing
	if _playing and _time >= _plot_t_max() - 0.01:
		_time = 0.0
	_update_play_btn()


func _update_play_btn() -> void:
	if _btn_play:
		_btn_play.text = "Pause" if _playing else "Play"


func _on_reset_time() -> void:
	_time = 0.0
	_playing = false
	_update_play_btn()
	_refresh_live()


func _on_step() -> void:
	_time = minf(_time + 0.5, _plot_t_max())
	_refresh_live()


func _k2_eff() -> float:
	if model.use_arrhenius:
		# Same Af, Ea as run 1; different T
		var af: float = model.af
		if af <= 0.0:
			# calibrate from current k at T1 if needed
			model.calibrate_arrhenius()
			af = model.af
		return af * exp(-model.ea / (ReactionRatesModel.R * maxf(_t2, 1.0)))
	return _k2


func _conc_at(t: float, kk: float) -> float:
	t = maxf(t, 0.0)
	var a0: float = model.a0
	match model.order:
		0:
			return maxf(0.0, a0 - kk * t)
		1:
			return a0 * exp(-kk * t)
		2:
			return a0 / (1.0 + kk * a0 * t)
	return a0


func _half_life_k(kk: float) -> float:
	if kk <= 0.0:
		return INF
	match model.order:
		0:
			return model.a0 / (2.0 * kk)
		1:
			return log(2.0) / kk
		2:
			return 1.0 / (kk * model.a0)
	return INF


func _series_for_k(kk: float, tmax: float, n: int = 180) -> Array:
	var out: Array = []
	for i in range(n + 1):
		var t: float = (float(i) / float(n)) * tmax
		out.append({"t": t, "a": _conc_at(t, kk)})
	return out


func _plot_t_max() -> float:
	var hl1: float = model.half_life()
	var hl2: float = _half_life_k(_k2_eff()) if _compare else hl1
	var hl: float = hl1
	if _compare and is_finite(hl2):
		hl = maxf(hl1 if is_finite(hl1) else 0.0, hl2)
	if not is_finite(hl) or hl <= 0.0:
		return 60.0
	return clampf(hl * 4.0, 10.0, 300.0)


func _rebuild_series() -> void:
	var tmax: float = _plot_t_max()
	_series = model.series(tmax, 180)
	if _compare:
		_series2 = _series_for_k(_k2_eff(), tmax, 180)
	else:
		_series2.clear()


func _refresh() -> void:
	if _slider_a0 == null:
		return
	_updating = true
	_slider_a0.value = model.a0
	_slider_k.value = model.k
	_slider_t.value = model.t_kelvin
	_slider_ea.value = model.ea
	_slider_t2.value = _t2
	_slider_k2.value = _k2
	_chk_arrh.button_pressed = model.use_arrhenius
	_chk_compare.button_pressed = _compare
	_updating = false

	_out_a0.text = "[A]0 = %.2f mol/L" % model.a0
	_out_k.text = "k₁ = %.3f %s" % [model.k, model.k_units()]
	_out_t.text = "T₁ = %.0f K" % model.t_kelvin
	_out_ea.text = "Ea = %.0f kJ/mol" % (model.ea / 1000.0)
	_out_t2.text = "T₂ = %.0f K" % _t2
	_out_k2.text = "k₂ = %.3f %s" % [_k2, model.k_units()]

	_slider_t.editable = model.use_arrhenius
	_slider_ea.editable = model.use_arrhenius
	_slider_k.editable = not model.use_arrhenius
	_slider_t.modulate = Color.WHITE if model.use_arrhenius else Color(1, 1, 1, 0.4)
	_slider_ea.modulate = Color.WHITE if model.use_arrhenius else Color(1, 1, 1, 0.4)
	_slider_k.modulate = Color.WHITE if not model.use_arrhenius else Color(1, 1, 1, 0.4)

	# Compare: T2 when Arrhenius, k2 otherwise
	_slider_t2.editable = _compare and model.use_arrhenius
	_slider_k2.editable = _compare and not model.use_arrhenius
	_slider_t2.modulate = Color.WHITE if _slider_t2.editable else Color(1, 1, 1, 0.35)
	_slider_k2.modulate = Color.WHITE if _slider_k2.editable else Color(1, 1, 1, 0.35)
	_out_t2.modulate = Color.WHITE if _compare else Color(1, 1, 1, 0.4)
	_out_k2.modulate = Color.WHITE if _compare else Color(1, 1, 1, 0.4)
	_r_a2.modulate = Color.WHITE if _compare else Color(1, 1, 1, 0.4)
	_r_hl2.modulate = Color.WHITE if _compare else Color(1, 1, 1, 0.4)

	for i in _order_row.get_child_count():
		var b: Button = _order_row.get_child(i) as Button
		if b:
			b.theme_type_variation = &"ChipActive" if i == model.order else &"Chip"

	_refresh_live()


func _refresh_live() -> void:
	var a: float = model.concentration(_time)
	var rate: float = model.rate_at(_time)
	var hl: float = model.half_life()
	var ke: float = model.effective_k()
	_r_a.text = "%.4f mol/L" % a
	_r_rate.text = "%.4f" % rate
	_r_hl.text = ("%.2f s" % hl) if is_finite(hl) else "—"
	_r_k.text = "%s %s" % [_format_significant(ke, 4), model.k_units()]

	if _compare:
		var k2e: float = _k2_eff()
		var a2: float = _conc_at(_time, k2e)
		var hl2: float = _half_life_k(k2e)
		_r_a2.text = "%.4f mol/L" % a2
		_r_hl2.text = ("%.2f s" % hl2) if is_finite(hl2) else "—"
	else:
		_r_a2.text = "—"
		_r_hl2.text = "—"

	var msg: String = "%s · t = %.1f s · [A]₁ = %.4f" % [model.order_name(), _time, a]
	if _compare:
		msg += " · [A]₂ = %.4f" % _conc_at(_time, _k2_eff())
	set_status(msg)
	if _plot:
		_plot.queue_redraw()


func _draw_plot() -> void:
	if _plot == null:
		return
	var c: Control = _plot
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#161616"), true)

	var pad_l: float = 48.0
	var pad_r: float = 16.0
	var pad_t: float = 28.0
	var pad_b: float = 36.0
	var pw: float = w - pad_l - pad_r
	var ph: float = h - pad_t - pad_b
	var tmax: float = _plot_t_max()
	var amax: float = maxf(model.a0, 0.1)

	# Fine instrument grid keeps the concentration trace readable without changing its scale.
	for grid_i in range(1, 5):
		var grid_y: float = pad_t + ph * float(grid_i) / 5.0
		c.draw_line(Vector2(pad_l, grid_y), Vector2(pad_l + pw, grid_y), Color("#78909c", 0.16), 1.0)
		var grid_x: float = pad_l + pw * float(grid_i) / 5.0
		c.draw_line(Vector2(grid_x, pad_t), Vector2(grid_x, pad_t + ph), Color("#78909c", 0.12), 1.0)
	c.draw_line(Vector2(pad_l, pad_t), Vector2(pad_l, pad_t + ph), Color("#546e7a"), 1.0)
	c.draw_line(Vector2(pad_l, pad_t + ph), Vector2(pad_l + pw, pad_t + ph), Color("#546e7a"), 1.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(pad_l, 16), "[A] vs t", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))
	c.draw_string(ThemeDB.fallback_font, Vector2(pad_l + pw * 0.35, h - 12), "t (s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#78909c"))

	# Legend
	c.draw_string(ThemeDB.fallback_font, Vector2(pad_l + pw - 100, 16), "● Run 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#42a5f5"))
	if _compare:
		c.draw_string(ThemeDB.fallback_font, Vector2(pad_l + pw - 100, 30), "● Run 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffb74d"))

	# Series 2 (behind)
	if _compare and _series2.size() >= 2:
		var pts2 := PackedVector2Array()
		for p in _series2:
			pts2.append(Vector2(
				pad_l + float(p.t) / tmax * pw,
				pad_t + ph - float(p.a) / amax * ph
			))
		c.draw_polyline(pts2, Color("#ffb74d"), 2.0, true)
		var hl2: float = _half_life_k(_k2_eff())
		if is_finite(hl2) and hl2 < tmax:
			var hx2: float = pad_l + hl2 / tmax * pw
			c.draw_line(Vector2(hx2, pad_t), Vector2(hx2, pad_t + ph), Color("#ffb74d", 0.4), 1.2)
			c.draw_string(ThemeDB.fallback_font, Vector2(hx2 + 2, pad_t + 28), "t½₂", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffb74d"))

	# Series 1
	if _series.size() >= 2:
		var pts := PackedVector2Array()
		for p in _series:
			pts.append(Vector2(
				pad_l + float(p.t) / tmax * pw,
				pad_t + ph - float(p.a) / amax * ph
			))
		c.draw_polyline(pts, Color("#42a5f5"), 2.0, true)

	var hl: float = model.half_life()
	if is_finite(hl) and hl < tmax:
		var hx: float = pad_l + hl / tmax * pw
		c.draw_line(Vector2(hx, pad_t), Vector2(hx, pad_t + ph), Color("#ffeb3b", 0.55), 1.5)
		c.draw_string(ThemeDB.fallback_font, Vector2(hx + 4, pad_t + 14), "t½₁", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffeb3b"))

	# Time marker + points on both curves
	var tx: float = pad_l + clampf(_time / tmax, 0.0, 1.0) * pw
	var a_now: float = model.concentration(_time)
	var ty: float = pad_t + ph - a_now / amax * ph
	c.draw_line(Vector2(tx, pad_t), Vector2(tx, pad_t + ph), Color("#ef5350", 0.7), 1.5)
	c.draw_circle(Vector2(tx, ty), 5.0, Color("#42a5f5"))
	if _compare:
		var a2: float = _conc_at(_time, _k2_eff())
		var ty2: float = pad_t + ph - a2 / amax * ph
		c.draw_circle(Vector2(tx, ty2), 5.0, Color("#ffb74d"))

	# Concentration bars
	var bx: float = w - 40.0
	var by: float = pad_t + ph
	var bh: float = ph
	var fill: float = clampf(a_now / amax, 0.0, 1.0)
	c.draw_rect(Rect2(bx - 18, pad_t, 14, bh), Color("#263238"), false, 1.5)
	c.draw_rect(Rect2(bx - 16, by - fill * bh, 10, fill * bh), Color("#42a5f5", 0.8), true)
	if _compare:
		var a2b: float = _conc_at(_time, _k2_eff())
		var fill2: float = clampf(a2b / amax, 0.0, 1.0)
		c.draw_rect(Rect2(bx - 2, pad_t, 14, bh), Color("#263238"), false, 1.5)
		c.draw_rect(Rect2(bx, by - fill2 * bh, 10, fill2 * bh), Color("#ffb74d", 0.8), true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_0:
			_on_order(0)
			get_viewport().set_input_as_handled()
		KEY_1:
			_on_order(1)
			get_viewport().set_input_as_handled()
		KEY_2:
			_on_order(2)
			get_viewport().set_input_as_handled()
		KEY_SPACE:
			_on_play()
			get_viewport().set_input_as_handled()
		KEY_C:
			_on_compare(not _compare)
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_reset_time()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()


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
