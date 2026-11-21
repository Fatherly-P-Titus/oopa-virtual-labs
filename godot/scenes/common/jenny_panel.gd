extends CanvasLayer
## Jenny guide — portrait avatar + tip carousel.

@export var page_id: String = ""
@export var start_open: bool = false

const FIREBRICK := Color("#b22222")
const FIREBRICK_DEEP := Color("#8c1b1b")
const INK := Color("#1b1b1b")
const MUTED := Color("#666666")
const LINE := Color("#e7e3e0")
const PAGE_BG := Color("#faf9f8")

const TEX_NEUTRAL := "res://assets/jenny/jenny_avatar.png"
const TEX_EXPLAIN := "res://assets/jenny/jenny_avatar_explain.png"
const TEX_LAB := "res://assets/jenny/jenny_avatar_lab.png"
const TEX_FAB := "res://assets/jenny/jenny_fab.png"

@onready var _fab: Button = $Fab
@onready var _fab_icon: TextureRect = $Fab/FabInner/FabIcon
@onready var _fab_label: Label = $Fab/FabInner/FabLabel
@onready var _panel: PanelContainer = $Panel
@onready var _avatar_tex: TextureRect = $Panel/Margin/VBox/HeaderBar/AvatarWrap/AvatarMask/AvatarTex
@onready var _name_label: Label = $Panel/Margin/VBox/HeaderBar/NameCol/Name
@onready var _role_label: Label = $Panel/Margin/VBox/HeaderBar/NameCol/Role
@onready var _page_label: Label = $Panel/Margin/VBox/HeaderBar/NameCol/PageName
@onready var _close: Button = $Panel/Margin/VBox/HeaderBar/Close
@onready var _type_badge: Label = $Panel/Margin/VBox/TypeRow/TypeBadge
@onready var _tip_title: Label = $Panel/Margin/VBox/TipTitle
@onready var _tip_body: Label = $Panel/Margin/VBox/TipBody
@onready var _dots: HBoxContainer = $Panel/Margin/VBox/Dots
@onready var _counter: Label = $Panel/Margin/VBox/Nav/Counter
@onready var _prev: Button = $Panel/Margin/VBox/Nav/Prev
@onready var _next: Button = $Panel/Margin/VBox/Nav/Next
@onready var _avatar_mask: PanelContainer = $Panel/Margin/VBox/HeaderBar/AvatarWrap/AvatarMask

var _tips: Array = []
var _index: int = 0
var _open: bool = false
var _tween: Tween
var _tex_neutral: Texture2D
var _tex_explain: Texture2D
var _tex_lab: Texture2D
var _tex_fab: Texture2D

func _ready() -> void:
	_load_textures()
	_style_all()
	_apply_fab_icon()
	_panel.visible = false
	_panel.modulate.a = 0.0
	_open = false
	if page_id == "":
		page_id = JennyService.current_page_id
	_bind_page(page_id)
	if not JennyService.tips_changed.is_connected(_on_tips_changed):
		JennyService.tips_changed.connect(_on_tips_changed)
	if start_open and _tips.size() > 0:
		_set_open(true, false)

func _load_textures() -> void:
	_tex_neutral = _load_tex(TEX_NEUTRAL)
	_tex_explain = _load_tex(TEX_EXPLAIN)
	_tex_lab = _load_tex(TEX_LAB)
	_tex_fab = _load_tex(TEX_FAB)
	if _tex_neutral:
		_avatar_tex.texture = _tex_neutral

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r = ResourceLoader.load(path, "Texture2D")
		if r is Texture2D:
			return r
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.new()
		if img.load(abs_path) == OK and not img.is_empty():
			return ImageTexture.create_from_image(img)
	push_warning("Jenny: missing texture %s" % path)
	return null

func _apply_fab_icon() -> void:
	if _fab_icon and _tex_fab:
		_fab_icon.texture = _tex_fab
	elif _fab_icon and _tex_neutral:
		_fab_icon.texture = _tex_neutral

