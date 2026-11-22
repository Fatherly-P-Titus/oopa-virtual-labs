extends LabShell
## Projectile motion — trajectory, ideal overlay, 1–2 mouse-placed hoops, presets, ghost.

var model: ProjectileModel = ProjectileModel.new()

var _stage: Control

var _slider_v0: HSlider
var _slider_ang: HSlider
var _slider_h0: HSlider
var _slider_g: HSlider
var _slider_drag: HSlider
var _slider_wind: HSlider
var _slider_e: HSlider
var _slider_mu: HSlider
var _out_v0: Label
var _out_ang: Label
var _out_h0: Label
var _out_g: Label
var _out_drag: Label
var _out_wind: Label
var _out_e: Label
var _out_mu: Label
var _chk_ideal: CheckButton
var _chk_target: CheckButton
var _btn_play: Button
var _btn_hoop1: Button
var _btn_hoop2: Button
var _r_t: Label
var _r_range: Label
var _r_hmax: Label
var _r_speed: Label
var _r_ideal_r: Label
var _r_ideal_h: Label
var _r_ideal_t: Label
var _r_ke: Label
var _r_pe: Label
var _r_delta_r: Label
var _r_hit: Label
var _r_place: Label
var _keys_hint: Label

var _updating: bool = false
var _playing: bool = false
var _path: PackedVector2Array = PackedVector2Array()
var _ideal_path: PackedVector2Array = PackedVector2Array()
var _ghost_path: PackedVector2Array = PackedVector2Array()
var _sample_every: float = 0.02
var _accum: float = 0.0

# World scale (updated each draw / used for mouse mapping)
var _world_w: float = 50.0
var _world_h: float = 20.0
var _origin: Vector2 = Vector2.ZERO
var _plot_w: float = 100.0
var _plot_h: float = 100.0
var _ground_y: float = 0.0
# Frozen view bounds — recomputed only on reset / hoop / param change (stops shake)
var _view_w: float = 50.0
var _view_h: float = 20.0

# Hoops: click stage to place (1 or 2)
var _target_on: bool = true
var _tr: float = 1.2
var _hoops: Array = [Vector2(40.0, 8.0)]
var _place_index: int = 0
var _hit: Array = [false]
var _closest: Array = [1e9]

const PRESETS: Array = [
	{"name": "Classic 45°", "v0": 25.0, "ang": 45.0, "h0": 0.0, "g": 9.81, "drag": 0.0, "wind": 0.0, "e": 0.0, "mu": 0.3, "hoops": [Vector2(50.0, 5.0)]},
	{"name": "High drag", "v0": 30.0, "ang": 40.0, "h0": 0.0, "g": 9.81, "drag": 0.08, "wind": 0.0, "e": 0.0, "mu": 0.3, "hoops": [Vector2(25.0, 4.0)]},
	{"name": "Headwind", "v0": 28.0, "ang": 35.0, "h0": 0.0, "g": 9.81, "drag": 0.02, "wind": -8.0, "e": 0.0, "mu": 0.3, "hoops": [Vector2(35.0, 6.0)]},
	{"name": "Cliff", "v0": 20.0, "ang": 25.0, "h0": 15.0, "g": 9.81, "drag": 0.0, "wind": 0.0, "e": 0.0, "mu": 0.3, "hoops": [Vector2(45.0, 5.0)]},
	{"name": "Bouncy", "v0": 22.0, "ang": 50.0, "h0": 0.0, "g": 9.81, "drag": 0.0, "wind": 0.0, "e": 0.75, "mu": 0.15, "hoops": [Vector2(20.0, 3.0), Vector2(35.0, 2.0)]},
]


