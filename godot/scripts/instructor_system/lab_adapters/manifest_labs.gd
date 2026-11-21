extends RefCounted
class_name OopaManifestLabs
## Reads labs_manifest.json — all available labs (exam scope = all).

const MANIFEST_PATH := "res://data/config/labs_manifest.json"


func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		return data
	return {}


func list_available_labs(hub_filter: PackedStringArray = PackedStringArray()) -> Array:
	## Returns Array of {hub_id, lab_id, title, scene, blurb}
	var man: Dictionary = load_manifest()
	var out: Array = []
	for field in man.get("fields", []):
		var hub_id: String = str(field.get("id", ""))
		if hub_filter.size() > 0 and not hub_id in hub_filter:
			continue
		for lab in field.get("labs", []):
			if str(lab.get("status", "")) != "available":
				continue
			out.append({
				"hub_id": hub_id,
				"lab_id": str(lab.get("id", "")),
				"title": str(lab.get("title", "")),
				"scene": str(lab.get("scene", "")),
				"blurb": str(lab.get("blurb", "")),
			})
	return out


func lab_ids_for_hub(hub_id: String) -> PackedStringArray:
	var ids := PackedStringArray()
	for lab in list_available_labs(PackedStringArray([hub_id])):
		ids.append(str(lab["lab_id"]))
	return ids
