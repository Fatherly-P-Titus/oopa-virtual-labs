extends LabShell
## Two-source interference — field, screen graph, intensity mode, single/double, slow-mo.

var model: WaveModel = WaveModel.new()

var _stage: Control
var _slider_lam: HSlider
var _slider_freq: HSlider
var _slider_sep: HSlider
var _slider_a1: HSlider
var _slider_a2: HSlider
var _slider_ph: HSlider
var _slider_screen: HSlider
var _out_lam: Label
var _out_freq: Label
var _out_sep: Label
var _out_a1: Label
var _out_a2: Label
var _out_ph: Label
var _out_screen: Label
var _chk_double: CheckButton
var _chk_avg: CheckButton
var _chk_graph: CheckButton
var _btn_play: Button
var _speed_row: HBoxContainer
var _r_v: Label
var _r_k: Label
var _r_w: Label
var _r_dy: Label
var _r_probe: Label
var _keys_hint: Label

var _updating: bool = false
var _show_graph: bool = true
var _probe: Vector2 = Vector2(-1, -1)
var _field_img: Image
var _field_tex: ImageTexture
var _field_w: int = 140
var _field_h: int = 105
var _dirty: bool = true
var _accum: float = 0.0

# Layout from last draw (for click mapping)
var _ox: float = 0.0
var _oy: float = 0.0
var _bw: float = 0.0
var _bh: float = 0.0
var _scale: float = 1.0

const PRESETS: Array = [
	{"name": "In phase", "lam": 40.0, "freq": 1.0, "sep": 80.0, "a1": 1.0, "a2": 1.0, "ph": 0.0, "dbl": true},
	{"name": "Out of phase", "lam": 40.0, "freq": 1.0, "sep": 80.0, "a1": 1.0, "a2": 1.0, "ph": 3.14159, "dbl": true},
	{"name": "Single source", "lam": 40.0, "freq": 1.0, "sep": 80.0, "a1": 1.0, "a2": 0.0, "ph": 0.0, "dbl": false},
	{"name": "Wide sep", "lam": 35.0, "freq": 1.2, "sep": 140.0, "a1": 1.0, "a2": 1.0, "ph": 0.0, "dbl": true},
]


func _ready() -> void:
	lab_title = "Wave Interference"
	lab_eyebrow = "PHYSICS  /  WAVE INTERFERENCE"
	lab_lead = "Two coherent sources — field, screen intensity, single/double, slow motion."
	field_id = "physics"
	page_id = "wave_interference"
	back_label = "<- Physics"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.set_wavelength(40.0)
	model.set_freq(1.0)
	model.sep = 80.0
	model.screen_x = 360.0
	_field_img = Image.create(_field_w, _field_h, false, Image.FORMAT_RGB8)
	_field_tex = ImageTexture.create_from_image(_field_img)
	_rebuild_field()
	_refresh_ui()
	set_process(true)
	set_process_unhandled_input(true)
	set_status("Toggle graph for screen I(y). Click field to probe.")


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "WaveStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "PRESETS")
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 4)
	sb.add_child(pr)
	var pr2 := HBoxContainer.new()
	pr2.add_theme_constant_override("separation", 4)
	sb.add_child(pr2)
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		var b := Button.new()
		b.text = str(p["name"])
		b.theme_type_variation = &"Chip"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		b.pressed.connect(_on_preset.bind(idx))
		if i < 2:
			pr.add_child(b)
		else:
			pr2.add_child(b)

	_add_section(sb, "WAVE")
	_out_lam = Label.new()
	_out_lam.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_lam)
	_slider_lam = _make_slider(15.0, 100.0, 1.0, _on_lam)
	sb.add_child(_slider_lam)
	_out_freq = Label.new()
	_out_freq.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_freq)
	_slider_freq = _make_slider(0.3, 3.0, 0.05, _on_freq)
	sb.add_child(_slider_freq)
	_out_sep = Label.new()
	_out_sep.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_sep)
	_slider_sep = _make_slider(20.0, 160.0, 2.0, _on_sep)
	sb.add_child(_slider_sep)

	_add_section(sb, "SOURCES")
	_chk_double = CheckButton.new()
	_chk_double.text = "Double source (S1 + S2)"
	_chk_double.button_pressed = true
	_chk_double.toggled.connect(_on_double)
	sb.add_child(_chk_double)
	_out_a1 = Label.new()
	_out_a1.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_a1)
	_slider_a1 = _make_slider(0.0, 1.5, 0.05, _on_amp)
	sb.add_child(_slider_a1)
	_out_a2 = Label.new()
	_out_a2.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_a2)
	_slider_a2 = _make_slider(0.0, 1.5, 0.05, _on_amp)
	sb.add_child(_slider_a2)
	_out_ph = Label.new()
	_out_ph.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_ph)
	_slider_ph = _make_slider(0.0, 6.28, 0.05, _on_phase)
	sb.add_child(_slider_ph)

	_add_section(sb, "DISPLAY")
	_chk_avg = CheckButton.new()
	_chk_avg.text = "Time-average intensity"
	_chk_avg.toggled.connect(_on_avg)
	sb.add_child(_chk_avg)
	_chk_graph = CheckButton.new()
	_chk_graph.text = "Show screen graph"
	_chk_graph.button_pressed = true
	_chk_graph.toggled.connect(_on_graph)
	sb.add_child(_chk_graph)
	_out_screen = Label.new()
	_out_screen.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_screen)
	_slider_screen = _make_slider(200.0, 390.0, 5.0, _on_screen)
	sb.add_child(_slider_screen)

	_add_section(sb, "TIME")
	_btn_play = Button.new()
	_btn_play.text = "Pause"
	_btn_play.pressed.connect(_on_play)
	sb.add_child(_btn_play)
	_speed_row = HBoxContainer.new()
	_speed_row.add_theme_constant_override("separation", 4)
	sb.add_child(_speed_row)
	for item in [["0.25×", 0.25], ["0.5×", 0.5], ["1×", 1.0]]:
		var sb_btn := Button.new()
		sb_btn.text = str(item[0])
		sb_btn.theme_type_variation = &"Chip"
		sb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sc: float = float(item[1])
		sb_btn.pressed.connect(_on_speed.bind(sc))
		_speed_row.add_child(sb_btn)

	_add_section(sb, "READOUTS")
	_r_v = _stat_row(sb, "Speed v")
	_r_k = _stat_row(sb, "k = 2π/λ")
	_r_w = _stat_row(sb, "ω = 2πf")
	_r_dy = _stat_row(sb, "Δy ≈ λL/d")
	_r_probe = _stat_row(sb, "Probe")

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: Space pause · click field · Esc back"
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
	model.step(delta)
	_accum += delta
	var interval: float = 0.08 if model.time_average else 0.06
	if _accum >= interval or _dirty:
		_accum = 0.0
		_dirty = false
		_rebuild_field()
	_refresh_readouts()
	if _stage:
		_stage.queue_redraw()


