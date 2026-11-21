extends RefCounted
class_name OopaLocalStore
## Local filesystem storage under user://oopa/ with optional res:// seeds.

const USER_ROOT := "user://oopa"
const SEED_ROOT := "res://data/instructor_system"


func ensure_dirs() -> void:
	_dir_make(USER_ROOT)
	_dir_make(USER_ROOT + "/exams")
	_dir_make(USER_ROOT + "/rosters")
	_dir_make(USER_ROOT + "/attempts")
	_dir_make(USER_ROOT + "/grades")
	_dir_make(USER_ROOT + "/audit")


func _dir_make(path: String) -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	# recursive create relative to user://
	var rel := path.replace("user://", "")
	var parts: PackedStringArray = rel.split("/")
	var cur := "user://"
	for p in parts:
		if p.is_empty():
			continue
		cur = cur.path_join(p) if cur != "user://" else "user://".path_join(p)
		# DirAccess.make_dir_recursive is available in Godot 4
	DirAccess.make_dir_recursive_absolute(path)


func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	return data


func _write_json_file(path: String, data: Variant) -> Error:
	ensure_dirs()
	var parent: String = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK


func _list_json(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var fn: String = d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".json"):
			out.append(dir_path.path_join(fn))
		fn = d.get_next()
	d.list_dir_end()
	return out


# ----- instructors / hubs (seed + optional override) -----

func load_instructors() -> Array:
	ensure_dirs()
	var override_path := USER_ROOT + "/instructors_override.json"
	if FileAccess.file_exists(override_path):
		var o: Variant = _read_json_file(override_path)
		if o is Dictionary and o.has("instructors"):
			return (o["instructors"] as Array).duplicate(true)
	var seed_path := SEED_ROOT + "/instructors.json"
	var s: Variant = _read_json_file(seed_path)
	if s is Dictionary and s.has("instructors"):
		return (s["instructors"] as Array).duplicate(true)
	return []


func load_hubs() -> Array:
	var seed_path := SEED_ROOT + "/hubs.json"
	var s: Variant = _read_json_file(seed_path)
	if s is Dictionary and s.has("hubs"):
		return (s["hubs"] as Array).duplicate(true)
	return []


# ----- exams -----

func exam_path(exam_id: String) -> String:
	return USER_ROOT + "/exams/%s.json" % OopaIds.sanitize_filename(exam_id)


func save_exam(exam: Dictionary) -> Error:
	var id: String = str(exam.get("exam_id", ""))
	if id.is_empty():
		return ERR_INVALID_PARAMETER
	return _write_json_file(exam_path(id), exam)


func load_exam(exam_id: String) -> Dictionary:
	var data: Variant = _read_json_file(exam_path(exam_id))
	if data is Dictionary:
		return data
	return {}


func list_exams() -> Array:
	var result: Array = []
	for path in _list_json(USER_ROOT + "/exams"):
		var data: Variant = _read_json_file(path)
		if data is Dictionary:
			result.append(data)
	return result


func delete_exam(exam_id: String) -> Error:
	var path := exam_path(exam_id)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(path)


# ----- rosters -----

func roster_path(roster_id: String) -> String:
	return USER_ROOT + "/rosters/%s.json" % OopaIds.sanitize_filename(roster_id)


func roster_csv_path(roster_id: String) -> String:
	return USER_ROOT + "/rosters/%s.csv" % OopaIds.sanitize_filename(roster_id)


func save_roster(roster: Dictionary) -> Error:
	var id: String = str(roster.get("roster_id", ""))
	if id.is_empty():
		return ERR_INVALID_PARAMETER
	var err := _write_json_file(roster_path(id), roster)
	if err != OK:
		return err
	# mirror CSV
	return save_roster_csv(id, roster.get("students", []) as Array)


func load_roster(roster_id: String) -> Dictionary:
	var data: Variant = _read_json_file(roster_path(roster_id))
	if data is Dictionary:
		return data
	return {}


func list_rosters() -> Array:
	var result: Array = []
	for path in _list_json(USER_ROOT + "/rosters"):
		var data: Variant = _read_json_file(path)
		if data is Dictionary:
			result.append(data)
	return result


func delete_roster(roster_id: String) -> Error:
	var jp := roster_path(roster_id)
	var cp := roster_csv_path(roster_id)
	if FileAccess.file_exists(cp):
		DirAccess.remove_absolute(cp)
	if not FileAccess.file_exists(jp):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(jp)


