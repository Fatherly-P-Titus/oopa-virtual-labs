extends Control
class_name ShellAndTubeEquipment
## Layered orthographic 2.5D illustration of a horizontal one-shell-pass exchanger.

signal component_selected(component_id: String)
signal view_mode_changed(mode: String)

const DESIGN_SIZE := Vector2(1200, 560)
const TWEEN_TIME := 0.42
const COMPONENTS := {
	"shell": {"name": "Pressure shell", "fluid": "Shell side", "description": "Contains the shell-side stream and directs it across the tube bundle. This view represents one shell pass with segmental baffles."},
	"front_head": {"name": "Front channel head", "fluid": "Tube side", "description": "Distributes tube-side flow into the selected two-pass channel arrangement and collects the returning pass."},
	"rear_head": {"name": "Rear channel cover", "fluid": "Tube side", "description": "Closes the rear end of the tube circuit and allows access for inspection and maintenance."},
	"tube_bundle": {"name": "Tube bundle", "fluid": "Tube side", "description": "Parallel heat-transfer tubes carry one fluid while the shell-side stream passes around them. Individual lines represent a subset of the bundle."},
	"tube_sheet_front": {"name": "Front tube sheet", "fluid": "Tube-side boundary", "description": "Supports and seals tube ends at the channel head, separating tube-side and shell-side fluids."},
	"tube_sheet_rear": {"name": "Rear tube sheet", "fluid": "Tube-side boundary", "description": "Supports the far ends of the tubes and maintains the pressure boundary between the two circuits."},
	"baffles": {"name": "Segmental baffles", "fluid": "Shell side", "description": "Support the tube bundle and redirect shell-side flow across the tubes. Spacing and cut shown are a representative educational arrangement."},
	"tube_inlet": {"name": "Tube-side inlet", "fluid": "Tube side", "description": "Connection for the tube-side inlet stream. The two-pass channel head separates inlet and return chambers."},
	"tube_outlet": {"name": "Tube-side outlet", "fluid": "Tube side", "description": "Connection returning the tube-side stream from the second pass."},
	"shell_inlet": {"name": "Shell-side inlet nozzle", "fluid": "Shell side", "description": "Feeds the shell-side stream into the shell. Nozzle placement is illustrative and not a pressure-vessel design."},
	"shell_outlet": {"name": "Shell-side outlet nozzle", "fluid": "Shell side", "description": "Collects shell-side fluid after it traverses the baffled tube bundle."},
	"supports": {"name": "Saddle supports", "fluid": "Structure", "description": "Transfer equipment weight to its foundation while supporting the cylindrical shell."},
	"instruments": {"name": "Measurement taps", "fluid": "Instrumentation", "description": "Representative temperature and pressure tap locations. The live outlet temperatures are supplied by the validated heat-exchanger model; pressure estimates are shown in the operation panel."}
}

var cutaway_progress := 0.0
var exploded_progress := 0.0
var selected_component := "shell"
var _view_mode := "external"
var _tween: Tween
var _scale := 1.0
var _origin := Vector2.ZERO
var operating_state: Dictionary = {}
var _elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(520, 340)
	queue_redraw()

func _process(delta: float) -> void:
	if not operating_state.is_empty() and _view_mode != "external":
		var speed := clampf((float(operating_state.get("hot_mass_flow_kg_s", 0.2)) + float(operating_state.get("cold_mass_flow_kg_s", 0.2))) * 1.8, 0.25, 2.8)
		_elapsed = fposmod(_elapsed + delta * speed, 1.0)
		queue_redraw()

func set_operating_state(state: Dictionary) -> void:
	operating_state = state.duplicate(true)
	queue_redraw()

func component_ids() -> Array[String]:
	var result: Array[String] = []
	for key in COMPONENTS: result.append(str(key))
	return result

func component_info(component_id: String = "") -> Dictionary:
	return COMPONENTS.get(component_id if component_id != "" else selected_component, {}).duplicate(true)

func view_mode() -> String:
	return _view_mode