func _ready() -> void:
	lab_title = "Projectile Motion"
	lab_eyebrow = "PHYSICS  /  PROJECTILE MOTION"
	lab_lead = "Click the canvas to place up to 2 hoops. Launch, compare runs, try presets."
	field_id = "physics"
	page_id = "projectile_motion"
	back_label = "<- Physics"
	super._ready()
	_build_stage()
	_build_sidebar()
	_apply_defaults()
	_hard_reset(false)
	set_process_unhandled_input(true)
	set_process(true)
	set_status("Click stage to place hoop. Select Hoop 1 or 2 first.")


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "ProjStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		push_error("Projectile: sidebar missing")
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

	_add_section(sb, "LAUNCH")
	_out_v0 = Label.new()
	_out_v0.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_v0)
	_slider_v0 = _make_slider(1.0, 50.0, 0.5, _on_param)
	sb.add_child(_slider_v0)

	_out_ang = Label.new()
	_out_ang.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_ang)
	_slider_ang = _make_slider(5.0, 85.0, 1.0, _on_param)
	sb.add_child(_slider_ang)

	_out_h0 = Label.new()
	_out_h0.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_h0)
	_slider_h0 = _make_slider(0.0, 20.0, 0.5, _on_param)
	sb.add_child(_slider_h0)

	_out_g = Label.new()
	_out_g.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_g)
	_slider_g = _make_slider(1.0, 20.0, 0.1, _on_param)
	sb.add_child(_slider_g)

	_add_section(sb, "ENVIRONMENT")
	_out_drag = Label.new()
	_out_drag.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_drag)
	_slider_drag = _make_slider(0.0, 0.15, 0.005, _on_param)
	sb.add_child(_slider_drag)

	_out_wind = Label.new()
	_out_wind.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_wind)
	_slider_wind = _make_slider(-15.0, 15.0, 0.5, _on_param)
	sb.add_child(_slider_wind)

	_out_e = Label.new()
	_out_e.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_e)
	_slider_e = _make_slider(0.0, 0.95, 0.05, _on_param)
	sb.add_child(_slider_e)

	_out_mu = Label.new()
	_out_mu.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_mu)
	_slider_mu = _make_slider(0.0, 0.8, 0.05, _on_param)
	sb.add_child(_slider_mu)

	_chk_ideal = CheckButton.new()
	_chk_ideal.text = "Show ideal parabola"
	_chk_ideal.button_pressed = true
	_chk_ideal.toggled.connect(_on_ideal_toggle)
	sb.add_child(_chk_ideal)

	_add_section(sb, "TARGET HOOPS")
	_chk_target = CheckButton.new()
	_chk_target.text = "Show hoops"
	_chk_target.button_pressed = true
	_chk_target.toggled.connect(_on_target_toggle)
	sb.add_child(_chk_target)

	_r_place = Label.new()
	_r_place.theme_type_variation = &"Hint"
	_r_place.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_place.text = "Click canvas to place. Select which hoop below."
	sb.add_child(_r_place)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 6)
	_btn_hoop1 = Button.new()
	_btn_hoop1.text = "Place hoop 1"
	_btn_hoop1.theme_type_variation = &"ChipActive"
	_btn_hoop1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_hoop1.pressed.connect(_on_select_hoop.bind(0))
	hrow.add_child(_btn_hoop1)
	_btn_hoop2 = Button.new()
	_btn_hoop2.text = "Place hoop 2"
	_btn_hoop2.theme_type_variation = &"Chip"
	_btn_hoop2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_hoop2.pressed.connect(_on_select_hoop.bind(1))
	hrow.add_child(_btn_hoop2)
	sb.add_child(hrow)

	var hrow2 := HBoxContainer.new()
	hrow2.add_theme_constant_override("separation", 6)
	var rem2 := Button.new()
	rem2.text = "Remove hoop 2"
	rem2.theme_type_variation = &"GhostButton"
	rem2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rem2.pressed.connect(_on_remove_hoop2)
	hrow2.add_child(rem2)
	sb.add_child(hrow2)

	_add_section(sb, "TIME / COMPARE")
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
	step.text = "+0.1 s"
	step.theme_type_variation = &"GhostButton"
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.pressed.connect(_on_step)
	row.add_child(step)
	sb.add_child(row)

	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 6)
	var store := Button.new()
	store.text = "Store run"
	store.theme_type_variation = &"GhostButton"
	store.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store.pressed.connect(_on_store_ghost)
	crow.add_child(store)
	var clear_g := Button.new()
	clear_g.text = "Clear ghost"
	clear_g.theme_type_variation = &"GhostButton"
	clear_g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_g.pressed.connect(_on_clear_ghost)
	crow.add_child(clear_g)
	sb.add_child(crow)

	_add_section(sb, "READOUTS")
	_r_t = _stat_row(sb, "t")
	_r_range = _stat_row(sb, "x (range)")
	_r_hmax = _stat_row(sb, "H max")
	_r_speed = _stat_row(sb, "Speed")
	_r_ke = _stat_row(sb, "KE")
	_r_pe = _stat_row(sb, "PE")
	_r_ideal_r = _stat_row(sb, "Ideal R")
	_r_ideal_h = _stat_row(sb, "Ideal H")
	_r_ideal_t = _stat_row(sb, "Ideal T")
	_r_delta_r = _stat_row(sb, "ΔR (ideal−x)")
	_r_hit = _stat_row(sb, "Hoops")

	_keys_hint = Label.new()
	_keys_hint.theme_type_variation = &"Hint"
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.text = "Keys: Space play · R reset · I ideal · 1/2 select hoop · S store · G clear · Esc back"
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


