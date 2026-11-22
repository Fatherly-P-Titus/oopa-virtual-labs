extends LabShell
## Kinetic particle box — pause, histogram, presets, select particle.

var model: ParticleModel = ParticleModel.new()

var _stage: Control

var _slider_count: HSlider
var _slider_size: HSlider
var _slider_temp: HSlider
var _slider_grav: HSlider
var _slider_elas: HSlider
var _out_count: Label
var _out_size: Label
var _out_temp: Label
var _out_grav: Label
var _out_elas: Label
var _chk_collide: CheckButton
var _chk_trails: CheckButton
var _btn_play: Button
var _btn_reset: Button

var _r_avg: Label
var _r_rms: Label
var _r_ke: Label
var _r_te: Label
var _r_col: Label
var _r_press: Label
var _r_sel: Label
var _keys_hint: Label

var _updating: bool = false
var _playing: bool = true
var _trails: Array = []
var _box_size: float = 300.0
var _selected: int = -1

# Layout metrics updated each draw (for mouse pick)
var _box_ox: float = 0.0
var _box_oy: float = 0.0
var _box_side: float = 300.0
var _box_scale: float = 1.0
var _hist_y0: float = 0.0

const BAND_COLORS: Array = [
	Color("#90caf9"),
	Color("#64b5f6"),
	Color("#42a5f5"),
	Color("#ff8a65"),
	Color("#e53935"),
]

const PRESETS: Array = [
	{
		"name": "Ideal gas",
		"count": 20, "radius": 6.0, "temp": 40.0, "grav": 0.0, "elas": 1.0,
		"collide": true, "trails": false,
	},
	{
		"name": "Settling",
		"count": 25, "radius": 7.0, "temp": 35.0, "grav": 350.0, "elas": 0.60,
		"collide": true, "trails": false,
	},
	{
		"name": "Hot dense",
		"count": 40, "radius": 5.0, "temp": 90.0, "grav": 0.0, "elas": 1.0,
		"collide": true, "trails": false,
	},
	{
		"name": "Cool sparse",
		"count": 8, "radius": 8.0, "temp": 10.0, "grav": 0.0, "elas": 1.0,
		"collide": true, "trails": false,
	},
	{
		"name": "No collide",
		"count": 20, "radius": 6.0, "temp": 50.0, "grav": 0.0, "elas": 1.0,
		"collide": false, "trails": true,
	},
]


func _ready() -> void:
	lab_title = "Particle Motion"
	lab_eyebrow = "PHYSICS  /  PARTICLE MOTION"
	lab_lead = "Hard spheres in a box. Pause, pick a particle, watch the speed histogram."
	field_id = "physics"
	page_id = "particle_motion"
	back_label = "<- Physics"
	super._ready()
	_build_stage()
	_build_sidebar()
	_apply_preset_dict(PRESETS[0])
	set_process(true)
	set_process_unhandled_input(true)
	set_status("Running. Click a particle to select. Space pauses.")


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "ParticleStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		push_error("Particle: sidebar missing")
		return

	_add_section(sb, "PRESETS")
	var row_a := HBoxContainer.new()
	row_a.add_theme_constant_override("separation", 4)
	var row_b := HBoxContainer.new()
	row_b.add_theme_constant_override("separation", 4)
	sb.add_child(row_a)
	sb.add_child(row_b)
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		var b := Button.new()
		b.text = str(p["name"])
		b.theme_type_variation = &"Chip"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		b.pressed.connect(_on_preset.bind(idx))
		if i < 3:
			row_a.add_child(b)
		else:
			row_b.add_child(b)

	_add_section(sb, "CONDITIONS")
	_out_count = Label.new()
	_out_count.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_count)
	_slider_count = _make_slider(2, 60, 1, _on_count)
	sb.add_child(_slider_count)

	_out_size = Label.new()
	_out_size.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_size)
	_slider_size = _make_slider(2, 14, 1, _on_size)
	sb.add_child(_slider_size)

	_out_temp = Label.new()
	_out_temp.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_temp)
	_slider_temp = _make_slider(0, 100, 1, _on_temp)
	sb.add_child(_slider_temp)

	_out_grav = Label.new()
	_out_grav.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_grav)
	_slider_grav = _make_slider(0, 600, 10, _on_grav)
	sb.add_child(_slider_grav)

	_out_elas = Label.new()
	_out_elas.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_elas)
	_slider_elas = _make_slider(0.50, 1.00, 0.01, _on_elas)
	sb.add_child(_slider_elas)

	_chk_collide = CheckButton.new()
	_chk_collide.text = "Particles collide with each other"
	_chk_collide.button_pressed = true
	_chk_collide.toggled.connect(_on_collide)
	sb.add_child(_chk_collide)

	_chk_trails = CheckButton.new()
	_chk_trails.text = "Show motion trails"
	_chk_trails.button_pressed = false
	_chk_trails.toggled.connect(_on_trails)
	sb.add_child(_chk_trails)

	_add_section(sb, "TIME")
	_btn_play = Button.new()
	_btn_play.text = "Pause"
	_btn_play.pressed.connect(_on_play)
	sb.add_child(_btn_play)

	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	var step := Button.new()
	step.text = "Step"
	step.theme_type_variation = &"GhostButton"
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.pressed.connect(_on_step)
	trow.add_child(step)
	_btn_reset = Button.new()
	_btn_reset.text = "Reset"
	_btn_reset.theme_type_variation = &"GhostButton"
	_btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_reset.pressed.connect(_on_reset)
	trow.add_child(_btn_reset)
	sb.add_child(trow)

	_add_section(sb, "READOUTS")
	_r_avg = _stat_row(sb, "Avg speed")
	_r_rms = _stat_row(sb, "RMS speed")
	_r_ke = _stat_row(sb, "Kinetic energy")
	_r_te = _stat_row(sb, "Total energy")
	_r_col = _stat_row(sb, "Collisions")
	_r_press = _stat_row(sb, "Wall pressure")
	_r_sel = _stat_row(sb, "Selected")

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: Space pause · . step · R reset · click particle · Esc back"
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


