extends LabShell
## Chemical Reactions v1 — catalogue + stoichiometry.

var model: ChemicalReactionsModel = ChemicalReactionsModel.new()

var _stage: Control
var _eq_label: Label
var _type_label: Label
var _note_label: Label
var _r_limit: Label
var _r_extent: Label
var _r_products: Label
var _r_left: Label
var _moles_host: VBoxContainer
var _mole_sliders: Dictionary = {}
var _updating: bool = false
var _pulse: float = 0.0
var _result: Dictionary = {}

# Builder
var _builder_a: OptionButton
var _builder_b: OptionButton

# Free mix (up to 3 slots)
var _mix_a: OptionButton
var _mix_b: OptionButton
var _mix_c: OptionButton
var _mix_msg: Label
var _no_reaction: bool = false


func _ready() -> void:
	lab_title = "Chemical Reactions"
	lab_eyebrow = "CHEMISTRY  /  CHEMICAL REACTIONS"
	lab_lead = "Pick a known reaction, set reactant moles, and see the type, balanced equation, limiting reagent, and products."
	field_id = "chemistry"
	page_id = "chemical_reactions"
	back_label = "<- Chemistry"
	super._ready()
	_build_stage()
	_build_sidebar()
	model.select_reaction("water_synth")
	_rebuild_mole_sliders()
	_solve()
	set_process(true)


func _process(delta: float) -> void:
	_pulse += delta
	if _stage:
		_stage.queue_redraw()


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "RxnStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))

	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	_type_label = Label.new()
	_type_label.theme_type_variation = &"Eyebrow"
	v.add_child(_type_label)
	_eq_label = Label.new()
	_eq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_eq_label.add_theme_font_size_override("font_size", 18)
	v.add_child(_eq_label)
	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.add_theme_font_size_override("font_size", 12)
	v.add_child(_note_label)
	var extra := get_extra()
	if extra:
		extra.add_child(card)


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "CATALOGUE")
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 4)
	sb.add_child(grid)
	for rx in model.reactions:
		var b := Button.new()
		b.text = str(rx["title"])
		b.theme_type_variation = &"Chip"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var rid: String = str(rx["id"])
		b.pressed.connect(func(): _on_select(rid))
		grid.add_child(b)

	_add_section(sb, "BUILDER (known pairs)")
	var tipb := Label.new()
	tipb.text = "Pick two species; if a catalogue reaction matches, it loads."
	tipb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tipb.add_theme_font_size_override("font_size", 11)
	sb.add_child(tipb)
	_builder_a = OptionButton.new()
	_builder_b = OptionButton.new()
	var species_list: Array = ["H2", "O2", "N2", "Cl2", "H2O", "CH4", "Na", "Cl2", "Zn", "CuSO4", "AgNO3", "NaCl", "HCl", "NaOH", "Fe", "C", "Mg", "CaCO3", "KClO3"]
	# unique
	var seen: Dictionary = {}
	for s in species_list:
		if seen.has(s):
			continue
		seen[s] = true
		_builder_a.add_item(model.formula(s))
		_builder_a.set_item_metadata(_builder_a.item_count - 1, s)
		_builder_b.add_item(model.formula(s))
		_builder_b.set_item_metadata(_builder_b.item_count - 1, s)
	sb.add_child(_builder_a)
	sb.add_child(_builder_b)
	var bfind := Button.new()
	bfind.text = "Find reaction"
	bfind.pressed.connect(_on_builder_find)
	sb.add_child(bfind)

	_add_section(sb, "FREE MIX")
	var ftip := Label.new()
	ftip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ftip.add_theme_font_size_override("font_size", 11)
	ftip.text = "Choose up to 3 species. Run mix: exact catalogue match loads; otherwise no reaction."
	sb.add_child(ftip)
	_mix_a = OptionButton.new()
	_mix_b = OptionButton.new()
	_mix_c = OptionButton.new()
	_fill_species_options(_mix_a, true)
	_fill_species_options(_mix_b, true)
	_fill_species_options(_mix_c, true)
	sb.add_child(_mix_a)
	sb.add_child(_mix_b)
	sb.add_child(_mix_c)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	sb.add_child(brow)
	var bmix := Button.new()
	bmix.text = "Run free mix"
	bmix.pressed.connect(_on_free_mix)
	brow.add_child(bmix)
	var bclr := Button.new()
	bclr.text = "Clear mix"
	bclr.theme_type_variation = &"GhostButton"
	bclr.pressed.connect(_on_clear_mix)
	brow.add_child(bclr)
	_mix_msg = Label.new()
	_mix_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mix_msg.add_theme_font_size_override("font_size", 12)
	_mix_msg.text = "Mix idle."
	sb.add_child(_mix_msg)

	_add_section(sb, "REACTANT MOLES")
	_moles_host = VBoxContainer.new()
	_moles_host.add_theme_constant_override("separation", 4)
	sb.add_child(_moles_host)

	_add_section(sb, "READOUTS")
	_r_limit = _stat(sb, "Limiting reactant")
	_r_extent = _stat(sb, "Reaction extent (×)")
	_r_products = Label.new()
	_r_products.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_products.add_theme_font_size_override("font_size", 12)
	sb.add_child(_r_products)
	_r_left = Label.new()
	_r_left.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_left.add_theme_font_size_override("font_size", 12)
	sb.add_child(_r_left)


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


