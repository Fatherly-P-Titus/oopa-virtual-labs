extends LabShell
## 1D/2D two-body collisions with restitution, masses, momentum & energy readouts.

var model: CollisionModel = CollisionModel.new()

var _stage: Control
var _dim_row: HBoxContainer
var _slider_m1: HSlider
var _slider_m2: HSlider
var _slider_v1: HSlider
var _slider_v2: HSlider
var _slider_e: HSlider
var _out_m1: Label
var _out_m2: Label
var _out_v1: Label
var _out_v2: Label
var _out_e: Label
var _btn_play: Button
var _r_t: Label
var _r_ke: Label
var _r_ke0: Label
var _r_px: Label
var _r_py: Label
var _r_col: Label
var _r_type: Label
var _keys_hint: Label

var _updating: bool = false
var _playing: bool = false
var _ke0: float = 0.0
var _trail1: PackedVector2Array = PackedVector2Array()
var _trail2: PackedVector2Array = PackedVector2Array()

const PRESETS: Array = [
	{"name": "Equal elastic", "dim": 0, "m1": 1.0, "m2": 1.0, "v1": 40.0, "v2": -40.0, "e": 1.0},
	{"name": "Heavy hits light", "dim": 0, "m1": 4.0, "m2": 1.0, "v1": 40.0, "v2": 0.0, "e": 1.0},
	{"name": "Inelastic stick", "dim": 0, "m1": 2.0, "m2": 2.0, "v1": 50.0, "v2": 0.0, "e": 0.0},
	{"name": "2D glance", "dim": 1, "m1": 2.0, "m2": 1.5, "v1": 35.0, "v2": -20.0, "e": 1.0},
]


func _ready() -> void:
	lab_title = "Collision Motion"
	lab_eyebrow = "PHYSICS  /  COLLISIONS"
	lab_lead = "1D and 2D two-body collisions — elastic, inelastic, momentum and energy."
	field_id = "physics"
	page_id = "collisions"
	back_label = "<- Physics"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.setup_1d_defaults()
	_ke0 = model.ke()
	_refresh_ui()
	set_process(true)
	set_process_unhandled_input(true)
	set_status("Set masses and speeds, then Play. Watch KE and momentum.")


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "ColStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "DIMENSION")
	_dim_row = HBoxContainer.new()
	_dim_row.add_theme_constant_override("separation", 6)
	sb.add_child(_dim_row)
	for item in [["1D", 0], ["2D", 1]]:
		var b := Button.new()
		b.text = str(item[0])
		b.theme_type_variation = &"Chip"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var d: int = int(item[1])
		b.pressed.connect(_on_dim.bind(d))
		_dim_row.add_child(b)

	_add_section(sb, "PRESETS")
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 4)
	sb.add_child(prow)
	var prow2 := HBoxContainer.new()
	prow2.add_theme_constant_override("separation", 4)
	sb.add_child(prow2)
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		var b2 := Button.new()
		b2.text = str(p["name"])
		b2.theme_type_variation = &"Chip"
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		b2.pressed.connect(_on_preset.bind(idx))
		if i < 2:
			prow.add_child(b2)
		else:
			prow2.add_child(b2)

	_add_section(sb, "MASSES")
	_out_m1 = Label.new()
	_out_m1.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_m1)
	_slider_m1 = _make_slider(0.5, 6.0, 0.1, _on_param)
	sb.add_child(_slider_m1)
	_out_m2 = Label.new()
	_out_m2.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_m2)
	_slider_m2 = _make_slider(0.5, 6.0, 0.1, _on_param)
	sb.add_child(_slider_m2)

	_add_section(sb, "INITIAL SPEEDS")
	_out_v1 = Label.new()
	_out_v1.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_v1)
	_slider_v1 = _make_slider(-80.0, 80.0, 1.0, _on_param)
	sb.add_child(_slider_v1)
	_out_v2 = Label.new()
	_out_v2.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_v2)
	_slider_v2 = _make_slider(-80.0, 80.0, 1.0, _on_param)
	sb.add_child(_slider_v2)

	_add_section(sb, "RESTITUTION e")
	_out_e = Label.new()
	_out_e.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_e)
	_slider_e = _make_slider(0.0, 1.0, 0.05, _on_param)
	sb.add_child(_slider_e)

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
	_r_type = _stat_row(sb, "Type")
	_r_ke0 = _stat_row(sb, "KE initial")
	_r_ke = _stat_row(sb, "KE now")
	_r_px = _stat_row(sb, "px total")
	_r_py = _stat_row(sb, "py total")
	_r_col = _stat_row(sb, "Collisions")

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: 1/2 dim · Space play · R reset · Esc back"
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