func save_roster_csv(roster_id: String, students: Array) -> Error:
	ensure_dirs()
	var path := roster_csv_path(roster_id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_line("S/N,Student Name,Matric Number")
	for s in students:
		var sn: int = int(s.get("sn", 0))
		var name: String = str(s.get("name", "")).replace(",", " ")
		var matric: String = str(s.get("matric", ""))
		f.store_line("%d,%s,%s" % [sn, name, matric])
	f.close()
	return OK


func parse_roster_csv(text: String) -> Dictionary:
	## Returns {ok: bool, students: Array, errors: PackedStringArray}
	var errors := PackedStringArray()
	var students: Array = []
	var lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	if lines.is_empty():
		errors.append("empty CSV")
		return {"ok": false, "students": students, "errors": errors}
	var header: String = lines[0].strip_edges().to_lower()
	if "matric" not in header or "name" not in header:
		errors.append("CSV must include columns: S/N, Student Name, Matric Number")
		return {"ok": false, "students": students, "errors": errors}
	var seen: Dictionary = {}
	for i in range(1, lines.size()):
		var line: String = lines[i].strip_edges()
		if line.is_empty():
			continue
		var cols: PackedStringArray = line.split(",", false)
		if cols.size() < 3:
			errors.append("line %d: expected 3 columns" % (i + 1))
			continue
		var sn: int = int(cols[0].strip_edges()) if cols[0].strip_edges().is_valid_int() else i
		var name: String = cols[1].strip_edges()
		var matric: String = OopaIds.normalize_matric(cols[2].strip_edges())
		# if more commas in name, join middle — simple: last col matric, first sn
		if cols.size() > 3:
			matric = OopaIds.normalize_matric(cols[cols.size() - 1].strip_edges())
			name = ",".join(cols.slice(1, cols.size() - 1)).strip_edges()
		if matric.is_empty() or name.is_empty():
			errors.append("line %d: name and matric required" % (i + 1))
			continue
		if seen.has(matric):
			errors.append("duplicate matric: " + matric)
			continue
		seen[matric] = true
		students.append(OopaSchemas.student_row(sn, name, matric))
	if students.is_empty() and errors.is_empty():
		errors.append("no student rows")
	return {"ok": errors.is_empty(), "students": students, "errors": errors}


func load_roster_csv_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "students": [], "errors": PackedStringArray(["file not found"])}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "students": [], "errors": PackedStringArray(["cannot open file"])}
	var text: String = f.get_as_text()
	f.close()
	return parse_roster_csv(text)


# ----- attempts -----

func attempt_dir(exam_id: String) -> String:
	return USER_ROOT + "/attempts/%s" % OopaIds.sanitize_filename(exam_id)


func attempt_path(exam_id: String, attempt_id: String) -> String:
	return attempt_dir(exam_id).path_join("%s.json" % OopaIds.sanitize_filename(attempt_id))


func save_attempt(attempt: Dictionary) -> Error:
	var eid: String = str(attempt.get("exam_id", ""))
	var aid: String = str(attempt.get("attempt_id", ""))
	if eid.is_empty() or aid.is_empty():
		return ERR_INVALID_PARAMETER
	return _write_json_file(attempt_path(eid, aid), attempt)


func load_attempt(exam_id: String, attempt_id: String) -> Dictionary:
	var data: Variant = _read_json_file(attempt_path(exam_id, attempt_id))
	if data is Dictionary:
		return data
	return {}


func list_attempts(exam_id: String) -> Array:
	var result: Array = []
	for path in _list_json(attempt_dir(exam_id)):
		var data: Variant = _read_json_file(path)
		if data is Dictionary:
			result.append(data)
	return result


# ----- grades -----

func grade_path(exam_id: String, matric: String) -> String:
	var m := OopaIds.sanitize_filename(OopaIds.normalize_matric(matric))
	return USER_ROOT + "/grades/%s/%s.json" % [OopaIds.sanitize_filename(exam_id), m]


func save_grade(grade: Dictionary) -> Error:
	var eid: String = str(grade.get("exam_id", ""))
	var matric: String = str(grade.get("matric", ""))
	if eid.is_empty() or matric.is_empty():
		return ERR_INVALID_PARAMETER
	return _write_json_file(grade_path(eid, matric), grade)


func load_grade(exam_id: String, matric: String) -> Dictionary:
	var data: Variant = _read_json_file(grade_path(exam_id, matric))
	if data is Dictionary:
		return data
	return {}


func list_grades(exam_id: String) -> Array:
	var result: Array = []
	var dir_path := USER_ROOT + "/grades/%s" % OopaIds.sanitize_filename(exam_id)
	for path in _list_json(dir_path):
		var data: Variant = _read_json_file(path)
		if data is Dictionary:
			result.append(data)
	return result


# ----- audit -----

func append_audit(event: String, detail: Dictionary = {}) -> void:
	ensure_dirs()
	var day: String = OopaIds._date_stamp()
	var path := USER_ROOT + "/audit/%s.log" % day
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var line := "%s\t%s\t%s" % [
		Time.get_datetime_string_from_system(true),
		event,
		JSON.stringify(detail)
	]
	f.store_line(line)
	f.close()
