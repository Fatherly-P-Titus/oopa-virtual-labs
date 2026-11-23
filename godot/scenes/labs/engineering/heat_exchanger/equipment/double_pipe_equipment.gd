extends Control
class_name DoublePipeEquipment
## Interactive 2.5D double-pipe exchanger. Flow and temperature cues are model-driven,
## representative visualizations and are not CFD or local temperature-field results.

signal component_selected(component_id: String)
signal view_mode_changed(mode: String)

const DESIGN_SIZE := Vector2(1120, 500)
const COMPONENTS := {
	"outer_pipe": {"name": "Outer pipe", "fluid": "Annulus boundary", "description": "The outer pressure boundary contains the annular stream around the inner heat-transfer tube."},
	"inner_tube": {"name": "Inner tube", "fluid": "Hot-side tube circuit", "description": "The inner tube separates the tube-side stream from the annular stream and provides a heat-transfer surface."},
	"annulus": {"name": "Annular passage", "fluid": "Cold-side annulus circuit", "description": "The ring-shaped passage between the two pipes carries the second fluid stream."},
	"hot_inlet": {"name": "Hot-side inlet", "fluid": "Hot circuit", "description": "Inlet connection for the stream represented in the inner tube. Its current temperature and flow are set by the operating controls."},
	"hot_outlet": {"name": "Hot-side outlet", "fluid": "Hot circuit", "description": "Outlet connection for the stream represented in the inner tube."},
	"cold_inlet": {"name": "Cold-side inlet", "fluid": "Cold circuit", "description": "Inlet connection for the stream represented in the annular passage."},
	"cold_outlet": {"name": "Cold-side outlet", "fluid": "Cold circuit", "description": "Outlet connection for the stream represented in the annular passage."},
	"supports": {"name": "Saddle supports", "fluid": "Structure", "description": "Support the outer pipe and transfer equipment weight to the foundation."},
	"instruments": {"name": "Temperature taps", "fluid": "Instrumentation", "description": "Readouts display inlet and outlet temperatures returned by the heat-exchanger model."}
}

var selected_component := "outer_pipe"
var cutaway_progress := 0.0
var exploded_progress := 0.0
var parallel_flow := false
var operating_state: Dictionary = {}
var _mode := "external"
var _tween: Tween
var _origin := Vector2.ZERO
var _scale := 1.0
var _elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(520, 330)
	queue_redraw()

func _process(delta: float) -> void:
	if not operating_state.is_empty() and _mode != "external":
		var speed := clampf((float(operating_state.get("hot_mass_flow_kg_s", 0.2)) + float(operating_state.get("cold_mass_flow_kg_s", 0.2))) * 1.8, 0.25, 2.8)
		_elapsed = fposmod(_elapsed + delta * speed, 1.0)
		queue_redraw()

func component_info(component_id: String = "") -> Dictionary:
	return COMPONENTS.get(component_id if component_id != "" else selected_component, {}).duplicate(true)

func set_operating_state(state: Dictionary, is_parallel: bool) -> void:
	operating_state = state.duplicate(true)
	parallel_flow = is_parallel
	queue_redraw()

func set_view_mode(mode: String) -> void:
	if not ["external", "cutaway", "flow"].has(mode): return
	_mode = mode
	if _tween and _tween.is_running(): _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_cutaway, cutaway_progress, 0.0 if mode == "external" else 1.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_exploded, exploded_progress, 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	view_mode_changed.emit(mode)

func restore_assembled() -> void:
	set_view_mode("external")

func _set_cutaway(value: float) -> void:
	cutaway_progress = value
	queue_redraw()

func _set_exploded(value: float) -> void:
	exploded_progress = value
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101923"), true)
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_scale = scale_factor
	_origin = (size - DESIGN_SIZE * scale_factor) * 0.5
	draw_set_transform(_origin, 0.0, Vector2.ONE * scale_factor)
	_draw_grid()
	_draw_equipment()
	_draw_selection()
	_draw_labels()
	draw_set_transform(Vector2.ZERO)
	_draw_overlay()

func _draw_grid() -> void:
	for x in range(24, 1120, 32): draw_line(Vector2(x, 28), Vector2(x, 466), Color("#172530"), 1.0)
	for y in range(28, 470, 32): draw_line(Vector2(24, y), Vector2(1090, y), Color("#172530"), 1.0)
	draw_line(Vector2(50, 410), Vector2(1070, 410), Color("#394a53"), 2.0)
	_draw_ellipse(Vector2(562, 408), Vector2(385, 24), Color(0.0, 0.0, 0.0, 0.33))