func set_view_mode(mode: String) -> void:
	if not ["external", "cutaway", "exploded"].has(mode): return
	_view_mode = mode
	if _tween and _tween.is_running(): _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_cutaway, cutaway_progress, 1.0 if mode != "external" else 0.0, TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_exploded, exploded_progress, 1.0 if mode == "exploded" else 0.0, TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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
	var sc := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_scale = sc
	_origin = (size - DESIGN_SIZE * sc) * 0.5
	draw_set_transform(_origin, 0.0, Vector2.ONE * sc)
	_draw_background()
	_draw_floor_shadow()
	_draw_supports()
	_draw_nozzles_back()
	_draw_inner_bundle()
	_draw_shell()
	_draw_heads_and_flanges()
	_draw_nozzles_front()
	_draw_instruments()
	_draw_callouts()
	_draw_selection()
	draw_set_transform(Vector2.ZERO)
	_draw_overlay()

func _draw_background() -> void:
	for x in range(24, 1200, 32): draw_line(Vector2(x, 28), Vector2(x, 532), Color("#172530"), 1.0)
	for y in range(28, 560, 32): draw_line(Vector2(24, y), Vector2(1176, y), Color("#172530"), 1.0)
	draw_line(Vector2(36, 476), Vector2(1164, 476), Color("#354650"), 2.0)

func _draw_floor_shadow() -> void:
	_draw_ellipse(Vector2(590, 470), Vector2(410, 25), Color(0.0, 0.0, 0.0, 0.32))

func _draw_supports() -> void:
	for x in [390.0, 750.0]:
		var offset := _exploded_offset("shell").y
		var p: float = float(x)
		_draw_polygon([Vector2(p - 55, 415 + offset), Vector2(p + 45, 415 + offset), Vector2(p + 65, 465), Vector2(p - 72, 465)], Color("#485b66"))
		draw_line(Vector2(p - 47, 422 + offset), Vector2(p + 40, 422 + offset), Color("#a6b6bd"), 4.0)
		_draw_round_rect(Rect2(p - 88, 463, 155, 12), Color("#24323a"), Color("#71838b"), 2.0)

func _draw_nozzles_back() -> void:
	var p := exploded_progress
	_draw_nozzle(Vector2(445, 158 - p * 28), Vector2(445, 95 - p * 28), Color("#4d606c"), "shell_inlet")
	_draw_nozzle(Vector2(720, 158 - p * 28), Vector2(720, 95 - p * 28), Color("#4d606c"), "shell_outlet")