func _process(delta: float) -> void:
	if not _playing:
		return
	model.advance(delta * 1.2)
	_trail1.append(Vector2(model.x1, model.y1))
	_trail2.append(Vector2(model.x2, model.y2))
	if _trail1.size() > 120:
		_trail1 = _trail1.slice(_trail1.size() - 100)
	if _trail2.size() > 120:
		_trail2 = _trail2.slice(_trail2.size() - 100)
	_refresh_live()


func _on_dim(d: int) -> void:
	if d == 0:
		model.setup_1d_defaults()
	else:
		model.setup_2d_defaults()
	_ke0 = model.ke()
	_trail1.clear()
	_trail2.clear()
	_playing = false
	_update_play_btn()
	_refresh_ui()


func _on_preset(idx: int) -> void:
	if idx < 0 or idx >= PRESETS.size():
		return
	var p: Dictionary = PRESETS[idx]
	if int(p["dim"]) == 0:
		model.setup_1d_defaults()
	else:
		model.setup_2d_defaults()
	model.m1 = float(p["m1"])
	model.m2 = float(p["m2"])
	model.e = float(p["e"])
	model.vx1 = float(p["v1"])
	model.vx2 = float(p["v2"])
	if model.dim == CollisionModel.Dim.D1:
		model.vy1 = 0.0
		model.vy2 = 0.0
	model.r1 = 12.0 + model.m1 * 4.0
	model.r2 = 12.0 + model.m2 * 4.0
	model.snapshot_initials()
	model.reset()
	_ke0 = model.ke()
	_trail1.clear()
	_trail2.clear()
	_playing = true
	_update_play_btn()
	_refresh_ui()
	set_status("Preset: %s" % str(p["name"]))


func _on_param(_v: float = 0.0) -> void:
	if _updating:
		return
	model.m1 = _slider_m1.value
	model.m2 = _slider_m2.value
	model.e = _slider_e.value
	model.vx1 = _slider_v1.value
	model.vx2 = _slider_v2.value
	if model.dim == CollisionModel.Dim.D1:
		model.vy1 = 0.0
		model.vy2 = 0.0
	model.r1 = 12.0 + model.m1 * 4.0
	model.r2 = 12.0 + model.m2 * 4.0
	model.snapshot_initials()
	model.reset()
	_ke0 = model.ke()
	_trail1.clear()
	_trail2.clear()
	_playing = false
	_update_play_btn()
	_refresh_ui()


func _on_play() -> void:
	_playing = not _playing
	_update_play_btn()


func _update_play_btn() -> void:
	if _btn_play:
		_btn_play.text = "Pause" if _playing else "Play"


func _on_reset() -> void:
	model.reset()
	_ke0 = model.ke()
	_trail1.clear()
	_trail2.clear()
	_playing = false
	_update_play_btn()
	_refresh_ui()


func _on_step() -> void:
	_playing = false
	_update_play_btn()
	model.advance(0.05)
	_trail1.append(Vector2(model.x1, model.y1))
	_trail2.append(Vector2(model.x2, model.y2))
	_refresh_live()


func _collision_type() -> String:
	if model.e >= 0.99:
		return "Elastic"
	if model.e <= 0.01:
		return "Perfectly inelastic"
	return "Inelastic (e=%.2f)" % model.e


func _refresh_ui() -> void:
	if _slider_m1 == null:
		return
	_updating = true
	_slider_m1.value = model.m1
	_slider_m2.value = model.m2
	_slider_v1.value = model.vx1 if model.t < 0.01 else model._ivx1
	_slider_v2.value = model.vx2 if model.t < 0.01 else model._ivx2
	# Always show initial velocities on sliders
	_slider_v1.value = model._ivx1
	_slider_v2.value = model._ivx2
	_slider_e.value = model.e
	_updating = false
	_out_m1.text = "m1 = %.1f kg" % model.m1
	_out_m2.text = "m2 = %.1f kg" % model.m2
	_out_v1.text = "v1x0 = %.0f" % model._ivx1
	_out_v2.text = "v2x0 = %.0f" % model._ivx2
	_out_e.text = "e = %.2f" % model.e
	for i in _dim_row.get_child_count():
		var b: Button = _dim_row.get_child(i) as Button
		if b:
			b.theme_type_variation = &"ChipActive" if i == model.dim else &"Chip"
	_refresh_live()


