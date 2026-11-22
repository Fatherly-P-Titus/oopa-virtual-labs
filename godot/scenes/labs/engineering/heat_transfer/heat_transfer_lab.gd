extends LabShell
## Heat Transfer — steady 1D multilayer wall conduction (+ optional convection films).

var model: HeatTransferModel = HeatTransferModel.new()

var _stage: Control
var _graph: Control
var _show_graph: bool = true

var _slider_th: HSlider
var _slider_tc: HSlider
var _slider_hh: HSlider
var _slider_hc: HSlider
var _out_th: Label
var _out_tc: Label
var _out_hh: Label
var _out_hc: Label
var _chk_conv: CheckBox
var _slider_n: HSlider
var _out_n: Label

var _layer_boxes: Array = []  # per-layer UI roots
var _layers_host: VBoxContainer

var _r_q: Label
var _r_rtot: Label
var _r_dt: Label
var _r_ifaces: Label
var _status_hint: Label

var _result: Dictionary = {}
var _updating: bool = false


func _ready() -> void:
	lab_title = "Heat Transfer"
	lab_eyebrow = "ENGINEERING  /  HEAT TRANSFER"
	lab_lead = "Steady heat flow through a multilayer wall. Change materials, thickness and temperatures — watch q and the temperature drop."
	field_id = "engineering"
	page_id = "heat_transfer"
	back_label = "<- Engineering"
	super._ready()
	_build_stage()
	_build_sidebar()
	_rebuild_layer_ui()
	_solve_and_refresh()
	set_process_unhandled_input(true)


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "WallStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))

	var graph_card := PanelContainer.new()
	graph_card.theme_type_variation = &"Card"
	graph_card.custom_minimum_size = Vector2(0, 160)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(0, 140)
	_graph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_card.add_child(_graph)
	var extra := get_extra()
	if extra:
		extra.add_child(graph_card)
	_graph.draw.connect(Callable(self, "_draw_graph"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "PRESETS")
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	sb.add_child(prow)
	for item in [
		["Winter wall", "winter_wall"],
		["Bare brick", "bare_brick"],
		["Metal sheet", "metal_sheet"],
		["Glazing", "double_glaze"],
	]:
		var b := Button.new()
		b.text = str(item[0])
		b.theme_type_variation = &"Chip"
		var pid: String = str(item[1])
		b.pressed.connect(func(): _on_preset(pid))
		prow.add_child(b)

	_add_section(sb, "BOUNDARY")
	_chk_conv = CheckBox.new()
	_chk_conv.text = "Include surface convection films"
	_chk_conv.button_pressed = model.use_conv
	_chk_conv.toggled.connect(_on_conv)
	sb.add_child(_chk_conv)

	_out_th = Label.new()
	sb.add_child(_out_th)
	_slider_th = _make_slider(sb, -20.0, 80.0, model.t_hot, 1.0, _on_th)

	_out_tc = Label.new()
	sb.add_child(_out_tc)
	_slider_tc = _make_slider(sb, -40.0, 60.0, model.t_cold, 1.0, _on_tc)

	_out_hh = Label.new()
	sb.add_child(_out_hh)
	_slider_hh = _make_slider(sb, 1.0, 50.0, model.h_hot, 0.5, _on_hh)

	_out_hc = Label.new()
	sb.add_child(_out_hc)
	_slider_hc = _make_slider(sb, 1.0, 80.0, model.h_cold, 0.5, _on_hc)

	_add_section(sb, "LAYERS")
	_out_n = Label.new()
	sb.add_child(_out_n)
	_slider_n = _make_slider(sb, 1.0, 4.0, float(model.layers.size()), 1.0, _on_n)

	_layers_host = VBoxContainer.new()
	_layers_host.add_theme_constant_override("separation", 8)
	sb.add_child(_layers_host)

	_add_section(sb, "READOUTS")
	_r_q = _stat(sb, "Heat flux q")
	_r_rtot = _stat(sb, "R total")
	_r_dt = _stat(sb, "ΔT")
	_r_ifaces = Label.new()
	_r_ifaces.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_ifaces.add_theme_font_size_override("font_size", 12)
	sb.add_child(_r_ifaces)

	_status_hint = Label.new()
	_status_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_hint.add_theme_font_size_override("font_size", 12)
	_status_hint.text = "q = ΔT / ΣR. Insulation (low k) raises R and cuts heat loss."
	sb.add_child(_status_hint)

	var btn_graph := Button.new()
	btn_graph.text = "Toggle T-profile graph"
	btn_graph.theme_type_variation = &"GhostButton"
	btn_graph.pressed.connect(func():
		_show_graph = not _show_graph
		if _graph and _graph.get_parent():
			_graph.get_parent().visible = _show_graph
		if _graph:
			_graph.queue_redraw()
	)
	sb.add_child(btn_graph)


func _make_slider(parent: Control, mn: float, mx: float, val: float, step: float, cb: Callable) -> HSlider:
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
	sb.add_child(row)


func _stat(sb: VBoxContainer, title: String) -> Label:
	var card := PanelContainer.new()
	card.theme_type_variation = &"MetricCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cap := Label.new()
	cap.text = title
	cap.theme_type_variation = &"StatLabel"
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cap)
	var v := Label.new()
	v.theme_type_variation = &"StatValue"
	v.text = "—"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	card.add_child(row)
	sb.add_child(card)
	return v


