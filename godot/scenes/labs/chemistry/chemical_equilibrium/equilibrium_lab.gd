extends LabShell
## Chemical equilibrium — Kc solvers, bars, Q vs Kc, Le Chatelier T shifts.

var model: EquilibriumModel = EquilibriumModel.new()

var _stage: Control
var _rxn_opt: OptionButton
var _slider_kc: HSlider
var _slider_v: HSlider
var _slider_t: HSlider
var _out_kc: Label
var _out_v: Label
var _out_t: Label
var _init_sliders: Dictionary = {}  # species -> HSlider
var _init_labels: Dictionary = {}
var _init_box: VBoxContainer
var _r_q: Label
var _r_kc: Label
var _r_xi: Label
var _r_dir: Label
var _r_msg: Label
var _keys_hint: Label

var _updating: bool = false
var _last: Dictionary = {}
var _rxn_keys: Array = ["isom", "addition", "dimer", "haber"]


func _ready() -> void:
	lab_title = "Chemical Equilibrium"
	lab_eyebrow = "CHEMISTRY  /  EQUILIBRIUM"
	lab_lead = "Solve Kc equilibrium. Change V, amounts or T and watch the shift."
	field_id = "chemistry"
	page_id = "chemical_equilibrium"
	back_label = "<- Chemistry"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.reaction = "isom"
	_rebuild_init_controls()
	_solve_and_refresh()
	set_process_unhandled_input(true)
	set_status("Pick a reaction, set Kc and initials, then observe equilibrium.")


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "EqStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		push_error("Equilibrium: sidebar missing")
		return

	_add_section(sb, "REACTION")
	_rxn_opt = OptionButton.new()
	for k in _rxn_keys:
		_rxn_opt.add_item(str(EquilibriumModel.REACTIONS[k]["name"]))
	_rxn_opt.item_selected.connect(_on_rxn)
	sb.add_child(_rxn_opt)

	_add_section(sb, "Kc / VOLUME / T")
	_out_kc = Label.new()
	_out_kc.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_kc)
	_slider_kc = _make_slider(0.01, 100.0, 0.01, _on_param)
	sb.add_child(_slider_kc)

	_out_v = Label.new()
	_out_v.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_v)
	_slider_v = _make_slider(0.25, 5.0, 0.05, _on_param)
	sb.add_child(_slider_v)

	_out_t = Label.new()
	_out_t.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_t)
	_slider_t = _make_slider(200.0, 800.0, 5.0, _on_t_slider)
	sb.add_child(_slider_t)

	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	var cool := Button.new()
	cool.text = "T −50"
	cool.theme_type_variation = &"GhostButton"
	cool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cool.pressed.connect(_on_shift_t.bind(-50.0))
	trow.add_child(cool)
	var heat := Button.new()
	heat.text = "T +50"
	heat.theme_type_variation = &"GhostButton"
	heat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heat.pressed.connect(_on_shift_t.bind(50.0))
	trow.add_child(heat)
	sb.add_child(trow)

	_add_section(sb, "INITIAL MOLES")
	_init_box = VBoxContainer.new()
	_init_box.add_theme_constant_override("separation", 6)
	sb.add_child(_init_box)

	var rst := Button.new()
	rst.text = "Reset initials"
	rst.theme_type_variation = &"GhostButton"
	rst.pressed.connect(_on_reset_init)
	sb.add_child(rst)

	_add_section(sb, "READOUTS")
	_r_q = _stat_row(sb, "Q (initial)")
	_r_kc = _stat_row(sb, "Kc")
	_r_xi = _stat_row(sb, "ξ (extent)")
	_r_dir = _stat_row(sb, "Shift")
	_r_msg = _stat_row(sb, "Status")

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: 1–4 reaction · [ ] Kc · −/+ T · R reset · Esc back"
	sb.add_child(_keys_hint)


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


func _rebuild_init_controls() -> void:
	for c in _init_box.get_children():
		c.queue_free()
	_init_sliders.clear()
	_init_labels.clear()
	var species: Array = model.rxn()["species"]
	for s in species:
		var lab := Label.new()
		lab.theme_type_variation = &"CtlLabel"
		lab.text = "n(%s) = …" % model.label_for(str(s))
		_init_box.add_child(lab)
		_init_labels[s] = lab
		var sl := _make_slider(0.0, 5.0, 0.05, _on_param)
		sl.value = float(model.initial.get(s, 0.0))
		_init_box.add_child(sl)
		_init_sliders[s] = sl


