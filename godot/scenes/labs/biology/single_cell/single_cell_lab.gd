extends LabShell
## Single-Celled Organisms — Phase 2: draw cells + transport + env sliders.

var model: SingleCellModel = SingleCellModel.new()

var _stage: Control
var _scroll: ScrollContainer
var _btn_play: Button
var _o_tick: Label
var _o_pop: Label
var _o_t: Label
var _o_ph: Label
var _o_vis: Label
var _o_ox: Label
var _s_t: HSlider
var _s_ph: HSlider
var _s_vis: HSlider
var _s_ox: HSlider
var _updating: bool = false
var _acc: float = 0.0
const STEPS_PER_SEC: float = 12.0

var _show_food: bool = true
var _show_waste: bool = false
var _chk_food: CheckBox
var _chk_waste: CheckBox
var _o_food: Label

var _graph: Control
var _type_labels: Dictionary = {}  # typeId -> Label

# Phase 5 — camera + possession
var _zoom: float = 1.0
var _cam_x: float = 0.0  # world-space pan (top-left of view in world coords when zoomed)
var _cam_y: float = 0.0
var _possess_id: int = -1
var _o_possess: Label
var _s_zoom: HSlider
var _o_zoom: Label
var _drag_pan: bool = false
var _drag_last: Vector2 = Vector2.ZERO


func _ready() -> void:
	lab_title = "Single-Celled Organisms"
	lab_eyebrow = "BIOLOGY  /  SINGLE-CELL"
	lab_lead = "Agent cells in a media bath. Play the sim, change temperature, pH and oxygen, watch populations respond."
	field_id = "biology"
	page_id = "single_cell"
	back_label = "<- Biology"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.reset(30.0, 0.0)
	_sync_sliders()
	_refresh_labels()
	set_process(true)
	set_status("Paused · press Play to run metabolism, motion and division.")


func _process(delta: float) -> void:
	if not model.running:
		return
	_acc += delta * STEPS_PER_SEC
	var guard: int = 0
	while _acc >= 1.0 and guard < 4:
		_acc -= 1.0
		guard += 1
		model.step()
	_refresh_labels()
	if _stage:
		_stage.queue_redraw()