func _draw_equipment() -> void:
	var shell_alpha := 1.0 - 0.88 * cutaway_progress
	var shift := exploded_progress * 28.0
	# Supports and baseplates anchor the horizontal equipment.
	for x in [330.0, 760.0]:
		_draw_polygon([Vector2(x - 48, 350), Vector2(x + 42, 350), Vector2(x + 62, 405), Vector2(x - 65, 405)], Color("#465963"))
		_draw_line(Vector2(x - 38, 359), Vector2(x + 34, 359), Color("#aab9be"), 3.0)
		draw_rect(Rect2(x - 78, 403, 150, 10), Color("#25343c"), true)
	# Outer pipe: faceted shell, end ellipses, raised longitudinal highlight and flange rings.
	var outer := Rect2(176 + shift, 158, 770, 190)
	_draw_ellipse(Vector2(outer.position.x + 12, outer.get_center().y), Vector2(38, 96), Color("#687b84", shell_alpha))
	_draw_polygon([Vector2(outer.position.x + 12, outer.position.y + 18), Vector2(outer.end.x - 25, outer.position.y + 18), Vector2(outer.end.x, outer.position.y + 42), Vector2(outer.end.x, outer.end.y - 38), Vector2(outer.end.x - 25, outer.end.y - 14), Vector2(outer.position.x + 12, outer.end.y - 14)], Color("#465b66", shell_alpha))
	_draw_ellipse(Vector2(outer.end.x - 10, outer.get_center().y), Vector2(34, 94), Color("#2b3d46", shell_alpha))
	_draw_line(Vector2(outer.position.x + 40, outer.position.y + 32), Vector2(outer.end.x - 25, outer.position.y + 32), Color("#c2cdd0", 0.5 * shell_alpha), 5.0)
	_draw_line(Vector2(outer.position.x + 42, outer.end.y - 32), Vector2(outer.end.x - 25, outer.end.y - 32), Color("#1d2d35", 0.8 * shell_alpha), 5.0)
	for fx in [outer.position.x + 60, outer.end.x - 55]:
		_draw_round_rect(Rect2(fx - 8, outer.position.y + 15, 18, 160), Color("#74868e", shell_alpha), Color("#d0dadd", shell_alpha), 2.0)
		for bolt_y in range(0, 7): draw_circle(Vector2(fx + 1, outer.position.y + 30 + bolt_y * 21), 2.6, Color("#e2e8e9", shell_alpha))
	# Annular passage is visible inside the shell and bounded by the inner tube.
	if cutaway_progress > 0.02:
		var annulus_tint := Color("#317fa3", 0.22 + 0.18 * cutaway_progress)
		_draw_round_rect(Rect2(246 + shift, 207, 628, 98), annulus_tint, Color("#67b6d5", 0.55 * cutaway_progress), 1.5)
	# Inner tube, with circular exposed ends and a polished metallic edge.
	var inner_tint := Color("#9eafb5", 0.42 + 0.58 * cutaway_progress)
	if cutaway_progress > 0.02:
		_draw_line(Vector2(224 + shift, 256), Vector2(876 + shift, 256), Color("#23343b"), 36.0)
		_draw_line(Vector2(224 + shift, 256), Vector2(876 + shift, 256), inner_tint, 24.0)
		_draw_line(Vector2(238 + shift, 248), Vector2(866 + shift, 248), Color("#e0e8e9", 0.55 * (0.35 + 0.65 * cutaway_progress)), 3.0)
		for x in [224.0 + shift, 876.0 + shift]:
			_draw_ellipse(Vector2(x, 256), Vector2(18, 18), Color("#273b44"))
			draw_circle(Vector2(x, 256), 10.0, Color("#101923"))
	# Cutaway lips communicate that the front shell wall is removed for inspection.
	if cutaway_progress > 0.02:
		_draw_round_rect(Rect2(248 + shift, 205, 625, 7), Color("#91a2a8", 0.8 * cutaway_progress), Color("#dce4e6", 0.8 * cutaway_progress), 1.0)
		_draw_round_rect(Rect2(248 + shift, 300, 625, 7), Color("#344953", 0.95 * cutaway_progress), Color("#83979f", 0.7 * cutaway_progress), 1.0)
	# Annulus and tube connections, flanged unions, and flow labels.
	var cold_inlet_x := 286.0 + shift if parallel_flow else 828.0 + shift
	var cold_outlet_x := 828.0 + shift if parallel_flow else 286.0 + shift
	_draw_connection(Vector2(cold_inlet_x, 205), Vector2(cold_inlet_x, 108), Color("#4d606b"), "cold_inlet")
	_draw_connection(Vector2(cold_outlet_x, 305), Vector2(cold_outlet_x, 386), Color("#4d606b"), "cold_outlet")
	_draw_connection(Vector2(224 + shift, 256), Vector2(104 + shift, 256), Color("#566b75"), "hot_inlet")
	_draw_connection(Vector2(876 + shift, 256), Vector2(1010 + shift, 256), Color("#566b75"), "hot_outlet")
	# Model-derived representative pathway tint and direction.
	var hot_in := float(operating_state.get("hot_in_k", 373.15))
	var hot_out := float(operating_state.get("hot_out_k", 353.15))
	var cold_in := float(operating_state.get("cold_in_k", 293.15))
	var cold_out := float(operating_state.get("cold_out_k", 313.15))
	if cutaway_progress > 0.12 and operating_state.has("hot_out_k") and operating_state.has("cold_out_k"):
		var hot_start := _thermal_color(hot_in)
		var hot_end := _thermal_color(hot_out)
		var cold_start := _thermal_color(cold_in)
		var cold_end := _thermal_color(cold_out)
		var hot_from := 224.0 + shift
		var hot_to := 876.0 + shift
		var cold_from := 260.0 + shift
		var cold_to := 856.0 + shift
		var cold_start_x := cold_from if parallel_flow else cold_to
		var cold_end_x := cold_to if parallel_flow else cold_from
		for segment in range(10):
			var t0 := float(segment) / 10.0
			var t1 := float(segment + 1) / 10.0
			var hx0 := lerpf(hot_from, hot_to, t0)
			var hx1 := lerpf(hot_from, hot_to, t1)
			var hot_color := hot_start.lerp(hot_end, (t0 + t1) * 0.5)
			_draw_line(Vector2(hx0, 256), Vector2(hx1, 256), hot_color, 5.0)
			var cx0 := lerpf(cold_start_x, cold_end_x, t0)
			var cx1 := lerpf(cold_start_x, cold_end_x, t1)
			var cold_color := cold_start.lerp(cold_end, (t0 + t1) * 0.5)
			_draw_line(Vector2(cx0, 220), Vector2(cx1, 220), cold_color, 4.0)
			_draw_line(Vector2(cx0, 292), Vector2(cx1, 292), cold_color, 4.0)
		_draw_arrow(Vector2(hot_from, 256), Vector2(hot_to, 256), hot_start.lerp(hot_end, 0.45), 2.0)
		_draw_arrow(Vector2(cold_start_x, 220), Vector2(cold_end_x, 220), cold_start.lerp(cold_end, 0.45), 2.0)
		_draw_arrow(Vector2(cold_start_x, 292), Vector2(cold_end_x, 292), cold_start.lerp(cold_end, 0.45), 2.0)
		_draw_particles(hot_from, hot_to, 256, hot_start.lerp(hot_end, _elapsed), float(operating_state.get("hot_mass_flow_kg_s", 0.2)))
		_draw_particles(cold_start_x, cold_end_x, 220, cold_start.lerp(cold_end, _elapsed), float(operating_state.get("cold_mass_flow_kg_s", 0.2)))
	# Instrument locations are labelled with actual model outlet readings.
	if operating_state.has("hot_out_k") and operating_state.has("cold_out_k"):
		_draw_gauge(Vector2(570, 145), "HOT OUT", _format_c(hot_out), Color("#ee815f"))
		_draw_gauge(Vector2(700, 145), "COLD OUT", _format_c(cold_out), Color("#60b4df"))

