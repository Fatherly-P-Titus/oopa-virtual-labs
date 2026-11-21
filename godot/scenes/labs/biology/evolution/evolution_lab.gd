extends LabShell
## Evolution — selection, mutation, drift on a continuous trait.

var model: EvolutionModel = EvolutionModel.new()

var _stage: Control
var _graph: Control
var _btn_play: Button
var _running: bool = false
var _acc: float = 0.0
const GENS_PER_SEC: float = 8.0

var _s_pop: HSlider
var _s_mut: HSlider
var _s_msd: HSlider
var _s_sig: HSlider
var _s_opt: HSlider
var _s_spd: HSlider
var _o_pop: Label
var _o_mut: Label
var _o_msd: Label
var _o_sig: Label
var _o_opt: Label
var _o_spd: Label
var _r_gen: Label
var _r_mean: Label
var _r_var: Label
var _r_fit: Label
var _r_status: Label
var _updating: bool = false


func _ready() -> void:
	lab_title = "Evolution"
	lab_eyebrow = "BIOLOGY  /  EVOLUTION"
	lab_lead = "Natural selection on a heritable trait. Mutation and drift compete with selection — watch the population track the optimum."
	field_id = "biology"
	page_id = "evolution"
	back_label = "<- Biology"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.apply_preset("stabilizing")
	_sync_sliders()
	_refresh()
	set_process(true)
	set_status("Stabilizing selection · press Play.")


func _process(delta: float) -> void:
	if not _running:
		return
	_acc += delta * GENS_PER_SEC
	var guard: int = 0
	while _acc >= 1.0 and guard < 6:
		_acc -= 1.0
		guard += 1
		model.step_generation()
	_refresh()


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "PopView"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))

	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size = Vector2(0, 160)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(0, 140)
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
	for item in [["Stabilizing", "stabilizing"], ["Strong sel.", "strong_selection"], ["Weak / drift", "weak_drift"], ["Moving target", "moving_target"]]:
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
	bs.text = "Step gen"
	bs.theme_type_variation = &"GhostButton"
	bs.pressed.connect(_on_step)
	row.add_child(bs)
	var br := Button.new()
	br.text = "Reset"
	br.theme_type_variation = &"GhostButton"
	br.pressed.connect(_on_reset)
	row.add_child(br)

	_add_section(sb, "PARAMETERS")
	_o_pop = Label.new(); sb.add_child(_o_pop)
	_s_pop = _slider(sb, 20.0, 200.0, float(model.pop_size), 5.0, _on_pop)
	_o_mut = Label.new(); sb.add_child(_o_mut)
	_s_mut = _slider(sb, 0.0, 0.5, model.mutation_rate, 0.01, _on_mut)
	_o_msd = Label.new(); sb.add_child(_o_msd)
	_s_msd = _slider(sb, 0.01, 0.2, model.mutation_sd, 0.01, _on_msd)
	_o_sig = Label.new(); sb.add_child(_o_sig)
	_s_sig = _slider(sb, 0.05, 0.5, model.selection_sigma, 0.01, _on_sig)
	_o_opt = Label.new(); sb.add_child(_o_opt)
	_s_opt = _slider(sb, 0.0, 1.0, model.optimum, 0.01, _on_opt)
	_o_spd = Label.new(); sb.add_child(_o_spd)
	_s_spd = _slider(sb, -0.02, 0.02, model.optimum_speed, 0.001, _on_spd)

	_add_section(sb, "READOUTS")
	_r_gen = _stat(sb, "Generation")
	_r_mean = _stat(sb, "Mean trait")
	_r_var = _stat(sb, "Trait variance")
	_r_fit = _stat(sb, "Mean fitness")
	_r_status = Label.new()
	_r_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_status.add_theme_font_size_override("font_size", 12)
	sb.add_child(_r_status)

	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.text = "Yellow line = environmental optimum. Smaller σ = stronger selection. Moving target shifts the optimum each generation."
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
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"Eyebrow"
	sb.add_child(l)


func _stat(sb: VBoxContainer, title: String) -> Label:
	var c := Label.new()
	c.text = title
	c.add_theme_font_size_override("font_size", 11)
	sb.add_child(c)
	var v := Label.new()
	v.theme_type_variation = &"StatValue"
	v.text = "—"
	sb.add_child(v)
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
	_s_pop.value = float(model.pop_size)
	_s_mut.value = model.mutation_rate
	_s_msd.value = model.mutation_sd
	_s_sig.value = model.selection_sigma
	_s_opt.value = model.optimum
	_s_spd.value = model.optimum_speed
	_updating = false


func _on_play() -> void:
	_running = not _running
	_btn_play.text = "Pause" if _running else "Play"
	set_status("Running…" if _running else "Paused")


func _on_step() -> void:
	_running = false
	_btn_play.text = "Play"
	model.step_generation()
	_refresh()


func _on_reset() -> void:
	_running = false
	_btn_play.text = "Play"
	model.reset()
	_refresh()
	set_status("Population re-seeded")


func _on_pop(v: float) -> void:
	if _updating: return
	model.pop_size = int(v)


func _on_mut(v: float) -> void:
	if _updating: return
	model.mutation_rate = v
	_refresh()


