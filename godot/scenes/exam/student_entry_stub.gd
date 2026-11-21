extends Control
## M04 placeholder — student exam entry not yet implemented.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#faf9f8")
	add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	var t := Label.new()
	t.text = "Student Exam Entry"
	t.add_theme_font_size_override("font_size", 24)
	v.add_child(t)
	var m := Label.new()
	m.text = "Coming in Milestone 04 — examination runtime."
	m.add_theme_color_override("font_color", Color("#666666"))
	v.add_child(m)
	var b := Button.new()
	b.text = "Back to main menu"
	b.pressed.connect(func(): SceneRouter.go_main_menu())
	v.add_child(b)
