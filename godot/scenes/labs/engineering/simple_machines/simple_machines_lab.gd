extends LabShell
## Simple Machines — lever, incline, pulley, wheel & axle.

var model: SimpleMachinesModel = SimpleMachinesModel.new()

var _stage: Control

var _s_load: HSlider
var _s_eta: HSlider
var _s_dl: HSlider
var _s_de: HSlider
var _s_ang: HSlider
var _s_mu: HSlider
var _s_strands: HSlider
var _s_R: HSlider
var _s_r: HSlider

var _o_load: Label
var _o_eta: Label
var _o_dl: Label
var _o_de: Label
var _o_ang: Label
var _o_mu: Label
var _o_strands: Label
var _o_R: Label
var _o_r: Label

var _box_lever: VBoxContainer
var _box_incline: VBoxContainer
var _box_pulley: VBoxContainer
var _box_wheel: VBoxContainer

var _r_ma_i: Label
var _r_ma_a: Label
var _r_eff_i: Label
var _r_eff_a: Label
var _r_note: Label

var _result: Dictionary = {}
var _updating: bool = false
var _anim_t: float = 0.0


func _ready() -> void:
	lab_title = "Simple Machines"
	lab_eyebrow = "ENGINEERING  /  SIMPLE MACHINES"
	lab_lead = "Mechanical advantage: levers, ramps, pulleys, and wheel-and-axle. Ideal vs real effort."
	field_id = "engineering"
	page_id = "simple_machines"
	back_label = "<- Engineering"
	super._ready()
	_build_stage()
	_build_sidebar()
	_on_kind(SimpleMachinesModel.Kind.LEVER)
	set_process(true)


func _process(delta: float) -> void:
	_anim_t += delta
	if _stage:
		_stage.queue_redraw()


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "MachineStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "MACHINE")
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 6)
	sb.add_child(kinds)
	for item in [
		["Lever", SimpleMachinesModel.Kind.LEVER],
		["Incline", SimpleMachinesModel.Kind.INCLINE],
		["Pulley", SimpleMachinesModel.Kind.PULLEY],
		["Wheel", SimpleMachinesModel.Kind.WHEEL_AXLE],
	]:
		var b := Button.new()
		b.text = str(item[0])
		b.theme_type_variation = &"Chip"
		var k: int = int(item[1])
		b.pressed.connect(func(): _on_kind(k))
		kinds.add_child(b)

	_add_section(sb, "PRESETS")
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	sb.add_child(prow)
	for item in [["Crowbar", "crowbar"], ["Wheelbarrow", "wheelbarrow"], ["Ramp", "ramp"], ["Block & tackle", "block_tackle"], ["Well wheel", "well_wheel"]]:
		var b2 := Button.new()
		b2.text = str(item[0])
		b2.theme_type_variation = &"Chip"
		var id: String = str(item[1])
		b2.pressed.connect(func(): _on_preset(id))
		prow.add_child(b2)

	_add_section(sb, "SHARED")
	_o_load = Label.new()
	sb.add_child(_o_load)
	_s_load = _slider(sb, 10.0, 1000.0, model.load_w, 10.0, _on_load)
	_o_eta = Label.new()
	sb.add_child(_o_eta)
	_s_eta = _slider(sb, 0.05, 1.0, model.eta, 0.01, _on_eta)

	_box_lever = VBoxContainer.new()
	sb.add_child(_box_lever)
	_add_section(_box_lever, "LEVER ARMS")
	_o_dl = Label.new()
	_box_lever.add_child(_o_dl)
	_s_dl = _slider(_box_lever, 0.05, 2.0, model.d_load, 0.05, _on_dl)
	_o_de = Label.new()
	_box_lever.add_child(_o_de)
	_s_de = _slider(_box_lever, 0.05, 3.0, model.d_effort, 0.05, _on_de)
	var cls_row := HBoxContainer.new()
	_box_lever.add_child(cls_row)
	for c in [1, 2, 3]:
		var bc := Button.new()
		bc.text = "Class %d" % c
		bc.theme_type_variation = &"Chip"
		var cc: int = c
		bc.pressed.connect(func(): _on_class(cc))
		cls_row.add_child(bc)

	_box_incline = VBoxContainer.new()
	sb.add_child(_box_incline)
	_add_section(_box_incline, "INCLINE")
	_o_ang = Label.new()
	_box_incline.add_child(_o_ang)
	_s_ang = _slider(_box_incline, 5.0, 60.0, model.angle_deg, 1.0, _on_ang)
	_o_mu = Label.new()
	_box_incline.add_child(_o_mu)
	_s_mu = _slider(_box_incline, 0.0, 0.8, model.mu, 0.01, _on_mu)

	_box_pulley = VBoxContainer.new()
	sb.add_child(_box_pulley)
	_add_section(_box_pulley, "PULLEY")
	_o_strands = Label.new()
	_box_pulley.add_child(_o_strands)
	_s_strands = _slider(_box_pulley, 1.0, 8.0, float(model.strands), 1.0, _on_strands)

	_box_wheel = VBoxContainer.new()
	sb.add_child(_box_wheel)
	_add_section(_box_wheel, "WHEEL & AXLE")
	_o_R = Label.new()
	_box_wheel.add_child(_o_R)
	_s_R = _slider(_box_wheel, 0.05, 0.6, model.R_wheel, 0.01, _on_R)
	_o_r = Label.new()
	_box_wheel.add_child(_o_r)
	_s_r = _slider(_box_wheel, 0.01, 0.25, model.r_axle, 0.005, _on_r)

	_add_section(sb, "READOUTS")
	_r_ma_i = _stat(sb, "MA ideal")
	_r_ma_a = _stat(sb, "MA actual")
	_r_eff_i = _stat(sb, "Effort ideal")
	_r_eff_a = _stat(sb, "Effort actual")
	_r_note = Label.new()
	_r_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_note.add_theme_font_size_override("font_size", 12)
	sb.add_child(_r_note)


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


