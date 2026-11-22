extends LabShell
## Ecosystems — nutrient → producer → herbivore → carnivore food web.

var model: EcosystemsModel = EcosystemsModel.new()

var _pyramid: Control
var _graph: Control
var _btn_play: Button
var _running: bool = false
var _acc: float = 0.0
const YEARS_PER_SEC: float = 1.8

var _s_in: HSlider
var _s_grow: HSlider
var _s_graze: HSlider
var _s_pred: HSlider
var _s_rec: HSlider
var _o_in: Label
var _o_grow: Label
var _o_graze: Label
var _o_pred: Label
var _o_rec: Label
var _r_n: Label
var _r_p: Label
var _r_h: Label
var _r_c: Label
var _r_d: Label
var _r_tot: Label
var _r_status: Label
var _updating: bool = false


func _ready() -> void:
	lab_title = "Ecosystems"
	lab_eyebrow = "BIOLOGY  /  ECOSYSTEMS"
	lab_lead = "Energy and matter through a food web: nutrients, producers, herbivores, carnivores, and detritus."
	field_id = "biology"
	page_id = "ecosystems"
	back_label = "<- Biology"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.apply_preset("grassland")
	_sync_sliders()
	_refresh()
	set_process(true)
	set_status("Grassland web · press Play.")


func _process(delta: float) -> void:
	if not _running:
		return
	_acc += delta * YEARS_PER_SEC
	var guard: int = 0
	while _acc >= model.DT and guard < 40:
		_acc -= model.DT
		guard += 1
		model.step(model.DT)
	_refresh()


