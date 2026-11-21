extends Node
## Jenny tip packs from data/jenny/jenny_texts.json

signal tips_changed(page_id: String)

var _pages: Dictionary = {}
var current_page_id: String = ""

func _ready() -> void:
	_load_texts()

func _load_texts() -> void:
	var path := "res://data/jenny/jenny_texts.json"
	if not FileAccess.file_exists(path):
		push_warning("JennyService: missing %s" % path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_pages = parsed.get("pages", {})
	else:
		push_warning("JennyService: invalid JSON")

func set_page(page_id: String) -> void:
	current_page_id = page_id
	tips_changed.emit(page_id)

func get_page_tips(page_id: String = "") -> Array:
	var id := page_id if page_id != "" else current_page_id
	if _pages.has(id):
		return _pages[id].get("page_convo", [])
	return []

func get_page_title(page_id: String = "") -> String:
	var id := page_id if page_id != "" else current_page_id
	if _pages.has(id):
		return str(_pages[id].get("page_name", id))
	return id

func has_tips(page_id: String = "") -> bool:
	return get_page_tips(page_id).size() > 0
