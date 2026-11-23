extends SceneTree

const MANIFEST_PATH := "res://data/config/labs_manifest.json"
const EXPECTED_SCENE := "res://scenes/labs/engineering/heat_exchanger/heat_exchanger_lab.tscn"
const EXPECTED_SCRIPT := "res://scenes/labs/engineering/heat_exchanger/heat_exchanger_lab.gd"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_failures_append("Labs manifest could not be opened.")
	else:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		var found := false
		if parsed is Dictionary:
			for field in parsed.get("fields", []):
				if str(field.get("id", "")) != "engineering": continue
				for lab in field.get("labs", []):
					if str(lab.get("id", "")) == "heat_exchanger":
						found = true
						_expect(str(lab.get("scene", "")) == EXPECTED_SCENE, "Manifest scene path differs from the M11 scene.")
						_expect(str(lab.get("status", "")) == "available", "Foundation route must be available in the Engineering hub.")
		_expect(found, "Heat Exchanger entry is missing from the Engineering manifest.")
	_expect(ResourceLoader.exists(EXPECTED_SCENE), "Manifest scene resource does not exist.")
	var packed := load(EXPECTED_SCENE) as PackedScene
	_expect(packed != null, "Heat Exchanger scene could not be loaded.")
	if packed != null:
		var instance := packed.instantiate()
		_expect(instance is Control, "Heat Exchanger root must remain a Control-based LabShell scene.")
		if instance is Control:
			_expect(str(instance.get("field_id")) == "engineering", "LabShell field identity must be Engineering.")
			_expect(str(instance.get("page_id")) == "heat_exchanger", "LabShell page identity must be heat_exchanger.")
			_expect(instance.get_script() != null and instance.get_script().resource_path == EXPECTED_SCRIPT, "Heat Exchanger controller script is not attached.")
		instance.free()
	await _test_engineering_hub_navigation()
	if failures.is_empty():
		print("PASS: Heat Exchanger M11.1 route and LabShell foundation")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _failures_append(message: String) -> void:
	failures.append(message)


func _test_engineering_hub_navigation() -> void:
	var app_state := root.get_node_or_null("AppState")
	var router := root.get_node_or_null("SceneRouter")
	if app_state == null or router == null:
		_failures_append("Project navigation autoloads were not available to the route test.")
		return
	app_state.call("set_field", "engineering")
	var hub_scene := load("res://scenes/hub/field_hub.tscn") as PackedScene
	if hub_scene == null:
		_failures_append("Engineering field hub scene could not be loaded.")
		return
	var hub := hub_scene.instantiate()
	root.add_child(hub)
	current_scene = hub
	await process_frame
	var grid := hub.get_node_or_null("Margin/VBox/Scroll/Grid")
	if grid == null:
		failures.append("Engineering hub catalogue grid was not found.")
		return
	var target: Button
	for card in grid.get_children():
		if _contains_label(card, "Heat Exchanger Design & Simulation"):
			target = card as Button
			break
	if target == null:
		failures.append("Heat Exchanger card was not built in the Engineering hub.")
		return
	target.emit_signal("pressed")
	await process_frame
	await process_frame
	var opened := current_scene
	_expect(opened != null and opened.get_script() != null and opened.get_script().resource_path == EXPECTED_SCRIPT, "Selecting the Engineering hub card did not open the M11 scene.")
	_expect(str(app_state.get("current_lab")) == "heat_exchanger", "SceneRouter did not register the heat_exchanger lab identity.")


func _contains_label(node: Node, expected_text: String) -> bool:
	if node is Label and node.text == expected_text:
		return true
	for child in node.get_children():
		if _contains_label(child, expected_text):
			return true
	return false
