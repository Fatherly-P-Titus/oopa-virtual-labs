extends Control
class_name LabShell
## Shared lab chrome — web .sim-layout (stage 1fr | sidebar 330px).

@export var lab_title: String = "Lab"
@export var lab_eyebrow: String = "FIELD  /  LAB"
@export var lab_lead: String = ""
@export var field_id: String = "chemistry"
@export var page_id: String = ""
@export var back_label: String = "← Back"

var _eyebrow: Label
var _title: Label
var _lead: Label
var _back: Button
var _brand_accent: ColorRect
var _brand_subtitle: Label
var _brand_divider: ColorRect
var _stage_host: Control
var _extra_host: VBoxContainer
var _sidebar_vbox: VBoxContainer
var _sidebar_panel: Control
var _main_margin: MarginContainer
var _status_accent: ColorRect
var _status: Label
var _footer: Label

func _ready() -> void:
	_resolve_nodes()
	var th: Resource = load("res://themes/oopa_theme.tres")
	if th:
		theme = th
	_apply_copy()
	if _back != null and not _back.pressed.is_connected(_on_back):
		_back.pressed.connect(_on_back)
	if page_id != "":
		JennyService.set_page(page_id)
		_ensure_jenny()
	if _lead != null:
		_lead.visible = lab_lead.strip_edges() != ""
	if not resized.is_connected(_apply_responsive_layout):
		resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func _resolve_nodes() -> void:
	_eyebrow = _find_label("%Eyebrow", "MainMargin/MainVBox/Header/HeaderText/Eyebrow")
	_title = _find_label("%Title", "MainMargin/MainVBox/Header/HeaderText/Title")
	_lead = _find_label("%Lead", "MainMargin/MainVBox/Lead")
	_brand_accent = get_node_or_null("%BrandAccent") as ColorRect
	_brand_subtitle = _find_label("%BrandSubtitle", "MainMargin/MainVBox/Header/BrandLockup/BrandCopy/BrandSubtitle")
	_brand_divider = get_node_or_null("%BrandDivider") as ColorRect
	_back = get_node_or_null("%Back") as Button
	if _back == null:
		_back = get_node_or_null("MainMargin/MainVBox/Header/Back") as Button
	_main_margin = get_node_or_null("MainMargin") as MarginContainer
	_stage_host = get_node_or_null("%StageHost") as Control
	if _stage_host == null:
		_stage_host = get_node_or_null("MainMargin/MainVBox/SimLayout/Left/Stage/StageHost") as Control
	_extra_host = get_node_or_null("%ExtraHost") as VBoxContainer
	if _extra_host == null:
		_extra_host = get_node_or_null("MainMargin/MainVBox/SimLayout/Left/ExtraHost") as VBoxContainer
	_sidebar_vbox = get_node_or_null("%SidebarVBox") as VBoxContainer
	if _sidebar_vbox == null:
		_sidebar_vbox = get_node_or_null("MainMargin/MainVBox/SimLayout/Sidebar/Scroll/SidebarVBox") as VBoxContainer
	_sidebar_panel = get_node_or_null("MainMargin/MainVBox/SimLayout/Sidebar") as Control
	_status_accent = get_node_or_null("%StatusAccent") as ColorRect
	_status = _find_label("%Status", "MainMargin/MainVBox/StatusRow/Status")
	_footer = _find_label("%Footer", "MainMargin/MainVBox/Footer")

func _find_label(unique: String, path: String) -> Label:
	var n: Node = get_node_or_null(unique)
	if n == null:
		n = get_node_or_null(path)
	return n as Label

func _apply_copy() -> void:
	var accent := _field_accent()
	if _eyebrow:
		_eyebrow.text = lab_eyebrow
		_eyebrow.add_theme_color_override("font_color", accent)
	if _title:
		_title.text = lab_title
	if _lead:
		_lead.text = lab_lead
	if _brand_accent:
		_brand_accent.color = accent
	if _brand_subtitle:
		_brand_subtitle.add_theme_color_override("font_color", Color("#66758a"))
	if _status_accent:
		_status_accent.color = accent
	if _back:
		_back.text = back_label
		_back.tooltip_text = "Return to the %s hub" % field_id.capitalize() if field_id != "" else "Return to the main menu"
	if _footer:
		_footer.text = "Shared laboratory workspace"

func _field_accent() -> Color:
	match field_id:
		"engineering":
			return Color("#16b8a6")
		"physics":
			return Color("#3b82f6")
		"chemistry":
			return Color("#f2a84a")
		"biology":
			return Color("#67c49a")
		_:
			return Color("#16b8a6")

func _apply_responsive_layout() -> void:
	var viewport_width := get_viewport_rect().size.x
	if _brand_subtitle:
		_brand_subtitle.visible = viewport_width >= 840.0
	if _brand_divider:
		_brand_divider.visible = viewport_width >= 840.0
	if _sidebar_panel:
		_sidebar_panel.custom_minimum_size.x = 290.0 if viewport_width < 1024.0 else 330.0
	if _main_margin:
		var margin := 14 if viewport_width < 900.0 else 20
		_main_margin.add_theme_constant_override("margin_left", margin)
		_main_margin.add_theme_constant_override("margin_right", margin)
	if _title:
		_title.clip_text = true

func get_stage() -> Control:
	if _stage_host == null:
		_resolve_nodes()
	return _stage_host

func get_extra() -> VBoxContainer:
	if _extra_host == null:
		_resolve_nodes()
	return _extra_host

func get_sidebar() -> VBoxContainer:
	if _sidebar_vbox == null:
		_resolve_nodes()
	return _sidebar_vbox

func set_status(text: String) -> void:
	if _status == null:
		_resolve_nodes()
	if _status:
		_status.text = text

func add_to_stage(child: Control) -> void:
	var stage := get_stage()
	if stage == null:
		push_error("LabShell: StageHost missing")
		return
	child.set_anchors_preset(Control.PRESET_FULL_RECT)
	child.anchor_right = 1.0
	child.anchor_bottom = 1.0
	child.offset_left = 0.0
	child.offset_top = 0.0
	child.offset_right = 0.0
	child.offset_bottom = 0.0
	stage.add_child(child)

func _on_back() -> void:
	if field_id != "":
		AppState.set_field(field_id)
		SceneRouter.go_field(field_id)
	else:
		SceneRouter.go_main_menu()

func _ensure_jenny() -> void:
	if has_node("JennyPanel"):
		return
	var sc: PackedScene = load("res://scenes/common/jenny_panel.tscn") as PackedScene
	if sc:
		var j: Node = sc.instantiate()
		j.name = "JennyPanel"
		if "page_id" in j:
			j.set("page_id", page_id)
		add_child(j)
