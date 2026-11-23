extends Control
class_name LogicGateCanvas
## Interactive 2D view for the production Boolean circuit model.

signal component_selected(component_id: int)
signal input_toggled(component_id: int)
signal connect_requested(source_id: int, target_id: int, input_port: int)
signal component_moved(component_id: int, position: Vector2)
signal component_delete_requested(component_id: int)
signal connection_delete_requested(connection_index: int)
signal status_requested(message: String)

const MODEL_SCRIPT := preload("res://scripts/models/engineering/logic_circuit_model.gd")
const NODE_SIZE := Vector2(184.0, 116.0)
const GRID_SIZE := 32.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 1.8

var circuit_model: RefCounted
var selected_id := -1
var wire_source_id := -1
var evaluation: Dictionary = {}
var _zoom := 1.0
var _pan := Vector2(48.0, 42.0)
var _drag_component_id := -1
var _drag_offset := Vector2.ZERO
var _panning := false
var _pan_origin := Vector2.ZERO
var _mouse_world := Vector2.ZERO
var _selected_wire := -1

func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(480, 360)
	queue_redraw()


func set_model(model: RefCounted) -> void:
	circuit_model = model
	queue_redraw()


func set_view_state(selected: int, source: int, result: Dictionary) -> void:
	selected_id = selected
	wire_source_id = source
	evaluation = result
	queue_redraw()


func add_position() -> Vector2:
	return screen_to_world(size * 0.5)


func zoom_step(direction: int) -> void:
	var center := size * 0.5
	var before := screen_to_world(center)
	_zoom = clampf(_zoom * (1.12 if direction > 0 else 1.0 / 1.12), ZOOM_MIN, ZOOM_MAX)
	_pan = center - before * _zoom
	queue_redraw()


func screen_to_world(point: Vector2) -> Vector2:
	return (point - _pan) / _zoom


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101820"), true)
	draw_set_transform(_pan, 0.0, Vector2.ONE * _zoom)
	_draw_grid()
	if circuit_model == null:
		draw_set_transform(Vector2.ZERO)
		return
	var components: Array[Dictionary] = circuit_model.components()
	var wires: Array[Dictionary] = circuit_model.connections()
	for index in wires.size():
		_draw_wire(wires[index], components)
	if wire_source_id >= 0:
		var source: Dictionary = circuit_model.component(wire_source_id)
		if not source.is_empty():
			var start := _output_port(source)
			var end := screen_to_world(_mouse_world)
			_draw_curve(start, end, Color("#F6B84A"), 3.0, true)
	for component in components:
		_draw_component(component)
	draw_set_transform(Vector2.ZERO)
	_draw_hud()


func _draw_grid() -> void:
	var first := screen_to_world(Vector2.ZERO)
	var last := screen_to_world(size)
	var x_start := floori(first.x / GRID_SIZE) * GRID_SIZE
	var y_start := floori(first.y / GRID_SIZE) * GRID_SIZE
	for x in range(x_start, int(last.x) + int(GRID_SIZE), int(GRID_SIZE)):
		draw_line(Vector2(x, first.y), Vector2(x, last.y), Color("#1D2B35"), 1.0)
	for y in range(y_start, int(last.y) + int(GRID_SIZE), int(GRID_SIZE)):
		draw_line(Vector2(first.x, y), Vector2(last.x, y), Color("#1D2B35"), 1.0)


func _draw_wire(wire: Dictionary, components: Array[Dictionary]) -> void:
	var source: Dictionary = circuit_model.component(int(wire["from"]))
	var target: Dictionary = circuit_model.component(int(wire["to"]))
	if source.is_empty() or target.is_empty():
		return
	var port := int(wire["input"])
	var start := _output_port(source)
	var finish := _input_port(target, port)
	var state: int = circuit_model.input_state(int(target["id"]), port, evaluation)
	var color := _signal_color(state)
	var index := _connection_index(wire)
	if index == _selected_wire:
		color = Color("#F6B84A")
	_draw_curve(start, finish, color, 3.0 if index == _selected_wire else 2.0, false)
	var middle := (start + finish) * 0.5
	draw_circle(middle, 4.0, color)


