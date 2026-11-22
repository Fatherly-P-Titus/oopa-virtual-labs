extends RefCounted
class_name OopaAdminUI
## Shared visual helpers for instructor and assessment screens.

const NAVY := Color("#101827")
const SLATE := Color("#19263a")
const GRAPHITE := Color("#26364d")
const MIST := Color("#e9eef5")
const WHITE := Color("#ffffff")
const TEAL := Color("#16b8a6")
const BLUE := Color("#3b82f6")
const AMBER := Color("#f2a84a")
const MUTED := Color("#607087")
const RED := Color("#c44545")


static func page(root: Control, dark: bool = false) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = NAVY if dark else MIST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	root.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)
	return content


static func heading(parent: Node, eyebrow: String, title_text: String, subtitle: String = "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)
	var eye := Label.new()
	eye.text = eyebrow.to_upper()
	eye.add_theme_color_override("font_color", TEAL)
	eye.add_theme_font_size_override("font_size", 11)
	box.add_child(eye)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", NAVY)
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	if not subtitle.is_empty():
		var desc := Label.new()
		desc.text = subtitle
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", MUTED)
		desc.add_theme_font_size_override("font_size", 13)
		box.add_child(desc)
	return box


static func panel(parent: Node, dark: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"ElevatedPanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = SLATE if dark else WHITE
	style.border_color = GRAPHITE if dark else Color("#d3dce7")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p


static func label(text_value: String, size: int = 14, color: Color = NAVY) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text_value: String, variation: String = "SecondaryButton") -> Button:
	var b := Button.new()
	b.text = text_value
	b.theme_type_variation = StringName(variation)
	return b


static func status(parent: Node, message: String, kind: String = "info") -> PanelContainer:
	var variation := "StatusInfo"
	var color := BLUE
	match kind:
		"success":
			variation = "StatusSuccess"
			color = TEAL
		"warning":
			variation = "StatusWarning"
			color = AMBER
		"error":
			variation = "StatusError"
			color = RED
	var box := PanelContainer.new()
	box.theme_type_variation = StringName(variation)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(4, 24)
	marker.color = color
	row.add_child(marker)
	var msg := label(message, 12, NAVY)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(msg)
	parent.add_child(box)
	return box


static func stat_card(parent: Node, caption: String, value: String, detail: String) -> PanelContainer:
	var card := panel(parent)
	card.theme_type_variation = &"MetricCard"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var a := label(caption.to_upper(), 10, MUTED)
	v.add_child(a)
	var n := label(value, 28, NAVY)
	v.add_child(n)
	var d := label(detail, 11, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return card


static func input_field(parent: Node, caption: String, placeholder: String, secret: bool = false) -> LineEdit:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	parent.add_child(group)
	group.add_child(label(caption, 12, MUTED))
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.custom_minimum_size.y = 44
	group.add_child(field)
	return field
