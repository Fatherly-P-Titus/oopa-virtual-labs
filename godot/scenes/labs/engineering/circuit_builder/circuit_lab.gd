extends LabShell
## Chip-board circuit: 400×400 stage, 40×40 chips, port-to-port wires.

var model: CircuitModel = CircuitModel.new()

var _stage: Control

const BOARD: float = 400.0
const CHIP: float = 40.0
const STROKE: float = 2.0

var _drag_kind: int = -1
var _dragging: bool = false
var _wire_from: String = ""  # port id when connecting
var _selected_chip: int = -1
var _hover_slot: Vector2i = Vector2i(-1, -1)
var _pulse_t: float = 0.0

var _slider_val: HSlider
var _wiper_slider: HSlider
var _wiper_label: Label
var _fuse_reset_button: Button
var _out_val: Label
var _r_msg: Label
var _r_sel: Label
var _r_power: Label
var _r_voltage: Label
var _r_current: Label

var _ox: float = 0.0
var _oy: float = 0.0


func _ready() -> void:
	lab_title = "Circuit Builder"
	lab_eyebrow = "ENGINEERING  /  CIRCUIT BUILDER"
	lab_lead = "Drag chips onto the board. Click any port, then another port to wire them. Ports accept multiple wires for series and parallel circuits. Switches toggle ON/OFF."
	field_id = "engineering"
	page_id = "circuit_builder"
	back_label = "<- Engineering"
	super._ready()
	_build_stage()
	_build_sidebar()
	set_process(true)
	set_process_unhandled_input(true)
	set_status("Start with an empty board. Add components, then connect their ports.")


func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "ChipStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	add_to_stage(_stage)
	_stage.draw.connect(Callable(self, "_draw_stage"))


func _build_sidebar() -> void:
	var sb: VBoxContainer = get_sidebar()
	if sb == null:
		return

	_add_section(sb, "COMPONENT TILES")
	var hint := Label.new()
	hint.theme_type_variation = &"Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Drag a tile onto the 400×400 board. Click two ports to add a wire."
	sb.add_child(hint)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	sb.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	sb.add_child(row2)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	sb.add_child(row3)
	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 8)
	sb.add_child(row4)
	var row5 := HBoxContainer.new()
	row5.add_theme_constant_override("separation", 8)
	sb.add_child(row5)

	var kinds: Array = [
		CircuitModel.Kind.BAT, CircuitModel.Kind.R, CircuitModel.Kind.LEDW,
		CircuitModel.Kind.LEDO, CircuitModel.Kind.SWITCH, CircuitModel.Kind.DIODE,
		CircuitModel.Kind.CAP, CircuitModel.Kind.IND, CircuitModel.Kind.POT,
		CircuitModel.Kind.FUSE, CircuitModel.Kind.MOTOR, CircuitModel.Kind.LAMP,
		CircuitModel.Kind.TRANSISTOR,
	]
	for i in kinds.size():
		var card := _make_tile(int(kinds[i]))
		if i < 3:
			row1.add_child(card)
		elif i < 6:
			row2.add_child(card)
		elif i < 9:
			row3.add_child(card)
		elif i < 12:
			row4.add_child(card)
		else:
			row5.add_child(card)

	_add_section(sb, "SELECTED")
	_out_val = Label.new()
	_out_val.theme_type_variation = &"CtlLabel"
	sb.add_child(_out_val)
	_slider_val = HSlider.new()
	_slider_val.min_value = 1.0
	_slider_val.max_value = 10000.0
	_slider_val.value_changed.connect(_on_val)
	sb.add_child(_slider_val)
	_wiper_label = Label.new()
	_wiper_label.text = "Wiper position: 50%"
	_wiper_label.visible = false
	sb.add_child(_wiper_label)
	_wiper_slider = HSlider.new()
	_wiper_slider.min_value = 0.0
	_wiper_slider.max_value = 100.0
	_wiper_slider.step = 1.0
	_wiper_slider.value = 50.0
	_wiper_slider.visible = false
	_wiper_slider.value_changed.connect(_on_wiper_val)
	sb.add_child(_wiper_slider)
	_fuse_reset_button = Button.new()
	_fuse_reset_button.text = "Reset / replace fuse"
	_fuse_reset_button.visible = false
	_fuse_reset_button.pressed.connect(_reset_selected_fuse)
	sb.add_child(_fuse_reset_button)

	var rotate_row := HBoxContainer.new()
	rotate_row.add_theme_constant_override("separation", 8)
	sb.add_child(rotate_row)
	var rotate_ccw := Button.new()
	rotate_ccw.text = "Rotate ↶"
	rotate_ccw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotate_ccw.pressed.connect(_rotate_selected.bind(false))
	rotate_row.add_child(rotate_ccw)
	var rotate_cw := Button.new()
	rotate_cw.text = "Rotate ↷"
	rotate_cw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotate_cw.pressed.connect(_rotate_selected.bind(true))
	rotate_row.add_child(rotate_cw)

	var del := Button.new()
	del.text = "Delete selected chip"
	del.theme_type_variation = &"GhostButton"
	del.pressed.connect(_on_delete)
	sb.add_child(del)
	var clr := Button.new()
	clr.text = "Clear board"
	clr.theme_type_variation = &"GhostButton"
	clr.pressed.connect(_on_clear)
	sb.add_child(clr)

	_add_section(sb, "READOUTS")
	_r_msg = _stat(sb, "Status")
	_r_power = _stat(sb, "Battery power")
	_r_voltage = _stat(sb, "Selected voltage")
	_r_current = _stat(sb, "Selected current")
	_r_sel = _stat(sb, "Selected component")

	var h2 := Label.new()
	h2.theme_type_variation = &"Hint"
	h2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h2.text = "Click a port to start a wire and another port to finish it. Ports support four or more wires. Click a wire away from a port to remove only that wire. Select a component and use Rotate, or press R/Right and L/Left. Blue = anode/+; red = cathode/−. Diodes conduct forward and block reverse current until approximate reverse breakdown."
	sb.add_child(h2)