func _apply_preset_dict(p: Dictionary) -> void:
	model.count = int(p["count"])
	model.radius = float(p["radius"])
	model.temperature = float(p["temp"])
	model.gravity = float(p["grav"])
	model.elasticity = float(p["elas"])
	model.collide_particles = bool(p["collide"])
	model.show_trails = bool(p["trails"])
	model.rebuild()
	_selected = -1
	_init_trails()
	_playing = true
	_update_play_btn()
	_refresh_ui()


func _init_trails() -> void:
	_trails.clear()
	for i in model.particles.size():
		_trails.append(PackedVector2Array())


func _process(delta: float) -> void:
	if not _playing:
		_refresh_readouts()
		if _stage:
			_stage.queue_redraw()
		return
	var dt: float = minf(delta, 0.033)
	var steps: int = 2
	var h: float = dt / float(steps)
	for i in range(steps):
		model.step(h)
	_sample_trails()
	_refresh_readouts()
	if _stage:
		_stage.queue_redraw()


func _sample_trails() -> void:
	if not model.show_trails:
		return
	while _trails.size() < model.particles.size():
		_trails.append(PackedVector2Array())
	for i in model.particles.size():
		var p: Dictionary = model.particles[i]
		var trail: PackedVector2Array = _trails[i]
		trail.append(Vector2(float(p.x), float(p.y)))
		if trail.size() > 40:
			trail = trail.slice(trail.size() - 40)
		_trails[i] = trail


func _on_preset(idx: int) -> void:
	if idx < 0 or idx >= PRESETS.size():
		return
	_apply_preset_dict(PRESETS[idx])
	set_status("Preset: %s" % str(PRESETS[idx]["name"]))


func _on_count(v: float) -> void:
	if _updating:
		return
	model.count = int(v)
	model.rebuild()
	_selected = -1
	_init_trails()
	_refresh_ui()


func _on_size(v: float) -> void:
	if _updating:
		return
	model.radius = v
	model.rebuild()
	_selected = -1
	_init_trails()
	_refresh_ui()


func _on_temp(v: float) -> void:
	if _updating:
		return
	model.set_temperature(v)
	_refresh_ui()


func _on_grav(v: float) -> void:
	if _updating:
		return
	model.gravity = v
	_refresh_ui()


func _on_elas(v: float) -> void:
	if _updating:
		return
	model.elasticity = v
	_refresh_ui()


func _on_collide(pressed: bool) -> void:
	model.collide_particles = pressed


func _on_trails(pressed: bool) -> void:
	model.show_trails = pressed
	if not pressed:
		_init_trails()


func _on_play() -> void:
	_playing = not _playing
	_update_play_btn()


