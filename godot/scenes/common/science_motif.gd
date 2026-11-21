extends Control
## Lightweight discipline-specific line art for navigation surfaces.

@export var discipline: String = "physics" : set = set_discipline
@export var accent: Color = Color("#3b82f6") : set = set_accent

func set_discipline(value: String) -> void:
	discipline = value
	queue_redraw()

func set_accent(value: Color) -> void:
	accent = value
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var faint := Color(accent.r, accent.g, accent.b, 0.18)
	var bright := Color(accent.r, accent.g, accent.b, 0.58)
	var radius := minf(size.x, size.y) * 0.42
	if discipline == "engineering":
		for i in range(5):
			var x := size.x * (0.12 + float(i) * 0.19)
			draw_line(Vector2(x, size.y * 0.15), Vector2(x, size.y * 0.84), faint, 1.0)
		for i in range(4):
			var y := size.y * (0.2 + float(i) * 0.2)
			draw_line(Vector2(size.x * 0.1, y), Vector2(size.x * 0.88, y), faint, 1.0)
		var points := [Vector2(size.x*0.12,size.y*0.65),Vector2(size.x*0.36,size.y*0.65),Vector2(size.x*0.36,size.y*0.38),Vector2(size.x*0.66,size.y*0.38),Vector2(size.x*0.66,size.y*0.73),Vector2(size.x*0.88,size.y*0.73)]
		for i in range(points.size()-1):
			draw_line(points[i], points[i+1], bright, 2.0, true)
		for point in [points[0], points[2], points[3], points[4], points[5]]:
			draw_circle(point, 4.0, accent)
	elif discipline == "chemistry":
		var points := [center+Vector2(-radius,0),center+Vector2(-radius*0.5,-radius*0.86),center+Vector2(radius*0.5,-radius*0.86),center+Vector2(radius,0),center+Vector2(radius*0.5,radius*0.86),center+Vector2(-radius*0.5,radius*0.86)]
		for i in range(points.size()):
			draw_line(points[i], points[(i+1)%points.size()], faint, 2.0, true)
		for i in range(points.size()):
			draw_circle(points[i], 7.0 if i == 0 or i == 3 else 5.0, bright if i == 0 or i == 3 else faint)
		draw_circle(center, 6.0, accent)
	elif discipline == "biology":
		for i in range(3):
			var offset := Vector2(float(i-1)*size.x*0.19, float((i%2)-0.5)*size.y*0.12)
			var cell_center := center + offset
			draw_circle(cell_center, radius*0.42, faint)
			draw_arc(cell_center, radius*0.42, 0.0, TAU, 48, bright, 1.5, true)
			draw_circle(cell_center+Vector2(radius*0.08,-radius*0.04), radius*0.11, bright)
			for n in range(5):
				var a := TAU * float(n)/5.0
				draw_circle(cell_center+Vector2(cos(a),sin(a))*radius*0.25, 2.0, accent)
	else:
		for orbit in [0.52, 0.78, 1.0]:
			draw_arc(center, radius*orbit, 0.0, TAU, 64, faint, 1.3, true)
		draw_circle(center, 6.0, accent)
		for angle in [0.3, 2.4, 4.4]:
			var point := center + Vector2(cos(angle), sin(angle))*radius*0.78
			draw_line(center, point, faint, 1.0)
			draw_circle(point, 4.0, bright)