func _rebuild_field() -> void:
	if _field_img == null:
		return
	for j in _field_h:
		for i in _field_w:
			var wx: float = (float(i) + 0.5) / float(_field_w) * model.box_w
			var wy: float = (float(j) + 0.5) / float(_field_h) * model.box_h
			var val: float = model.sample_at(Vector2(wx, wy))
			var col: Color
			if model.time_average:
				# Brightness map
				var n: float = clampf(val * 0.08, 0.0, 1.0)
				col = Color(n, n * 0.85, 0.2 + n * 0.3)
			else:
				var n2: float = clampf(val * 0.35, -1.0, 1.0)
				if n2 >= 0.0:
					col = Color(n2, n2 * 0.2, 0.1)
				else:
					col = Color(0.1, 0.25 * (-n2), -n2)
			_field_img.set_pixel(i, j, col)
	_field_tex = ImageTexture.create_from_image(_field_img)


func _on_preset(idx: int) -> void:
	if idx < 0 or idx >= PRESETS.size():
		return
	var p: Dictionary = PRESETS[idx]
	model.set_wavelength(float(p["lam"]))
	model.set_freq(float(p["freq"]))
	model.sep = float(p["sep"])
	model.amp1 = float(p["a1"])
	model.amp2 = float(p["a2"])
	model.phase2 = float(p["ph"])
	model.double_source = bool(p["dbl"])
	_dirty = true
	_refresh_ui()
	set_status("Preset: %s" % str(p["name"]))


func _on_lam(v: float) -> void:
	if _updating:
		return
	model.set_wavelength(v)
	_dirty = true
	_refresh_ui()


func _on_freq(v: float) -> void:
	if _updating:
		return
	model.set_freq(v)
	_dirty = true
	_refresh_ui()


func _on_sep(v: float) -> void:
	if _updating:
		return
	model.sep = v
	_dirty = true
	_refresh_ui()


func _on_amp(_v: float = 0.0) -> void:
	if _updating:
		return
	model.amp1 = _slider_a1.value
	model.amp2 = _slider_a2.value
	_dirty = true
	_refresh_ui()


func _on_phase(v: float) -> void:
	if _updating:
		return
	model.phase2 = v
	_dirty = true
	_refresh_ui()


