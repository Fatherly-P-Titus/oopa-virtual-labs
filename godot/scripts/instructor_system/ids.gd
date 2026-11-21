extends RefCounted
class_name OopaIds
## ID generation and string normalization for the instructor system.

const HEX := "0123456789ABCDEF"


static func normalize_matric(m: String) -> String:
	return m.strip_edges().to_upper()


static func sanitize_filename(s: String) -> String:
	var out := ""
	for i in range(s.length()):
		var ch: String = s[i]
		var o: int = ch.unicode_at(0)
		if (o >= 48 and o <= 57) or (o >= 65 and o <= 90) or (o >= 97 and o <= 122) or ch == "-" or ch == "_":
			out += ch
		else:
			out += "_"
	if out.is_empty():
		out = "x"
	return out


static func _rand4() -> String:
	var s := ""
	for i in range(4):
		s += HEX[randi() % 16]
	return s


static func _date_stamp() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d" % [int(dt.get("year", 2026)), int(dt.get("month", 1)), int(dt.get("day", 1))]


static func hub_short(hub_id: String) -> String:
	match hub_id:
		"chemistry":
			return "CHEM"
		"biology":
			return "BIO"
		"physics":
			return "PHYS"
		"engineering":
			return "ENG"
		_:
			var u := hub_id.to_upper()
			return u.substr(0, mini(4, u.length()))


static func exam_id(hub_id: String) -> String:
	return "EX-%s-%s-%s" % [hub_short(hub_id), _date_stamp(), _rand4()]


static func roster_id(hub_id: String) -> String:
	return "RO-%s-%s-%s" % [hub_short(hub_id), _date_stamp(), _rand4()]


static func attempt_id(exam_id: String, matric: String) -> String:
	var m := sanitize_filename(normalize_matric(matric))
	var ts: int = int(Time.get_unix_time_from_system())
	return "AT-%s-%s-%d" % [sanitize_filename(exam_id), m, ts]


static func grade_id(exam_id: String, matric: String) -> String:
	return "GR-%s-%s" % [sanitize_filename(exam_id), sanitize_filename(normalize_matric(matric))]


static func access_code_6() -> String:
	var n: int = randi() % 1000000
	return "%06d" % n