func _make_tile(kind: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(72, 56)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_tile_input.bind(kind))
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	var lab := Label.new()
	lab.text = model.label_of(kind)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 14)
	vb.add_child(lab)
	var sub := Label.new()
	sub.text = "drag"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 9)
	sub.modulate = Color(0.6, 0.6, 0.6)
	vb.add_child(sub)
	return panel


func _add_section(sb: VBoxContainer, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"PanelTitle"
	l.uppercase = true
	sb.add_child(l)


func _stat(sb: VBoxContainer, key: String) -> Label:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.theme_type_variation = &"StatLabel"
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := Label.new()
	v.theme_type_variation = &"StatValue"
	v.add_theme_font_size_override("font_size", 13)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	sb.add_child(row)
	return v


func _process(delta: float) -> void:
	_pulse_t += delta
	if _dragging and _stage:
		_hover_slot = _pixel_to_slot(_stage.get_local_mouse_position())
		_stage.queue_redraw()
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_drag()
	elif _stage:
		_stage.queue_redraw()
	if model.has_transient_component():
		model.step(delta)
		_refresh()


func _on_tile_input(event: InputEvent, kind: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = true
		_drag_kind = kind
		_wire_from = ""
		set_status("Dragging %s — drop on the board." % model.label_of(kind))
		accept_event()


func _finish_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	if _drag_kind < 0:
		return
	if _hover_slot.x >= 0 and model.slot_free(_hover_slot.x, _hover_slot.y):
		model.add_chip(_drag_kind, _hover_slot.x, _hover_slot.y)
		set_status("Placed %s." % model.label_of(_drag_kind))
		_refresh()
	else:
		set_status("Cannot place there.")
	_drag_kind = -1
	if _stage:
		_stage.queue_redraw()


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_slot = _pixel_to_slot(event.position)
		_stage.queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _dragging:
		# Ports take priority over chip bodies and wires so an engaged port remains
		# clickable and switch terminals can be wired instead of toggling the switch.
		var port: String = _hit_port(event.position)
		if port != "":
			_on_port_click(port)
			_stage.accept_event()
			return

		var cid: int = _hit_chip(event.position)
		if cid >= 0:
			var ch: Dictionary = model.chip_by_id(cid)
			if not ch.is_empty() and int(ch.kind) == CircuitModel.Kind.SWITCH:
				var new_state: bool = not bool(ch.get("closed", true))
				model.set_switch_closed(cid, new_state)
				_selected_chip = cid
				_wire_from = ""
				_refresh()
				if _stage:
					_stage.queue_redraw()
				set_status("Switch %s" % ("ON" if new_state else "OFF"))
				_stage.accept_event()
				return

		# Only remove a wire when the click is not on a port.
		var wid: int = _hit_wire(event.position)
		if wid >= 0:
			model.remove_wire(wid)
			_wire_from = ""
			_refresh()
			set_status("Wire removed.")
			_stage.accept_event()
			return

		if cid >= 0:
			_selected_chip = cid
			_refresh()
			_stage.accept_event()
			return
		_selected_chip = -1
		_refresh()
		_stage.accept_event()


func _on_port_click(port: String) -> void:
	if _wire_from == "":
		_wire_from = port
		var n: int = model.port_connection_count(port)
		set_status("Wire from port (%d existing connection(s)) — click another port." % n)
	elif _wire_from == port:
		_wire_from = ""
		set_status("Wire cancelled.")
	else:
		var wres: Dictionary = model.add_wire(_wire_from, port)
		_wire_from = ""
		_refresh()
		if wres.is_empty():
			set_status(model.message if model.message != "" else "Could not add wire.")
		else:
			set_status("Wire connected. Both ports remain available for additional connections.")
	if _stage:
		_stage.queue_redraw()



func _pixel_to_slot(pos: Vector2) -> Vector2i:
	var lx: float = pos.x - _ox
	var ly: float = pos.y - _oy
	if lx < 0.0 or ly < 0.0 or lx > BOARD or ly > BOARD:
		return Vector2i(-1, -1)
	var sc: int = int(lx / CircuitModel.SLOT_PX)
	var sr: int = int(ly / CircuitModel.SLOT_PX)
	sc = clampi(sc, 0, CircuitModel.SLOTS - 1)
	sr = clampi(sr, 0, CircuitModel.SLOTS - 1)
	return Vector2i(sr, sc)


func _slot_origin(sr: int, sc: int) -> Vector2:
	# Chip centered in slot
	var cx: float = _ox + (float(sc) + 0.5) * CircuitModel.SLOT_PX
	var cy: float = _oy + (float(sr) + 0.5) * CircuitModel.SLOT_PX
	return Vector2(cx - CHIP * 0.5, cy - CHIP * 0.5)


func _port_pos(chip_id: int, index: int) -> Vector2:
	var ch: Dictionary = model.chip_by_id(chip_id)
	if ch.is_empty():
		return Vector2.ZERO
	var o: Vector2 = _slot_origin(int(ch.slot_r), int(ch.slot_c))
	var center: Vector2 = o + Vector2(CHIP * 0.5, CHIP * 0.5)
	var rot: int = int(ch.get("rot", 0))
	var kind: int = int(ch.kind)
	var local: Vector2
	if kind == CircuitModel.Kind.TRANSISTOR:
		if index == 0: # collector
			local = Vector2(CHIP * 0.35, -CHIP * 0.5)
		elif index == 1: # base
			local = Vector2(-CHIP * 0.5, 0.0)
		else: # emitter
			local = Vector2(CHIP * 0.35, CHIP * 0.5)
	elif kind == CircuitModel.Kind.POT:
		# Track ends at the top corners; the adjustable wiper is centered below.
		if index == 0:
			local = Vector2(-CHIP * 0.37, -CHIP * 0.5)
		elif index == 1:
			local = Vector2(CHIP * 0.37, -CHIP * 0.5)
		else:
			local = Vector2(0.0, CHIP * 0.5)
	elif kind == CircuitModel.Kind.SWITCH:
		# Inputs (0, 1) sit on the upper corners; outputs (2, 3) on the lower corners.
		var switch_x: float = -0.38 if index == 0 or index == 2 else 0.38
		var switch_y: float = -0.5 if index < 2 else 0.5
		local = Vector2(CHIP * switch_x, CHIP * switch_y)
	elif kind == CircuitModel.Kind.LEDW or kind == CircuitModel.Kind.LEDO or kind == CircuitModel.Kind.DIODE or kind == CircuitModel.Kind.MOTOR or kind == CircuitModel.Kind.LAMP:
		# Round components have two terminals close together near the top of the body.
		var round_x: float = -0.19 if index == 0 else 0.19
		local = Vector2(CHIP * round_x, -CHIP * 0.29)
	else:
		# Battery and resistor: terminal nodes sit at the two top corners.
		var square_x: float = -0.37 if index == 0 else 0.37
		local = Vector2(CHIP * square_x, -CHIP * 0.5)
	# Rotation remains available for components that have not been wired yet.
	for _r in range(rot % 4):
		local = Vector2(-local.y, local.x)
	return center + local



func _hit_wire(pos: Vector2) -> int:
	# Return wire id if click near a segment, else -1
	for wdict in model.wires:
		var pa: String = str(wdict.port_a)
		var pb: String = str(wdict.port_b)
		var parts_a: PackedStringArray = pa.split("_")
		var parts_b: PackedStringArray = pb.split("_")
		var ida: int = int(parts_a[0].substr(1))
		var idb: int = int(parts_b[0].substr(1))
		var ia: int = int(parts_a[1])
		var ib: int = int(parts_b[1])
		var a: Vector2 = _wire_endpoint(pa, int(wdict.id))
		var b: Vector2 = _wire_endpoint(pb, int(wdict.id))
		# distance from point to segment
		var ab: Vector2 = b - a
		var t: float = 0.0
		var denom: float = ab.length_squared()
		if denom > 1e-6:
			t = clampf((pos - a).dot(ab) / denom, 0.0, 1.0)
		var proj: Vector2 = a + ab * t
		if pos.distance_to(proj) <= 8.0:
			return int(wdict.id)
	return -1



func _wire_endpoint(port: String, wire_id: int) -> Vector2:
	## Slight offset so multiple wires on one port are visible (fan out).
	var parts: PackedStringArray = port.split("_")
	if parts.size() < 2:
		return Vector2.ZERO
	var cid: int = int(parts[0].substr(1))
	var pidx: int = int(parts[1])
	var base: Vector2 = _port_pos(cid, pidx)
	# Collect wire ids touching this port (stable order)
	var ids: Array = []
	for w in model.wires:
		if str(w.port_a) == port or str(w.port_b) == port:
			ids.append(int(w.id))
	ids.sort()
	var idx: int = ids.find(wire_id)
	if idx < 0 or ids.size() <= 1:
		return base
	var n: int = ids.size()
	var spread: float = 3.5
	var t: float = float(idx) - float(n - 1) * 0.5
	# Vertical fan-out remains readable for four or more wires on a port.
	return base + Vector2(0.0, t * spread)


func _hit_port(pos: Vector2) -> String:
	for c in model.chips:
		var nports: int = model.port_count(int(c.kind))
		for pi in range(nports):
			var pp: Vector2 = _port_pos(int(c.id), pi)
			if pos.distance_to(pp) <= 10.0:
				return model.port_id(int(c.id), pi)
	return ""


func _hit_chip(pos: Vector2) -> int:
	for c in model.chips:
		var o: Vector2 = _slot_origin(int(c.slot_r), int(c.slot_c))
		var rect := Rect2(o, Vector2(CHIP, CHIP))
		if rect.has_point(pos):
			return int(c.id)
	return -1


func _on_val(v: float) -> void:
	var ch: Dictionary = model.chip_by_id(_selected_chip)
	if ch.is_empty():
		return
	var k: int = int(ch.kind)
	if k == CircuitModel.Kind.R:
		ch.value = v
	elif k == CircuitModel.Kind.BAT:
		ch.value = clampf(v, 0.0, 24.0)
	elif k == CircuitModel.Kind.CAP:
		ch.value = clampf(v, 1.0, 1000.0)
	elif k == CircuitModel.Kind.IND:
		ch.value = clampf(v, 1.0, 1000.0)
	elif k == CircuitModel.Kind.POT:
		ch.value = clampf(v, 100.0, 100000.0)
	elif k == CircuitModel.Kind.FUSE:
		ch.value = clampf(v, 0.1, 5.0)
	elif k == CircuitModel.Kind.MOTOR:
		ch.value = clampf(v, 1.0, 100.0)
	elif k == CircuitModel.Kind.LAMP:
		ch.value = clampf(v, 1.0, 100.0)
	elif k == CircuitModel.Kind.TRANSISTOR:
		ch.value = clampf(v, 20.0, 300.0)
	model.solve()
	_refresh()


func _on_wiper_val(v: float) -> void:
	var ch: Dictionary = model.chip_by_id(_selected_chip)
	if ch.is_empty() or int(ch.kind) != CircuitModel.Kind.POT:
		return
	ch["wiper"] = clampf(v / 100.0, 0.0, 1.0)
	_wiper_label.text = "Wiper position: %.0f%%" % v
	model.solve()
	_refresh()


func _reset_selected_fuse() -> void:
	var ch: Dictionary = model.chip_by_id(_selected_chip)
	if ch.is_empty() or int(ch.kind) != CircuitModel.Kind.FUSE:
		return
	ch["blown"] = false
	model.solve()
	_refresh()


func _on_delete() -> void:
	if _selected_chip < 0:
		return
	model.remove_chip(_selected_chip)
	_selected_chip = -1
	_refresh()


func _on_clear() -> void:
	model.clear()
	_selected_chip = -1
	_wire_from = ""
	_refresh()


func _refresh() -> void:
	if _r_msg == null:
		return
	_r_msg.text = model.message
	_r_power.text = "%.3f W" % model.total_power
	var ch: Dictionary = model.chip_by_id(_selected_chip)
	if ch.is_empty():
		_r_sel.text = "—"
		_r_voltage.text = "—"
		_r_current.text = "—"
		_out_val.text = "Value"
		_slider_val.editable = false
		_wiper_label.visible = false
		_wiper_slider.visible = false
		_fuse_reset_button.visible = false
	else:
		var k: int = int(ch.kind)		
		_fuse_reset_button.visible = false
		var i: float = float(model.chip_i.get(int(ch.id), 0.0))
		var v: float = float(model.chip_v.get(int(ch.id), 0.0))
		var extra: String = ""
		if k == CircuitModel.Kind.LEDW or k == CircuitModel.Kind.LEDO:
			extra = " · LIT" if bool(ch.lit) else " · off"
		elif k == CircuitModel.Kind.DIODE:
			extra = " · forward" if i > 0.001 else " · blocking/reverse"
		elif k == CircuitModel.Kind.SWITCH:
			extra = " · ON" if bool(ch.closed) else " · OFF"
		elif k == CircuitModel.Kind.CAP:
			extra = " · charging" if absf(i) > 0.0001 else " · holding charge"
		elif k == CircuitModel.Kind.IND:
			extra = " · energized" if absf(i) > 0.0001 else " · no current"
		elif k == CircuitModel.Kind.POT:
			extra = " · wiper %.0f%%" % (float(ch.get("wiper", 0.5)) * 100.0)
		elif k == CircuitModel.Kind.FUSE:
			extra = " · BLOWN" if bool(ch.get("blown", false)) else " · intact"
		elif k == CircuitModel.Kind.MOTOR:
			extra = " · %.0f RPM" % (float(model.motor_speed.get(int(ch.id), 0.0)) * 3000.0)
		elif k == CircuitModel.Kind.LAMP:
			extra = " · glowing %.0f%%" % (float(model.lamp_temperature.get(int(ch.id), 0.0)) * 100.0) if float(model.lamp_temperature.get(int(ch.id), 0.0)) > 0.08 else " · cold/off"
		elif k == CircuitModel.Kind.TRANSISTOR:
			extra = " · active" if float(model.transistor_base_current.get(int(ch.id), 0.0)) > 0.0001 else " · cutoff"
		_r_sel.text = "%s%s" % [model.label_of(k), extra]
		_r_voltage.text = "%.3f V" % v
		_r_current.text = "%.4f A (signed)" % i
		if k == CircuitModel.Kind.R:
			_out_val.text = "R = %.0f Ω" % float(ch.value)
			_slider_val.min_value = 10.0
			_slider_val.max_value = 100000.0
			_slider_val.step = 10.0
			_slider_val.value = float(ch.value)
			_slider_val.editable = true
		elif k == CircuitModel.Kind.BAT:
			_out_val.text = "V = %.1f V" % float(ch.value)
			_slider_val.min_value = 0.0
			_slider_val.max_value = 24.0
			_slider_val.step = 0.5
			_slider_val.value = float(ch.value)
			_slider_val.editable = true
		elif k == CircuitModel.Kind.CAP:
			_out_val.text = "C = %.0f µF" % float(ch.value)
			_slider_val.min_value = 1.0
			_slider_val.max_value = 1000.0
			_slider_val.step = 1.0
			_slider_val.value = float(ch.value)
			_slider_val.editable = true
		elif k == CircuitModel.Kind.IND:
			_out_val.text = "L = %.0f mH" % float(ch.value)
			_slider_val.min_value = 1.0
			_slider_val.max_value = 1000.0
			_slider_val.step = 1.0
			_slider_val.value = float(ch.value)
			_slider_val.editable = true
			_wiper_label.visible = false
			_wiper_slider.visible = false
		elif k == CircuitModel.Kind.POT:
			_out_val.text = "Rtrack = %.0f Ω" % float(ch.value)
			_slider_val.min_value = 100.0
			_slider_val.max_value = 100000.0
			_slider_val.step = 100.0
			_slider_val.value = float(ch.value)
			_slider_val.editable = true
			_wiper_label.visible = true
			_wiper_slider.visible = true
			_wiper_slider.value = float(ch.get("wiper", 0.5)) * 100.0
			_wiper_label.text = "Wiper position: %.0f%%" % (float(ch.get("wiper", 0.5)) * 100.0)
			_fuse_reset_button.visible = false
		elif k == CircuitModel.Kind.FUSE:
			_out_val.text = "Rating = %.2f A" % float(ch.value)
			_slider_val.min_value = 0.1
			_slider_val.max_value = 5.0
			_slider_val.step = 0.1
			_slider_val.value = float(ch.value)
			_slider_val.editable = not bool(ch.get("blown", false))
			_wiper_label.visible = false
			_wiper_slider.visible = false
			_fuse_reset_button.visible = true
			_fuse_reset_button.text = "Reset blown fuse" if bool(ch.get("blown", false)) else "Replace fuse / reset state"
		elif k == CircuitModel.Kind.MOTOR:
			var rpm := float(model.motor_speed.get(int(ch.id), 0.0)) * 3000.0
			_out_val.text = "Armature R = %.1f Ω · %.0f RPM" % [float(ch.value), rpm]
			_slider_val.min_value = 1.0
			_slider_val.max_value = 100.0
			_slider_val.step = 1.0
			_slider_val.value = float(ch.value)
			_slider_val.editable = true
			_wiper_label.visible = false
			_wiper_slider.visible = false
			_fuse_reset_button.visible = false
		elif k == CircuitModel.Kind.LAMP:
			var lamp_temp := float(model.lamp_temperature.get(int(ch.id), 0.0))
			_out_val.text = "Hot R = %.1f Ω · brightness %.0f%%" % [float(ch.value) * lerpf(0.12, 1.0, lamp_temp), lamp_temp * 100.0]
			_slider_val.min_value = 1.0
			_slider_val.max_value = 100.0
			_slider_val.step = 1.0
			_slider_val.value = float(ch.value)
			_slider_val.editable = true
			_wiper_label.visible = false
			_wiper_slider.visible = false
			_fuse_reset_button.visible = false
		elif k == CircuitModel.Kind.TRANSISTOR:
			var ib := float(model.transistor_base_current.get(int(ch.id), 0.0))
			var ic := float(model.transistor_collector_current.get(int(ch.id), 0.0))
			_out_val.text = "DC gain β = %.0f · IB %.3f mA · IC %.3f A" % [float(ch.value), ib * 1000.0, ic]
			_slider_val.min_value = 20.0
			_slider_val.max_value = 300.0
			_slider_val.step = 10.0
			_slider_val.value = float(ch.value)
			_slider_val.editable = true
			_wiper_label.visible = false
			_wiper_slider.visible = false
			_fuse_reset_button.visible = false
		else:
			_out_val.text = model.label_of(k)
			_slider_val.editable = false
			_wiper_label.visible = false
			_wiper_slider.visible = false
			_fuse_reset_button.visible = false
	set_status(model.message)
	if _stage:
		_stage.queue_redraw()


func _glow_color(kind: int) -> Color:
	match kind:
		CircuitModel.Kind.R:
			return Color("#e53935")
		CircuitModel.Kind.LEDW:
			return Color("#ffffff")
		CircuitModel.Kind.LEDO:
			return Color("#ff9800")
		CircuitModel.Kind.DIODE:
			return Color("#42a5f5")
		CircuitModel.Kind.BAT:
			return Color("#ffc107")
		CircuitModel.Kind.SWITCH:
			return Color("#66bb6a")
	return Color.WHITE


func _draw_stage() -> void:
	if _stage == null:
		return
	var c: Control = _stage
	var w: float = c.size.x
	var h: float = c.size.y
	if w < 40.0 or h < 40.0:
		return
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#0d1117"), true)

	_ox = (w - BOARD) * 0.5
	_oy = (h - BOARD) * 0.5

	# Board card
	c.draw_rect(Rect2(_ox - 6.0, _oy - 6.0, BOARD + 12.0, BOARD + 12.0), Color("#b22222"), false, 3.0)
	c.draw_rect(Rect2(_ox, _oy, BOARD, BOARD), Color("#1a1a1a"), true)

	# Slot guides
	for i in range(CircuitModel.SLOTS + 1):
		var x: float = _ox + float(i) * CircuitModel.SLOT_PX
		var y: float = _oy + float(i) * CircuitModel.SLOT_PX
		c.draw_line(Vector2(x, _oy), Vector2(x, _oy + BOARD), Color(1, 1, 1, 0.04), 1.0)
		c.draw_line(Vector2(_ox, y), Vector2(_ox + BOARD, y), Color(1, 1, 1, 0.04), 1.0)

	# Wires under chips (slight offset when a port has multiple wires so they stay visible)
	for wdict in model.wires:
		var pa: String = str(wdict.port_a)
		var pb: String = str(wdict.port_b)
		var parts_a: PackedStringArray = pa.split("_")
		var parts_b: PackedStringArray = pb.split("_")
		var ida: int = int(parts_a[0].substr(1))
		var idb: int = int(parts_b[0].substr(1))
		var ia: int = int(parts_a[1])
		var ib: int = int(parts_b[1])
		var port_a_pos: Vector2 = _port_pos(ida, ia)
		var port_b_pos: Vector2 = _port_pos(idb, ib)
		var a: Vector2 = _wire_endpoint(pa, int(wdict.id))
		var b: Vector2 = _wire_endpoint(pb, int(wdict.id))
		var live: bool = float(model.wire_i.get(int(wdict.id), 0.0)) > 0.001
		var col := Color("#ffeb3b") if live else Color("#b0bec5")
		# Fan endpoints apart at crowded ports, while keeping the main wire straight
		# so wire hit-testing matches what the student sees.
		c.draw_line(port_a_pos, a, col, 1.5)
		c.draw_line(a, b, col, 2.0)
		c.draw_line(b, port_b_pos, col, 1.5)

	# Pending wire
	if _wire_from != "":
		var parts: PackedStringArray = _wire_from.split("_")
		var id0: int = int(parts[0].substr(1))
		var i0: int = int(parts[1])
		var a2: Vector2 = _port_pos(id0, i0)
		var mouse: Vector2 = c.get_local_mouse_position()
		c.draw_line(a2, mouse, Color("#90caf9"), 2.0)

	# Ghost chip while dragging
	if _dragging and _drag_kind >= 0 and _hover_slot.x >= 0:
		var o: Vector2 = _slot_origin(_hover_slot.x, _hover_slot.y)
		var okp: bool = model.slot_free(_hover_slot.x, _hover_slot.y)
		var gcol := Color(0.3, 0.9, 0.4, 0.4) if okp else Color(0.9, 0.2, 0.2, 0.4)
		c.draw_rect(Rect2(o, Vector2(CHIP, CHIP)), gcol, true)

	# Chips
	var pulse: float = 0.55 + 0.45 * sin(_pulse_t * 3.0)
	for ch in model.chips:
		_draw_chip(c, ch, pulse)

	c.draw_string(ThemeDB.fallback_font, Vector2(_ox, _oy - 14.0), "Circuit board 400×400", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b0bec5"))


func _draw_chip(c: Control, ch: Dictionary, pulse: float) -> void:
	var o: Vector2 = _slot_origin(int(ch.slot_r), int(ch.slot_c))
	var rect := Rect2(o, Vector2(CHIP, CHIP))
	var center: Vector2 = o + Vector2(CHIP * 0.5, CHIP * 0.5)
	var kind: int = int(ch.kind)
	var i_chip: float = absf(float(model.chip_i.get(int(ch.id), 0.0)))
	var active: bool = i_chip > 0.001
	if kind == CircuitModel.Kind.LEDW or kind == CircuitModel.Kind.LEDO:
		# Emission is strictly tied to the solver's lit state and non-zero current.
		active = bool(ch.get("lit", false)) and i_chip > 0.001
	if kind == CircuitModel.Kind.SWITCH:
		active = bool(ch.closed)

	var fill := Color("#2a2a2a")
	var stroke := Color("#90a4ae")
	if kind == CircuitModel.Kind.BAT:
		stroke = Color("#ffc107")
		fill = Color("#3e2723")
	elif kind == CircuitModel.Kind.R:
		stroke = Color("#e53935") if active else Color("#90a4ae")
		fill = Color("#3e2723")
	elif kind == CircuitModel.Kind.LEDW:
		stroke = Color.WHITE if active else Color("#cfd8dc")
		fill = Color("#d9e0e5") if not active else Color("#ffffff")
		if active:
			var inten: float = clampf(i_chip / 0.035, 0.55, 1.0)
			# Broad, bright white halo with a high-intensity core.
			c.draw_circle(center, CHIP * 0.78, Color(0.72, 0.86, 1.0, (0.18 + 0.12 * pulse) * inten))
			c.draw_circle(center, CHIP * 0.62, Color(0.86, 0.94, 1.0, (0.28 + 0.16 * pulse) * inten))
			c.draw_circle(center, CHIP * 0.47, Color(1.0, 1.0, 1.0, (0.48 + 0.20 * pulse) * inten))
			c.draw_circle(center, CHIP * 0.31, Color(1.0, 1.0, 1.0, 0.72 * inten))
	elif kind == CircuitModel.Kind.LEDO:
		stroke = Color("#ff9800") if active else Color("#cfd8dc")
		fill = Color("#ffd166") if active else Color("#3a2a18")
		if active:
			var inten2: float = clampf(i_chip / 0.035, 0.55, 1.0)
			# Strong amber/orange halo and bright yellow-white core.
			c.draw_circle(center, CHIP * 0.78, Color(1.0, 0.24, 0.0, (0.20 + 0.12 * pulse) * inten2))
			c.draw_circle(center, CHIP * 0.62, Color(1.0, 0.38, 0.02, (0.32 + 0.16 * pulse) * inten2))
			c.draw_circle(center, CHIP * 0.47, Color(1.0, 0.56, 0.08, (0.52 + 0.18 * pulse) * inten2))
			c.draw_circle(center, CHIP * 0.31, Color(1.0, 0.88, 0.48, 0.78 * inten2))
	elif kind == CircuitModel.Kind.DIODE:
		stroke = Color("#42a5f5") if active else Color("#90a4ae")
		fill = Color("#0d2b3d")
	elif kind == CircuitModel.Kind.CAP:
		stroke = Color("#ab8cff") if active else Color("#9575cd")
		fill = Color("#241c35")
	elif kind == CircuitModel.Kind.IND:
		stroke = Color("#26c6da") if active else Color("#00838f")
		fill = Color("#102d32")
	elif kind == CircuitModel.Kind.POT:
		stroke = Color("#66bb6a") if active else Color("#2e7d32")
		fill = Color("#142b1b")
	elif kind == CircuitModel.Kind.FUSE:
		stroke = Color("#ef5350") if bool(ch.get("blown", false)) else Color("#ffca28")
		fill = Color("#3b2920") if bool(ch.get("blown", false)) else Color("#302b1c")
	elif kind == CircuitModel.Kind.MOTOR:
		stroke = Color("#29b6f6") if active else Color("#0277bd")
		fill = Color("#102a3a")
	elif kind == CircuitModel.Kind.TRANSISTOR:
		var base_drive := float(model.transistor_base_current.get(int(ch.id), 0.0))
		stroke = Color("#80cbc4") if base_drive > 0.0001 else Color("#607d8b")
		fill = Color("#12332f") if base_drive > 0.0001 else Color("#202b31")
	elif kind == CircuitModel.Kind.LAMP:
		var temp_glow := float(model.lamp_temperature.get(int(ch.id), 0.0))
		stroke = Color("#ffb74d") if temp_glow > 0.08 else Color("#8d6e63")
		fill = Color("#6d3b17") if temp_glow > 0.08 else Color("#33271f")
		if temp_glow > 0.08:
			c.draw_circle(center, CHIP * 0.78, Color(1.0, 0.32, 0.02, 0.20 * temp_glow))
			c.draw_circle(center, CHIP * 0.58, Color(1.0, 0.52, 0.05, 0.28 * temp_glow))
			c.draw_circle(center, CHIP * 0.36, Color(1.0, 0.82, 0.28, 0.42 * temp_glow))
	elif kind == CircuitModel.Kind.SWITCH:
		stroke = Color("#66bb6a") if bool(ch.closed) else Color("#e53935")

	if int(ch.id) == _selected_chip:
		c.draw_rect(Rect2(o.x - 3.0, o.y - 3.0, CHIP + 6.0, CHIP + 6.0), Color("#ffeb3b"), false, 2.0)

	# LEDs and diodes use round bodies; the other parts remain square.
	var round_body: bool = kind == CircuitModel.Kind.LEDW or kind == CircuitModel.Kind.LEDO or kind == CircuitModel.Kind.DIODE or kind == CircuitModel.Kind.MOTOR or kind == CircuitModel.Kind.LAMP
	if round_body:
		c.draw_circle(center, CHIP * 0.42, fill)
		c.draw_circle(center, CHIP * 0.42, stroke, false, STROKE)
	else:
		c.draw_rect(rect, fill, true)
		c.draw_rect(rect, stroke, false, STROKE)

	# Component-specific symbols are drawn on the body for quick recognition.
	if kind == CircuitModel.Kind.BAT:
		c.draw_line(center + Vector2(-7, -7), center + Vector2(-7, 8), Color.WHITE, 2.0)
		c.draw_line(center + Vector2(1, -3), center + Vector2(1, 4), Color.WHITE, 3.0)
		c.draw_line(center + Vector2(-3, 0), center + Vector2(5, 0), Color.WHITE, 1.5)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-15, 16), "+  −", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	elif kind == CircuitModel.Kind.R:
		var zig := PackedVector2Array([center + Vector2(-12, 1), center + Vector2(-8, -5), center + Vector2(-3, 7), center + Vector2(2, -5), center + Vector2(7, 7), center + Vector2(12, 1)])
		c.draw_polyline(zig, Color.WHITE, 2.0, true)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-4, 16), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	elif kind == CircuitModel.Kind.DIODE:
		c.draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), Color.WHITE, 1.5)
		c.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -7), center + Vector2(-5, 7), center + Vector2(5, 0)]), Color.WHITE)
		c.draw_line(center + Vector2(6, -8), center + Vector2(6, 8), Color.WHITE, 2.0)
	elif kind == CircuitModel.Kind.LEDW or kind == CircuitModel.Kind.LEDO:
		var led_col := Color("#455a64") if kind == CircuitModel.Kind.LEDW else Color("#ffb74d")
		c.draw_line(center + Vector2(-8, 1), center + Vector2(8, 1), led_col, 1.5)
		c.draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -5), center + Vector2(-4, 7), center + Vector2(5, 1)]), led_col)
		# Outgoing light arrows distinguish an LED from a plain diode.
		c.draw_line(center + Vector2(4, -8), center + Vector2(10, -13), led_col, 1.5)
		c.draw_line(center + Vector2(7, -13), center + Vector2(10, -13), led_col, 1.5)
		c.draw_line(center + Vector2(10, -13), center + Vector2(10, -10), led_col, 1.5)
	elif kind == CircuitModel.Kind.CAP:
		# Standard non-polarized capacitor symbol: two parallel plates.
		c.draw_line(center + Vector2(-5, -10), center + Vector2(-5, 10), Color("#e1d7ff"), 3.0)
		c.draw_line(center + Vector2(5, -10), center + Vector2(5, 10), Color("#e1d7ff"), 3.0)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-12, 16), "%.0fµF" % float(ch.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#e1d7ff"))
	elif kind == CircuitModel.Kind.MOTOR:
		# DC motor: rotor circle and armature marks; spin indicator follows speed.
		var speed_now := float(model.motor_speed.get(int(ch.id), 0.0))
		var rotor_col := Color("#b3e5fc") if active else Color("#78909c")
		c.draw_circle(center, 10.0, Color("#0d1b24"), false, 1.5)
		var angle := _pulse_t * (2.0 + speed_now * 18.0)
		var rotor_end := center + Vector2(cos(angle), sin(angle)) * 8.0
		c.draw_line(center, rotor_end, rotor_col, 2.5)
		c.draw_circle(center, 2.5, Color.WHITE)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-14, 16), "%.0fRPM" % (speed_now * 3000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, rotor_col)
	elif kind == CircuitModel.Kind.LAMP:
		# Incandescent lamp: bulb filament and glow scale with simulated temperature.
		var temp_glow := clampf(float(model.lamp_temperature.get(int(ch.id), 0.0)), 0.0, 1.0)
		var bulb_col := Color(1.0, 0.88 - 0.25 * temp_glow, 0.52 - 0.42 * temp_glow) if temp_glow > 0.08 else Color("#b0bec5")
		c.draw_circle(center, 10.0, Color("#201810"), false, 1.5)
		c.draw_line(center + Vector2(-6, 5), center + Vector2(6, -5), bulb_col, 2.0)
		c.draw_line(center + Vector2(-5, -5), center + Vector2(5, 5), bulb_col, 2.0)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-12, 16), "%.0f%%" % (temp_glow * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, bulb_col)
	elif kind == CircuitModel.Kind.FUSE:
		# Cartridge fuse: metallic end caps and a link that visibly breaks when blown.
		var fuse_col := Color("#ef5350") if bool(ch.get("blown", false)) else Color("#ffe082")
		c.draw_line(center + Vector2(-13, 0), center + Vector2(-8, 0), Color("#cfd8dc"), 3.0)
		c.draw_line(center + Vector2(8, 0), center + Vector2(13, 0), Color("#cfd8dc"), 3.0)
		c.draw_rect(Rect2(center + Vector2(-8, -5), Vector2(16, 10)), Color("#6d5b3c"), false, 1.5)
		if bool(ch.get("blown", false)):
			c.draw_line(center + Vector2(-6, 0), center + Vector2(-2, -3), fuse_col, 2.0)
			c.draw_line(center + Vector2(2, 3), center + Vector2(6, 0), fuse_col, 2.0)
		else:
			c.draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), fuse_col, 2.0)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-12, 16), "%.1fA" % float(ch.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, fuse_col)
	elif kind == CircuitModel.Kind.POT:
		# Potentiometer track and adjustable wiper arrow.
		var pot_col := Color("#b9f6ca")
		c.draw_line(center + Vector2(-12, -5), center + Vector2(12, -5), pot_col, 2.0)
		c.draw_line(center + Vector2(0, -13), center + Vector2(0, 5), pot_col, 2.0)
		c.draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 2), center + Vector2(4, 2), center + Vector2(0, 7)]), pot_col)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-13, 16), "%.0fkΩ" % (float(ch.value) / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, pot_col)
	elif kind == CircuitModel.Kind.IND:
		# Recognizable inductor/coil symbol.
		var coil_color := Color("#b2f5fc")
		for coil_i in range(4):
			var coil_x := center.x - 12.0 + float(coil_i) * 8.0
			c.draw_arc(Vector2(coil_x + 4.0, center.y), 4.0, PI, TAU, 16, coil_color, 2.0, true)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-13, 16), "%.0fmH" % float(ch.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#b2f5fc"))
	elif kind == CircuitModel.Kind.TRANSISTOR:
		# Simplified NPN symbol: base bar, collector/emitter branches, and emitter arrow.
		var tcol := Color("#b2dfdb") if float(model.transistor_base_current.get(int(ch.id), 0.0)) > 0.0001 else Color("#90a4ae")
		c.draw_line(center + Vector2(-8, -10), center + Vector2(-8, 10), tcol, 2.0)
		c.draw_line(center + Vector2(-8, -3), center + Vector2(2, -10), tcol, 2.0)
		c.draw_line(center + Vector2(2, -10), center + Vector2(8, -14), tcol, 2.0)
		c.draw_line(center + Vector2(-8, 3), center + Vector2(2, 10), tcol, 2.0)
		c.draw_line(center + Vector2(2, 10), center + Vector2(8, 14), tcol, 2.0)
		c.draw_line(center + Vector2(2, 6), center + Vector2(7, 5), tcol, 1.5)
		c.draw_line(center + Vector2(2, 6), center + Vector2(4, 1), tcol, 1.5)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-10, 17), "NPN", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, tcol)
	elif kind == CircuitModel.Kind.SWITCH:
		var sw_col := Color("#66bb6a") if bool(ch.closed) else Color("#ef5350")
		c.draw_circle(center + Vector2(-8, 2), 2.5, Color.WHITE)
		c.draw_circle(center + Vector2(8, 2), 2.5, Color.WHITE)
		var lever_end := center + Vector2(7, 0) if bool(ch.closed) else center + Vector2(5, -9)
		c.draw_line(center + Vector2(-8, 2), lever_end, sw_col, 2.5)
		c.draw_string(ThemeDB.fallback_font, center + Vector2(-5, 16), "ON" if bool(ch.closed) else "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

	# Ports: blue = +, red = −; connection count remains visible at busy nodes.
	var nports: int = model.port_count(kind)
	for pi in range(nports):
		var pp: Vector2 = _port_pos(int(ch.id), pi)
		var pid: String = model.port_id(int(ch.id), pi)
		var nconn: int = model.port_connection_count(pid)
		var base_col := Color("#2196f3") if model.port_is_positive(kind, pi) else Color("#e53935")
		if kind == CircuitModel.Kind.POT and pi == 2:
			base_col = Color("#66bb6a")
		if kind == CircuitModel.Kind.TRANSISTOR and pi == 1:
			base_col = Color("#66bb6a")
		if pid == _wire_from:
			base_col = Color("#ffeb3b")
		var rad: float = 4.0 + float(mini(nconn, 8)) * 0.25
		c.draw_circle(pp, rad, base_col)
		c.draw_circle(pp, rad, Color("#212121"), false, 1.0)
		if nconn > 0:
			c.draw_string(ThemeDB.fallback_font, Vector2(pp.x + 5.0, pp.y - 4.0), str(nconn), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#cfd8dc"))


func _rotate_selected(clockwise: bool) -> void:
	if _selected_chip < 0:
		set_status("Select an unwired chip to rotate.")
		return
	if model.chip_has_wires(_selected_chip):
		set_status("Disconnect wires before rotating.")
		return
	if model.rotate_chip(_selected_chip, clockwise):
		set_status("Rotated %s." % ("CW" if clockwise else "CCW"))
		if _stage:
			_stage.queue_redraw()
	else:
		set_status("Cannot rotate.")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R, KEY_RIGHT:
			_rotate_selected(true)
			get_viewport().set_input_as_handled()
		KEY_L, KEY_LEFT:
			_rotate_selected(false)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _wire_from != "":
				_wire_from = ""
				set_status("Wire cancelled.")
				if _stage:
					_stage.queue_redraw()
			elif _dragging:
				_dragging = false
				_drag_kind = -1
			else:
				_on_back()
			get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			_on_delete()
			get_viewport().set_input_as_handled()