func _build_stage() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "WorldScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_stage(_scroll)

	_stage = Control.new()
	_stage.name = "CellStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	_stage.draw.connect(Callable(self, "_draw_stage"))
	_update_stage_size()
	_scroll.add_child(_stage)

	var graph_card := PanelContainer.new()
	graph_card.theme_type_variation = &"Card"
	graph_card.custom_minimum_size = Vector2(0, 150)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(0, 130)
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
	for item in [["Aqueous", "aqueous"], ["Hot Spring", "hot_spring"], ["Agar Plate", "agar"]]:
		var bp := Button.new()
		bp.text = str(item[0])
		bp.theme_type_variation = &"Chip"
		var pid: String = str(item[1])
		bp.pressed.connect(func(): _on_preset(pid))
		prow.add_child(bp)

	_add_section(sb, "TRANSPORT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	sb.add_child(row)
	_btn_play = Button.new()
	_btn_play.text = "Play"
	_btn_play.pressed.connect(_on_play)
	row.add_child(_btn_play)
	var b_step := Button.new()
	b_step.text = "Step"
	b_step.theme_type_variation = &"GhostButton"
	b_step.pressed.connect(_on_step)
	row.add_child(b_step)
	var b_reset := Button.new()
	b_reset.text = "Reset"
	b_reset.theme_type_variation = &"GhostButton"
	b_reset.pressed.connect(_on_reset)
	row.add_child(b_reset)

	_o_tick = Label.new()
	_o_pop = Label.new()
	var observation_card := PanelContainer.new()
	observation_card.theme_type_variation = &"MetricCard"
	var observation_stack := VBoxContainer.new()
	observation_stack.add_theme_constant_override("separation", 4)
	_o_tick.add_theme_color_override("font_color", Color("#66758A"))
	_o_pop.add_theme_font_size_override("font_size", 18)
	_o_pop.add_theme_color_override("font_color", Color("#101827"))
	observation_stack.add_child(_o_tick)
	observation_stack.add_child(_o_pop)
	observation_card.add_child(observation_stack)
	sb.add_child(observation_card)

	_add_section(sb, "CAMERA")
	_o_zoom = Label.new()
	sb.add_child(_o_zoom)
	_s_zoom = _slider(sb, 1.0, 8.0, 1.0, 0.25, _on_zoom)
	var cam_row := HBoxContainer.new()
	cam_row.add_theme_constant_override("separation", 6)
	sb.add_child(cam_row)
	var bz := Button.new()
	bz.text = "Zoom +"
	bz.theme_type_variation = &"GhostButton"
	bz.pressed.connect(func(): _set_zoom(_zoom + 0.5))
	cam_row.add_child(bz)
	var bz2 := Button.new()
	bz2.text = "Zoom −"
	bz2.theme_type_variation = &"GhostButton"
	bz2.pressed.connect(func(): _set_zoom(_zoom - 0.5))
	cam_row.add_child(bz2)
	var br := Button.new()
	br.text = "Reset view"
	br.theme_type_variation = &"GhostButton"
	br.pressed.connect(_reset_camera)
	cam_row.add_child(br)

	_o_possess = Label.new()
	_o_possess.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_o_possess.add_theme_font_size_override("font_size", 12)
	_o_possess.text = "Possess: none (click a cell)"
	sb.add_child(_o_possess)
	var bex := Button.new()
	bex.text = "Exit possession"
	bex.theme_type_variation = &"GhostButton"
	bex.pressed.connect(_exit_possess)
	sb.add_child(bex)

	_add_section(sb, "MEDIA")
	_o_t = Label.new()
	sb.add_child(_o_t)
	_s_t = _slider(sb, 5.0, 55.0, model.temperature, 0.5, _on_t)
	_o_ph = Label.new()
	sb.add_child(_o_ph)
	_s_ph = _slider(sb, 4.0, 10.0, model.pH, 0.1, _on_ph)
	_o_vis = Label.new()
	sb.add_child(_o_vis)
	_s_vis = _slider(sb, 0.4, 3.0, model.viscosity, 0.05, _on_vis)
	_o_ox = Label.new()
	sb.add_child(_o_ox)
	_s_ox = _slider(sb, 0.0, 1.5, model.oxygen, 0.05, _on_ox)

	_add_section(sb, "FOOD / WASTE")
	_chk_food = CheckBox.new()
	_chk_food.text = "Show food patches"
	_chk_food.button_pressed = true
	_chk_food.toggled.connect(func(on: bool):
		_show_food = on
		if _stage:
			_stage.queue_redraw()
	)
	sb.add_child(_chk_food)
	_chk_waste = CheckBox.new()
	_chk_waste.text = "Show waste heatmap"
	_chk_waste.button_pressed = false
	_chk_waste.toggled.connect(func(on: bool):
		_show_waste = on
		if _stage:
			_stage.queue_redraw()
	)
	sb.add_child(_chk_waste)

	var food_row := HBoxContainer.new()
	food_row.add_theme_constant_override("separation", 6)
	sb.add_child(food_row)
	var b_food := Button.new()
	b_food.text = "+ Food (center)"
	b_food.pressed.connect(_on_add_food_center)
	food_row.add_child(b_food)
	var b_food2 := Button.new()
	b_food2.text = "+ Food (scatter)"
	b_food2.theme_type_variation = &"GhostButton"
	b_food2.pressed.connect(_on_add_food_scatter)
	food_row.add_child(b_food2)
	_o_food = Label.new()
	_o_food.add_theme_font_size_override("font_size", 11)
	sb.add_child(_o_food)

	_add_section(sb, "TYPES (live)")
	_type_labels.clear()
	for tid in model.type_ids():
		var tdef: Dictionary = SingleCellModel.CELL_TYPES[tid]
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", tdef["color"] as Color)
		l.text = "%s: 0" % str(tdef["name"])
		sb.add_child(l)
		_type_labels[str(tid)] = l
		var desc := Label.new()
		desc.text = "  %s" % str(tdef["description"])
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		sb.add_child(desc)

	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.text = "Click a cell to possess it. Scroll wheel or sliders to zoom. Drag empty space to pan when zoomed."
	sb.add_child(tip)


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


func _add_section(sb: VBoxContainer, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(3, 16)
	marker.color = Color("#67C49A")
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"Eyebrow"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	sb.add_child(row)


func _sync_sliders() -> void:
	_updating = true
	_s_t.value = model.temperature
	_s_ph.value = model.pH
	_s_vis.value = model.viscosity
	_s_ox.value = model.oxygen
	_updating = false


func _on_preset(id: String) -> void:
	model.running = false
	if _btn_play:
		_btn_play.text = "Play"
	model.apply_preset_id(id)
	_exit_possess()
	_reset_camera()
	_sync_sliders()
	_refresh_labels()
	if _stage:
		_stage.queue_redraw()
	if _graph:
		_graph.queue_redraw()
	set_status("Preset: %s · %d cells" % [id, model.cell_count()])


func _on_play() -> void:
	model.running = not model.running
	_btn_play.text = "Pause" if model.running else "Play"
	set_status("Running…" if model.running else "Paused")


func _on_step() -> void:
	if model.running:
		model.running = false
		_btn_play.text = "Play"
	model.step()
	_refresh_labels()
	if _stage:
		_stage.queue_redraw()
	set_status("Step · tick %d · pop %d" % [model.tick, model.cell_count()])


func _on_reset() -> void:
	model.running = false
	_btn_play.text = "Play"
	model.reset(30.0, 0.0)
	_sync_sliders()
	_refresh_labels()
	if _stage:
		_stage.queue_redraw()
	set_status("Reset · %d cells seeded" % model.cell_count())


func _on_t(v: float) -> void:
	if _updating: return
	model.temperature = v
	_refresh_labels()


func _on_ph(v: float) -> void:
	if _updating: return
	model.pH = v
	_refresh_labels()


func _on_vis(v: float) -> void:
	if _updating: return
	model.viscosity = v
	_refresh_labels()


func _on_ox(v: float) -> void:
	if _updating: return
	model.oxygen = v
	_refresh_labels()


func _refresh_labels() -> void:
	_o_tick.text = "Tick: %d" % model.tick
	_o_pop.text = "Population: %d" % model.cell_count()
	_o_t.text = "Temperature = %.1f °C" % model.temperature
	_o_ph.text = "pH = %.1f" % model.pH
	_o_vis.text = "Viscosity = %.2f" % model.viscosity
	_o_ox.text = "Oxygen = %.2f" % model.oxygen
	if _o_food:
		_o_food.text = "Food field total ≈ %.1f" % _food_total()
	var counts: Dictionary = model.count_by_type()
	for tid in _type_labels.keys():
		var lab: Label = _type_labels[tid]
		var n: int = int(counts.get(tid, 0))
		var nm: String = str(SingleCellModel.CELL_TYPES[tid]["name"])
		lab.text = "%s: %d" % [nm, n]
	if _graph:
		_graph.queue_redraw()
	_update_possess_label()
	if _o_zoom:
		_o_zoom.text = "Zoom = %.1f×" % _zoom


func _draw_stage() -> void:
	if _stage == null:
		return
	var c := _stage
	var sz: Vector2 = c.size
	if sz.x < 20.0 or sz.y < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#0a0a0a"))

	var xform: Dictionary = _view_xform(sz)
	var scale: float = float(xform["scale"])
	var ox: float = float(xform["ox"])
	var oy: float = float(xform["oy"])
	var cell_px: float = SingleCellModel.GRID_RES * scale

	c.draw_rect(Rect2(ox, oy, SingleCellModel.WORLD_W * scale, SingleCellModel.WORLD_H * scale), Color("#0e0e0e"))
	# Edge padding band (cells stay inside)
	var pad: float = SingleCellModel.EDGE_PAD * scale
	c.draw_rect(Rect2(ox, oy, SingleCellModel.WORLD_W * scale, SingleCellModel.WORLD_H * scale), Color("#b22222", 0.12), false, 1.0)
	c.draw_rect(Rect2(ox + pad, oy + pad, SingleCellModel.WORLD_W * scale - pad * 2.0, SingleCellModel.WORLD_H * scale - pad * 2.0), Color("#ffffff", 0.06), false, 1.0)

	# Waste still grid-based (subtle)
	if _show_waste:
		for r in range(model.grid_rows):
			for col in range(model.grid_cols):
				var i: int = model.grid_index(col, r)
				var wv: float = clampf(model.waste[i] / 8.0, 0.0, 1.0)
				if wv > 0.04:
					var fx: float = ox + float(col) * cell_px
					var fy: float = oy + float(r) * cell_px
					c.draw_rect(Rect2(fx, fy, cell_px + 0.5, cell_px + 0.5), Color(0.55, 0.55, 0.55, 0.12 + 0.45 * wv))

	# Food = circular patches (50–75 world-px radius)
	if _show_food:
		for p in model.food_patches:
			var amt: float = float(p["amount"])
			if amt <= 0.15:
				continue
			var pr: float = float(p["radius"]) * scale
			var pc: Vector2 = Vector2(ox + float(p["x"]) * scale, oy + float(p["y"]) * scale)
			var alpha: float = clampf(0.2 + amt / 80.0, 0.2, 0.55)
			c.draw_circle(pc, pr, Color(0.2, 0.85, 0.35, alpha))
			c.draw_circle(pc, pr, Color(0.4, 1.0, 0.5, 0.35), false, 1.5)

	c.draw_rect(Rect2(ox, oy, SingleCellModel.WORLD_W * scale, SingleCellModel.WORLD_H * scale), Color("#b22222", 0.35), false, 1.5)

	for cell in model.cells:
		var x: float = ox + float(cell["x"]) * scale
		var y: float = oy + float(cell["y"]) * scale
		var rad: float = clampf(float(cell["size"]) * 2.8 * scale, 2.2, 7.0)
		var col: Color = model.type_color(str(cell["typeId"]))
		var e: float = clampf(float(cell["energy"]) / 30.0, 0.25, 1.0)
		col = Color(col.r, col.g, col.b, 0.55 + 0.45 * e)
		c.draw_circle(Vector2(x, y), rad, col)
		if int(cell["id"]) == _possess_id:
			c.draw_arc(Vector2(x, y), rad + 3.0, 0.0, TAU, 20, Color("#ffeb3b"), 1.5, true)

	# Follow possessed cell with soft pan
	if _possess_id >= 0:
		var pc: Dictionary = _find_cell(_possess_id)
		if not pc.is_empty():
			_center_on(float(pc["x"]), float(pc["y"]), sz)

	c.draw_string(ThemeDB.fallback_font, Vector2(8.0, 16.0), "zoom %.1f× · %d cells · click cell to possess" % [_zoom, model.cell_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#90a4ae"))


func _food_total() -> float:
	return model.food_total()


func _on_add_food_center() -> void:
	model.add_food_amount(40.0)
	_refresh_labels()
	if _stage:
		_stage.queue_redraw()
	set_status("Added food blob at center · total food ≈ %.0f" % _food_total())


func _on_add_food_scatter() -> void:
	for _i in range(5):
		model.add_food_amount(12.0, randf() * SingleCellModel.WORLD_W, randf() * SingleCellModel.WORLD_H)
	_refresh_labels()
	if _stage:
		_stage.queue_redraw()
	set_status("Scattered food · total food ≈ %.0f" % _food_total())


func _draw_graph() -> void:
	if _graph == null:
		return
	var c := _graph
	var sz: Vector2 = c.size
	if sz.x < 20.0 or sz.y < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#121214"))
	var pad := 28.0
	var plot := Rect2(pad, 16.0, sz.x - pad * 2.0, sz.y - 36.0)
	c.draw_rect(plot, Color("#1a1a1e"))
	c.draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, 12.0), "Population (red) · Avg energy (amber)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	var pop: Array = model.stats_population
	var eng: Array = model.stats_avg_energy
	if pop.size() < 2:
		c.draw_string(ThemeDB.fallback_font, plot.position + Vector2(8, plot.size.y * 0.5), "Run the sim to build history…", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#78909c"))
		return

	var pmax: float = 1.0
	for v in pop:
		pmax = maxf(pmax, float(v))
	var emax: float = 1.0
	for v in eng:
		emax = maxf(emax, float(v))

	var ppts := PackedVector2Array()
	var epts := PackedVector2Array()
	var n: int = pop.size()
	for i in range(n):
		var u: float = float(i) / float(maxi(n - 1, 1))
		var px: float = plot.position.x + u * plot.size.x
		ppts.append(Vector2(px, plot.position.y + (1.0 - float(pop[i]) / pmax) * plot.size.y))
		if i < eng.size():
			epts.append(Vector2(px, plot.position.y + (1.0 - float(eng[i]) / emax) * plot.size.y))
	if ppts.size() >= 2:
		c.draw_polyline(ppts, Color("#e53935"), 2.0, true)
	if epts.size() >= 2:
		c.draw_polyline(epts, Color("#ffb300"), 2.0, true)

	c.draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, plot.end.y + 14.0), "n=%d  max pop=%.0f" % [n, pmax], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#90a4ae"))


func _view_xform(sz: Vector2) -> Dictionary:
	# Stage canvas is sized to the world; draw 1:1 into it (scrollbars pan).
	var sx: float = sz.x / SingleCellModel.WORLD_W
	var sy: float = sz.y / SingleCellModel.WORLD_H
	var scale: float = minf(sx, sy)
	var ox: float = (sz.x - SingleCellModel.WORLD_W * scale) * 0.5
	var oy: float = (sz.y - SingleCellModel.WORLD_H * scale) * 0.5
	return {"scale": scale, "ox": ox, "oy": oy, "base": scale}


func _update_stage_size() -> void:
	if _stage == null:
		return
	# Base map ~0.55 px per world unit; zoom enlarges scrollable canvas
	const MAP_SCALE: float = 0.55
	var w: float = SingleCellModel.WORLD_W * MAP_SCALE * _zoom
	var h: float = SingleCellModel.WORLD_H * MAP_SCALE * _zoom
	_stage.custom_minimum_size = Vector2(w, h)
	_stage.size = Vector2(w, h)


func _screen_to_world(pos: Vector2, sz: Vector2) -> Vector2:
	var xform: Dictionary = _view_xform(sz)
	var scale: float = maxf(float(xform["scale"]), 1e-6)
	var ox: float = float(xform["ox"])
	var oy: float = float(xform["oy"])
	return Vector2((pos.x - ox) / scale, (pos.y - oy) / scale)


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, 1.0, 8.0)
	if _s_zoom and not _updating:
		_updating = true
		_s_zoom.value = _zoom
		_updating = false
	_update_stage_size()
	_refresh_labels()
	if _stage:
		_stage.queue_redraw()


func _on_zoom(v: float) -> void:
	if _updating:
		return
	_zoom = v
	_update_stage_size()
	_refresh_labels()
	if _stage:
		_stage.queue_redraw()


func _reset_camera() -> void:
	_zoom = 1.0
	_cam_x = 0.0
	_cam_y = 0.0
	_updating = true
	if _s_zoom:
		_s_zoom.value = 1.0
	_updating = false
	_update_stage_size()
	if _scroll:
		_scroll.scroll_horizontal = 0
		_scroll.scroll_vertical = 0
	_refresh_labels()
	if _stage:
		_stage.queue_redraw()


func _center_on(wx: float, wy: float, sz: Vector2) -> void:
	# Soft-follow via ScrollContainer
	if _scroll == null or _stage == null:
		return
	var xform: Dictionary = _view_xform(sz)
	var scale: float = float(xform["scale"])
	var ox: float = float(xform["ox"])
	var oy: float = float(xform["oy"])
	var sx: float = ox + wx * scale
	var sy: float = oy + wy * scale
	var vis: Vector2 = _scroll.size
	var target_h: float = sx - vis.x * 0.5
	var target_v: float = sy - vis.y * 0.5
	_scroll.scroll_horizontal = int(lerpf(float(_scroll.scroll_horizontal), target_h, 0.15))
	_scroll.scroll_vertical = int(lerpf(float(_scroll.scroll_vertical), target_v, 0.15))


func _find_cell(cid: int) -> Dictionary:
	for c in model.cells:
		if int(c["id"]) == cid:
			return c
	return {}


func _hit_cell(world: Vector2) -> int:
	var best: int = -1
	var best_d: float = 10.0  # world px threshold
	for c in model.cells:
		var dx: float = float(c["x"]) - world.x
		var dy: float = float(c["y"]) - world.y
		var d: float = sqrt(dx * dx + dy * dy)
		var rad: float = maxf(float(c["size"]) * 3.5, 5.5)
		if d < rad + 4.0 and d < best_d:
			best_d = d
			best = int(c["id"])
	return best


func _exit_possess() -> void:
	_possess_id = -1
	_update_possess_label()
	if _stage:
		_stage.queue_redraw()
	set_status("Possession cleared")


func _update_possess_label() -> void:
	if _o_possess == null:
		return
	if _possess_id < 0:
		_o_possess.text = "Possess: none (click a cell)"
		return
	var c: Dictionary = _find_cell(_possess_id)
	if c.is_empty():
		_o_possess.text = "Possess: cell #%d (dead)" % _possess_id
		_possess_id = -1
		return
	var tid: String = str(c["typeId"])
	var nm: String = str(SingleCellModel.CELL_TYPES.get(tid, {}).get("name", tid))
	_o_possess.text = "Possess #%d %s | E=%.1f size=%.2f age=%d | (%.0f, %.0f)" % [
		_possess_id, nm, float(c["energy"]), float(c["size"]), int(c["age"]), float(c["x"]), float(c["y"])
	]


func _on_stage_input(event: InputEvent) -> void:
	if _stage == null:
		return
	var sz: Vector2 = _stage.size
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_zoom(_zoom + 0.25)
			_stage.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_zoom(_zoom - 0.25)
			_stage.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var world: Vector2 = _screen_to_world(mb.position, sz)
			var hit: int = _hit_cell(world)
			if hit >= 0:
				_possess_id = hit
				_update_possess_label()
				set_status("Possessing cell #%d" % hit)
				if _stage:
					_stage.queue_redraw()
			else:
				_drag_pan = true
				_drag_last = mb.position
			_stage.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_drag_pan = false
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_exit_possess()
			_stage.accept_event()
	elif event is InputEventMouseMotion and _drag_pan:
		var mm: InputEventMouseMotion = event
		var delta: Vector2 = mm.position - _drag_last
		_drag_last = mm.position
		if _scroll:
			_scroll.scroll_horizontal = int(_scroll.scroll_horizontal - delta.x)
			_scroll.scroll_vertical = int(_scroll.scroll_vertical - delta.y)
