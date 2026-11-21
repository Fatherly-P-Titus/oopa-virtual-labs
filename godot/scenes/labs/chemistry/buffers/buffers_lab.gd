extends LabShell
## Acid-base strength and buffers on LabShell.

var model: BuffersModel = BuffersModel.new()

var _stage: Control
var _mode_row: HBoxContainer
var _acid_opt: OptionButton
var _slider_ha: HSlider
var _slider_a: HSlider
var _slider_strong: HSlider
var _slider_add_a: HSlider
var _slider_add_b: HSlider
var _out_ha: Label
var _out_a: Label
var _out_strong: Label
var _out_add_a: Label
var _out_add_b: Label
var _chk_strong_acid: CheckButton
var _r_ph: Label
var _r_poh: Label
var _r_pka: Label
var _r_ha: Label
var _r_a: Label
var _r_note: Label
var _keys_hint: Label

var _updating: bool = false
var _acid_keys: Array = ["acetic", "formic", "benzoic", "hydrofluoric", "hypochlorous"]
var _last: Dictionary = {}


func _ready() -> void:
	lab_title = "Acid-Base / Buffers"
	lab_eyebrow = "CHEMISTRY  /  BUFFERS"
	lab_lead = "Weak acid quadratic, buffer (Henderson-Hasselbalch), strong acid/base."
	field_id = "chemistry"
	page_id = "buffers"
	back_label = "<- Chemistry"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.mode = BuffersModel.Mode.BUFFER
	_refresh()
	set_process_unhandled_input(true)
	set_status("Adjust concentrations and watch pH on the scale.")


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "BufferStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))


func _build_sidebar() -> void:
	var sb := get_sidebar()
	if sb == null:
		push_error("Buffers: sidebar missing")
		return

	_add_section(sb, "MODE")
	_mode_row = HBoxContainer.new()
	_mode_row.add_theme_constant_override("separation", 6)
	sb.add_child(_mode_row)
	var modes: Array = [
		["Weak", BuffersModel.Mode.WEAK],
		["Buffer", BuffersModel.Mode.BUFFER],
		["Strong", BuffersModel.Mode.STRONG],
	]
	for item in modes:
		var b := Button.new()
		b.text = str(item[0])
		b.theme_type_variation = &"Chip"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m: int = item[1]
		b.pressed.connect(_on_mode.bind(m))
		_mode_row.add_child(b)

	_add_section(sb, "ACID")
	_acid_opt = OptionButton.new()
	for k in _acid_keys:
		_acid_opt.add_item(str(BuffersModel.ACIDS[k]["name"]))
	_acid_opt.item_selected.connect(_on_acid)
	sb.add_child(_acid_opt)

	_add_section(sb, "CONCENTRATIONS")
	_out_ha = Label.new()
	_out_ha.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_ha)
	_slider_ha = _make_slider(0.01, 1.0, 0.01, _on_param)
	sb.add_child(_slider_ha)

	_out_a = Label.new()
	_out_a.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_a)
	_slider_a = _make_slider(0.0, 1.0, 0.01, _on_param)
	sb.add_child(_slider_a)

	_out_strong = Label.new()
	_out_strong.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_strong)
	_slider_strong = _make_slider(0.001, 1.0, 0.001, _on_param)
	sb.add_child(_slider_strong)

	_chk_strong_acid = CheckButton.new()
	_chk_strong_acid.text = "Strong is acid (off = base)"
	_chk_strong_acid.button_pressed = true
	_chk_strong_acid.toggled.connect(_on_strong_kind)
	sb.add_child(_chk_strong_acid)

	_add_section(sb, "PERTURB BUFFER")
	_out_add_a = Label.new()
	_out_add_a.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_add_a)
	_slider_add_a = _make_slider(0.0, 0.25, 0.005, _on_param)
	sb.add_child(_slider_add_a)

	_out_add_b = Label.new()
	_out_add_b.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_add_b)
	_slider_add_b = _make_slider(0.0, 0.25, 0.005, _on_param)
	sb.add_child(_slider_add_b)

	var rst := Button.new()
	rst.text = "Reset perturbations"
	rst.theme_type_variation = &"GhostButton"
	rst.pressed.connect(_on_reset_pert)
	sb.add_child(rst)

	_add_section(sb, "READOUTS")
	_r_ph = _stat_row(sb, "pH")
	_r_poh = _stat_row(sb, "pOH")
	_r_pka = _stat_row(sb, "pKa")
	_r_ha = _stat_row(sb, "[HA]")
	_r_a = _stat_row(sb, "[A-]")
	_r_note = _stat_row(sb, "Note")

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: 1 Weak · 2 Buffer · 3 Strong · R reset pert. · Esc back"
	sb.add_child(_keys_hint)


