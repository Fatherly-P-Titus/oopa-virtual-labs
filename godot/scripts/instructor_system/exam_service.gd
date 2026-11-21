extends RefCounted
class_name OopaExamService
## Create / list / load exams with hub permission checks.


func list_for_session(session: Dictionary) -> Array:
	var store := OopaLocalStore.new()
	var auth := OopaAuthService.new()
	var all: Array = store.list_exams()
	var out: Array = []
	for e in all:
		var hub: String = str(e.get("hub_id", ""))
		if auth.can_access_hub(session, hub):
			out.append(e)
	return out


func create_exam(
	session: Dictionary,
	title: String,
	hub_id: String,
	lab_id: String,
	duration_min: int,
	access_code: String = "",
	roster_id: String = "",
	items: Array = [],
	status: String = "published"
) -> Dictionary:
	## Returns {ok, message, exam}
	var auth := OopaAuthService.new()
	if not auth.can_access_hub(session, hub_id):
		return {"ok": false, "message": "Not authorized for this hub.", "exam": {}}
	if title.strip_edges().is_empty():
		return {"ok": false, "message": "Exam title is required.", "exam": {}}
	# lab must be available and in hub
	var labs := OopaManifestLabs.new().list_available_labs(PackedStringArray([hub_id]))
	var found := false
	for lab in labs:
		if str(lab.get("lab_id", "")) == lab_id:
			found = true
			break
	if not found:
		return {"ok": false, "message": "Lab not available for this hub.", "exam": {}}
	var code: String = access_code.strip_edges()
	if code.is_empty():
		code = OopaIds.access_code_6()
	if code.length() != 6 or not code.is_valid_int():
		return {"ok": false, "message": "Access code must be 6 digits.", "exam": {}}
	var eid: String = OopaIds.exam_id(hub_id)
	var exam: Dictionary = OopaSchemas.exam(
		eid, title.strip_edges(), hub_id, lab_id, duration_min, code,
		str(session.get("staff_id", "")), roster_id, items, status
	)
	var verr: PackedStringArray = OopaSchemas.validate_exam(exam)
	if verr.size() > 0:
		return {"ok": false, "message": ",".join(verr), "exam": {}}
	var store := OopaLocalStore.new()
	if store.save_exam(exam) != OK:
		return {"ok": false, "message": "Failed to save exam.", "exam": {}}
	store.append_audit("exam_created", {"exam_id": eid, "by": str(session.get("staff_id", ""))})
	return {"ok": true, "message": "Saved", "exam": exam}


func update_exam(session: Dictionary, exam: Dictionary) -> Dictionary:
	var auth := OopaAuthService.new()
	var hub: String = str(exam.get("hub_id", ""))
	if not auth.can_access_hub(session, hub):
		return {"ok": false, "message": "Not authorized.", "exam": {}}
	var verr: PackedStringArray = OopaSchemas.validate_exam(exam)
	if verr.size() > 0:
		return {"ok": false, "message": ",".join(verr), "exam": {}}
	var store := OopaLocalStore.new()
	if store.save_exam(exam) != OK:
		return {"ok": false, "message": "Save failed.", "exam": {}}
	store.append_audit("exam_updated", {"exam_id": str(exam.get("exam_id", ""))})
	return {"ok": true, "message": "Updated", "exam": exam}


func get_exam(exam_id: String) -> Dictionary:
	return OopaLocalStore.new().load_exam(exam_id)


func bind_roster(session: Dictionary, exam_id: String, roster_id: String) -> Dictionary:
	var exam: Dictionary = get_exam(exam_id)
	if exam.is_empty():
		return {"ok": false, "message": "Exam not found."}
	var auth := OopaAuthService.new()
	if not auth.can_access_hub(session, str(exam.get("hub_id", ""))):
		return {"ok": false, "message": "Not authorized."}
	exam["roster_id"] = roster_id
	return update_exam(session, exam)