func _update_play_btn() -> void:
	if _btn_play:
		_btn_play.text = "Pause" if _playing else "Play"


func _on_step() -> void:
	_playing = false
	_update_play_btn()
	model.step(1.0 / 60.0)
	_sample_trails()
	_refresh_readouts()
	if _stage:
		_stage.queue_redraw()


func _on_reset() -> void:
	model.rebuild()
	_selected = -1
	_init_trails()
	_playing = true
	_update_play_btn()
	_refresh_ui()
	set_status("Box reset.")


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_particle(event.position)
		_stage.accept_event()


func _pick_particle(screen: Vector2) -> void:
	# Convert to box-local world
	if _box_side < 1.0:
		return
	var lx: float = (screen.x - _box_ox) / _box_scale
	var ly: float = (screen.y - _box_oy) / _box_scale
	if lx < 0.0 or ly < 0.0 or lx > ParticleModel.BOX or ly > ParticleModel.BOX:
		_selected = -1
		_refresh_readouts()
		if _stage:
			_stage.queue_redraw()
		return
	var best: int = -1
	var best_d: float = 1e9
	var r: float = model.radius
	for i in model.particles.size():
		var p: Dictionary = model.particles[i]
		var dx: float = lx - float(p.x)
		var dy: float = ly - float(p.y)
		var d: float = sqrt(dx * dx + dy * dy)
		if d <= r * 1.8 and d < best_d:
			best_d = d
			best = i
	_selected = best
	_refresh_readouts()
	if _stage:
		_stage.queue_redraw()
	if _selected >= 0:
		set_status("Selected particle #%d" % (_selected + 1))


func _refresh_ui() -> void:
	if _slider_count == null:
		return
	_updating = true
	_slider_count.value = model.count
	_slider_size.value = model.radius
	_slider_temp.value = model.temperature
	_slider_grav.value = model.gravity
	_slider_elas.value = model.elasticity
	_chk_collide.button_pressed = model.collide_particles
	_chk_trails.button_pressed = model.show_trails
	_updating = false

	_out_count.text = "Particles = %d" % model.count
	_out_size.text = "Particle size = %.0f px" % model.radius
	_out_temp.text = "Temperature = %.0f °C" % model.temperature
	_out_grav.text = "Gravity = %.0f" % model.gravity
	_out_elas.text = "Elasticity = %.2f" % model.elasticity
	_refresh_readouts()
	if _stage:
		_stage.queue_redraw()


func _refresh_readouts() -> void:
	if _r_avg == null:
		return
	_r_avg.text = "%.1f" % model.avg_speed
	_r_rms.text = "%.1f" % model.rms_speed
	_r_ke.text = "%.1f" % model.kinetic_energy
	_r_te.text = "%.1f" % model.total_energy
	_r_col.text = "%d" % model.collision_count
	_r_press.text = "%.4f" % model.wall_pressure
	if _selected >= 0 and _selected < model.particles.size():
		var p: Dictionary = model.particles[_selected]
		var spd: float = sqrt(float(p.vx) * float(p.vx) + float(p.vy) * float(p.vy))
		var ke: float = 0.5 * spd * spd
		_r_sel.text = "#%d · v=%.1f · KE=%.1f" % [_selected + 1, spd, ke]
	else:
		_r_sel.text = "— (click a particle)"
	var run: String = "running" if _playing else "paused"
	set_status("%s · N=%d · T=%.0f°C · e=%.2f · P=%.4f" % [
		run, model.count, model.temperature, model.elasticity, model.wall_pressure
	])


func _speed_histogram(bins: int = 12) -> PackedFloat32Array:
	var hist := PackedFloat32Array()
	hist.resize(bins)
	for i in bins:
		hist[i] = 0.0
	if model.particles.is_empty():
		return hist
	var vmax: float = maxf(model.rms_speed * 2.5, 40.0)
	for p in model.particles:
		var spd: float = sqrt(float(p.vx) * float(p.vx) + float(p.vy) * float(p.vy))
		var bi: int = int(clampf(spd / vmax, 0.0, 0.999) * float(bins))
		hist[bi] = hist[bi] + 1.0
	return hist