func _add_section(sb: VBoxContainer, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"PanelTitle"
	l.uppercase = true
	sb.add_child(l)


func _make_slider(mn: float, mx: float, step: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value_changed.connect(cb)
	return s


func _stat_row(sb: VBoxContainer, key: String) -> Label:
	var row := HBoxContainer.new()
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
	sb.add_child(row)
	return v


func _on_mode(m: int) -> void:
	model.mode = m as BuffersModel.Mode
	_refresh()


func _on_acid(idx: int) -> void:
	if idx < 0 or idx >= _acid_keys.size():
		return
	model.set_acid(str(_acid_keys[idx]))
	_refresh()


func _on_param(_v: float = 0.0) -> void:
	if _updating:
		return
	model.c_ha = _slider_ha.value
	model.c_a = _slider_a.value
	model.c_strong = _slider_strong.value
	model.add_acid = _slider_add_a.value
	model.add_base = _slider_add_b.value
	_refresh()


func _on_strong_kind(pressed: bool) -> void:
	model.strong_is_acid = pressed
	_refresh()


func _on_reset_pert() -> void:
	model.add_acid = 0.0
	model.add_base = 0.0
	_refresh()


func _refresh() -> void:
	if _slider_ha == null:
		return
	_updating = true
	_slider_ha.value = model.c_ha
	_slider_a.value = model.c_a
	_slider_strong.value = model.c_strong
	_slider_add_a.value = model.add_acid
	_slider_add_b.value = model.add_base
	_chk_strong_acid.button_pressed = model.strong_is_acid
	_updating = false

	_out_ha.text = "c(HA) = %.3f M" % model.c_ha
	_out_a.text = "c(A-) = %.3f M" % model.c_a
	_out_strong.text = "c(strong) = %.3f M" % model.c_strong
	_out_add_a.text = "Add strong acid = %.3f M" % model.add_acid
	_out_add_b.text = "Add strong base = %.3f M" % model.add_base

	# Mode chips
	for i in _mode_row.get_child_count():
		var b: Button = _mode_row.get_child(i) as Button
		if b:
			b.theme_type_variation = &"ChipActive" if i == int(model.mode) else &"Chip"

	# Enable relevant sliders
	var is_buf: bool = model.mode == BuffersModel.Mode.BUFFER
	var is_weak: bool = model.mode == BuffersModel.Mode.WEAK
	var is_strong: bool = model.mode == BuffersModel.Mode.STRONG
	_slider_ha.editable = is_weak or is_buf
	_slider_a.editable = is_buf
	_slider_strong.editable = is_strong
	_slider_add_a.editable = is_buf
	_slider_add_b.editable = is_buf
	_chk_strong_acid.visible = is_strong
	_slider_ha.modulate = Color.WHITE if _slider_ha.editable else Color(1, 1, 1, 0.4)
	_slider_a.modulate = Color.WHITE if _slider_a.editable else Color(1, 1, 1, 0.4)
	_slider_strong.modulate = Color.WHITE if _slider_strong.editable else Color(1, 1, 1, 0.4)
	_slider_add_a.modulate = Color.WHITE if _slider_add_a.editable else Color(1, 1, 1, 0.4)
	_slider_add_b.modulate = Color.WHITE if _slider_add_b.editable else Color(1, 1, 1, 0.4)

	_last = model.solve()
	_r_ph.text = "%.2f" % float(_last.pH)
	_r_poh.text = "%.2f" % float(_last.pOH)
	_r_pka.text = "%.2f" % float(_last.pKa)
	var extra: Dictionary = _last.get("extra", {})
	_r_ha.text = "%.4f" % float(extra.get("HA", 0.0))
	_r_a.text = "%.4f" % float(extra.get("A", 0.0))
	if bool(extra.get("broken", false)):
		_r_note.text = "Buffer broken"
	else:
		_r_note.text = str(_last.get("acid_name", ""))

	var mode_name: String = ["Weak acid", "Buffer", "Strong"][int(model.mode)]
	set_status("%s · pH %.2f · pKa %.2f · %s" % [mode_name, float(_last.pH), float(_last.pKa), model.acid_formula()])
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
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#161616"), true)

	var ph: float = float(_last.get("pH", 7.0)) if not _last.is_empty() else float(model.solve().get("pH", 7.0))
	var pka: float = float(_last.get("pKa", model.pKa())) if not _last.is_empty() else float(model.pKa())

	# --- pH scale ---
	var pad: float = 48.0
	var bar_y: float = h * 0.22
	var bar_h: float = 36.0
	var bar_w: float = w - 2.0 * pad
	for i in 140:
		var t: float = float(i) / 140.0
		var col: Color = Color.from_hsv(0.72 - t * 0.72, 0.7, 0.92)
		c.draw_rect(Rect2(pad + t * bar_w, bar_y, bar_w / 140.0 + 1.0, bar_h), col, true)
	# pKa marker (yellow)
	var xk: float = pad + clampf(pka, 0.0, 14.0) / 14.0 * bar_w
	c.draw_line(Vector2(xk, bar_y - 4), Vector2(xk, bar_y + bar_h + 4), Color("#ffeb3b"), 2.5)
	c.draw_string(ThemeDB.fallback_font, Vector2(xk - 14, bar_y - 10), "pKa", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffeb3b"))
	# pH marker
	var xp: float = pad + clampf(ph, 0.0, 14.0) / 14.0 * bar_w
	c.draw_line(Vector2(xp, bar_y - 8), Vector2(xp, bar_y + bar_h + 8), Color.WHITE, 3.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(xp - 22, bar_y + bar_h + 22), "pH %.2f" % ph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	c.draw_string(ThemeDB.fallback_font, Vector2(pad, bar_y - 18), "pH scale (0 - 14)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))
	c.draw_string(ThemeDB.fallback_font, Vector2(pad, bar_y + bar_h + 40), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#78909c"))
	c.draw_string(ThemeDB.fallback_font, Vector2(pad + bar_w - 12, bar_y + bar_h + 40), "14", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#78909c"))

	# --- Beaker ---
	var bx: float = w * 0.5
	var by: float = h * 0.92
	var bw: float = minf(120.0, w * 0.22)
	var bh: float = h * 0.38
	var top: float = by - bh
	# Glass
	c.draw_rect(Rect2(bx - bw * 0.5, top, bw, bh), Color("#263238"), false, 2.5)
	c.draw_line(Vector2(bx - bw * 0.5, top), Vector2(bx + bw * 0.5, top), Color("#263238"), 2.5)
	# Liquid ~70%
	var liq_h: float = bh * 0.7
	var liq_col: Color = _ph_liquid_color(ph)
	c.draw_rect(Rect2(bx - bw * 0.5 + 3, by - liq_h, bw - 6, liq_h), liq_col, true)
	c.draw_string(ThemeDB.fallback_font, Vector2(bx - 36, by + 18), model.acid_formula(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))
	c.draw_string(ThemeDB.fallback_font, Vector2(bx - 40, top - 16), "pH %.2f" % ph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# Species bars for buffer/weak
	if model.mode != BuffersModel.Mode.STRONG and not _last.is_empty():
		var extra: Dictionary = _last.get("extra", {})
		var ha_v: float = float(extra.get("HA", 0.0))
		var a_v: float = float(extra.get("A", 0.0))
		var tot: float = maxf(ha_v + a_v, 1e-9)
		var bar_x: float = pad
		var bar2_y: float = h * 0.55
		var bar2_w: float = w * 0.28
		var bar2_h: float = 22.0
		var ha_w: float = (ha_v / tot) * bar2_w
		var a_w: float = (a_v / tot) * bar2_w
		c.draw_rect(Rect2(bar_x, bar2_y, ha_w, bar2_h), Color("#ef5350"), true)
		c.draw_rect(Rect2(bar_x + ha_w, bar2_y, a_w, bar2_h), Color("#42a5f5"), true)
		c.draw_string(ThemeDB.fallback_font, Vector2(bar_x, bar2_y - 12), "HA (red) / A- (blue)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#90a4ae"))
		c.draw_string(ThemeDB.fallback_font, Vector2(bar_x, bar2_y + bar2_h + 14), "ratio A-/HA = %.2f" % (a_v / maxf(ha_v, 1e-12)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b0bec5"))


func _ph_liquid_color(ph: float) -> Color:
	# Soft rainbow mapping for beaker fill
	var t: float = clampf(ph / 14.0, 0.0, 1.0)
	return Color.from_hsv(0.72 - t * 0.72, 0.45, 0.85, 0.85)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_1:
			_on_mode(int(BuffersModel.Mode.WEAK))
			get_viewport().set_input_as_handled()
		KEY_2:
			_on_mode(int(BuffersModel.Mode.BUFFER))
			get_viewport().set_input_as_handled()
		KEY_3:
			_on_mode(int(BuffersModel.Mode.STRONG))
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_reset_pert()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