func _on_rxn(idx: int) -> void:
	if idx < 0 or idx >= _rxn_keys.size():
		return
	model.reaction = str(_rxn_keys[idx])
	# Sensible defaults per reaction
	match model.reaction:
		"isom":
			model.Kc = 4.0
			model.initial = {"A": 1.0, "B": 0.0, "C": 0.0, "N2": 1.0, "H2": 3.0, "NH3": 0.0}
		"addition":
			model.Kc = 2.0
			model.initial = {"A": 1.0, "B": 1.0, "C": 0.0, "N2": 1.0, "H2": 3.0, "NH3": 0.0}
		"dimer":
			model.Kc = 0.5
			model.initial = {"A": 2.0, "B": 0.0, "C": 0.0, "N2": 1.0, "H2": 3.0, "NH3": 0.0}
		"haber":
			model.Kc = 0.5
			model.initial = {"A": 1.0, "B": 0.0, "C": 0.0, "N2": 1.0, "H2": 3.0, "NH3": 0.0}
	_rebuild_init_controls()
	_solve_and_refresh()


func _on_param(_v: float = 0.0) -> void:
	if _updating:
		return
	model.Kc = _slider_kc.value
	model.V = _slider_v.value
	for s in _init_sliders.keys():
		model.initial[s] = _init_sliders[s].value
	_solve_and_refresh()


func _on_t_slider(_v: float = 0.0) -> void:
	if _updating:
		return
	var old_t: float = model.T
	model.T = _slider_t.value
	# Apply Le Chatelier-style Kc shift relative to previous T
	var delta: float = model.T - old_t
	if absf(delta) > 0.5:
		# shift_temperature also changes T; restore our slider T after
		var target_t: float = model.T
		model.T = old_t
		model.shift_temperature(delta)
		model.T = target_t
	_solve_and_refresh()


func _on_shift_t(delta: float) -> void:
	model.shift_temperature(delta)
	_solve_and_refresh()


func _on_reset_init() -> void:
	_on_rxn(_rxn_keys.find(model.reaction) if model.reaction in _rxn_keys else 0)


func _solve_and_refresh() -> void:
	_last = model.solve()
	_refresh_ui()


func _refresh_ui() -> void:
	if _slider_kc == null:
		return
	_updating = true
	_slider_kc.value = model.Kc
	_slider_v.value = model.V
	_slider_t.value = model.T
	for s in _init_sliders.keys():
		_init_sliders[s].value = float(model.initial.get(s, 0.0))
		if _init_labels.has(s):
			_init_labels[s].text = "n(%s) = %.2f mol" % [model.label_for(str(s)), float(model.initial.get(s, 0.0))]
	_updating = false

	_out_kc.text = "Kc = %s" % _format_significant(model.Kc, 3)
	_out_v.text = "V = %.2f L" % model.V
	_out_t.text = "T = %.0f K (%s)" % [
		model.T,
		"endo" if str(model.rxn().get("thermo", "")) == "endo" else "exo"
	]

	var ok: bool = bool(_last.get("ok", false))
	_r_kc.text = _format_significant(float(_last.get("Kc", model.Kc)), 4)
	_r_q.text = _fmt_q(float(_last.get("Q", 0.0)))
	_r_xi.text = "%.4f" % float(_last.get("xi", 0.0))
	_r_msg.text = str(_last.get("message", ""))

	var q: float = float(_last.get("Q", 0.0))
	var kc: float = float(_last.get("Kc", model.Kc))
	if not ok:
		_r_dir.text = "—"
	elif not is_finite(q):
		_r_dir.text = "Q large → reverse"
	elif q < kc * 0.98:
		_r_dir.text = "Q < Kc → forward"
	elif q > kc * 1.02:
		_r_dir.text = "Q > Kc → reverse"
	else:
		_r_dir.text = "Q ≈ Kc (at eq.)"

	var rxn_name: String = str(model.rxn().get("name", ""))
	set_status("%s · Kc=%s · V=%.2f L · %s" % [rxn_name, _format_significant(model.Kc, 3), model.V, _r_dir.text])
	if _stage:
		_stage.queue_redraw()


func _fmt_q(q: float) -> String:
	if not is_finite(q):
		return "∞"
	if q > 1e4 or (q > 0.0 and q < 1e-3):
		return _format_scientific(q, 3)
	return _format_significant(q, 4)


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