func _add_section(sb: VBoxContainer, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"Eyebrow"
	sb.add_child(l)


func _on_select(id: String) -> void:
	_no_reaction = false
	model.select_reaction(id)
	_rebuild_mole_sliders()
	_solve()


func _on_builder_find() -> void:
	var ia: int = _builder_a.selected
	var ib: int = _builder_b.selected
	if ia < 0 or ib < 0:
		return
	var a: String = str(_builder_a.get_item_metadata(ia))
	var b: String = str(_builder_b.get_item_metadata(ib))
	var rid: String = model.find_by_reactant_pair(a, b)
	if rid == "":
		set_status("No catalogue reaction for %s + %s" % [model.formula(a), model.formula(b)])
		return
	_on_select(rid)
	set_status("Loaded: %s" % model.get_reaction()["title"])


func _rebuild_mole_sliders() -> void:
	if _moles_host == null:
		return
	while _moles_host.get_child_count() > 0:
		var ch: Node = _moles_host.get_child(0)
		_moles_host.remove_child(ch)
		ch.free()
	_mole_sliders.clear()
	var rx: Dictionary = model.get_reaction()
	for sp in rx.get("reactants", []):
		var sid: String = str(sp["id"])
		var lab := Label.new()
		lab.text = "%s (coeff %d)" % [model.formula(sid), int(sp["c"])]
		_moles_host.add_child(lab)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 12.0
		s.step = 0.1
		s.value = float(model.reactant_moles.get(sid, 2.0))
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sid2: String = sid
		s.value_changed.connect(func(v: float): _on_moles(sid2, v))
		_moles_host.add_child(s)
		_mole_sliders[sid] = s


func _on_moles(sid: String, v: float) -> void:
	if _updating:
		return
	model.set_moles(sid, v)
	_solve()


func _solve() -> void:
	_result = model.solve()
	_type_label.text = str(_result.get("type_name", ""))
	_eq_label.text = str(_result.get("equation", ""))
	_note_label.text = str(_result.get("note", ""))
	_r_limit.text = str(_result.get("limiting_name", "—"))
	_r_extent.text = "%.3f batch equivalents" % float(_result.get("extent", 0.0))
	var prod: Dictionary = _result.get("produced", {})
	var bits: PackedStringArray = PackedStringArray()
	for k in prod.keys():
		bits.append("%s: %.3f mol" % [model.formula(str(k)), float(prod[k])])
	_r_products.text = "Products — " + (", ".join(bits) if bits.size() > 0 else "none")
	var left: Dictionary = _result.get("leftover", {})
	var bits2: PackedStringArray = PackedStringArray()
	for k2 in left.keys():
		bits2.append("%s: %.3f mol" % [model.formula(str(k2)), float(left[k2])])
	_r_left.text = "Leftover — " + (", ".join(bits2) if bits2.size() > 0 else "none")
	set_status("%s · limiting %s · extent %.2f" % [str(_result.get("title", "")), str(_result.get("limiting_name", "")), float(_result.get("extent", 0.0))])
	if _stage:
		_stage.queue_redraw()


func _draw_stage() -> void:
	if _stage == null:
		return
	var c := _stage
	var sz: Vector2 = c.size
	if sz.x < 20.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#101418"))
	var vis: Dictionary = _result.get("visual", {})
	var extent: float = float(_result.get("extent", 0.0))
	var activity: float = clampf(extent / 3.0, 0.0, 1.0)

	# Two flasks → arrow → products flask
	var y: float = sz.y * 0.55
	var f1 := Vector2(sz.x * 0.22, y)
	var f2 := Vector2(sz.x * 0.78, y)
	_draw_flask(c, f1, Color("#42a5f5", 0.35 + 0.25 * activity), "Reactants")
	_draw_flask(c, f2, Color("#66bb6a", 0.25 + 0.4 * activity), "Products")
	# Arrow
	c.draw_line(Vector2(sz.x * 0.38, y), Vector2(sz.x * 0.62, y), Color("#b22222"), 3.0)
	c.draw_line(Vector2(sz.x * 0.62, y), Vector2(sz.x * 0.58, y - 8), Color("#b22222"), 3.0)
	c.draw_line(Vector2(sz.x * 0.62, y), Vector2(sz.x * 0.58, y + 8), Color("#b22222"), 3.0)

	# Particles
	var n: int = int(8 + activity * 16)
	for i in range(n):
		var u: float = fmod(_pulse * 0.4 + float(i) / float(n), 1.0)
		var x: float = lerpf(sz.x * 0.28, sz.x * 0.72, u)
		var yy: float = y + sin(_pulse * 3.0 + float(i)) * 12.0
		var col := Color("#ffeb3b", 0.5 + 0.5 * activity)
		if bool(vis.get("precipitate", false)):
			col = Color("#eceff1", 0.7)
		elif bool(vis.get("gas", false)):
			col = Color("#90caf9", 0.6)
		c.draw_circle(Vector2(x, yy), 3.0 + activity * 2.0, col)

	if bool(vis.get("heat", false)):
		for i in range(5):
			var hx: float = sz.x * 0.72 + float(i) * 6.0
			var hy: float = y - 50.0 - absf(sin(_pulse * 4.0 + float(i))) * 20.0
			c.draw_circle(Vector2(hx, hy), 3.0, Color("#ff9800", 0.5))

	c.draw_string(ThemeDB.fallback_font, Vector2(16, 24), str(_result.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#eceff1"))
	c.draw_string(ThemeDB.fallback_font, Vector2(16, 46), str(_result.get("equation", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#90caf9"))
	if _no_reaction:
		c.draw_string(ThemeDB.fallback_font, Vector2(16, 72), "No reaction under catalogue conditions", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ef9a9a"))


func _draw_flask(c: Control, center: Vector2, fill: Color, label: String) -> void:
	var w := 70.0
	var h := 90.0
	var rect := Rect2(center.x - w * 0.5, center.y - h * 0.3, w, h)
	c.draw_rect(rect, fill)
	c.draw_rect(rect, Color("#cfd8dc"), false, 2.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(center.x - 30, center.y + h * 0.75), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b0bec5"))



func _fill_species_options(ob: OptionButton, allow_empty: bool = false) -> void:
	ob.clear()
	if allow_empty:
		ob.add_item("— none —")
		ob.set_item_metadata(0, "")
	for sid in model.all_species_ids():
		ob.add_item(model.formula(str(sid)))
		ob.set_item_metadata(ob.item_count - 1, str(sid))


func _on_free_mix() -> void:
	var selected: Array = []
	for ob in [_mix_a, _mix_b, _mix_c]:
		if ob == null:
			continue
		var i: int = ob.selected
		if i < 0:
			continue
		var sid: String = str(ob.get_item_metadata(i))
		if sid == "":
			continue
		if not selected.has(sid):
			selected.append(sid)
	var res: Dictionary = model.match_reactants(selected)
	_mix_msg.text = str(res.get("message", ""))
	if bool(res.get("matched", false)):
		_no_reaction = false
		_on_select(str(res.get("reaction_id", "")))
		set_status("Free mix matched: %s" % str(model.get_reaction().get("title", "")))
	else:
		_no_reaction = true
		_result = {
			"ok": false,
			"title": "No reaction",
			"equation": _join_formulas(selected) + "  →  ?",
			"type_name": "No reaction",
			"note": str(res.get("message", "")),
			"extent": 0.0,
			"limiting_name": "—",
			"produced": {},
			"leftover": {},
			"visual": {},
		}
		_type_label.text = "No reaction"
		_eq_label.text = str(_result["equation"])
		_note_label.text = str(_result["note"])
		_r_limit.text = "—"
		_r_extent.text = "0"
		_r_products.text = "Products — none"
		_r_left.text = "Leftover — mix unchanged"
		set_status("No reaction for this free mix")
		if _stage:
			_stage.queue_redraw()


func _on_clear_mix() -> void:
	_no_reaction = false
	if _mix_a:
		_mix_a.select(0)
	if _mix_b:
		_mix_b.select(0)
	if _mix_c:
		_mix_c.select(0)
	_mix_msg.text = "Mix cleared."


func _join_formulas(ids: Array) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for s in ids:
		bits.append(model.formula(str(s)))
	return " + ".join(bits)