func _style_all() -> void:
	var font_semi: Font = null
	var font_bold: Font = null
	var font_reg: Font = null
	if ResourceLoader.exists("res://assets/fonts/Inter-SemiBold.ttf"):
		font_semi = load("res://assets/fonts/Inter-SemiBold.ttf")
	if ResourceLoader.exists("res://assets/fonts/Inter-Bold.ttf"):
		font_bold = load("res://assets/fonts/Inter-Bold.ttf")
	if ResourceLoader.exists("res://assets/fonts/Inter-Regular.ttf"):
		font_reg = load("res://assets/fonts/Inter-Regular.ttf")

	# FAB pill
	var fab_s := _flat(FIREBRICK, 28)
	fab_s.content_margin_left = 8
	fab_s.content_margin_right = 16
	fab_s.content_margin_top = 6
	fab_s.content_margin_bottom = 6
	var fab_h := fab_s.duplicate()
	fab_h.bg_color = FIREBRICK_DEEP
	_fab.add_theme_stylebox_override("normal", fab_s)
	_fab.add_theme_stylebox_override("hover", fab_h)
	_fab.add_theme_stylebox_override("pressed", fab_h)
	_fab.text = ""
	if font_semi:
		_fab_label.add_theme_font_override("font", font_semi)
	_fab_label.add_theme_font_size_override("font_size", 14)
	_fab_label.add_theme_color_override("font_color", Color.WHITE)

	# Panel card
	var panel_s := _flat(Color.WHITE, 16)
	panel_s.set_border_width_all(1)
	panel_s.border_color = LINE
	panel_s.shadow_color = Color(0, 0, 0, 0.18)
	panel_s.shadow_size = 12
	panel_s.shadow_offset = Vector2(0, 4)
	_panel.add_theme_stylebox_override("panel", panel_s)

	# Circular mask for avatar (clip via rounded panel + texture expand)
	var av := _flat(Color("#f0f0f0"), 28)
	_avatar_mask.add_theme_stylebox_override("panel", av)
	_avatar_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	if font_bold:
		_name_label.add_theme_font_override("font", font_bold)
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", INK)

	_role_label.add_theme_color_override("font_color", FIREBRICK)
	_role_label.add_theme_font_size_override("font_size", 11)
	if font_semi:
		_role_label.add_theme_font_override("font", font_semi)

	_page_label.add_theme_color_override("font_color", MUTED)
	_page_label.add_theme_font_size_override("font_size", 11)

	_style_ghost_button(_close, true)
	_close.add_theme_font_size_override("font_size", 18)

	_type_badge.add_theme_color_override("font_color", FIREBRICK)
	_type_badge.add_theme_font_size_override("font_size", 11)
	if font_semi:
		_type_badge.add_theme_font_override("font", font_semi)

	if font_semi:
		_tip_title.add_theme_font_override("font", font_semi)
	_tip_title.add_theme_font_size_override("font_size", 17)
	_tip_title.add_theme_color_override("font_color", INK)

	if font_reg:
		_tip_body.add_theme_font_override("font", font_reg)
	_tip_body.add_theme_font_size_override("font_size", 14)
	_tip_body.add_theme_color_override("font_color", Color("#333333"))

	_style_ghost_button(_prev)
	_style_ghost_button(_next)
	_counter.add_theme_color_override("font_color", MUTED)
	_counter.add_theme_font_size_override("font_size", 12)

func _flat(bg: Color, radius: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	return s

func _style_ghost_button(btn: Button, square: bool = false) -> void:
	var s := _flat(Color(1, 1, 1, 0), 8)
	s.set_border_width_all(1)
	s.border_color = LINE
	s.content_margin_left = 12 if not square else 8
	s.content_margin_right = 12 if not square else 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	var h := s.duplicate()
	h.border_color = FIREBRICK
	h.bg_color = PAGE_BG
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("disabled", s)
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_color_override("font_hover_color", FIREBRICK)
	btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.7, 0.7))