func _draw_inner_bundle() -> void:
	var sep := exploded_progress
	var x1 := 298.0 + sep * 115.0
	var x2 := 840.0 + sep * 120.0
	var shell_y := -exploded_progress * 92.0
	var top := 232.0 + shell_y
	var bottom := 372.0 + shell_y
	if cutaway_progress > 0.01 and operating_state.has("hot_out_k") and operating_state.has("cold_out_k"):
		# The shell-side temperature tint follows model inlet/outlet values. Arrows are
		# representative baffled passages, not a resolved local temperature field.
		for y in [258.0, 302.0, 346.0]:
			_draw_arrow(Vector2(380, y + shell_y), Vector2(468, y + shell_y + 22), _stream_color(false, 0.35), 3.0, 0.9 * cutaway_progress)
			_draw_arrow(Vector2(545, y + shell_y + 22), Vector2(635, y + shell_y), _stream_color(false, 0.7), 3.0, 0.9 * cutaway_progress)
		_draw_arrow(Vector2(x1 + 30, 282 + shell_y), Vector2(x2 - 24, 282 + shell_y), _stream_color(true, 0.4), 4.0, 0.85 * cutaway_progress)
		_draw_arrow(Vector2(x2 - 24, 326 + shell_y), Vector2(x1 + 30, 326 + shell_y), _stream_color(true, 0.8), 4.0, 0.85 * cutaway_progress)
		for particle in range(4):
			var progress := fposmod(_elapsed + float(particle) * 0.25, 1.0)
			var px := lerpf(x1 + 40, x2 - 30, progress)
			draw_circle(Vector2(px, 282 + shell_y), 4.0, _stream_color(true, progress))
			var return_x := lerpf(x2 - 30, x1 + 40, fposmod(progress + 0.5, 1.0))
			draw_circle(Vector2(return_x, 326 + shell_y), 3.5, _stream_color(true, 1.0 - progress))
	# Tube bundle: individual, polished straight-tube paths.
	for row in range(7):
		var y := top + 12.0 + row * 20.0
		var tube_color := Color("#aebdc2") if row % 2 == 0 else Color("#82969e")
		draw_line(Vector2(x1, y), Vector2(x2, y), Color("#24323a"), 10.0)
		draw_line(Vector2(x1, y - 2), Vector2(x2, y - 2), tube_color, 4.5)
		draw_line(Vector2(x1, y - 3.2), Vector2(x2, y - 3.2), Color("#e0e8e9", 0.58), 1.0)
	# Segmented baffles: vertical plates with alternating segmental windows.
	for index in range(4):
		var bx := lerpf(410.0, 730.0, float(index) / 3.0) + sep * (float(index) - 1.5) * 18.0
		var lower_cut := index % 2 == 0
		var poly: PackedVector2Array
		if lower_cut:
			poly = PackedVector2Array([Vector2(bx - 7, top + 2), Vector2(bx + 7, top + 2), Vector2(bx + 7, bottom - 34), Vector2(bx, bottom - 18), Vector2(bx - 7, bottom - 34)])
		else:
			poly = PackedVector2Array([Vector2(bx - 7, top + 34), Vector2(bx, top + 18), Vector2(bx + 7, top + 34), Vector2(bx + 7, bottom - 2), Vector2(bx - 7, bottom - 2)])
		_draw_polygon(poly, Color("#bc8747", 0.92 * cutaway_progress))
		for k in range(5): draw_line(poly[k], poly[(k + 1) % poly.size()], Color("#f2c77d", 0.8 * cutaway_progress), 1.5)
	# Tube sheets at both ends.
	for x in [x1 - 9.0, x2 + 2.0]:
		_draw_round_rect(Rect2(x - 8, top - 7, 16, bottom - top + 14), Color("#647883", 0.35 + 0.65 * cutaway_progress), Color("#d2dfe2", 0.5 + 0.5 * cutaway_progress), 2.0)
		for row in range(7): draw_circle(Vector2(x, top + 12 + row * 20), 3.0, Color("#d4e1e4", cutaway_progress))

func _draw_shell() -> void:
	var sh := _exploded_offset("shell")
	var rect := Rect2(240 + sh.x, 194 + sh.y, 680, 206)
	var opaque := 1.0 - 0.94 * cutaway_progress
	if cutaway_progress < 0.99:
		# Cylindrical shell wall with elliptical end, lower shadow, highlight band and seam.
		_draw_ellipse(Vector2(rect.position.x + rect.size.x * 0.53, rect.position.y + rect.size.y + 10), Vector2(355, 30), Color(0, 0, 0, 0.35 * opaque))
		_draw_polygon([Vector2(rect.position.x + 18, rect.position.y), Vector2(rect.end.x - 18, rect.position.y), Vector2(rect.end.x, rect.position.y + 28), Vector2(rect.end.x, rect.end.y - 28), Vector2(rect.end.x - 18, rect.end.y), Vector2(rect.position.x + 18, rect.end.y), Vector2(rect.position.x, rect.end.y - 28), Vector2(rect.position.x, rect.position.y + 28)], Color("#425764", opaque))
		_draw_ellipse(Vector2(rect.position.x + 18, rect.get_center().y), Vector2(30, rect.size.y * 0.5), Color("#657a84", opaque))
		_draw_ellipse(Vector2(rect.end.x - 18, rect.get_center().y), Vector2(30, rect.size.y * 0.5), Color("#273943", opaque))
		draw_line(Vector2(rect.position.x + 35, rect.position.y + 24), Vector2(rect.end.x - 28, rect.position.y + 24), Color("#c1d0d5", 0.52 * opaque), 5.0)
		draw_line(Vector2(rect.position.x + 32, rect.end.y - 20), Vector2(rect.end.x - 31, rect.end.y - 20), Color("#1a2a32", 0.8 * opaque), 6.0)
		for x in [rect.position.x + 18, rect.end.x - 18]: draw_line(Vector2(x, rect.position.y + 30), Vector2(x, rect.end.y - 30), Color("#a8b7bc", 0.8 * opaque), 3.0)
	# Cutaway shell lip and upper section retain the pressure-boundary context.
	if cutaway_progress > 0.02:
		var alpha := cutaway_progress
		_draw_polygon([Vector2(rect.position.x + 28, rect.position.y + 7), Vector2(rect.end.x - 28, rect.position.y + 7), Vector2(rect.end.x - 42, rect.position.y + 22), Vector2(rect.position.x + 42, rect.position.y + 22)], Color("#7c929c", 0.82 * alpha))
		_draw_polygon([Vector2(rect.position.x + 8, rect.end.y - 12), Vector2(rect.end.x - 8, rect.end.y - 12), Vector2(rect.end.x - 28, rect.end.y + 8), Vector2(rect.position.x + 28, rect.end.y + 8)], Color("#364a54", 0.9 * alpha))
		for i in range(18):
			var bx := rect.position.x + 48 + i * 34
			draw_circle(Vector2(bx, rect.position.y + 13), 3.0, Color("#d6e0e3", alpha))