func _on_msd(v: float) -> void:
	if _updating: return
	model.mutation_sd = v
	_refresh()


func _on_sig(v: float) -> void:
	if _updating: return
	model.selection_sigma = v
	model._evaluate()
	_refresh()


func _on_opt(v: float) -> void:
	if _updating: return
	model.optimum = v
	model._evaluate()
	_refresh()


func _on_spd(v: float) -> void:
	if _updating: return
	model.optimum_speed = v
	_refresh()


func _refresh() -> void:
	_o_pop.text = "Population N = %d" % model.pop_size
	_o_mut.text = "Mutation rate = %.2f" % model.mutation_rate
	_o_msd.text = "Mutation SD = %.2f" % model.mutation_sd
	_o_sig.text = "Selection σ = %.2f (smaller = stronger)" % model.selection_sigma
	_o_opt.text = "Optimum z* = %.2f" % model.optimum
	_o_spd.text = "Optimum speed = %.3f / gen" % model.optimum_speed
	_r_gen.text = "%d" % model.generation
	_r_mean.text = "%.3f" % model.mean_trait()
	_r_var.text = "%.4f" % model.variance_trait()
	_r_fit.text = "%.3f" % model.mean_fitness()
	_r_status.text = model.status()
	set_status("gen %d · mean %.3f · opt %.3f · %s" % [model.generation, model.mean_trait(), model.optimum, model.status()])
	if _stage:
		_stage.queue_redraw()
	if _graph:
		_graph.queue_redraw()


func _draw_stage() -> void:
	if _stage == null:
		return
	var c := _stage
	var sz: Vector2 = c.size
	if sz.x < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#101418"))

	# Trait axis area
	var pad := 40.0
	var axis_y: float = sz.y * 0.72
	var x0: float = pad
	var x1: float = sz.x - pad
	c.draw_line(Vector2(x0, axis_y), Vector2(x1, axis_y), Color("#546e7a"), 2.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(x0, axis_y + 18.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#90a4ae"))
	c.draw_string(ThemeDB.fallback_font, Vector2(x1 - 20.0, axis_y + 18.0), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#90a4ae"))
	c.draw_string(ThemeDB.fallback_font, Vector2(x0, 22.0), "Trait distribution · gen %d" % model.generation, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b0bec5"))

	# Optimum marker
	var ox: float = x0 + model.optimum * (x1 - x0)
	c.draw_line(Vector2(ox, axis_y - 90.0), Vector2(ox, axis_y + 8.0), Color("#ffeb3b"), 2.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(ox - 10.0, axis_y - 96.0), "z*", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fff59d"))

	# Histogram bars
	var bins: int = 24
	var hist: PackedInt32Array = model.histogram(bins)
	var hmax: int = 1
	for i in range(bins):
		hmax = maxi(hmax, hist[i])
	var bar_w: float = (x1 - x0) / float(bins)
	for i in range(bins):
		var h: float = float(hist[i]) / float(hmax) * 80.0
		var bx: float = x0 + float(i) * bar_w
		var col := Color("#42a5f5", 0.75)
		c.draw_rect(Rect2(bx + 1.0, axis_y - h, bar_w - 2.0, h), col)

	# Individuals as dots jittered vertically
	var n: int = model.individuals.size()
	for i in range(n):
		var z: float = float(model.individuals[i]["trait"])
		var fit: float = float(model.individuals[i]["fitness"])
		var px: float = x0 + z * (x1 - x0)
		var py: float = axis_y + 28.0 + fmod(float(i) * 7.3, 36.0)
		var col := Color(0.25 + 0.6 * fit, 0.35, 0.85 - 0.4 * fit, 0.85)
		c.draw_circle(Vector2(px, py), 3.0, col)

	# Mean marker
	var mx: float = x0 + model.mean_trait() * (x1 - x0)
	c.draw_circle(Vector2(mx, axis_y), 5.0, Color("#e53935"))
	c.draw_string(ThemeDB.fallback_font, Vector2(mx + 6.0, axis_y - 8.0), "mean", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ef9a9a"))


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
	c.draw_string(ThemeDB.fallback_font, Vector2(pad, 12.0), "Mean trait (red) · optimum (yellow) · mean fitness (cyan)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b0bec5"))

	var n: int = model.hist_gen.size()
	if n < 2:
		return
	var mean_pts := PackedVector2Array()
	var opt_pts := PackedVector2Array()
	var fit_pts := PackedVector2Array()
	for i in range(n):
		var u: float = float(i) / float(n - 1)
		var px: float = plot.position.x + u * plot.size.x
		mean_pts.append(Vector2(px, plot.position.y + (1.0 - float(model.hist_mean[i])) * plot.size.y))
		opt_pts.append(Vector2(px, plot.position.y + (1.0 - float(model.hist_opt[i])) * plot.size.y))
		fit_pts.append(Vector2(px, plot.position.y + (1.0 - float(model.hist_mean_fit[i])) * plot.size.y))
	c.draw_polyline(opt_pts, Color("#ffeb3b"), 1.5, true)
	c.draw_polyline(mean_pts, Color("#e53935"), 2.0, true)
	c.draw_polyline(fit_pts, Color("#26c6da"), 1.5, true)