func _draw_curve(start: Vector2, finish: Vector2, color: Color, width: float, dashed: bool) -> void:
	var dx := maxf(56.0, absf(finish.x - start.x) * 0.48)
	var control_a := start + Vector2(dx, 0)
	var control_b := finish - Vector2(dx, 0)
	var previous := start
	for step in range(1, 25):
		var t := float(step) / 24.0
		var inv := 1.0 - t
		var point := inv * inv * inv * start + 3.0 * inv * inv * t * control_a + 3.0 * inv * t * t * control_b + t * t * t * finish
		if not dashed or step % 2 == 1:
			draw_line(previous, point, color, width, true)
		previous = point


func _draw_component(item: Dictionary) -> void:
	var kind := str(item["kind"])
	var rect := Rect2(item["position"], NODE_SIZE)
	var selected := int(item["id"]) == selected_id
	var body := Color("#172832") if kind == "INPUT" else (Color("#202D3A") if kind == "OUTPUT" else Color("#1B2733"))
	draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Color(0, 0, 0, 0.30), true)
	draw_rect(rect, body, true)
	draw_rect(rect, Color("#55D6BE") if selected else Color("#344957"), false, 2.0 if selected else 1.0)
	var state := int(evaluation.get("values", {}).get(int(item["id"]), MODEL_SCRIPT.UNKNOWN))
	var accent := _signal_color(state)
	draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), accent, true)
	var font := get_theme_default_font()
	var title := str(item["label"])
	var subtitle := kind.capitalize() if kind in ["INPUT", "OUTPUT"] else kind + " gate"
	draw_string(font, rect.position + Vector2(16, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#EAF4F5"))
	draw_string(font, rect.position + Vector2(16, 49), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#91AAB4"))
	if kind == "INPUT":
		var high := bool(item["value"])
		var toggle_rect := Rect2(rect.position + Vector2(16, 66), Vector2(112, 30))
		draw_rect(toggle_rect, Color("#144E4A") if high else Color("#29343A"), true)
		draw_rect(toggle_rect, Color("#2ABCA7") if high else Color("#53616A"), false, 1.0)
		draw_string(font, toggle_rect.position + Vector2(12, 20), "HIGH · 1" if high else "LOW · 0", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#FFFFFF"))
	elif kind == "OUTPUT":
		draw_string(font, rect.position + Vector2(16, 92), circuit_model.signal_text(state), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, accent)
	else:
		var gate_rect := Rect2(rect.position + Vector2(32, 60), Vector2(120, 40))
		_draw_gate_symbol(gate_rect, kind, font)
		var output_state: String = circuit_model.signal_text(state)
		draw_string(font, rect.position + Vector2(16, 108), output_state, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, accent)
	for port in range(circuit_model.input_count(kind)):
		var point := _input_port(item, port)
		var port_state: int = circuit_model.input_state(int(item["id"]), port, evaluation)
		var port_color := Color("#F6B84A") if wire_source_id >= 0 else _signal_color(port_state)
		draw_circle(point, 9.0 if wire_source_id >= 0 else 7.0, port_color)
		draw_circle(point, 3.0, Color("#101820"))
		draw_string(font, point + Vector2(10, 4), "Y" if kind == "OUTPUT" else ("A" if port == 0 else "B"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#D3E1E3"))
	if circuit_model.has_output(kind):
		var point := _output_port(item)
		draw_circle(point, 7.0, _signal_color(state))
		draw_circle(point, 3.0, Color("#101820"))
		draw_string(font, point - Vector2(20, -4), "Y", HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color("#D3E1E3"))


func _draw_gate_symbol(rect: Rect2, kind: String, font: Font) -> void:
	var ink := Color("#4C6672")
	match kind:
		"AND", "NAND":
			var points := PackedVector2Array([rect.position, rect.position + Vector2(52, 0), rect.position + Vector2(78, 20), rect.position + Vector2(52, 40), rect.position])
			draw_colored_polygon(points, Color("#243C49"))
			for i in range(points.size() - 1): draw_line(points[i], points[i + 1], ink, 2.0)
			draw_line(rect.position + Vector2(78, 20), rect.position + Vector2(120, 20), ink, 2.0)
			if kind == "NAND": draw_circle(rect.position + Vector2(82, 20), 4.0, Color("#243C49")); draw_arc(rect.position + Vector2(82, 20), 4.0, 0, TAU, 20, ink, 1.5)
		"OR", "NOR", "XOR", "XNOR":
			var left := rect.position
			var p := PackedVector2Array([left + Vector2(0, 0), left + Vector2(26, 0), left + Vector2(74, 20), left + Vector2(26, 40), left + Vector2(0, 40)])
			draw_colored_polygon(p, Color("#243C49"))
			for i in range(p.size() - 1): draw_line(p[i], p[i + 1], ink, 2.0)
			draw_line(left + Vector2(74, 20), left + Vector2(120, 20), ink, 2.0)
			if kind in ["XOR", "XNOR"]:
				draw_line(left + Vector2(-7, 0), left + Vector2(19, 20), ink, 2.0)
				draw_line(left + Vector2(19, 20), left + Vector2(-7, 40), ink, 2.0)
			if kind in ["NOR", "XNOR"]: draw_circle(left + Vector2(78, 20), 4.0, Color("#243C49")); draw_arc(left + Vector2(78, 20), 4.0, 0, TAU, 20, ink, 1.5)
		"NOT":
			var p := PackedVector2Array([rect.position, rect.position + Vector2(62, 20), rect.position + Vector2(0, 40)])
			draw_colored_polygon(p, Color("#243C49"))
			for i in range(3): draw_line(p[i], p[(i + 1) % 3], ink, 2.0)
			draw_circle(rect.position + Vector2(68, 20), 4.0, Color("#243C49")); draw_arc(rect.position + Vector2(68, 20), 4.0, 0, TAU, 20, ink, 1.5)
			draw_line(rect.position + Vector2(72, 20), rect.position + Vector2(120, 20), ink, 2.0)
	draw_string(font, rect.position + Vector2(91, 25), kind, HORIZONTAL_ALIGNMENT_CENTER, 54, 10, Color("#D7E7E9"))


func _draw_hud() -> void:
	var font := get_theme_default_font()
	var zoom_text := "%.0f%%" % (_zoom * 100.0)
	draw_string(font, Vector2(16, size.y - 18), "GRID 32   ·   ZOOM %s   ·   DRAG OUTPUT TO INPUT" % zoom_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#77909A"))
	if wire_source_id >= 0:
		draw_string(font, Vector2(16, 24), "Choose a destination input pin  ·  Esc cancels", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#F6B84A"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_world = event.position
		if _panning:
			_pan = event.position - _pan_origin
			queue_redraw()
		elif _drag_component_id >= 0 and circuit_model != null:
			var position: Vector2 = screen_to_world(event.position) - _drag_offset
			position = (position / GRID_SIZE).round() * GRID_SIZE
			circuit_model.set_component_position(_drag_component_id, position)
			queue_redraw()
		else:
			queue_redraw()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			if _panning: _pan_origin = _pan - event.position
			accept_event()
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var before := screen_to_world(event.position)
			_zoom = clampf(_zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), ZOOM_MIN, ZOOM_MAX)
			_pan = event.position - before * _zoom
			queue_redraw()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				_mouse_world = event.position
				_handle_left_press(event.position)
			else:
				if _drag_component_id >= 0:
					var item: Dictionary = circuit_model.component(_drag_component_id)
					if not item.is_empty(): component_moved.emit(_drag_component_id, item["position"])
				_drag_component_id = -1
			queue_redraw()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var wire_index := _wire_at(event.position)
			if wire_index >= 0:
				_selected_wire = wire_index
				status_requested.emit("Wire selected. Press Delete to remove it.")
				queue_redraw()
				accept_event()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and wire_source_id >= 0:
			wire_source_id = -1
			queue_redraw()
			accept_event()
		elif event.keycode == KEY_DELETE:
			if _selected_wire >= 0: connection_delete_requested.emit(_selected_wire)
			elif selected_id >= 0: component_delete_requested.emit(selected_id)
			accept_event()


func _handle_left_press(point: Vector2) -> void:
	if circuit_model == null: return
	var world := screen_to_world(point)
	var component := _component_at(world)
	if not component.is_empty():
		var kind := str(component["kind"])
		var id := int(component["id"])
		var output_hit: bool = circuit_model.has_output(kind) and _near(world, _output_port(component), 13.0)
		var input_port := _input_port_at(component, world)
		if wire_source_id >= 0 and input_port >= 0:
			connect_requested.emit(wire_source_id, id, input_port)
			wire_source_id = -1
			_selected_wire = -1
			return
		if output_hit:
			wire_source_id = id
			selected_id = id
			component_selected.emit(id)
			return
		if input_port >= 0:
			status_requested.emit("Start wiring at a component output, then drop on this input pin.")
			return
		selected_id = id
		_selected_wire = -1
		component_selected.emit(id)
		if kind == MODEL_SCRIPT.INPUT and Rect2(component["position"] + Vector2(16, 66), Vector2(112, 30)).has_point(world):
			input_toggled.emit(id)
		else:
			_drag_component_id = id
			_drag_offset = world - component["position"]
		return
	var wire_index := _wire_at(point)
	if wire_index >= 0:
		_selected_wire = wire_index
		selected_id = -1
		status_requested.emit("Wire selected. Press Delete to remove it.")
	else:
		selected_id = -1
		_selected_wire = -1
		component_selected.emit(-1)
	queue_redraw()


func _component_at(world: Vector2) -> Dictionary:
	var items: Array[Dictionary] = circuit_model.components()
	for index in range(items.size() - 1, -1, -1):
		if Rect2(items[index]["position"], NODE_SIZE).has_point(world): return items[index]
	return {}


func _input_port_at(item: Dictionary, world: Vector2) -> int:
	for port in range(circuit_model.input_count(str(item["kind"]))):
		if _near(world, _input_port(item, port), 13.0): return port
	return -1


func _input_port(item: Dictionary, port: int) -> Vector2:
	var count: int = circuit_model.input_count(str(item["kind"]))
	return Vector2(item["position"].x, item["position"].y + NODE_SIZE.y * float(port + 1) / float(count + 1))


func _output_port(item: Dictionary) -> Vector2:
	return Vector2(item["position"].x + NODE_SIZE.x, item["position"].y + NODE_SIZE.y * 0.5)


func _connection_index(needle: Dictionary) -> int:
	var wires: Array[Dictionary] = circuit_model.connections()
	for i in wires.size():
		if wires[i] == needle: return i
	return -1


func _wire_at(screen_point: Vector2) -> int:
	if circuit_model == null: return -1
	var p := screen_to_world(screen_point)
	var wires: Array[Dictionary] = circuit_model.connections()
	var components: Dictionary = {}
	for item in circuit_model.components(): components[int(item["id"])] = item
	for i in range(wires.size() - 1, -1, -1):
		var wire := wires[i]
		if not components.has(int(wire["from"])) or not components.has(int(wire["to"])): continue
		var start := _output_port(components[int(wire["from"])])
		var finish := _input_port(components[int(wire["to"])], int(wire["input"]))
		var previous := start
		for step in range(1, 25):
			var t := float(step) / 24.0
			var dx := maxf(56.0, absf(finish.x - start.x) * 0.48)
			var a := start + Vector2(dx, 0)
			var b := finish - Vector2(dx, 0)
			var inv := 1.0 - t
			var current := inv * inv * inv * start + 3.0 * inv * inv * t * a + 3.0 * inv * t * t * b + t * t * t * finish
			if _distance_to_segment(p, previous, current) <= 9.0 / _zoom: return i
			previous = current
	return -1


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	var t := clampf((point - a).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return point.distance_to(a + segment * t)


func _near(a: Vector2, b: Vector2, radius: float) -> bool:
	return a.distance_to(b) <= radius


func _signal_color(state: int) -> Color:
	match state:
		MODEL_SCRIPT.LOW: return Color("#637782")
		MODEL_SCRIPT.HIGH: return Color("#41D7BB")
		MODEL_SCRIPT.ERROR: return Color("#F26B6B")
		_: return Color("#F6B84A")