func _add_section(parent: Control, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(3, 16)
	marker.color = Color("#F2A84A")
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"Eyebrow"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	parent.add_child(row)


func _stat(sb: VBoxContainer, title: String) -> Label:
	var card := PanelContainer.new()
	card.theme_type_variation = &"MetricCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var c := Label.new()
	c.text = title
	c.theme_type_variation = &"StatLabel"
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	var v := Label.new()
	v.theme_type_variation = &"StatValue"
	v.text = "—"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	card.add_child(row)
	sb.add_child(card)
	return v


func _on_kind(k: int) -> void:
	model.set_kind(k)
	_box_lever.visible = k == SimpleMachinesModel.Kind.LEVER
	_box_incline.visible = k == SimpleMachinesModel.Kind.INCLINE
	_box_pulley.visible = k == SimpleMachinesModel.Kind.PULLEY
	_box_wheel.visible = k == SimpleMachinesModel.Kind.WHEEL_AXLE
	_solve_and_refresh()


func _on_preset(id: String) -> void:
	model.apply_preset(id)
	_on_kind(model.kind)
	_sync_sliders()
	_solve_and_refresh()
	set_status("Preset: %s" % id)


func _sync_sliders() -> void:
	_updating = true
	_s_load.value = model.load_w
	_s_eta.value = model.eta
	_s_dl.value = model.d_load
	_s_de.value = model.d_effort
	_s_ang.value = model.angle_deg
	_s_mu.value = model.mu
	_s_strands.value = float(model.strands)
	_s_R.value = model.R_wheel
	_s_r.value = model.r_axle
	_updating = false


func _on_load(v: float) -> void:
	if _updating: return
	model.load_w = v
	_solve_and_refresh()


func _on_eta(v: float) -> void:
	if _updating: return
	model.eta = v
	_solve_and_refresh()


func _on_dl(v: float) -> void:
	if _updating: return
	model.d_load = v
	_solve_and_refresh()


func _on_de(v: float) -> void:
	if _updating: return
	model.d_effort = v
	_solve_and_refresh()


func _on_class(c: int) -> void:
	model.lever_class = c
	_solve_and_refresh()


func _on_ang(v: float) -> void:
	if _updating: return
	model.angle_deg = v
	_solve_and_refresh()


func _on_mu(v: float) -> void:
	if _updating: return
	model.mu = v
	_solve_and_refresh()


func _on_strands(v: float) -> void:
	if _updating: return
	model.strands = int(v)
	_solve_and_refresh()


func _on_R(v: float) -> void:
	if _updating: return
	model.R_wheel = v
	_solve_and_refresh()


func _on_r(v: float) -> void:
	if _updating: return
	model.r_axle = v
	_solve_and_refresh()


func _solve_and_refresh() -> void:
	_result = model.solve()
	_o_load.text = "Load W = %.0f N" % model.load_w
	_o_eta.text = "Efficiency η = %.0f%%" % (model.eta * 100.0)
	_o_dl.text = "Load arm d_L = %.2f m" % model.d_load
	_o_de.text = "Effort arm d_E = %.2f m" % model.d_effort
	_o_ang.text = "Angle = %.0f°" % model.angle_deg
	_o_mu.text = "Friction μ = %.2f" % model.mu
	_o_strands.text = "Supporting strands = %d" % model.strands
	_o_R.text = "Wheel radius R = %.0f cm" % (model.R_wheel * 100.0)
	_o_r.text = "Axle radius r = %.0f cm" % (model.r_axle * 100.0)

	_r_ma_i.text = "%.2f" % float(_result.get("maIdeal", 0.0))
	_r_ma_a.text = "%.2f" % float(_result.get("maActual", 0.0))
	_r_eff_i.text = "%.1f N" % float(_result.get("effortIdeal", 0.0))
	_r_eff_a.text = "%.1f N" % float(_result.get("effortActual", 0.0))

	match model.kind:
		SimpleMachinesModel.Kind.LEVER:
			_r_note.text = "Class %d lever · MA ≈ d_E / d_L. Longer effort arm → less effort." % model.lever_class
		SimpleMachinesModel.Kind.INCLINE:
			_r_note.text = "Gentler slope (smaller angle) raises MA. Friction increases required effort."
		SimpleMachinesModel.Kind.PULLEY:
			_r_note.text = "Ideal MA equals number of strands supporting the load."
		SimpleMachinesModel.Kind.WHEEL_AXLE:
			_r_note.text = "MA ≈ R / r. Large wheel, small axle → less effort on the rim."

	set_status("MA actual = %.2f · effort = %.1f N" % [float(_result.get("maActual", 0.0)), float(_result.get("effortActual", 0.0))])
	if _stage:
		_stage.queue_redraw()


func _draw_stage() -> void:
	if _stage == null:
		return
	var c := _stage
	var sz: Vector2 = c.size
	if sz.x < 20.0 or sz.y < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#141418"))
	match model.kind:
		SimpleMachinesModel.Kind.LEVER:
			_draw_lever(c, sz)
		SimpleMachinesModel.Kind.INCLINE:
			_draw_incline(c, sz)
		SimpleMachinesModel.Kind.PULLEY:
			_draw_pulley(c, sz)
		SimpleMachinesModel.Kind.WHEEL_AXLE:
			_draw_wheel(c, sz)


func _draw_lever(c: Control, sz: Vector2) -> void:
	var mid := Vector2(sz.x * 0.5, sz.y * 0.55)
	var de: float = model.d_effort
	var dl: float = model.d_load
	var scale: float = 140.0 / maxf(de + dl, 0.5)
	# Class placement of fulcrum / load / effort
	var fulcrum: Vector2
	var load_pt: Vector2
	var effort_pt: Vector2
	match model.lever_class:
		2:  # load between fulcrum and effort
			fulcrum = mid + Vector2(- (de) * scale * 0.5, 0)
			load_pt = fulcrum + Vector2(dl * scale, 0)
			effort_pt = fulcrum + Vector2(de * scale, 0)
		3:  # effort between fulcrum and load
			fulcrum = mid + Vector2(- (dl) * scale * 0.5, 0)
			effort_pt = fulcrum + Vector2(de * scale, 0)
			load_pt = fulcrum + Vector2(dl * scale, 0)
		_:  # class 1: fulcrum between
			fulcrum = mid
			load_pt = fulcrum + Vector2(-dl * scale, 0)
			effort_pt = fulcrum + Vector2(de * scale, 0)

	# Beveled beam profile; force positions still follow the existing lever geometry.
	c.draw_line(load_pt + Vector2(0, -2), effort_pt + Vector2(0, -2), Color(0.0, 0.0, 0.0, 0.3), 13.0)
	c.draw_line(load_pt + Vector2(0, -7), effort_pt + Vector2(0, -7), Color("#607d8b"), 11.0)
	c.draw_line(load_pt + Vector2(0, -9), effort_pt + Vector2(0, -9), Color("#dce7eb"), 4.0)
	# Fulcrum triangle
	var tri := PackedVector2Array([fulcrum + Vector2(0, 4), fulcrum + Vector2(-14, 28), fulcrum + Vector2(14, 28)])
	c.draw_colored_polygon(PackedVector2Array([tri[0] + Vector2(3, 3), tri[1] + Vector2(3, 3), tri[2] + Vector2(3, 3)]), Color(0.0, 0.0, 0.0, 0.25))
	c.draw_colored_polygon(tri, Color("#b22222"))
	c.draw_line(tri[1] + Vector2(3, -1), tri[0] + Vector2(0, 2), Color("#ef9a9a"), 2.0)
	c.draw_string(ThemeDB.fallback_font, fulcrum + Vector2(-20, 46), "Fulcrum", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ef9a9a"))

	# Load box
	c.draw_rect(Rect2(load_pt + Vector2(-13, -37), Vector2(32, 28)), Color(0.0, 0.0, 0.0, 0.25), true)
	c.draw_rect(Rect2(load_pt + Vector2(-16, -40), Vector2(32, 28)), Color("#ef6c00"))
	c.draw_line(load_pt + Vector2(-14, -38), load_pt + Vector2(14, -38), Color("#ffcc80"), 2.0)
	c.draw_string(ThemeDB.fallback_font, load_pt + Vector2(-18, -48), "LOAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffcc80"))
	c.draw_string(ThemeDB.fallback_font, load_pt + Vector2(-20, 20), "%.0f N" % model.load_w, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffe0b2"))
	c.draw_line(load_pt, load_pt + Vector2(0, -12), Color("#ffb74d"), 2.0)

	# Effort arrow
	var bob: float = sin(_anim_t * 3.0) * 4.0
	c.draw_line(effort_pt + Vector2(0, -8), effort_pt + Vector2(0, -36 + bob), Color("#66bb6a"), 3.0)
	c.draw_line(effort_pt + Vector2(0, -36 + bob), effort_pt + Vector2(-8, -24 + bob), Color("#66bb6a"), 3.0)
	c.draw_line(effort_pt + Vector2(0, -36 + bob), effort_pt + Vector2(8, -24 + bob), Color("#66bb6a"), 3.0)
	c.draw_string(ThemeDB.fallback_font, effort_pt + Vector2(-24, -48 + bob), "EFFORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a5d6a7"))
	c.draw_string(ThemeDB.fallback_font, effort_pt + Vector2(-20, 20), "%.0f N" % float(_result.get("effortActual", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#c8e6c9"))

	c.draw_string(ThemeDB.fallback_font, Vector2(24, 28), "Class %d lever · d_L=%.2fm · d_E=%.2fm" % [model.lever_class, dl, de], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))


func _draw_incline(c: Control, sz: Vector2) -> void:
	var base := Vector2(60, sz.y * 0.75)
	var run: float = minf(sz.x - 120.0, 360.0)
	var ang: float = deg_to_rad(model.angle_deg)
	var rise: float = run * tan(ang)
	rise = minf(rise, sz.y * 0.55)
	run = rise / maxf(tan(ang), 0.01)
	var top := base + Vector2(run, -rise)
	c.draw_line(base + Vector2(3, 4), top + Vector2(3, 4), Color(0.0, 0.0, 0.0, 0.3), 12.0)
	c.draw_line(base, top, Color("#546e7a"), 10.0)
	c.draw_line(base + Vector2(0, -2), top + Vector2(0, -2), Color("#cfd8dc"), 4.0)
	c.draw_line(base, base + Vector2(run, 0), Color("#546e7a"), 2.0)
	# Ramp fill
	var poly := PackedVector2Array([base, top, base + Vector2(run, 0)])
	c.draw_colored_polygon(poly, Color("#37474f", 0.5))
	# Load on ramp
	var u: float = 0.55 + 0.08 * sin(_anim_t * 2.0)
	var pos: Vector2 = base.lerp(top, u)
	c.draw_rect(Rect2(pos + Vector2(-11, -25), Vector2(28, 24)), Color(0.0, 0.0, 0.0, 0.25), true)
	c.draw_rect(Rect2(pos + Vector2(-14, -28), Vector2(28, 24)), Color("#ef6c00"))
	c.draw_line(pos + Vector2(-12, -26), pos + Vector2(12, -26), Color("#ffcc80"), 2.0)
	c.draw_string(ThemeDB.fallback_font, pos + Vector2(-18, -36), "LOAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffcc80"))
	# Effort along slope
	var dir: Vector2 = (top - base).normalized()
	var e0: Vector2 = pos + dir * 20.0
	var e1: Vector2 = e0 + dir * 40.0
	c.draw_line(e0, e1, Color("#66bb6a"), 3.0)
	c.draw_string(ThemeDB.fallback_font, e1 + Vector2(4, 0), "effort %.0f N" % float(_result.get("effortActual", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a5d6a7"))
	c.draw_string(ThemeDB.fallback_font, Vector2(24, 28), "θ = %.0f° · μ = %.2f · MA = %.2f" % [model.angle_deg, model.mu, float(_result.get("maActual", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))


func _draw_pulley(c: Control, sz: Vector2) -> void:
	var cx: float = sz.x * 0.5
	var top_y: float = sz.y * 0.22
	var n: int = model.strands
	# Fixed support
	c.draw_line(Vector2(cx - 50, top_y - 20), Vector2(cx + 50, top_y - 20), Color("#90a4ae"), 4.0)
	# Sheaves
	var sheave_r := 22.0
	c.draw_circle(Vector2(cx, top_y + 10), sheave_r, Color("#455a64"))
	c.draw_circle(Vector2(cx, top_y + 10), sheave_r, Color("#cfd8dc"), false, 2.0)
	c.draw_circle(Vector2(cx, top_y + 10), sheave_r - 5.0, Color("#78909c"), false, 1.0)
	c.draw_circle(Vector2(cx, top_y + 10), 5.0, Color("#263238"))
	if n >= 2:
		c.draw_circle(Vector2(cx, top_y + 70), sheave_r * 0.9, Color("#546e7a"))
		c.draw_circle(Vector2(cx, top_y + 70), sheave_r * 0.9, Color("#cfd8dc"), false, 2.0)
		c.draw_circle(Vector2(cx, top_y + 70), sheave_r * 0.9 - 5.0, Color("#90a4ae"), false, 1.0)
		c.draw_circle(Vector2(cx, top_y + 70), 5.0, Color("#263238"))
	# Strands
	for i in range(mini(n, 6)):
		var ox: float = -18.0 + float(i) * 8.0
		c.draw_line(Vector2(cx + ox, top_y + 10), Vector2(cx + ox, top_y + 130), Color("#ffe082"), 2.0)
	# Load
	var ly: float = top_y + 150 + 6.0 * sin(_anim_t * 2.5)
	c.draw_rect(Rect2(cx - 19, ly + 3.0, 44, 36), Color(0.0, 0.0, 0.0, 0.25), true)
	c.draw_rect(Rect2(cx - 22, ly, 44, 36), Color("#ef6c00"))
	c.draw_line(Vector2(cx - 20.0, ly + 2.0), Vector2(cx + 20.0, ly + 2.0), Color("#ffcc80"), 2.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(cx - 20, ly + 52), "%.0f N" % model.load_w, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffe0b2"))
	# Effort free end
	c.draw_line(Vector2(cx + 36, top_y + 10), Vector2(cx + 70, top_y + 100), Color("#66bb6a"), 3.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(cx + 74, top_y + 110), "effort %.0f N" % float(_result.get("effortActual", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a5d6a7"))
	c.draw_string(ThemeDB.fallback_font, Vector2(24, 28), "%d strands · MA ideal = %d" % [n, n], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))


func _draw_wheel(c: Control, sz: Vector2) -> void:
	var center := Vector2(sz.x * 0.45, sz.y * 0.5)
	var R: float = clampf(model.R_wheel * 280.0, 40.0, 110.0)
	var r: float = clampf(model.r_axle * 280.0, 10.0, R * 0.6)
	# Wheel
	c.draw_circle(center, R, Color("#37474f"))
	c.draw_circle(center, R, Color("#90caf9"), false, 3.0)
	c.draw_circle(center, R - 6.0, Color("#78909c"), false, 1.0)
	c.draw_arc(center + Vector2(-2.0, -2.0), R - 4.0, PI * 1.1, PI * 1.85, 32, Color(0.82, 0.91, 0.96, 0.65), 2.0, true)
	c.draw_circle(center, r, Color("#b22222"))
	c.draw_circle(center, r, Color("#ef9a9a"), false, 2.0)
	c.draw_circle(center, maxf(r - 4.0, 2.0), Color("#263238"), false, 1.0)
	# Spokes spin
	for i in range(6):
		var a: float = _anim_t * 1.2 + float(i) * PI / 3.0
		c.draw_line(center, center + Vector2(cos(a), sin(a)) * R * 0.92, Color("#546e7a"), 2.0)
	# Load on axle
	c.draw_line(center + Vector2(0, r), center + Vector2(0, r + 50), Color("#ffb74d"), 2.0)
	c.draw_rect(Rect2(center + Vector2(-16, r + 50), Vector2(32, 28)), Color("#ef6c00"))
	c.draw_string(ThemeDB.fallback_font, center + Vector2(24, r + 70), "load %.0f N" % model.load_w, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffe0b2"))
	# Effort on rim
	var a2: float = -0.4
	var rim: Vector2 = center + Vector2(cos(a2), sin(a2)) * R
	c.draw_line(rim, rim + Vector2(40, -20), Color("#66bb6a"), 3.0)
	c.draw_string(ThemeDB.fallback_font, rim + Vector2(44, -24), "effort %.0f N" % float(_result.get("effortActual", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a5d6a7"))
	c.draw_string(ThemeDB.fallback_font, Vector2(24, 28), "R=%.0f cm · r=%.0f cm · MA≈R/r" % [model.R_wheel * 100.0, model.r_axle * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))