func _draw_labels() -> void:
	var font := get_theme_default_font()
	var arrangement := "PARALLEL FLOW" if parallel_flow else "COUNTER-CURRENT FLOW"
	draw_string(font, Vector2(410, 442), "DOUBLE-PIPE  ·  INNER TUBE + ANNULAR PASSAGE  ·  %s" % arrangement, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color("#a8bbc1"))
	if cutaway_progress > 0.35:
		draw_string(font, Vector2(292, 196), "ANNULAR STREAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#7cc9e2"))
		draw_string(font, Vector2(458, 275), "INNER-TUBE STREAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f3a187"))

func _draw_overlay() -> void:
	var title := "FLOW PATH · REPRESENTATIVE" if _mode == "flow" else ("CUTAWAY · INTERNAL PASSAGES" if _mode == "cutaway" else "EXTERNAL EQUIPMENT VIEW")
	var state_note := "MODEL-DRIVEN TEMPERATURE TINTS" if operating_state.has("hot_out_k") else "WAITING FOR VALID MODEL INPUTS"
	draw_string(get_theme_default_font(), Vector2(18, 22), title + "  ·  " + state_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#74c9bb"))
	draw_string(get_theme_default_font(), Vector2(18, size.y - 12), "Representative stream paths; no CFD or local field solution", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#92a5ad"))

func _draw_connection(base: Vector2, end: Vector2, color: Color, component: String) -> void:
	var direction := (end - base).normalized()
	var side := Vector2(-direction.y, direction.x) * 16.0
	_draw_polygon([base - side, base + side, end + side * 0.72, end - side * 0.72], color)
	_draw_line(base - side + Vector2(2, -2), end - side * 0.72 + Vector2(2, -2), Color("#c5d0d4"), 3.0)
	_draw_round_rect(Rect2(end.x - 23, end.y - 9, 46, 18), Color("#354953"), Color("#bac8cd"), 2.0)
	for dx in [-14.0, 14.0]: draw_circle(end + Vector2(dx, 0), 2.5, Color("#dfe7e9"))

func _draw_gauge(center: Vector2, label: String, reading: String, tint: Color) -> void:
	draw_circle(center, 23, Color("#20323b"))
	draw_arc(center, 23, 0, TAU, 28, Color("#bdcbd0"), 2.0)
	draw_line(center + Vector2(-8, 3), center + Vector2(7, -6), tint, 2.0)
	draw_string(get_theme_default_font(), center + Vector2(-34, -30), "%s %s" % [label, reading], HORIZONTAL_ALIGNMENT_LEFT, 100, 9, tint)

func _draw_particles(from_x: float, to_x: float, y: float, tint: Color, mass_flow: float) -> void:
	var direction := signf(to_x - from_x)
	var span := absf(to_x - from_x)
	var flow_scale := clampf(mass_flow / 0.2, 0.55, 1.8)
	for i in range(4):
		var t := fposmod(_elapsed * flow_scale + float(i) * 0.25, 1.0)
		draw_circle(Vector2(from_x + direction * span * t, y), 4.0, tint)
		draw_circle(Vector2(from_x + direction * span * t, y), 1.4, Color("#f4f8f7"))

func _thermal_color(temp_k: float) -> Color:
	# Temperature is converted to a restrained cool-to-warm presentation palette.
	var fraction := clampf((temp_k - 273.15) / 100.0, 0.0, 1.0)
	return Color("#55a9db").lerp(Color("#ed805f"), fraction)

func _format_c(temp_k: float) -> String:
	return "%.1f°C" % (temp_k - 273.15)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point: Vector2 = (event.position - _origin) / _scale
		var component := _component_at(point)
		if component != "":
			selected_component = component
			component_selected.emit(component)
			queue_redraw()
			accept_event()

func _component_at(point: Vector2) -> String:
	var hitboxes := {
		"hot_inlet": Rect2(72, 214, 166, 84), "hot_outlet": Rect2(860 + exploded_progress * 28, 214, 190, 84),
		"cold_inlet": Rect2(245 if parallel_flow else 785, 80, 90, 145), "cold_outlet": Rect2(785 if parallel_flow else 245, 288, 90, 120),
		"instruments": Rect2(535, 115, 175, 70), "supports": Rect2(230, 345, 620, 70),
		"inner_tube": Rect2(216, 226, 675, 62), "annulus": Rect2(239, 194, 645, 112),
		"outer_pipe": Rect2(168, 145, 790, 220)
	}
	for id in ["hot_inlet", "hot_outlet", "cold_inlet", "cold_outlet", "instruments", "supports", "inner_tube", "annulus", "outer_pipe"]:
		if Rect2(hitboxes[id]).has_point(point): return id
	return ""

func _draw_arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	_draw_line(from, to, color, width)
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	_draw_polygon([to, to - direction * 12.0 + normal * 6.0, to - direction * 12.0 - normal * 6.0], color)

func _draw_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, true)

func _draw_selection() -> void:
	var bounds := _component_at_selection_bounds(selected_component)
	if bounds.size != Vector2.ZERO:
		draw_rect(bounds, Color("#f5c76d"), false, 3.0)

func _component_at_selection_bounds(component: String) -> Rect2:
	match component:
		"inner_tube": return Rect2(216, 226, 675, 62)
		"annulus": return Rect2(239, 194, 645, 112)
		"outer_pipe": return Rect2(168, 145, 790, 220)
		"hot_inlet": return Rect2(72, 214, 166, 84)
		"hot_outlet": return Rect2(860, 214, 190, 84)
		"cold_inlet": return Rect2(245 if parallel_flow else 785, 80, 90, 145)
		"cold_outlet": return Rect2(785 if parallel_flow else 245, 288, 90, 120)
		"supports": return Rect2(230, 345, 620, 70)
		"instruments": return Rect2(535, 115, 175, 70)
		_: return Rect2()

func _draw_polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(36):
		var angle := TAU * float(i) / 36.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _draw_round_rect(rect: Rect2, fill: Color, border: Color, width: float) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, width)
