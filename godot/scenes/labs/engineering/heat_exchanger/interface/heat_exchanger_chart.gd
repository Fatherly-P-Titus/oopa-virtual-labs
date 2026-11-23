extends Control
class_name HeatExchangerChart
## Lightweight, calculation-fed chart panel for the Heat Exchanger analysis workspace.

var chart_title := ""
var chart_note := ""
var x_title := ""
var y_title := ""
var _series: Array = []
var _categories: Array[String] = []
var _kind := "line"

func _ready() -> void:
	queue_redraw()

func set_line_chart(title: String, note: String, x_label: String, y_label: String, series_data: Array) -> void:
	chart_title = title
	chart_note = note
	x_title = x_label
	y_title = y_label
	_kind = "line"
	_series = series_data.duplicate(true)
	_categories.clear()
	queue_redraw()

func set_bar_chart(title: String, note: String, y_label: String, categories: Array[String], series_data: Array) -> void:
	chart_title = title
	chart_note = note
	y_title = y_label
	x_title = "Equipment configuration"
	_kind = "bar"
	_categories = categories.duplicate()
	_series = series_data.duplicate(true)
	queue_redraw()

func chart_series() -> Array:
	return _series.duplicate(true)

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color("#111c25"), true)
	draw_rect(bounds, Color("#293943"), false, 1.0)
	var font := get_theme_default_font()
	if font == null: return
	draw_string(font, Vector2(14, 21), chart_title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 13, Color("#e2ebed"))
	draw_string(font, Vector2(14, 39), chart_note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 9, Color("#91a5ad"))
	var plot := Rect2(54, 78, maxf(size.x - 70, 80), maxf(size.y - 120, 50))
	if _kind == "bar":
		_draw_bars(font, plot)
	else:
		_draw_lines(font, plot)
	draw_string(font, Vector2(54, size.y - 10), x_title, HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, 10, Color("#a8b8bd"))

func _draw_lines(font: Font, plot: Rect2) -> void:
	var x_min := INF
	var x_max := -INF
	var y_min := INF
	var y_max := -INF
	for series in _series:
		for raw_point in series.get("values", []):
			var point: Vector2 = raw_point
			x_min = minf(x_min, point.x)
			x_max = maxf(x_max, point.x)
			y_min = minf(y_min, point.y)
			y_max = maxf(y_max, point.y)
	if not is_finite(x_min) or not is_finite(y_min):
		x_min = 0.0
		x_max = 1.0
		y_min = 0.0
		y_max = 1.0
	if is_equal_approx(x_min, x_max): x_max = x_min + 1.0
	if is_equal_approx(y_min, y_max):
		y_min -= 0.5
		y_max += 0.5
	var y_pad := (y_max - y_min) * 0.1
	y_min -= y_pad
	y_max += y_pad
	_draw_axes(font, plot, x_min, x_max, y_min, y_max)
	for series_index in range(_series.size()):
		var series: Dictionary = _series[series_index]
		var values: Array = series.get("values", [])
		var tint: Color = series.get("color", Color.WHITE)
		var previous := Vector2.ZERO
		for i in range(values.size()):
			var point: Vector2 = values[i]
			var mapped := Vector2(plot.position.x + (point.x - x_min) / (x_max - x_min) * plot.size.x, plot.end.y - (point.y - y_min) / (y_max - y_min) * plot.size.y)
			if i > 0: draw_line(previous, mapped, tint, 2.0, true)
			draw_circle(mapped, 3.0, tint)
			previous = mapped
		_draw_legend(font, series_index, str(series.get("label", "Series")), tint)