func _rebuild_layer_ui() -> void:
	if _layers_host == null:
		return
	while _layers_host.get_child_count() > 0:
		var ch: Node = _layers_host.get_child(0)
		_layers_host.remove_child(ch)
		ch.free()
	_layer_boxes.clear()
	for i in range(model.layers.size()):
		_layers_host.add_child(_make_layer_row(i))


func _make_layer_row(i: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "Layer %d" % (i + 1)
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)

	var mats := HBoxContainer.new()
	mats.add_theme_constant_override("separation", 4)
	box.add_child(mats)
	var cur: String = str(model.layers[i].get("material", "brick"))
	for key in model.material_keys():
		var b := Button.new()
		var mat: Dictionary = HeatTransferModel.MATERIALS[key]
		b.text = str(mat["name"]).substr(0, 4)
		b.tooltip_text = "%s  k=%.3f W/m·K" % [mat["name"], mat["k"]]
		b.theme_type_variation = &"Chip"
		b.toggle_mode = true
		b.button_pressed = (key == cur)
		var k2: String = key
		var ii: int = i
		b.pressed.connect(func(): _on_mat(ii, k2))
		mats.add_child(b)

	var thick := Label.new()
	thick.name = "ThickLabel"
	thick.text = "L = %.0f mm" % (float(model.layers[i].get("L", 0.05)) * 1000.0)
	box.add_child(thick)
	var s := HSlider.new()
	s.min_value = 5.0
	s.max_value = 300.0
	s.step = 5.0
	s.value = float(model.layers[i].get("L", 0.05)) * 1000.0
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ii2: int = i
	s.value_changed.connect(func(v: float): _on_thick(ii2, v, thick))
	box.add_child(s)
	_layer_boxes.append(box)
	return box


func _on_preset(id: String) -> void:
	model.apply_preset(id)
	_updating = true
	_slider_th.value = model.t_hot
	_slider_tc.value = model.t_cold
	_slider_hh.value = model.h_hot
	_slider_hc.value = model.h_cold
	_chk_conv.button_pressed = model.use_conv
	_slider_n.value = float(model.layers.size())
	_updating = false
	_rebuild_layer_ui()
	_solve_and_refresh()
	set_status("Preset: %s" % id)


func _on_conv(on: bool) -> void:
	model.use_conv = on
	_solve_and_refresh()


func _on_th(v: float) -> void:
	if _updating:
		return
	model.t_hot = v
	_solve_and_refresh()


func _on_tc(v: float) -> void:
	if _updating:
		return
	model.t_cold = v
	_solve_and_refresh()


func _on_hh(v: float) -> void:
	if _updating:
		return
	model.h_hot = v
	_solve_and_refresh()


func _on_hc(v: float) -> void:
	if _updating:
		return
	model.h_cold = v
	_solve_and_refresh()


func _on_n(v: float) -> void:
	if _updating:
		return
	model.set_layer_count(int(v))
	_rebuild_layer_ui()
	_solve_and_refresh()


