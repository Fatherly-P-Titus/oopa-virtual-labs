extends RefCounted
class_name OopaSchemas
## Record factories and light validation for instructor-system entities.


static func instructor(staff_id: String, passcode: String, role: String, hubs: Array, display_name: String, active: bool = true) -> Dictionary:
	return {
		"staff_id": staff_id,
		"passcode": passcode,
		"role": role,
		"hubs": hubs.duplicate(),
		"display_name": display_name,
		"active": active,
	}


static func exam(
	exam_id: String,
	title: String,
	hub_id: String,
	lab_id: String,
	duration_min: int,
	access_code: String,
	created_by: String,
	roster_id: String = "",
	items: Array = [],
	status: String = "draft"
) -> Dictionary:
	return {
		"exam_id": exam_id,
		"title": title,
		"hub_id": hub_id,
		"lab_id": lab_id,
		"duration_min": clampi(duration_min, 5, 60),
		"access_code": access_code,
		"created_by": created_by,
		"created_at": Time.get_datetime_string_from_system(true),
		"roster_id": roster_id,
		"items": items.duplicate(true),
		"status": status,
	}


static func exam_item(item_id: String, type: String, prompt: String, max_points: float, payload: Dictionary = {}) -> Dictionary:
	## type: mcq | numeric | short_text | manual | lab_task
	return {
		"item_id": item_id,
		"type": type,
		"prompt": prompt,
		"max_points": max_points,
		"payload": payload.duplicate(true),
	}


static func roster(roster_id: String, hub_id: String, label: String, students: Array = [], source: String = "manual") -> Dictionary:
	return {
		"roster_id": roster_id,
		"hub_id": hub_id,
		"label": label,
		"students": students.duplicate(true),
		"source": source,
		"updated_at": Time.get_datetime_string_from_system(true),
	}


static func student_row(sn: int, name: String, matric: String) -> Dictionary:
	return {
		"sn": sn,
		"name": name.strip_edges(),
		"matric": OopaIds.normalize_matric(matric),
	}


static func attempt(
	attempt_id: String,
	exam_id: String,
	name: String,
	matric: String,
	duration_min: int
) -> Dictionary:
	return {
		"attempt_id": attempt_id,
		"exam_id": exam_id,
		"name": name.strip_edges(),
		"matric": OopaIds.normalize_matric(matric),
		"started_at": Time.get_datetime_string_from_system(true),
		"submitted_at": "",
		"duration_min": duration_min,
		"timer_seconds_remaining": duration_min * 60,
		"answers": {},
		"lab_meta": {},
		"status": "in_progress",
	}


static func grade(
	grade_id: String,
	exam_id: String,
	attempt_id: String,
	matric: String,
	auto_score: float,
	manual_score: float,
	max_points: float,
	graded_by: String,
	comments: String = ""
) -> Dictionary:
	return {
		"grade_id": grade_id,
		"exam_id": exam_id,
		"attempt_id": attempt_id,
		"matric": OopaIds.normalize_matric(matric),
		"auto_score": auto_score,
		"manual_score": manual_score,
		"total": auto_score + manual_score,
		"max_points": max_points,
		"comments": comments,
		"graded_by": graded_by,
		"graded_at": Time.get_datetime_string_from_system(true),
	}


static func validate_exam(e: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	if str(e.get("exam_id", "")).is_empty():
		errs.append("exam_id required")
	if str(e.get("title", "")).strip_edges().is_empty():
		errs.append("title required")
	if str(e.get("hub_id", "")).is_empty():
		errs.append("hub_id required")
	if str(e.get("lab_id", "")).is_empty():
		errs.append("lab_id required")
	var dur: int = int(e.get("duration_min", 0))
	if dur < 5 or dur > 60:
		errs.append("duration_min must be 5–60")
	var code: String = str(e.get("access_code", ""))
	if code.length() != 6 or not code.is_valid_int():
		errs.append("access_code must be 6 digits")
	return errs


static func validate_roster(r: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	if str(r.get("roster_id", "")).is_empty():
		errs.append("roster_id required")
	if str(r.get("hub_id", "")).is_empty():
		errs.append("hub_id required")
	var seen: Dictionary = {}
	for s in r.get("students", []):
		var m: String = OopaIds.normalize_matric(str(s.get("matric", "")))
		if m.is_empty():
			errs.append("empty matric in roster")
			continue
		if seen.has(m):
			errs.append("duplicate matric: " + m)
		seen[m] = true
	return errs
