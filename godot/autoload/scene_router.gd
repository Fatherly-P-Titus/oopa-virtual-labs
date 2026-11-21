extends Node
## Central navigation between splash, hubs, and labs.

func go_splash() -> void:
	get_tree().change_scene_to_file("res://scenes/boot/splash.tscn")

func go_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/main_menu.tscn")

func go_field(field_id: String) -> void:
	AppState.set_field(field_id)
	# Field hubs can be specialized later; for now one reusable hub reads manifest
	get_tree().change_scene_to_file("res://scenes/hub/field_hub.tscn")

func open_lab(scene_path: String, lab_id: String = "") -> void:
	if lab_id != "":
		AppState.set_lab(lab_id)
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: lab scene missing: %s" % scene_path)
		return
	get_tree().change_scene_to_file(scene_path)


func go_instructor_login() -> void:
	get_tree().change_scene_to_file("res://scenes/instructor_system/login.tscn")


func go_instructor_dashboard() -> void:
	if not AppState.is_instructor_logged_in():
		go_instructor_login()
		return
	get_tree().change_scene_to_file("res://scenes/instructor_system/dashboard.tscn")


func go_student_exam_entry() -> void:
	# M04 will implement full entry; stub keeps menu wiring stable
	get_tree().change_scene_to_file("res://scenes/exam/student_entry.tscn")


func go_exam_editor() -> void:
	if not AppState.is_instructor_logged_in():
		go_instructor_login()
		return
	get_tree().change_scene_to_file("res://scenes/instructor_system/exam_editor.tscn")


func go_roster_manager() -> void:
	if not AppState.is_instructor_logged_in():
		go_instructor_login()
		return
	get_tree().change_scene_to_file("res://scenes/instructor_system/roster_manager.tscn")


func go_grading() -> void:
	if not AppState.is_instructor_logged_in():
		go_instructor_login()
		return
	get_tree().change_scene_to_file("res://scenes/instructor_system/grading_browser.tscn")