func _apply_defaults() -> void:
	model.v0 = 25.0
	model.angle_deg = 45.0
	model.h0 = 0.0
	model.g = 9.81
	model.c_drag = 0.0
	model.wind = 0.0
	model.e_bounce = 0.0
	model.mu = 0.3
	model.mass = 1.0
	_hoops = [Vector2(40.0, 8.0)]
	_place_index = 0
	_reset_hit_state()


func _reset_hit_state() -> void:
	_hit.clear()
	_closest.clear()
	for i in _hoops.size():
		_hit.append(false)
		_closest.append(1e9)


func _recompute_view_bounds() -> void:
	## Fixed camera window for the whole flight — do not track live x/y.
	var id: Dictionary = model.ideal()
	var w: float = maxf(float(id.get("R", 10.0)) * 1.35, 20.0)
	var h: float = maxf(maxf(float(id.get("H", 5.0)) * 1.45, model.h0 + 6.0), 10.0)
	# Room for bounces / drag overshoot
	w = maxf(w, model.v0 * 2.2)
	if _target_on:
		for hp in _hoops:
			w = maxf(w, float(hp.x) * 1.25 + 5.0)
			h = maxf(h, float(hp.y) * 1.35 + 3.0)
	_view_w = w
	_view_h = h


func _hard_reset(store_previous: bool) -> void:
	if store_previous and _path.size() > 5:
		_ghost_path = _path.duplicate()
	_playing = false
	_update_play_btn()
	_read_sliders_into_model()
	model.reset()
	_path = PackedVector2Array()
	_path.append(Vector2(model.x, model.y))
	_rebuild_ideal_path()
	_recompute_view_bounds()
	_accum = 0.0
	_reset_hit_state()
	_refresh_ui()


func _read_sliders_into_model() -> void:
	if _slider_v0 == null:
		return
	model.v0 = _slider_v0.value
	model.angle_deg = _slider_ang.value
	model.h0 = _slider_h0.value
	model.g = _slider_g.value
	model.c_drag = _slider_drag.value
	model.wind = _slider_wind.value
	model.e_bounce = _slider_e.value
	model.mu = _slider_mu.value


func _rebuild_ideal_path() -> void:
	_ideal_path = PackedVector2Array()
	var id: Dictionary = model.ideal()
	var T: float = float(id.get("T", 1.0))
	var ivx: float = float(id.get("vx", 0.0))
	var ivy: float = float(id.get("vy", 0.0))
	if T <= 1e-6:
		_ideal_path.append(Vector2(0.0, model.h0))
		return
	var n: int = 80
	for i in range(n + 1):
		var tt: float = T * float(i) / float(n)
		var px: float = ivx * tt
		var py: float = model.h0 + ivy * tt - 0.5 * model.g * tt * tt
		if py < 0.0 and i > 0:
			_ideal_path.append(Vector2(px, 0.0))
			break
		_ideal_path.append(Vector2(px, maxf(py, 0.0)))


func _screen_to_world(sp: Vector2) -> Vector2:
	if _plot_w < 1.0 or _plot_h < 1.0:
		return Vector2.ZERO
	var wx: float = ((sp.x - _origin.x) / _plot_w) * _world_w
	var wy: float = ((_origin.y - sp.y) / _plot_h) * _world_h
	return Vector2(wx, maxf(wy, 0.0))


func _on_stage_input(event: InputEvent) -> void:
	if not _target_on:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world: Vector2 = _screen_to_world(event.position)
		_place_hoop_at(world)
		_stage.accept_event()


func _place_hoop_at(world: Vector2) -> void:
	world.x = clampf(world.x, 0.5, 120.0)
	world.y = clampf(world.y, 0.0, 40.0)
	if _place_index <= 0:
		if _hoops.is_empty():
			_hoops.append(world)
		else:
			_hoops[0] = world
		_place_index = 0
	else:
		# Ensure slot 1 exists
		if _hoops.size() < 2:
			_hoops.append(world)
		else:
			_hoops[1] = world
		_place_index = 1
	_reset_hit_state()
	_retest_path_hits()
	_recompute_view_bounds()
	_update_hoop_buttons()
	_refresh_ui()
	set_status("Hoop %d placed at (%.1f, %.1f) m" % [_place_index + 1, world.x, world.y])