func set_page(id: String) -> void:
	page_id = id
	JennyService.set_page(id)
	_bind_page(id)

func _on_tips_changed(id: String) -> void:
	if id == page_id or page_id == "":
		_bind_page(page_id if page_id != "" else id)

func _bind_page(id: String) -> void:
	_tips = JennyService.get_page_tips(id)
	_index = 0
	_page_label.text = JennyService.get_page_title(id)
	_fab.visible = _tips.size() > 0
	if not _fab.visible:
		_set_open(false, false)
	# Lab pages use lab-coat portrait as default
	if id in ["gas_laws", "chemistry", "biology", "physics", "engineering"]:
		_set_avatar(_tex_lab if _tex_lab else _tex_neutral)
	else:
		_set_avatar(_tex_neutral)
	_rebuild_dots()
	_show_tip()

func _set_avatar(tex: Texture2D) -> void:
	if tex and _avatar_tex:
		_avatar_tex.texture = tex

func _rebuild_dots() -> void:
	for c in _dots.get_children():
		c.queue_free()
	for i in range(_tips.size()):
		var d := PanelContainer.new()
		d.custom_minimum_size = Vector2(8, 8)
		var st := _flat(LINE if i != _index else FIREBRICK, 4)
		d.add_theme_stylebox_override("panel", st)
		_dots.add_child(d)

func _show_tip() -> void:
	if _tips.is_empty():
		_tip_title.text = "No tips yet"
		_tip_body.text = "Jenny will guide you here once tips are added for this screen."
		_type_badge.text = "INFO"
		_counter.text = "0 / 0"
		_prev.disabled = true
		_next.disabled = true
		_set_avatar(_tex_neutral)
		_rebuild_dots()
		return
	_index = clampi(_index, 0, _tips.size() - 1)
	var tip: Dictionary = _tips[_index]
	_tip_title.text = str(tip.get("title", "Tip"))
	_tip_body.text = str(tip.get("text", ""))
	var t := str(tip.get("type", "info")).to_upper()
	_type_badge.text = t
	_counter.text = "%d / %d" % [_index + 1, _tips.size()]
	_prev.disabled = _index <= 0
	_next.disabled = _index >= _tips.size() - 1
	# Pose by tip type
	if t == "TIP" and _tex_explain:
		_set_avatar(_tex_explain)
	elif page_id in ["gas_laws", "chemistry", "biology", "physics", "engineering"] and _tex_lab:
		_set_avatar(_tex_lab)
	else:
		_set_avatar(_tex_neutral)
	_rebuild_dots()

func _set_open(open: bool, animate: bool = true) -> void:
	_open = open
	_fab_label.text = "Close" if open else "Jenny"
	if _tween and _tween.is_running():
		_tween.kill()
	if not animate:
		_panel.visible = open
		_panel.modulate.a = 1.0 if open else 0.0
		return
	if open:
		_panel.visible = true
		_panel.modulate.a = 0.0
		var target_y := _panel.offset_top
		_panel.offset_top = target_y + 12
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
		_tween.tween_property(_panel, "offset_top", target_y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		var start_y := _panel.offset_top
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(_panel, "modulate:a", 0.0, 0.14)
		_tween.tween_property(_panel, "offset_top", start_y + 10, 0.14)
		_tween.chain().tween_callback(func():
			_panel.visible = false
			_panel.offset_top = start_y
		)

func _on_fab_pressed() -> void:
	_set_open(not _open)

func _on_close_pressed() -> void:
	_set_open(false)

func _on_prev_pressed() -> void:
	_index = maxi(_index - 1, 0)
	_show_tip()

func _on_next_pressed() -> void:
	_index = mini(_index + 1, _tips.size() - 1)
	_show_tip()