func _on_mat(i: int, key: String) -> void:
	model.set_layer_material(i, key)
	_rebuild_layer_ui()
	_solve_and_refresh()


func _on_thick(i: int, mm: float, lab: Label) -> void:
	model.set_layer_thickness(i, mm / 1000.0)
	if lab:
		lab.text = "L = %.0f mm" % mm
	_solve_and_refresh()


func _solve_and_refresh() -> void:
	_result = model.solve()
	_out_th.text = "T_hot (indoor) = %.0f °C" % model.t_hot
	_out_tc.text = "T_cold (outdoor) = %.0f °C" % model.t_cold
	_out_hh.text = "h_hot = %.1f W/m²K" % model.h_hot
	_out_hc.text = "h_cold = %.1f W/m²K" % model.h_cold
	_out_n.text = "Layers: %d" % model.layers.size()
	_slider_hh.visible = model.use_conv
	_slider_hc.visible = model.use_conv
	_out_hh.visible = model.use_conv
	_out_hc.visible = model.use_conv

	var q: float = float(_result.get("q", 0.0))
	var rt: float = float(_result.get("Rtot", 0.0))
	_r_q.text = "%.2f W/m²" % q
	_r_rtot.text = "%.3f m²K/W" % rt
	_r_dt.text = "%.1f K" % float(_result.get("dT", 0.0))

	var T: Array = _result.get("T", [])
	var labels: Array = _result.get("labels", [])
	var bits: PackedStringArray = PackedStringArray()
	for i in range(T.size()):
		if i == 0:
			bits.append("T0=%.1f°C" % float(T[i]))
		elif i <= labels.size():
			bits.append("→[%s]→ %.1f°C" % [str(labels[i - 1]), float(T[i])])
		else:
			bits.append("→ %.1f°C" % float(T[i]))
	_r_ifaces.text = " ".join(bits)

	set_status("q = ΔT/R = %.2f W/m² through the wall" % q)
	if _stage:
		_stage.queue_redraw()
	if _graph:
		_graph.queue_redraw()