func _on_select_hoop(idx: int) -> void:
	_place_index = clampi(idx, 0, 1)
	_update_hoop_buttons()
	set_status("Click canvas to place hoop %d." % (_place_index + 1))


func _on_remove_hoop2() -> void:
	if _hoops.size() > 1:
		_hoops.pop_back()
	_place_index = 0
	_reset_hit_state()
	_retest_path_hits()
	_recompute_view_bounds()
	_update_hoop_buttons()
	_refresh_ui()


func _update_hoop_buttons() -> void:
	if _btn_hoop1:
		_btn_hoop1.theme_type_variation = &"ChipActive" if _place_index == 0 else &"Chip"
	if _btn_hoop2:
		_btn_hoop2.theme_type_variation = &"ChipActive" if _place_index == 1 else &"Chip"


func _check_hoop_segment(a: Vector2, b: Vector2) -> void:
	if not _target_on:
		return
	for i in _hoops.size():
		var hpos: Vector2 = _hoops[i]
		var ab: Vector2 = b - a
		var ap: Vector2 = hpos - a
		var ab2: float = ab.length_squared()
		var t: float = 0.0
		if ab2 > 1e-12:
			t = clampf(ap.dot(ab) / ab2, 0.0, 1.0)
		var closest: Vector2 = a + ab * t
		var d: float = closest.distance_to(hpos)
		_closest[i] = minf(float(_closest[i]), d)
		if d <= _tr:
			_hit[i] = true


func _retest_path_hits() -> void:
	_reset_hit_state()
	if _path.size() < 2:
		return
	for i in range(1, _path.size()):
		_check_hoop_segment(_path[i - 1], _path[i])


func _process(delta: float) -> void:
	if not _playing:
		return
	if model.resting:
		_playing = false
		_update_play_btn()
		_refresh_ui()
		return
	var prev := Vector2(model.x, model.y)
	var sim_dt: float = delta * 1.25
	_accum += sim_dt
	model.advance(sim_dt)
	var cur := Vector2(model.x, model.y)
	_check_hoop_segment(prev, cur)
	while _accum >= _sample_every:
		_accum -= _sample_every
		_path.append(Vector2(model.x, model.y))
	_path.append(cur)
	_refresh_ui()


func _on_param(_v: float = 0.0) -> void:
	if _updating:
		return
	_hard_reset(false)


func _on_ideal_toggle(_pressed: bool) -> void:
	if _stage:
		_stage.queue_redraw()


func _on_target_toggle(pressed: bool) -> void:
	_target_on = pressed
	_retest_path_hits()
	_refresh_ui()


func _on_preset(idx: int) -> void:
	if idx < 0 or idx >= PRESETS.size():
		return
	var p: Dictionary = PRESETS[idx]
	_updating = true
	_slider_v0.value = float(p["v0"])
	_slider_ang.value = float(p["ang"])
	_slider_h0.value = float(p["h0"])
	_slider_g.value = float(p["g"])
	_slider_drag.value = float(p["drag"])
	_slider_wind.value = float(p["wind"])
	_slider_e.value = float(p["e"])
	_slider_mu.value = float(p["mu"])
	_updating = false
	_hoops = []
	for h in p["hoops"]:
		_hoops.append(h)
	_place_index = 0
	_hard_reset(false)
	_update_hoop_buttons()
	set_status("Preset: %s" % str(p["name"]))


func _on_play() -> void:
	if model.resting and not _playing:
		_hard_reset(false)
	_playing = not _playing
	_update_play_btn()


func _update_play_btn() -> void:
	if _btn_play:
		_btn_play.text = "Pause" if _playing else "Play"


func _on_reset() -> void:
	_hard_reset(true)


func _on_step() -> void:
	if model.resting:
		_hard_reset(false)
	var prev := Vector2(model.x, model.y)
	model.advance(0.1)
	var cur := Vector2(model.x, model.y)
	_check_hoop_segment(prev, cur)
	_path.append(cur)
	_refresh_ui()


func _on_store_ghost() -> void:
	if _path.size() > 2:
		_ghost_path = _path.duplicate()
		set_status("Stored current path as ghost.")
		if _stage:
			_stage.queue_redraw()
	else:
		set_status("Nothing to store — play a path first.")


func _on_clear_ghost() -> void:
	_ghost_path = PackedVector2Array()
	if _stage:
		_stage.queue_redraw()
	set_status("Ghost cleared.")