func _refresh_live() -> void:
	var p: Vector2 = model.momentum()
	_r_t.text = "%.2f s" % model.t
	_r_type.text = _collision_type()
	_r_ke0.text = "%.1f J" % _ke0
	_r_ke.text = "%.1f J" % model.ke()
	_r_px.text = "%.1f" % p.x
	_r_py.text = "%.1f" % p.y
	_r_col.text = "%d" % model.collision_count
	var loss: float = 0.0
	if _ke0 > 1e-6:
		loss = (1.0 - model.ke() / _ke0) * 100.0
	set_status("%s · KE %.0f%% of initial · px=%.1f" % [_collision_type(), 100.0 - loss, p.x])
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

	# Fit model box into stage
	var margin: float = 24.0
	var scale: float = minf((w - 2.0 * margin) / model.box_w, (h - 2.0 * margin) / model.box_h)
	var bw: float = model.box_w * scale
	var bh: float = model.box_h * scale
	var ox: float = (w - bw) * 0.5
	var oy: float = (h - bh) * 0.5

	c.draw_rect(Rect2(ox, oy, bw, bh), Color("#1a1a1a"), true)
	c.draw_rect(Rect2(ox, oy, bw, bh), Color("#b22222"), false, 2.0)

	# Trails
	if _trail1.size() >= 2:
		var t1 := PackedVector2Array()
		for p in _trail1:
			t1.append(Vector2(ox + p.x * scale, oy + p.y * scale))
		c.draw_polyline(t1, Color(0.3, 0.6, 1.0, 0.35), 1.5, true)
	if _trail2.size() >= 2:
		var t2 := PackedVector2Array()
		for p in _trail2:
			t2.append(Vector2(ox + p.x * scale, oy + p.y * scale))
		c.draw_polyline(t2, Color(1.0, 0.6, 0.2, 0.35), 1.5, true)

	# Specular highlights add volume while body centres/radii remain model-derived.
	var c1 := Vector2(ox + model.x1 * scale, oy + model.y1 * scale)
	var c2 := Vector2(ox + model.x2 * scale, oy + model.y2 * scale)
	var rr1: float = model.r1 * scale
	var rr2: float = model.r2 * scale
	c.draw_circle(c1 + Vector2(2.0, 4.0), rr1, Color(0.0, 0.0, 0.0, 0.28))
	c.draw_circle(c2 + Vector2(2.0, 4.0), rr2, Color(0.0, 0.0, 0.0, 0.28))
	c.draw_circle(c1, rr1, Color("#1976d2"))
	c.draw_circle(c1 - Vector2(rr1 * 0.28, rr1 * 0.30), rr1 * 0.30, Color("#bbdefb", 0.48))
	c.draw_circle(c1, rr1, Color("#90caf9"), false, 2.0)
	c.draw_circle(c2, rr2, Color("#e64a19"))
	c.draw_circle(c2 - Vector2(rr2 * 0.28, rr2 * 0.30), rr2 * 0.30, Color("#ffe0b2", 0.48))
	c.draw_circle(c2, rr2, Color("#ffccbc"), false, 2.0)

	# Arrowheads preserve the actual signed model velocities.
	var vs: float = 0.35 * scale
	var d1 := Vector2(model.vx1, model.vy1) * vs
	var d2 := Vector2(model.vx2, model.vy2) * vs
	c.draw_line(c1, c1 + d1, Color("#90caf9"), 2.0)
	c.draw_line(c2, c2 + d2, Color("#ffccbc"), 2.0)
	if d1.length() > 5.0:
		var dir1 := d1.normalized()
		c.draw_line(c1 + d1, c1 + d1 - dir1 * 8.0 + dir1.orthogonal() * 4.0, Color("#90caf9"), 2.0)
		c.draw_line(c1 + d1, c1 + d1 - dir1 * 8.0 - dir1.orthogonal() * 4.0, Color("#90caf9"), 2.0)
	if d2.length() > 5.0:
		var dir2 := d2.normalized()
		c.draw_line(c2 + d2, c2 + d2 - dir2 * 8.0 + dir2.orthogonal() * 4.0, Color("#ffccbc"), 2.0)
		c.draw_line(c2 + d2, c2 + d2 - dir2 * 8.0 - dir2.orthogonal() * 4.0, Color("#ffccbc"), 2.0)

	c.draw_string(ThemeDB.fallback_font, Vector2(c1.x - 6.0, c1.y + 4.0), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	c.draw_string(ThemeDB.fallback_font, Vector2(c2.x - 6.0, c2.y + 4.0), "2", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	var dim_s: String = "1D" if model.dim == CollisionModel.Dim.D1 else "2D"
	c.draw_string(ThemeDB.fallback_font, Vector2(ox, oy - 8.0), "%s collision  ·  e = %.2f" % [dim_s, model.e], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b0bec5"))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_1:
			_on_dim(0)
			get_viewport().set_input_as_handled()
		KEY_2:
			_on_dim(1)
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
