extends RefCounted
class_name OopaGradeService
## Hybrid grading: auto-score objective items + manual marks + CSV export.


func list_exams_for_session(session: Dictionary) -> Array:
	return OopaExamService.new().list_for_session(session)


func list_attempts(exam_id: String) -> Array:
	return OopaLocalStore.new().list_attempts(exam_id)


func load_grade(exam_id: String, matric: String) -> Dictionary:
	return OopaLocalStore.new().load_grade(exam_id, matric)


func auto_score_attempt(exam: Dictionary, attempt: Dictionary) -> Dictionary:
	## Returns {auto_score, max_auto, breakdown: [{item_id, points, max, note}]}
	var answers: Dictionary = attempt.get("answers", {})
	var total: float = 0.0
	var max_auto: float = 0.0
	var breakdown: Array = []
	for item in exam.get("items", []):
		var typ: String = str(item.get("type", "manual"))
		var iid: String = str(item.get("item_id", ""))
		var mx: float = float(item.get("max_points", 0.0))
		if typ == "manual" or typ == "lab_task":
			continue
		max_auto += mx
		var resp: String = str(answers.get(iid, "")).strip_edges()
		var pts: float = 0.0
		var note: String = ""
		var payload: Dictionary = item.get("payload", {})
		match typ:
			"mcq":
				var correct_value: Variant = payload.get("correct_index", payload.get("correct", ""))
				var correct: String = str(correct_value)
				if payload.has("correct_index") and typeof(correct_value) in [TYPE_INT, TYPE_FLOAT]:
					var correct_index_number := float(correct_value)
					if is_equal_approx(correct_index_number, roundf(correct_index_number)):
						correct = str(int(roundf(correct_index_number)))
				if resp != "" and resp == correct:
					pts = mx
					note = "correct"
				else:
					note = "incorrect"
			"numeric":
				var target: float = float(payload.get("value", 0.0))
				var tol: float = float(payload.get("tolerance", 0.01))
				if resp.is_valid_float():
					var v: float = float(resp)
					if absf(v - target) <= tol:
						pts = mx
						note = "within tolerance"
					else:
						note = "out of range"
				else:
					note = "not numeric"
			"short_text":
				var expected: String = str(payload.get("answer", "")).strip_edges().to_lower()
				if expected != "" and resp.to_lower() == expected:
					pts = mx
					note = "match"
				else:
					note = "no match"
			_:
				note = "skipped type"
		total += pts
		breakdown.append({"item_id": iid, "points": pts, "max": mx, "note": note, "type": typ})
	return {"auto_score": total, "max_auto": max_auto, "breakdown": breakdown}


func max_points(exam: Dictionary) -> float:
	var m: float = 0.0
	for item in exam.get("items", []):
		m += float(item.get("max_points", 0.0))
	# Practical notes always available as manual bucket if no items
	if exam.get("items", []).is_empty():
		m = 10.0  # default practical total when unstructured
	return m


func max_manual(exam: Dictionary) -> float:
	var m: float = 0.0
	var any_items := false
	for item in exam.get("items", []):
		any_items = true
		var typ: String = str(item.get("type", "manual"))
		if typ == "manual" or typ == "lab_task":
			m += float(item.get("max_points", 0.0))
	if not any_items:
		m = 10.0
	return m


func save_grade_record(
	session: Dictionary,
	exam: Dictionary,
	attempt: Dictionary,
	manual_score: float,
	comments: String = ""
) -> Dictionary:
	var auth := OopaAuthService.new()
	if not auth.can_access_hub(session, str(exam.get("hub_id", ""))):
		return {"ok": false, "message": "Not authorized.", "grade": {}}
	var auto: Dictionary = auto_score_attempt(exam, attempt)
	var auto_pts: float = float(auto.get("auto_score", 0.0))
	var max_pts: float = max_points(exam)
	var man: float = clampf(manual_score, 0.0, max_manual(exam))
	var matric: String = str(attempt.get("matric", ""))
	var gid: String = OopaIds.grade_id(str(exam.get("exam_id", "")), matric)
	var grade: Dictionary = OopaSchemas.grade(
		gid,
		str(exam.get("exam_id", "")),
		str(attempt.get("attempt_id", "")),
		matric,
		auto_pts,
		man,
		max_pts,
		str(session.get("staff_id", "")),
		comments
	)
	grade["auto_breakdown"] = auto.get("breakdown", [])
	grade["student_name"] = str(attempt.get("name", ""))
	grade["attempt_status"] = str(attempt.get("status", ""))
	var store := OopaLocalStore.new()
	if store.save_grade(grade) != OK:
		return {"ok": false, "message": "Save failed.", "grade": {}}
	store.append_audit("grade_saved", {"exam_id": str(exam.get("exam_id", "")), "matric": matric})
	return {"ok": true, "message": "Saved", "grade": grade}


func export_results_csv(exam_id: String) -> Dictionary:
	## Returns {ok, text, message}
	var store := OopaLocalStore.new()
	var exam: Dictionary = store.load_exam(exam_id)
	if exam.is_empty():
		return {"ok": false, "text": "", "message": "Exam not found"}
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Matric,Name,Auto,Manual,Total,Max,Status,Submitted_at,Graded_by")
	var attempts: Array = store.list_attempts(exam_id)
	# Index grades
	var grades_by_m: Dictionary = {}
	for g in store.list_grades(exam_id):
		grades_by_m[OopaIds.normalize_matric(str(g.get("matric", "")))] = g
	for a in attempts:
		var m: String = OopaIds.normalize_matric(str(a.get("matric", "")))
		var g: Dictionary = grades_by_m.get(m, {})
		var auto_s: float = float(g.get("auto_score", 0.0))
		var man_s: float = float(g.get("manual_score", 0.0))
		var tot: float = float(g.get("total", auto_s + man_s))
		var mx: float = float(g.get("max_points", max_points(exam)))
		var name: String = str(a.get("name", "")).replace(",", " ")
		var st: String = str(a.get("status", ""))
		var sub: String = str(a.get("submitted_at", ""))
		var by: String = str(g.get("graded_by", ""))
		if g.is_empty():
			# unscored: still show attempt
			var auto_tmp: Dictionary = auto_score_attempt(exam, a)
			auto_s = float(auto_tmp.get("auto_score", 0.0))
			man_s = 0.0
			tot = auto_s
			mx = max_points(exam)
			by = ""
		lines.append("%s,%s,%.2f,%.2f,%.2f,%.2f,%s,%s,%s" % [
			m, name, auto_s, man_s, tot, mx, st, sub, by
		])
	var text: String = "\n".join(lines) + "\n"
	# Also write to disk
	var path := "user://oopa/grades/%s/results.csv" % OopaIds.sanitize_filename(exam_id)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	return {"ok": true, "text": text, "message": path}
