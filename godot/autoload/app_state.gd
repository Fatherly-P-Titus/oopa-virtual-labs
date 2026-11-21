extends Node
## Global app state for OOPA Virtual Labs.

signal field_changed(field_id: String)
signal lab_changed(lab_id: String)

var current_field: String = ""
var current_lab: String = ""
var reduced_motion: bool = false

func set_field(field_id: String) -> void:
	current_field = field_id
	field_changed.emit(field_id)

func set_lab(lab_id: String) -> void:
	current_lab = lab_id
	lab_changed.emit(lab_id)


# ----- Instructor session (M02) -----
signal instructor_session_changed

var instructor_session: Dictionary = {}


func is_instructor_logged_in() -> bool:
	return not instructor_session.is_empty()


func set_instructor_session(data: Dictionary) -> void:
	instructor_session = data.duplicate(true)
	instructor_session_changed.emit()


func clear_instructor_session() -> void:
	instructor_session = {}
	instructor_session_changed.emit()


func instructor_can_hub(hub_id: String) -> bool:
	return OopaAuthService.new().can_access_hub(instructor_session, hub_id)


# ----- Exam attempt session (M04) -----
var current_exam: Dictionary = {}
var current_attempt: Dictionary = {}


func set_exam_session(exam: Dictionary, attempt: Dictionary) -> void:
	current_exam = exam.duplicate(true)
	current_attempt = attempt.duplicate(true)


func clear_exam_session() -> void:
	current_exam = {}
	current_attempt = {}