func _draw_bars(font: Font, plot: Rect2) -> void:
	var max_value := 0.0
	for series in _series:
		for value in series.get("values", []): max_value = maxf(max_value, float(value))
	if max_value <= 0.0: max_value = 1.0
	max_value *= 1.16
	_draw_axes(font, plot, 0.0, float(maxi(_categories.size(), 1)), 0.0, max_value, false)
	var category_count := maxi(_categories.size(), 1)
	var group_width := plot.size.x / float(category_count)
	var bar_width := minf(24.0, group_width * 0.72 / float(maxi(_series.size(), 1)))
	for category_index in range(category_count):
		var group_center := plot.position.x + group_width * (float(category_index) + 0.5)
		for series_index in range(_series.size()):
			var series: Dictionary = _series[series_index]
			var values: Array = series.get("values", [])
			if category_index >= values.size(): continue
			var value := float(values[category_index])
			var group_offset := (float(series_index) - (float(_series.size()) - 1.0) * 0.5) * bar_width
			var bar_height := value / max_value * plot.size.y
			var rect := Rect2(group_center + group_offset - bar_width * 0.42, plot.end.y - bar_height, bar_width * 0.84, bar_height)
			draw_rect(rect, series.get("color", Color.WHITE), true)
			draw_string(font, Vector2(rect.position.x - 9, rect.position.y - 4), "%.1f" % value, HORIZONTAL_ALIGNMENT_CENTER, bar_width + 18, 8, Color("#d4e0e2"))
		var category := _categories[category_index] if category_index < _categories.size() else ""
		draw_string(font, Vector2(group_center - group_width * 0.5, plot.end.y + 16), category, HORIZONTAL_ALIGNMENT_CENTER, group_width, 9, Color("#b4c3c7"))
	for series_index in range(_series.size()):
		var series: Dictionary = _series[series_index]
		_draw_legend(font, series_index, str(series.get("label", "Series")), series.get("color", Color.WHITE))

func _draw_axes(font: Font, plot: Rect2, x_min: float, x_max: float, y_min: float, y_max: float, show_x_ticks: bool = true) -> void:
	for tick in range(5):
		var fraction := float(tick) / 4.0
		var y := lerpf(plot.position.y, plot.end.y, fraction)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color("#293943"), 1.0)
		var value := lerpf(y_max, y_min, fraction)
		draw_string(font, Vector2(4, y + 3), _format_axis(value), HORIZONTAL_ALIGNMENT_RIGHT, 44, 8, Color("#81959e"))
	if show_x_ticks:
		var x_axis_min := INF
		var x_axis_max := -INF
		for series in _series:
			for raw_point in series.get("values", []):
				var point: Vector2 = raw_point
				x_axis_min = minf(x_axis_min, point.x)
				x_axis_max = maxf(x_axis_max, point.x)
		if not is_finite(x_axis_min): x_axis_min = 0.0
		if not is_finite(x_axis_max) or is_equal_approx(x_axis_min, x_axis_max): x_axis_max = x_axis_min + 1.0
		for tick in range(5):
			var fraction := float(tick) / 4.0
			var x := plot.position.x + plot.size.x * fraction
			var value := lerpf(x_axis_min, x_axis_max, fraction)
			draw_string(font, Vector2(x - 25, plot.end.y + 13), _format_axis(value), HORIZONTAL_ALIGNMENT_CENTER, 50, 8, Color("#81959e"))
	var ylabel_width := font.get_string_size(y_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(font, Vector2(plot.position.x + 4, plot.position.y - 4), y_title, HORIZONTAL_ALIGNMENT_LEFT, minf(ylabel_width + 8, plot.size.x), 8, Color("#a8b8bd"))
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), Color("#70858e"), 1.0)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, Color("#70858e"), 1.0)

func _draw_legend(font: Font, index: int, label: String, tint: Color) -> void:
	var x := maxf(66.0, size.x - 150.0)
	var y := 51.0 + float(index) * 12.0
	draw_line(Vector2(x, y), Vector2(x + 13, y), tint, 2.0)
	draw_string(font, Vector2(x + 17, y + 3), label, HORIZONTAL_ALIGNMENT_LEFT, 128, 8, Color("#c1cfd2"))

func _format_axis(value: float) -> String:
	if absf(value) >= 100.0: return "%.0f" % value
	if absf(value) >= 10.0: return "%.1f" % value
	return "%.2f" % value