func _draw_heads_and_flanges() -> void:
	var front := _exploded_offset("front_head")
	var rear := _exploded_offset("rear_head")
	var yshift := -exploded_progress * 92.0
	# Channel heads have domed profiles, layered rims and bolted flanges.
	_draw_domed_head(Vector2(223 + front.x, 296 + yshift), Vector2(76, 116), true, 0.9)
	_draw_domed_head(Vector2(937 + rear.x, 296 + yshift), Vector2(72, 116), false, 0.92)
	_draw_bolt_ring(Vector2(267 + front.x, 296 + yshift), 114, 22)
	_draw_bolt_ring(Vector2(898 + rear.x, 296 + yshift), 114, 22)
	# Heavy tube-sheet rims and visible split-pass divider.
	_draw_round_rect(Rect2(286 + exploded_progress * 20, 232 + yshift, 14, 128), Color("#73868d"), Color("#d0dadd"), 2.0)
	_draw_round_rect(Rect2(840 + exploded_progress * 105, 232 + yshift, 14, 128), Color("#677b84"), Color("#c1cfd3"), 2.0)
	if cutaway_progress > 0.15:
		draw_line(Vector2(224 + front.x, 296 + yshift), Vector2(265 + front.x, 296 + yshift), Color("#1c3039"), 7.0)
		draw_line(Vector2(217 + front.x, 297 + yshift), Vector2(258 + front.x, 297 + yshift), Color("#f6c071", 0.9), 3.0)

func _draw_nozzles_front() -> void:
	var y := 296.0 - exploded_progress * 92.0
	_draw_nozzle(Vector2(222, y - 30), Vector2(150, y - 55), Color("#586b75"), "tube_inlet")
	_draw_nozzle(Vector2(222, y + 28), Vector2(150, y + 53), Color("#586b75"), "tube_outlet")

func _draw_instruments() -> void:
	var sh := _exploded_offset("shell")
	for point in [Vector2(550, 194) + sh, Vector2(790, 194) + sh]:
		draw_line(point, point + Vector2(0, -24), Color("#9eafb5"), 3.0)
		draw_circle(point + Vector2(0, -32), 12, Color("#263a43"))
		draw_arc(point + Vector2(0, -32), 12, 0, TAU, 24, Color("#d8e4e6"), 2.0)
		draw_line(point + Vector2(-5, -32), point + Vector2(4, -36), Color("#f2bc64"), 2.0)
		draw_circle(point, 5.0, Color("#e9b96d"))

