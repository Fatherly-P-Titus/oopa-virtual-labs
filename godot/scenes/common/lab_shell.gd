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
var _stage_host: Control
var _extra_host: VBoxContainer
var _sidebar_vbox: VBoxContainer
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

func _resolve_nodes() -> void:
	_eyebrow = _find_label("%Eyebrow", "MainMargin/MainVBox/Header/HeaderText/Eyebrow")
	_title = _find_label("%Title", "MainMargin/MainVBox/Header/HeaderText/Title")
	_lead = _find_label("%Lead", "MainMargin/MainVBox/Lead")
	_back = get_node_or_null("%Back") as Button
	if _back == null:
		_back = get_node_or_null("MainMargin/MainVBox/Header/Back") as Button
	_stage_host = get_node_or_null("%StageHost") as Control
	if _stage_host == null:
		_stage_host = get_node_or_null("MainMargin/MainVBox/SimLayout/Left/Stage/StageHost") as Control
	_extra_host = get_node_or_null("%ExtraHost") as VBoxContainer
	if _extra_host == null:
		_extra_host = get_node_or_null("MainMargin/MainVBox/SimLayout/Left/ExtraHost") as VBoxContainer
	_sidebar_vbox = get_node_or_null("%SidebarVBox") as VBoxContainer
	if _sidebar_vbox == null:
		_sidebar_vbox = get_node_or_null("MainMargin/MainVBox/SimLayout/Sidebar/Scroll/SidebarVBox") as VBoxContainer
	_status = _find_label("%Status", "MainMargin/MainVBox/Status")
	_footer = _find_label("%Footer", "MainMargin/MainVBox/Footer")

func _find_label(unique: String, path: String) -> Label:
	var n: Node = get_node_or_null(unique)
	if n == null:
		n = get_node_or_null(path)
	return n as Label

func _apply_copy() -> void:
	if _eyebrow:
		_eyebrow.text = lab_eyebrow
	if _title:
		_title.text = lab_title
	if _lead:
		_lead.text = lab_lead
	if _back:
		_back.text = back_label
	if _footer:
		_footer.text = "OOPA Virtual Labs  ·  Ideal models for learning"

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