func _draw_stage() -> void:
	if _stage == null:
		return
	var c: Control = _stage
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return

	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#121212"), true)

	# Layout: box on top ~70%, histogram strip below
	var hist_h: float = minf(h * 0.22, 100.0)
	var top_h: float = h - hist_h - 12.0
	var side: float = minf(minf(w * 0.92, top_h * 0.92), _box_size)
	_box_side = side
	_box_ox = (w - side) * 0.5
	_box_oy = (top_h - side) * 0.5 + 8.0
	_box_scale = side / ParticleModel.BOX
	_hist_y0 = top_h + 4.0

	# Box
	c.draw_rect(Rect2(_box_ox, _box_oy, side, side), Color("#1a1a1a"), true)
	c.draw_rect(Rect2(_box_ox, _box_oy, side, side), Color("#b22222"), false, 3.0)

	# Trails
	if model.show_trails:
		for i in mini(_trails.size(), model.particles.size()):
			var trail: PackedVector2Array = _trails[i]
			if trail.size() < 2:
				continue
			var pts := PackedVector2Array()
			for p in trail:
				pts.append(Vector2(_box_ox + p.x * _box_scale, _box_oy + p.y * _box_scale))
			var col := Color(0.5, 0.7, 1.0, 0.35) if i == _selected else Color(0.5, 0.7, 1.0, 0.2)
			c.draw_polyline(pts, col, 1.2 if i == _selected else 1.0, true)

	# Particles
	var r_draw: float = model.radius * _box_scale
	for i in model.particles.size():
		var p: Dictionary = model.particles[i]
		var spd: float = sqrt(float(p.vx) * float(p.vx) + float(p.vy) * float(p.vy))
		var band: int = model.energy_band(spd)
		var col: Color = BAND_COLORS[clampi(band, 0, 4)]
		var cx: float = _box_ox + float(p.x) * _box_scale
		var cy: float = _box_oy + float(p.y) * _box_scale
		c.draw_circle(Vector2(cx, cy), r_draw, col)
		if i == _selected:
			c.draw_arc(Vector2(cx, cy), r_draw + 4.0, 0.0, TAU, 32, Color("#ffeb3b"), 2.0, true)
			# Velocity tick
			var vscale: float = 0.15
			var tip := Vector2(
				_box_ox + (float(p.x) + float(p.vx) * vscale) * _box_scale,
				_box_oy + (float(p.y) + float(p.vy) * vscale) * _box_scale
			)
			c.draw_line(Vector2(cx, cy), tip, Color("#ffeb3b"), 2.0)
		else:
			c.draw_circle(Vector2(cx, cy), r_draw, Color(1, 1, 1, 0.15), false, 1.0)

	c.draw_string(ThemeDB.fallback_font, Vector2(_box_ox, _box_oy - 6.0), "Particle Box", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b0bec5"))
	if not _playing:
		c.draw_string(ThemeDB.fallback_font, Vector2(_box_ox + side - 60.0, _box_oy - 6.0), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffeb3b"))

	# --- Speed histogram ---
	var hist: PackedFloat32Array = _speed_histogram(12)
	var hmax: float = 1.0
	for v in hist:
		hmax = maxf(hmax, v)
	var hx0: float = _box_ox
	var hy0: float = _hist_y0
	var hw: float = side
	var hh: float = hist_h - 20.0
	c.draw_rect(Rect2(hx0, hy0, hw, hh + 16.0), Color("#1a1a1a"), true)
	c.draw_string(ThemeDB.fallback_font, Vector2(hx0 + 4.0, hy0 + 12.0), "Speed distribution", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))
	var nbin: int = hist.size()
	var gap: float = 2.0
	var bar_w: float = (hw - 16.0 - gap * float(nbin - 1)) / float(nbin)
	var base: float = hy0 + hh + 4.0
	for i in nbin:
		var bh: float = (hist[i] / hmax) * (hh - 8.0)
		var bx: float = hx0 + 8.0 + float(i) * (bar_w + gap)
		# Colour bars from blue (slow) to red (fast)
		var tcol: float = float(i) / float(maxi(nbin - 1, 1))
		var bar_col := Color("#64b5f6").lerp(Color("#e53935"), tcol)
		c.draw_rect(Rect2(bx, base - bh, bar_w, bh), bar_col, true)
	c.draw_string(ThemeDB.fallback_font, Vector2(hx0 + 8.0, base + 12.0), "slow", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#78909c"))
	c.draw_string(ThemeDB.fallback_font, Vector2(hx0 + hw - 36.0, base + 12.0), "fast", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#78909c"))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_SPACE:
			_on_play()
			get_viewport().set_input_as_handled()
		KEY_PERIOD:
			_on_step()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_reset()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