func _draw_callouts() -> void:
	var font := get_theme_default_font()
	var sh := _exploded_offset("shell")
	if cutaway_progress > 0.5 and operating_state.has("hot_out_k") and operating_state.has("cold_out_k"):
		draw_string(font, Vector2(478, 408 + sh.y), "SHELL-SIDE CROSS-FLOW  ·  MODEL-TINTED REPRESENTATIVE PATH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _stream_color(false, 0.55))
		draw_string(font, Vector2(470, 430 + sh.y), "TUBE SIDE  ·  TWO-PASS CHANNEL (SCHEMATIC)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _stream_color(true, 0.55))
	elif cutaway_progress > 0.5:
		draw_string(font, Vector2(478, 408 + sh.y), "INTERNAL GEOMETRY  ·  VALID MODEL INPUTS REQUIRED FOR FLOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#c7954b"))
	else:
		draw_string(font, Vector2(430, 438), "SHELL-AND-TUBE  /  1 SHELL PASS · 2 TUBE PASSES · SEGMENTAL BAFFLES", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color("#a2b6be"))

func _draw_selection() -> void:
	var yshift := -exploded_progress * 92.0
	var bounds := Rect2()
	match selected_component:
		"shell":
			var offset := _exploded_offset("shell")
			bounds = Rect2(240 + offset.x, 194 + offset.y, 680, 206)
		"front_head": bounds = Rect2(147 + _exploded_offset("front_head").x, 180 + yshift, 130, 232)
		"rear_head": bounds = Rect2(866 + _exploded_offset("rear_head").x, 180 + yshift, 132, 232)
		"tube_bundle": bounds = Rect2(290 + exploded_progress * 115, 228 + yshift, 555, 150)
		"tube_sheet_front": bounds = Rect2(276 + exploded_progress * 20, 224 + yshift, 34, 146)
		"tube_sheet_rear": bounds = Rect2(826 + exploded_progress * 105, 224 + yshift, 34, 146)
		"baffles": bounds = Rect2(395 + exploded_progress * 80, 222 + yshift, 355, 156)
		"tube_inlet": bounds = Rect2(125, 216 + yshift, 105, 72)
		"tube_outlet": bounds = Rect2(125, 303 + yshift, 105, 72)
		"shell_inlet": bounds = Rect2(405, 72 - exploded_progress * 28, 80, 112)
		"shell_outlet": bounds = Rect2(680, 72 - exploded_progress * 28, 80, 112)
		"supports": bounds = Rect2(290, 410, 540, 65)
		"instruments": bounds = Rect2(525, 145 + yshift, 290, 78)
	if bounds.size != Vector2.ZERO:
		draw_rect(bounds, Color("#f5c76d", 0.95), false, 3.0)

func _draw_overlay() -> void:
	var font := get_theme_default_font()
	var label := "EXPLODED VIEW" if exploded_progress > 0.5 else ("CUTAWAY VIEW" if cutaway_progress > 0.5 else "EXTERNAL VIEW")
	draw_string(font, Vector2(22, 25), label + "  ·  REPRESENTATIVE EDUCATIONAL CONFIGURATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#76c9bc"))
	draw_string(font, Vector2(22, size.y - 14), "Select a component to inspect its engineering role", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#92a5ad"))
	if operating_state.has("hot_out_k") and operating_state.has("cold_out_k"):
		draw_string(font, Vector2(size.x - 228, 25), "HOT OUT %.1f°C  ·  COLD OUT %.1f°C" % [float(operating_state["hot_out_k"]) - 273.15, float(operating_state["cold_out_k"]) - 273.15], HORIZONTAL_ALIGNMENT_RIGHT, 210, 10, Color("#d3e0e2"))

func _stream_color(hot_side: bool, fraction: float) -> Color:
	var start := Color("#ef795f") if hot_side else Color("#48a8e8")
	var finish := Color("#eab27c") if hot_side else Color("#b1d98b")
	return start.lerp(finish, clampf(fraction, 0.0, 1.0))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var design_point: Vector2 = (event.position - _origin) / _scale
		var id := _component_at(design_point)
		if id != "":
			selected_component = id
			component_selected.emit(id)
			queue_redraw()
		accept_event()

func _component_at(point: Vector2) -> String:
	var yoff := -exploded_progress * 92.0
	var hitboxes := {
		"shell": Rect2(240 + _exploded_offset("shell").x, 194 + yoff, 680, 206),
		"front_head": Rect2(168 + _exploded_offset("front_head").x, 178 + yoff, 120, 236),
		"rear_head": Rect2(875 + _exploded_offset("rear_head").x, 178 + yoff, 130, 236),
		"tube_bundle": Rect2(294 + exploded_progress * 115, 230 + yoff, 548, 146),
		"tube_sheet_front": Rect2(276 + exploded_progress * 20, 224 + yoff, 34, 146),
		"tube_sheet_rear": Rect2(826 + exploded_progress * 105, 224 + yoff, 34, 146),
		"baffles": Rect2(395 + exploded_progress * 80, 222 + yoff, 355, 156),
		"tube_inlet": Rect2(125, 216 + yoff, 105, 72), "tube_outlet": Rect2(125, 303 + yoff, 105, 72),
		"shell_inlet": Rect2(405, 72 - exploded_progress * 28, 80, 112), "shell_outlet": Rect2(680, 72 - exploded_progress * 28, 80, 112),
		"supports": Rect2(290, 410, 540, 65), "instruments": Rect2(525, 145 + yoff, 290, 78)
	}
	# Prefer specific parts over the shell's large hit area.
	for id in ["tube_inlet", "tube_outlet", "shell_inlet", "shell_outlet", "instruments", "tube_sheet_front", "tube_sheet_rear", "baffles", "tube_bundle", "front_head", "rear_head", "supports", "shell"]:
		if Rect2(hitboxes[id]).has_point(point): return id
	return ""

func _exploded_offset(part: String) -> Vector2:
	match part:
		"shell": return Vector2(0, -exploded_progress * 16)
		"front_head": return Vector2(-108 * exploded_progress, -exploded_progress * 92)
		"rear_head": return Vector2(108 * exploded_progress, -exploded_progress * 92)
		_: return Vector2.ZERO

func _draw_nozzle(base: Vector2, end: Vector2, metal: Color, hit_id: String) -> void:
	var dir := (end - base).normalized()
	var side := Vector2(-dir.y, dir.x) * 18
	_draw_polygon([base - side, base + side, end + side * 0.72, end - side * 0.72], metal)
	draw_line(base - side + Vector2(2, -2), end - side * 0.72 + Vector2(2, -2), Color("#c0ccd0"), 3.0)
	_draw_round_rect(Rect2(end.x - 25, end.y - 8, 50, 16), Color("#384b55"), Color("#b9c7cb"), 2.0)
	for dx in [-16.0, 16.0]: draw_circle(end + Vector2(dx, 0), 2.5, Color("#dce5e7"))

func _draw_domed_head(center: Vector2, radii: Vector2, left_side: bool, alpha: float) -> void:
	var side := -1.0 if left_side else 1.0
	var points := PackedVector2Array()
	for i in range(13):
		var angle := -PI * 0.5 + PI * float(i) / 12.0
		points.append(center + Vector2(side * cos(angle) * radii.x, sin(angle) * radii.y))
	points.append(center + Vector2(0, radii.y))
	points.append(center + Vector2(0, -radii.y))
	_draw_polygon(points, Color("#435762", alpha))
	draw_arc(center, radii.y, -PI * 0.5, PI * 0.5, 28, Color("#bac8cc", alpha), 4.0)
	draw_line(center + Vector2(-side * radii.x * 0.45, -radii.y * 0.72), center + Vector2(-side * radii.x * 0.45, radii.y * 0.72), Color("#273941", alpha), 4.0)

func _draw_bolt_ring(center: Vector2, radius: float, count: int) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var point := center + Vector2(cos(angle) * 17, sin(angle) * radius * 0.83)
		draw_circle(point, 3.8, Color("#263640"))
		draw_circle(point + Vector2(-0.7, -0.8), 1.3, Color("#d6e0e3"))

func _draw_arrow(from: Vector2, to: Vector2, color: Color, width: float, alpha: float) -> void:
	var tint := Color(color, alpha)
	draw_line(from, to, tint, width, true)
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	_draw_polygon([to, to - direction * 12 + normal * 6, to - direction * 12 - normal * 6], tint)

func _draw_polygon(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)

func _draw_round_rect(rect: Rect2, fill: Color, border: Color, width: float) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, width)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