func _refresh_ui() -> void:
	if _slider_v0 == null:
		return
	_updating = true
	_slider_v0.value = model.v0
	_slider_ang.value = model.angle_deg
	_slider_h0.value = model.h0
	_slider_g.value = model.g
	_slider_drag.value = model.c_drag
	_slider_wind.value = model.wind
	_slider_e.value = model.e_bounce
	_slider_mu.value = model.mu
	_chk_target.button_pressed = _target_on
	_updating = false

	_out_v0.text = "v0 = %.1f m/s" % model.v0
	_out_ang.text = "Angle = %.0f deg" % model.angle_deg
	_out_h0.text = "h0 = %.1f m" % model.h0
	_out_g.text = "g = %.2f m/s2" % model.g
	_out_drag.text = "Drag c = %.3f" % model.c_drag
	_out_wind.text = "Wind = %.1f m/s" % model.wind
	_out_e.text = "Bounce e = %.2f" % model.e_bounce
	_out_mu.text = "Friction mu = %.2f" % model.mu

	if _r_place:
		var coords: String = ""
		for i in _hoops.size():
			var hp: Vector2 = _hoops[i]
			coords += " H%d (%.1f, %.1f)" % [i + 1, hp.x, hp.y]
		_r_place.text = "Placing hoop %d. Click canvas.%s" % [_place_index + 1, coords]

	var id: Dictionary = model.ideal()
	var ideal_r: float = float(id.get("R", 0.0))
	_r_t.text = "%.2f s" % model.t
	_r_range.text = "%.2f m" % model.x
	_r_hmax.text = "%.2f m" % model.max_y
	_r_speed.text = "%.2f m/s" % model.speed()
	_r_ke.text = "%.1f J" % model.ke()
	_r_pe.text = "%.1f J" % model.pe()
	_r_ideal_r.text = "%.2f m" % ideal_r
	_r_ideal_h.text = "%.2f m" % float(id.get("H", 0.0))
	_r_ideal_t.text = "%.2f s" % float(id.get("T", 0.0))
	_r_delta_r.text = "%.2f m" % (ideal_r - model.x)

	if not _target_on:
		_r_hit.text = "off"
	else:
		var parts: PackedStringArray = PackedStringArray()
		for i in _hoops.size():
			if bool(_hit[i]):
				parts.append("H%d HIT" % (i + 1))
			elif _path.size() > 3:
				parts.append("H%d miss (%.2f m)" % [i + 1, float(_closest[i])])
			else:
				parts.append("H%d —" % (i + 1))
		_r_hit.text = " · ".join(parts)

	var st: String = "t=%.2f s · x=%.2f m · y=%.2f m" % [model.t, model.x, model.y]
	var any_hit: bool = false
	for h in _hit:
		if bool(h):
			any_hit = true
			break
	if _target_on and any_hit:
		st += " · HOOP HIT"
	elif model.resting:
		st += " · at rest"
	elif model.rolling:
		st += " · rolling"
	set_status(st)
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
	_ground_y = h * 0.88
	c.draw_rect(Rect2(0.0, _ground_y, w, h - _ground_y), Color("#3e2723"), true)
	c.draw_line(Vector2(0.0, _ground_y), Vector2(w, _ground_y), Color("#5d4037"), 2.0)

	# Use frozen view bounds (set on reset / hoop place) — avoids left-right shake
	_world_w = maxf(_view_w, 10.0)
	_world_h = maxf(_view_h, 5.0)

	var pad_l: float = 40.0
	var pad_r: float = 20.0
	var pad_t: float = 24.0
	_plot_w = w - pad_l - pad_r
	_plot_h = _ground_y - pad_t
	_origin = Vector2(pad_l, _ground_y)

	for i in 5:
		var gx: float = pad_l + _plot_w * float(i) / 4.0
		c.draw_line(Vector2(gx, pad_t), Vector2(gx, _ground_y), Color("#1b2838"), 1.0)
		c.draw_string(ThemeDB.fallback_font, Vector2(gx - 8.0, _ground_y + 16.0), "%.0f" % (_world_w * float(i) / 4.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#78909c"))
	for j in 4:
		var gy: float = _ground_y - _plot_h * float(j) / 3.0
		c.draw_line(Vector2(pad_l, gy), Vector2(pad_l + _plot_w, gy), Color("#1b2838"), 1.0)

	c.draw_string(ThemeDB.fallback_font, Vector2(pad_l, 16.0), "Trajectory (m) — click to place hoop", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))

	if _ghost_path.size() >= 2:
		var gpts := PackedVector2Array()
		for p in _ghost_path:
			gpts.append(Vector2(_origin.x + (p.x / _world_w) * _plot_w, _origin.y - (p.y / _world_h) * _plot_h))
		c.draw_polyline(gpts, Color(0.7, 0.5, 0.9, 0.45), 2.0, true)

	if _chk_ideal != null and _chk_ideal.button_pressed and _ideal_path.size() >= 2:
		var ipts := PackedVector2Array()
		for p in _ideal_path:
			ipts.append(Vector2(_origin.x + (p.x / _world_w) * _plot_w, _origin.y - (p.y / _world_h) * _plot_h))
		c.draw_polyline(ipts, Color(1.0, 1.0, 1.0, 0.35), 1.5, true)

	if _path.size() >= 2:
		var pts := PackedVector2Array()
		for p in _path:
			pts.append(Vector2(_origin.x + (p.x / _world_w) * _plot_w, _origin.y - (p.y / _world_h) * _plot_h))
		c.draw_polyline(pts, Color("#42a5f5"), 2.5, true)

	# Hoops
	if _target_on:
		for i in _hoops.size():
			var hp: Vector2 = _hoops[i]
			var hx: float = _origin.x + (hp.x / _world_w) * _plot_w
			var hy: float = _origin.y - (hp.y / _world_h) * _plot_h
			var rx: float = (_tr / _world_w) * _plot_w
			var ry: float = (_tr / _world_h) * _plot_h
			var rr: float = (rx + ry) * 0.5
			var hit_i: bool = bool(_hit[i]) if i < _hit.size() else false
			var hoop_col := Color("#66bb6a") if hit_i else Color("#ffa726")
			if i == _place_index:
				c.draw_arc(Vector2(hx, hy), rr + 4.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 1.5, true)
			c.draw_arc(Vector2(hx, hy), rr, 0.0, TAU, 48, hoop_col, 3.0, true)
			c.draw_circle(Vector2(hx, hy), 2.5, hoop_col)
			c.draw_string(ThemeDB.fallback_font, Vector2(hx + rr + 4.0, hy + 4.0), "H%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hoop_col)

	for L in model.landings:
		var lx: float = float(L.get("x", 0.0))
		c.draw_circle(Vector2(_origin.x + (lx / _world_w) * _plot_w, _origin.y), 4.0, Color("#ffeb3b"))

	var bx: float = _origin.x + (model.x / _world_w) * _plot_w
	var by: float = _origin.y - (model.y / _world_h) * _plot_h
	var ball := Vector2(bx, by)
	c.draw_circle(ball, 7.0, Color("#ef5350"))
	c.draw_circle(ball, 7.0, Color("#ffcdd2"), false, 1.5)

	if model.speed() > 0.15 and not model.resting:
		var scale_v: float = 0.35
		var tip_x: float = _origin.x + ((model.x + model.vx * scale_v) / _world_w) * _plot_w
		var tip_y: float = _origin.y - ((model.y + model.vy * scale_v) / _world_h) * _plot_h
		c.draw_line(ball, Vector2(tip_x, tip_y), Color("#ffeb3b"), 2.0)

	c.draw_circle(Vector2(_origin.x, _origin.y - (model.h0 / _world_h) * _plot_h), 4.0, Color("#90caf9"))

	c.draw_string(ThemeDB.fallback_font, Vector2(w - 140.0, 18.0), "- ideal", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))
	c.draw_string(ThemeDB.fallback_font, Vector2(w - 140.0, 34.0), "- simulated", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#42a5f5"))
	c.draw_string(ThemeDB.fallback_font, Vector2(w - 140.0, 50.0), "- ghost", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.5, 0.9, 0.8))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	match k:
		KEY_SPACE:
			_on_play()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_reset()
			get_viewport().set_input_as_handled()
		KEY_I:
			if _chk_ideal:
				_chk_ideal.button_pressed = not _chk_ideal.button_pressed
				_on_ideal_toggle(_chk_ideal.button_pressed)
			get_viewport().set_input_as_handled()
		KEY_1:
			_on_select_hoop(0)
			get_viewport().set_input_as_handled()
		KEY_2:
			_on_select_hoop(1)
			get_viewport().set_input_as_handled()
		KEY_S:
			_on_store_ghost()
			get_viewport().set_input_as_handled()
		KEY_G:
			_on_clear_ghost()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_back()
			get_viewport().set_input_as_handled()