func _build_stage() -> void:
	_pyramid = Control.new()
	_pyramid.name = "Pyramid"
	_pyramid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pyramid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_to_stage(_pyramid)
	_pyramid.draw.connect(Callable(self, "_draw_pyramid"))

	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size = Vector2(0, 170)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(0, 150)
	_graph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_graph)
	var extra := get_extra()
	if extra:
		extra.add_child(card)
	_graph.draw.connect(Callable(self, "_draw_graph"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "PRESETS")
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	sb.add_child(prow)
	for item in [["Grassland", "grassland"], ["Ocean", "ocean"], ["Overfish", "overfish"], ["Nutrient bloom", "bloom"]]:
		var b := Button.new()
		b.text = str(item[0])
		b.theme_type_variation = &"Chip"
		var id: String = str(item[1])
		b.pressed.connect(func(): _on_preset(id))
		prow.add_child(b)

	_add_section(sb, "TRANSPORT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	sb.add_child(row)
	_btn_play = Button.new()
	_btn_play.text = "Play"
	_btn_play.pressed.connect(_on_play)
	row.add_child(_btn_play)
	var bs := Button.new()
	bs.text = "Step"
	bs.theme_type_variation = &"GhostButton"
	bs.pressed.connect(_on_step)
	row.add_child(bs)
	var br := Button.new()
	br.text = "Reset"
	br.theme_type_variation = &"GhostButton"
	br.pressed.connect(_on_reset)
	row.add_child(br)

	_add_section(sb, "DRIVERS")
	_o_in = Label.new(); sb.add_child(_o_in)
	_s_in = _slider(sb, 0.0, 10.0, model.nutrient_input, 0.1, _on_in)
	_o_grow = Label.new(); sb.add_child(_o_grow)
	_s_grow = _slider(sb, 0.05, 0.9, model.plant_growth, 0.01, _on_grow)
	_o_graze = Label.new(); sb.add_child(_o_graze)
	_s_graze = _slider(sb, 0.0, 0.08, model.graze, 0.001, _on_graze)
	_o_pred = Label.new(); sb.add_child(_o_pred)
	_s_pred = _slider(sb, 0.0, 0.1, model.pred, 0.001, _on_pred)
	_o_rec = Label.new(); sb.add_child(_o_rec)
	_s_rec = _slider(sb, 0.02, 0.4, model.recycle_rate, 0.01, _on_rec)

	_add_section(sb, "READOUTS")
	_r_n = _stat(sb, "Nutrients N")
	_r_p = _stat(sb, "Producers P")
	_r_h = _stat(sb, "Herbivores H")
	_r_c = _stat(sb, "Carnivores C")
	_r_d = _stat(sb, "Detritus D")
	_r_tot = _stat(sb, "Living biomass")
	_r_status = Label.new()
	_r_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_status.add_theme_font_size_override("font_size", 12)
	sb.add_child(_r_status)

	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.text = "Pyramid widths ∝ biomass. Only ~10–40% of energy transfers up each trophic step (efficiency sliders in model)."
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
	marker.color = Color("#16B8A6")
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


func _on_preset(id: String) -> void:
	_running = false
	_btn_play.text = "Play"
	model.apply_preset(id)
	_sync_sliders()
	_refresh()
	set_status("Preset: %s" % id)


func _sync_sliders() -> void:
	_updating = true
	_s_in.value = model.nutrient_input
	_s_grow.value = model.plant_growth
	_s_graze.value = model.graze
	_s_pred.value = model.pred
	_s_rec.value = model.recycle_rate
	_updating = false


func _on_play() -> void:
	_running = not _running
	_btn_play.text = "Pause" if _running else "Play"
	set_status("Running…" if _running else "Paused")


func _on_step() -> void:
	_running = false
	_btn_play.text = "Play"
	model.advance(0.5)
	_refresh()


func _on_reset() -> void:
	_running = false
	_btn_play.text = "Play"
	model.reset(model.n, model.p, model.h, model.c, model.d)
	# re-seed from current preset-ish: just zero time with current stocks
	model.t = 0.0
	model.hist_t.clear(); model.hist_n.clear(); model.hist_p.clear()
	model.hist_h.clear(); model.hist_c.clear(); model.hist_d.clear()
	model._record()
	_refresh()
	set_status("Reset time · stocks kept")


func _on_in(v: float) -> void:
	if _updating: return
	model.nutrient_input = v
	_refresh()


func _on_grow(v: float) -> void:
	if _updating: return
	model.plant_growth = v
	_refresh()


func _on_graze(v: float) -> void:
	if _updating: return
	model.graze = v
	_refresh()


func _on_pred(v: float) -> void:
	if _updating: return
	model.pred = v
	_refresh()


func _on_rec(v: float) -> void:
	if _updating: return
	model.recycle_rate = v
	_refresh()


func _refresh() -> void:
	_o_in.text = "Nutrient input = %.2f" % model.nutrient_input
	_o_grow.text = "Plant growth = %.2f" % model.plant_growth
	_o_graze.text = "Grazing rate = %.3f" % model.graze
	_o_pred.text = "Predation rate = %.3f" % model.pred
	_o_rec.text = "Recycle rate = %.2f" % model.recycle_rate
	_r_n.text = "%.2f" % model.n
	_r_p.text = "%.2f" % model.p
	_r_h.text = "%.2f" % model.h
	_r_c.text = "%.2f" % model.c
	_r_d.text = "%.2f" % model.d
	_r_tot.text = "%.2f" % model.total_biomass()
	_r_status.text = model.status()
	set_status("t=%.1f · biomass %.1f · %s" % [model.t, model.total_biomass(), model.status()])
	if _pyramid:
		_pyramid.queue_redraw()
	if _graph:
		_graph.queue_redraw()


func _draw_pyramid() -> void:
	if _pyramid == null:
		return
	var c := _pyramid
	var sz: Vector2 = c.size
	if sz.x < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#101418"))
	c.draw_string(ThemeDB.fallback_font, Vector2(16, 20), "Trophic pyramid (width ∝ biomass) · t=%.1f" % model.t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))

	var levels: Array = [
		{"name": "Carnivores", "v": model.c, "color": Color("#e53935")},
		{"name": "Herbivores", "v": model.h, "color": Color("#fb8c00")},
		{"name": "Producers", "v": model.p, "color": Color("#43a047")},
		{"name": "Nutrients", "v": model.n, "color": Color("#1e88e5")},
	]
	var vmax: float = 1.0
	for L in levels:
		vmax = maxf(vmax, float(L["v"]))
	vmax = maxf(vmax, model.d)

	var top: float = 40.0
	var bot: float = sz.y - 50.0
	var row_h: float = (bot - top) / float(levels.size())
	var cx: float = sz.x * 0.5
	var max_w: float = sz.x * 0.72

	for i in range(levels.size()):
		var L: Dictionary = levels[i]
		var frac: float = clampf(float(L["v"]) / vmax, 0.05, 1.0)
		var w: float = max_w * frac
		var y: float = top + float(i) * row_h
		var rect := Rect2(cx - w * 0.5, y + 6.0, w, row_h - 12.0)
		c.draw_rect(rect, L["color"])
		c.draw_rect(rect, Color(0, 0, 0, 0.35), false, 2.0)
		c.draw_string(ThemeDB.fallback_font, Vector2(cx - w * 0.5 + 8.0, y + row_h * 0.55), "%s  %.1f" % [str(L["name"]), float(L["v"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffffff"))

	# Detritus side bar
	var d_frac: float = clampf(model.d / vmax, 0.05, 1.0)
	var dh: float = (bot - top) * d_frac
	var drect := Rect2(sz.x - 36.0, bot - dh, 18.0, dh)
	c.draw_rect(drect, Color("#6d4c41"))
	c.draw_string(ThemeDB.fallback_font, Vector2(sz.x - 52.0, bot + 14.0), "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#bcaaa4"))

	# Flow arrows hint
	c.draw_string(ThemeDB.fallback_font, Vector2(16, sz.y - 18), "N → P → H → C · deaths → detritus → recycle to N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#78909c"))


func _draw_graph() -> void:
	if _graph == null:
		return
	var c := _graph
	var sz: Vector2 = c.size
	if sz.x < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#121418"))
	var pad := 28.0
	var plot := Rect2(pad, 16.0, sz.x - pad * 2.0, sz.y - 36.0)
	c.draw_rect(plot, Color("#1a1e24"))
	c.draw_string(ThemeDB.fallback_font, Vector2(pad, 12.0), "P green · H orange · C red · N blue", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	var series: Array = [
		{"arr": model.hist_p, "col": Color("#66bb6a")},
		{"arr": model.hist_h, "col": Color("#ffa726")},
		{"arr": model.hist_c, "col": Color("#ef5350")},
		{"arr": model.hist_n, "col": Color("#42a5f5")},
	]
	var vmax: float = 1.0
	for s in series:
		for v in s["arr"]:
			vmax = maxf(vmax, float(v))
	var n: int = model.hist_t.size()
	if n < 2:
		return
	for s in series:
		var arr: Array = s["arr"]
		if arr.size() < 2:
			continue
		var pts := PackedVector2Array()
		for i in range(arr.size()):
			var u: float = float(i) / float(maxi(arr.size() - 1, 1))
			pts.append(Vector2(plot.position.x + u * plot.size.x, plot.position.y + (1.0 - float(arr[i]) / vmax) * plot.size.y))
		c.draw_polyline(pts, s["col"], 2.0, true)