func _on_screen(v: float) -> void:
	if _updating:
		return
	model.screen_x = v
	_dirty = true
	_refresh_ui()


func _on_double(pressed: bool) -> void:
	model.double_source = pressed
	_dirty = true
	_refresh_ui()


func _on_avg(pressed: bool) -> void:
	model.time_average = pressed
	_dirty = true
	_refresh_ui()


func _on_graph(pressed: bool) -> void:
	_show_graph = pressed
	if _stage:
		_stage.queue_redraw()


func _on_speed(sc: float) -> void:
	model.time_scale = sc
	for i in _speed_row.get_child_count():
		var b: Button = _speed_row.get_child(i) as Button
		if b == null:
			continue
		var vals: Array = [0.25, 0.5, 1.0]
		b.theme_type_variation = &"ChipActive" if is_equal_approx(vals[i], sc) else &"Chip"
	set_status("Time scale %.2f×" % sc)


func _on_play() -> void:
	model.playing = not model.playing
	_btn_play.text = "Pause" if model.playing else "Play"


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _bw < 1.0:
			return
		var lx: float = (event.position.x - _ox) / _scale
		var ly: float = (event.position.y - _oy) / _scale
		if lx >= 0.0 and ly >= 0.0 and lx <= model.box_w and ly <= model.box_h:
			_probe = Vector2(lx, ly)
		else:
			_probe = Vector2(-1, -1)
		_stage.accept_event()
		_refresh_readouts()
		_stage.queue_redraw()


func _refresh_ui() -> void:
	if _slider_lam == null:
		return
	_updating = true
	_slider_lam.value = model.wavelength
	_slider_freq.value = model.freq
	_slider_sep.value = model.sep
	_slider_a1.value = model.amp1
	_slider_a2.value = model.amp2
	_slider_ph.value = model.phase2
	_slider_screen.value = model.screen_x
	_chk_double.button_pressed = model.double_source
	_chk_avg.button_pressed = model.time_average
	_chk_graph.button_pressed = _show_graph
	_updating = false
	_out_lam.text = "Wavelength λ = %.0f" % model.wavelength
	_out_freq.text = "Frequency f = %.2f Hz" % model.freq
	_out_sep.text = "Separation d = %.0f" % model.sep
	_out_a1.text = "Amplitude A1 = %.2f" % model.amp1
	_out_a2.text = "Amplitude A2 = %.2f" % model.amp2
	_out_ph.text = "Phase φ2 = %.2f rad" % model.phase2
	_out_screen.text = "Screen x = %.0f" % model.screen_x
	_slider_a2.editable = model.double_source
	_slider_ph.editable = model.double_source
	_slider_a2.modulate = Color.WHITE if model.double_source else Color(1, 1, 1, 0.35)
	_slider_ph.modulate = Color.WHITE if model.double_source else Color(1, 1, 1, 0.35)
	_refresh_readouts()


func _refresh_readouts() -> void:
	if _r_v == null:
		return
	_r_v.text = "%.1f" % model.speed
	_r_k.text = "%.3f" % model.k()
	_r_w.text = "%.2f" % model.omega()
	_r_dy.text = "%.1f" % model.theoretical_fringe_spacing()
	if _probe.x >= 0.0:
		var delta: float = model.path_diff_at(_probe)
		var m: float = model.fringe_order(_probe)
		var kind: String = ""
		if model.double_source:
			var frac: float = absf(m - roundf(m))
			if frac < 0.12:
				kind = " ~ constructive"
			elif absf(frac - 0.5) < 0.12:
				kind = " ~ destructive"
		_r_probe.text = "δ=%.1f m≈%.2f%s" % [delta, m, kind]
	else:
		_r_probe.text = "click field"
	var mode_s: String = "⟨I⟩" if model.time_average else "instant"
	var src_s: String = "double" if model.double_source else "single"
	set_status("%s · %s · λ=%.0f · d=%.0f · %.2f×" % [mode_s, src_s, model.wavelength, model.sep, model.time_scale])


