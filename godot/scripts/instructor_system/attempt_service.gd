extends RefCounted
class_name OopaAttemptService
## Start / resume / submit exam attempts. Fail closed on eligibility.


func find_exam_by_access_code(code: String) -> Dictionary:
	var want: String = code.strip_edges()
	if want.length() != 6:
		return {}
	for e in OopaLocalStore.new().list_exams():
		if str(e.get("access_code", "")) == want:
			# published or draft both allowed for local v1; prefer published
			return e
	return {}


func has_submitted(exam_id: String, matric: String) -> bool:
	var m: String = OopaIds.normalize_matric(matric)
	for a in OopaLocalStore.new().list_attempts(exam_id):
		if OopaIds.normalize_matric(str(a.get("matric", ""))) == m:
			var st: String = str(a.get("status", ""))
			if st == "submitted" or st == "expired":
				return true
	return false


func start_attempt(access_code: String, name: String, matric: String) -> Dictionary:
	## Returns {ok, message, attempt, exam}
	var code: String = access_code.strip_edges()
	var nm: String = name.strip_edges()
	var mat: String = OopaIds.normalize_matric(matric)
	if code.is_empty() or nm.is_empty() or mat.is_empty():
		return {"ok": false, "message": "Access code, name, and matric number are required.", "attempt": {}, "exam": {}}

	var exam: Dictionary = find_exam_by_access_code(code)
	if exam.is_empty():
		return {"ok": false, "message": "Invalid exam access code.", "attempt": {}, "exam": {}}

	var status: String = str(exam.get("status", "published"))
	if status == "closed":
		return {"ok": false, "message": "This exam is closed.", "attempt": {}, "exam": {}}

	if not OopaRosterService.new().is_eligible(exam, mat):
		return {"ok": false, "message": "You are not on the eligibility list for this exam.", "attempt": {}, "exam": {}}

	if has_submitted(str(exam.get("exam_id", "")), mat):
		return {"ok": false, "message": "An attempt was already submitted for this matric number.", "attempt": {}, "exam": {}}

	var eid: String = str(exam.get("exam_id", ""))
	var aid: String = OopaIds.attempt_id(eid, mat)
	var dur: int = int(exam.get("duration_min", 15))
	var attempt: Dictionary = OopaSchemas.attempt(aid, eid, nm, mat, dur)

	# Seed default answer slots from exam items (if any)
	var answers: Dictionary = {}
	for item in exam.get("items", []):
		var iid: String = str(item.get("item_id", ""))
		if iid != "":
			answers[iid] = ""
	# Always include a practical note field
	answers["_practical_notes"] = ""
	attempt["answers"] = answers
	attempt["lab_meta"] = {
		"lab_id": str(exam.get("lab_id", "")),
		"hub_id": str(exam.get("hub_id", "")),
	}

	var store := OopaLocalStore.new()
	if store.save_attempt(attempt) != OK:
		return {"ok": false, "message": "Could not save attempt.", "attempt": {}, "exam": {}}
	store.append_audit("attempt_started", {"exam_id": eid, "matric": mat})
	return {"ok": true, "message": "Started", "attempt": attempt, "exam": exam}


func save_progress(attempt: Dictionary) -> Error:
	return OopaLocalStore.new().save_attempt(attempt)


func submit_attempt(attempt: Dictionary, reason: String = "submitted") -> Dictionary:
	## reason: submitted | expired
	attempt["status"] = reason
	attempt["submitted_at"] = Time.get_datetime_string_from_system(true)
	attempt["timer_seconds_remaining"] = maxi(int(attempt.get("timer_seconds_remaining", 0)), 0)
	var store := OopaLocalStore.new()
	if store.save_attempt(attempt) != OK:
		return {"ok": false, "message": "Submit save failed.", "attempt": attempt}
	store.append_audit("attempt_submitted", {
		"exam_id": str(attempt.get("exam_id", "")),
		"matric": str(attempt.get("matric", "")),
		"reason": reason,
	})
	return {"ok": true, "message": "Submitted", "attempt": attempt}