func _draw_stage() -> void:
	if _stage == null:
		return
	var c: Control = _stage
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#161616"), true)

	var species: Array = model.rxn()["species"]
	var conc0: Dictionary = _last.get("initialConc", {})
	var conc: Dictionary = _last.get("conc", {})
	if conc.is_empty():
		c.draw_string(ThemeDB.fallback_font, Vector2(24, 40), "No solution yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#90a4ae"))
		return

	# Title
	c.draw_string(ThemeDB.fallback_font, Vector2(20, 24), str(model.rxn().get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#eceff1"))
	c.draw_string(ThemeDB.fallback_font, Vector2(20, 44), "Kc expr: %s" % str(model.rxn().get("KcExpr", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#90a4ae"))

	# Find max concentration for scale
	var cmax: float = 0.05
	for s in species:
		cmax = maxf(cmax, maxf(float(conc0.get(s, 0.0)), float(conc.get(s, 0.0))))

	var n: int = species.size()
	var gap: float = 16.0
	var group_w: float = (w - 40.0 - gap * float(n - 1)) / float(n)
	var bar_w: float = group_w * 0.38
	var base_y: float = h * 0.82
	var max_h: float = h * 0.48

	for i in n:
		var s: String = str(species[i])
		var gx: float = 20.0 + float(i) * (group_w + gap)
		var c_i: float = float(conc0.get(s, 0.0))
		var c_e: float = float(conc.get(s, 0.0))
		var h_i: float = (c_i / cmax) * max_h
		var h_e: float = (c_e / cmax) * max_h
		# Initial (grey)
		c.draw_rect(Rect2(gx, base_y - h_i, bar_w, h_i), Color("#78909c"), true)
		# Equilibrium (firebrick / blue)
		var eq_col := Color("#ef5350") if c_e >= c_i - 1e-9 else Color("#42a5f5")
		c.draw_rect(Rect2(gx + bar_w + 6.0, base_y - h_e, bar_w, h_e), eq_col, true)
		# Labels
		c.draw_string(ThemeDB.fallback_font, Vector2(gx, base_y + 18), model.label_for(s), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#cfd8dc"))
		c.draw_string(ThemeDB.fallback_font, Vector2(gx, base_y + 34), "i %.3f" % c_i, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#90a4ae"))
		c.draw_string(ThemeDB.fallback_font, Vector2(gx, base_y + 48), "eq %.3f" % c_e, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#eceff1"))

	# Legend
	c.draw_rect(Rect2(20, h - 28, 14, 14), Color("#78909c"), true)
	c.draw_string(ThemeDB.fallback_font, Vector2(40, h - 16), "Initial [ ]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))
	c.draw_rect(Rect2(140, h - 28, 14, 14), Color("#ef5350"), true)
	c.draw_string(ThemeDB.fallback_font, Vector2(160, h - 16), "Eq (↑ or same)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))
	c.draw_rect(Rect2(290, h - 28, 14, 14), Color("#42a5f5"), true)
	c.draw_string(ThemeDB.fallback_font, Vector2(310, h - 16), "Eq (↓)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	# Q vs Kc strip
	var q: float = float(_last.get("Q", 0.0))
	var kc: float = float(_last.get("Kc", model.Kc))
	c.draw_string(ThemeDB.fallback_font, Vector2(w * 0.55, 24), "Q vs Kc", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))
	var strip_x: float = w * 0.55
	var strip_y: float = 50.0
	var strip_w: float = w * 0.4
	c.draw_rect(Rect2(strip_x, strip_y, strip_w, 18), Color("#37474f"), true)
	# Map log scale roughly
	var log_q: float = 0.0
	var log_k: float = 0.0
	if is_finite(q) and q > 0.0:
		log_q = log(q) / log(10.0)
	if kc > 0.0:
		log_k = log(kc) / log(10.0)
	var lo: float = minf(log_q, log_k) - 1.0
	var hi: float = maxf(log_q, log_k) + 1.0
	var span: float = maxf(hi - lo, 0.5)
	var px_q: float = strip_x + clampf((log_q - lo) / span, 0.0, 1.0) * strip_w
	var px_k: float = strip_x + clampf((log_k - lo) / span, 0.0, 1.0) * strip_w
	c.draw_line(Vector2(px_k, strip_y - 4), Vector2(px_k, strip_y + 22), Color("#ffeb3b"), 2.0)
	if is_finite(q):
		c.draw_circle(Vector2(px_q, strip_y + 9), 6.0, Color("#ef5350"))
	c.draw_string(ThemeDB.fallback_font, Vector2(strip_x, strip_y + 36), "Kc", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffeb3b"))
	c.draw_string(ThemeDB.fallback_font, Vector2(strip_x + 40, strip_y + 36), "Q (initial)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ef5350"))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_1:
			_rxn_opt.select(0)
			_on_rxn(0)
			get_viewport().set_input_as_handled()
		KEY_2:
			_rxn_opt.select(1)
			_on_rxn(1)
			get_viewport().set_input_as_handled()
		KEY_3:
			_rxn_opt.select(2)
			_on_rxn(2)
			get_viewport().set_input_as_handled()
		KEY_4:
			_rxn_opt.select(3)
			_on_rxn(3)
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT, KEY_MINUS:
			model.Kc = clampf(model.Kc / 1.2, 0.01, 100.0)
			_solve_and_refresh()
			get_viewport().set_input_as_handled()
		KEY_BRACKETRIGHT, KEY_EQUAL:
			model.Kc = clampf(model.Kc * 1.2, 0.01, 100.0)
			_solve_and_refresh()
			get_viewport().set_input_as_handled()
		KEY_COMMA:
			_on_shift_t(-50.0)
			get_viewport().set_input_as_handled()
		KEY_PERIOD:
			_on_shift_t(50.0)
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_reset_init()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