func _draw_stage() -> void:
	if _stage == null:
		return
	var c: Control = _stage
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#0d1b2a"), true)

	var graph_h: float = 0.0
	if _show_graph:
		graph_h = minf(h * 0.28, 110.0)
	var top_h: float = h - graph_h - (8.0 if _show_graph else 0.0)

	var margin: float = 16.0
	_scale = minf((w - 2.0 * margin) / model.box_w, (top_h - 2.0 * margin) / model.box_h)
	_bw = model.box_w * _scale
	_bh = model.box_h * _scale
	_ox = (w - _bw) * 0.5
	_oy = (top_h - _bh) * 0.5 + 4.0

	if _field_tex:
		c.draw_texture_rect(_field_tex, Rect2(_ox, _oy, _bw, _bh), false)
	c.draw_rect(Rect2(_ox, _oy, _bw, _bh), Color("#b22222"), false, 2.0)

	# Screen / detector line
	var sx: float = _ox + model.screen_x * _scale
	c.draw_line(Vector2(sx, _oy), Vector2(sx, _oy + _bh), Color("#66bb6a"), 2.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(sx + 4.0, _oy + 12.0), "screen", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#66bb6a"))

	# Wavelength scale bar (bottom-left of field)
	var bar_len: float = model.wavelength * _scale
	var bar_x: float = _ox + 10.0
	var bar_y: float = _oy + _bh - 16.0
	c.draw_line(Vector2(bar_x, bar_y), Vector2(bar_x + bar_len, bar_y), Color.WHITE, 2.0)
	c.draw_line(Vector2(bar_x, bar_y - 4.0), Vector2(bar_x, bar_y + 4.0), Color.WHITE, 2.0)
	c.draw_line(Vector2(bar_x + bar_len, bar_y - 4.0), Vector2(bar_x + bar_len, bar_y + 4.0), Color.WHITE, 2.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(bar_x, bar_y - 6.0), "1 λ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

	# Sources
	var max_s: int = 2 if model.double_source else 1
	for s in range(1, max_s + 1):
		var sp: Vector2 = model.source_pos(s)
		var sc: Vector2 = Vector2(_ox + sp.x * _scale, _oy + sp.y * _scale)
		# Coherent wavefront guides use the configured wavelength and source position.
		for front_i in range(1, 3):
			var front_r: float = model.wavelength * _scale * float(front_i)
			if front_r < minf(_bw, _bh) * 0.48:
				c.draw_arc(sc, front_r, 0.0, TAU, 48, Color("#ffeb3b", 0.16), 1.2, true)
		c.draw_circle(sc, 9.0, Color("#5d4d16"))
		c.draw_circle(sc, 6.0, Color("#ffeb3b"))
		c.draw_circle(sc, 6.0, Color.WHITE, false, 1.5)
		c.draw_string(ThemeDB.fallback_font, Vector2(sc.x - 4.0, sc.y - 12.0), "S%d" % s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffeb3b"))

	# Probe
	if _probe.x >= 0.0:
		var pp := Vector2(_ox + _probe.x * _scale, _oy + _probe.y * _scale)
		c.draw_circle(pp, 5.0, Color("#66bb6a"))
		c.draw_arc(pp, 10.0, 0.0, TAU, 24, Color("#66bb6a"), 1.5, true)
		for s in range(1, max_s + 1):
			var sp2: Vector2 = model.source_pos(s)
			c.draw_line(Vector2(_ox + sp2.x * _scale, _oy + sp2.y * _scale), pp, Color(0.4, 0.9, 0.5, 0.45), 1.0)

	var mode_lbl: String = "Time-average ⟨I⟩" if model.time_average else "Instantaneous field"
	c.draw_string(ThemeDB.fallback_font, Vector2(_ox, _oy - 8.0), mode_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	# --- Collapsible screen graph ---
	if _show_graph:
		var gy: float = top_h + 4.0
		var gh: float = graph_h - 8.0
		var gx: float = _ox
		var gw: float = _bw
		c.draw_rect(Rect2(gx, gy, gw, gh), Color("#1a1a1a"), true)
		c.draw_rect(Rect2(gx, gy, gw, gh), Color("#37474f"), false, 1.0)
		c.draw_string(ThemeDB.fallback_font, Vector2(gx + 6.0, gy + 12.0), "Screen intensity I(y)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))
		var profile: PackedFloat32Array = model.screen_intensity_profile(64)
		var pmax: float = 0.01
		for v in profile:
			pmax = maxf(pmax, v)
		var n: int = profile.size()
		var pts := PackedVector2Array()
		for i in n:
			var py: float = gy + 16.0 + (float(i) + 0.5) / float(n) * (gh - 24.0)
			var px: float = gx + 8.0 + (profile[i] / pmax) * (gw - 20.0)
			pts.append(Vector2(px, py))
		if pts.size() >= 2:
			c.draw_polyline(pts, Color("#66bb6a"), 2.0, true)
		# y labels
		c.draw_string(ThemeDB.fallback_font, Vector2(gx + gw - 40.0, gy + 20.0), "top", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#78909c"))
		c.draw_string(ThemeDB.fallback_font, Vector2(gx + gw - 50.0, gy + gh - 6.0), "bottom", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#78909c"))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_SPACE:
			_on_play()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