func _draw_stage() -> void:
	if _stage == null or _result.is_empty():
		return
	var c := _stage
	var sz: Vector2 = c.size
	if sz.x < 10.0 or sz.y < 10.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#1a1a1e"))

	var layers: Array = _result.get("layers", [])
	var T: Array = _result.get("T", [])
	var q: float = float(_result.get("q", 0.0))

	# Layout: left room (hot) | wall stack | right outside (cold)
	var margin := 24.0
	var wall_h := minf(sz.y - 80.0, 220.0)
	var wall_y := (sz.y - wall_h) * 0.5
	var side_w := 70.0
	var wall_w := sz.x - margin * 2.0 - side_w * 2.0
	var wall_x := margin + side_w

	# Hot side air
	var hot_col := _temp_color(model.t_hot)
	c.draw_rect(Rect2(margin, wall_y, side_w - 8.0, wall_h), Color(hot_col, 0.35))
	c.draw_string(ThemeDB.fallback_font, Vector2(margin + 4.0, wall_y - 8.0), "HOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ef9a9a"))
	c.draw_string(ThemeDB.fallback_font, Vector2(margin + 4.0, wall_y + wall_h + 16.0), "%.0f°C" % model.t_hot, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffcdd2"))

	# Cold side
	var cold_col := _temp_color(model.t_cold)
	c.draw_rect(Rect2(wall_x + wall_w + 8.0, wall_y, side_w - 8.0, wall_h), Color(cold_col, 0.35))
	c.draw_string(ThemeDB.fallback_font, Vector2(wall_x + wall_w + 12.0, wall_y - 8.0), "COLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#90caf9"))
	c.draw_string(ThemeDB.fallback_font, Vector2(wall_x + wall_w + 12.0, wall_y + wall_h + 16.0), "%.0f°C" % model.t_cold, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#bbdefb"))

	# Layer widths proportional to thickness
	var Ltot := 0.0
	for ly in layers:
		Ltot += float(ly.get("L", 0.05))
	Ltot = maxf(Ltot, 1e-6)
	var x0 := wall_x
	# Temperature index offset if convection films present
	var t_idx := 1 if model.use_conv else 0
	for i in range(layers.size()):
		var ly: Dictionary = layers[i]
		var frac: float = float(ly.get("L", 0.05)) / Ltot
		var w: float = wall_w * frac
		var col: Color = ly.get("color", Color("#888888"))
		c.draw_rect(Rect2(x0, wall_y, w, wall_h), col.darkened(0.15))
		c.draw_rect(Rect2(x0, wall_y, w, wall_h), Color("#212121"), false, 2.0)
		# label
		var name: String = str(ly.get("name", "?"))
		if w > 28.0:
			c.draw_string(ThemeDB.fallback_font, Vector2(x0 + 4.0, wall_y + wall_h * 0.5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#212121"))
			c.draw_string(ThemeDB.fallback_font, Vector2(x0 + 4.0, wall_y + wall_h * 0.5 + 14.0), "%.0f mm" % (float(ly.get("L", 0)) * 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#424242"))
		# interface T after this layer
		var ti: int = t_idx + i + 1
		if ti < T.size() and w > 20.0:
			c.draw_string(ThemeDB.fallback_font, Vector2(x0 + w - 2.0, wall_y + 14.0), "%.1f°" % float(T[ti]), HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color("#212121"))
		x0 += w

	# Outer wall border
	c.draw_rect(Rect2(wall_x, wall_y, wall_w, wall_h), Color("#b22222"), false, 2.5)

	# Heat flux arrow
	var ay := wall_y + wall_h + 36.0
	var ax0 := wall_x
	var ax1 := wall_x + wall_w
	c.draw_line(Vector2(ax0, ay), Vector2(ax1, ay), Color("#ff8a65"), 3.0)
	c.draw_line(Vector2(ax1, ay), Vector2(ax1 - 12.0, ay - 7.0), Color("#ff8a65"), 3.0)
	c.draw_line(Vector2(ax1, ay), Vector2(ax1 - 12.0, ay + 7.0), Color("#ff8a65"), 3.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(wall_x, ay + 18.0), "Heat flux q = %.2f W/m²  (hot → cold)" % q, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffccbc"))


func _temp_color(t: float) -> Color:
	# map -20..60 to blue→red
	var u: float = clampf((t + 20.0) / 80.0, 0.0, 1.0)
	return Color(u, 0.25, 1.0 - u)


func _draw_graph() -> void:
	if _graph == null or _result.is_empty():
		return
	var c := _graph
	var sz: Vector2 = c.size
	if sz.x < 10.0 or sz.y < 10.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#121214"))
	var pad := 28.0
	var plot := Rect2(pad, 16.0, sz.x - pad * 2.0, sz.y - 40.0)
	c.draw_rect(plot, Color("#1e1e22"))

	var T: Array = _result.get("T", [])
	var x: Array = _result.get("x", [])
	if T.size() < 2 or x.size() != T.size():
		return
	var tmin: float = float(T[0])
	var tmax: float = float(T[0])
	for tv in T:
		tmin = minf(tmin, float(tv))
		tmax = maxf(tmax, float(tv))
	if absf(tmax - tmin) < 1e-6:
		tmax = tmin + 1.0

	# axes
	c.draw_line(plot.position, plot.position + Vector2(0, plot.size.y), Color("#546e7a"), 1.0)
	c.draw_line(plot.position + Vector2(0, plot.size.y), plot.position + Vector2(plot.size.x, plot.size.y), Color("#546e7a"), 1.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, 12.0), "T (°C) vs path (resistance share)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(T.size()):
		var px: float = plot.position.x + float(x[i]) * plot.size.x
		var py: float = plot.position.y + (1.0 - (float(T[i]) - tmin) / (tmax - tmin)) * plot.size.y
		pts.append(Vector2(px, py))
	if pts.size() >= 2:
		c.draw_polyline(pts, Color("#b22222"), 2.5, true)
	for p in pts:
		c.draw_circle(p, 3.5, Color("#ef5350"))

	c.draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, plot.end.y + 14.0), "Hot", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ef9a9a"))
	c.draw_string(ThemeDB.fallback_font, Vector2(plot.end.x - 24.0, plot.end.y + 14.0), "Cold", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#90caf9"))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_on_preset("winter_wall")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			# router back handled by shell often
			pass
