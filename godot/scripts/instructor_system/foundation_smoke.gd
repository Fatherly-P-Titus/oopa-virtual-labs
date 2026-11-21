extends RefCounted
class_name OopaFoundationSmoke
## Run from a tool script or temporary scene: returns PackedStringArray of failures (empty = pass).


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	var store := OopaLocalStore.new()
	store.ensure_dirs()

	# IDs
	var eid: String = OopaIds.exam_id("chemistry")
	if not eid.begins_with("EX-CHEM-"):
		fails.append("exam_id format")
	var code: String = OopaIds.access_code_6()
	if code.length() != 6:
		fails.append("access_code length")

	# Instructors seed
	var instructors: Array = store.load_instructors()
	if instructors.is_empty():
		fails.append("no instructors loaded from seed")
	var hubs: Array = store.load_hubs()
	if hubs.size() < 4:
		fails.append("hubs seed incomplete")

	# Exam round-trip
	var exam: Dictionary = OopaSchemas.exam(
		eid, "Smoke Test Exam", "chemistry", "gas_laws", 15, code, "AdminStaff/001", "", [], "draft"
	)
	var verr: PackedStringArray = OopaSchemas.validate_exam(exam)
	if verr.size() > 0:
		fails.append("exam validation: " + ",".join(verr))
	if store.save_exam(exam) != OK:
		fails.append("save_exam failed")
	var loaded: Dictionary = store.load_exam(eid)
	if str(loaded.get("exam_id", "")) != eid:
		fails.append("load_exam mismatch")

	# Roster + CSV parse
	var rid: String = OopaIds.roster_id("engineering")
	var parsed: Dictionary = store.parse_roster_csv(
		"S/N,Student Name,Matric Number\n1,Ada Okafor,ENG/2024/001\n2,Ben Yusuf,ENG/2024/014\n"
	)
	if not bool(parsed.get("ok", false)):
		fails.append("csv parse failed")
	var roster: Dictionary = OopaSchemas.roster(rid, "engineering", "Smoke Roster", parsed.get("students", []), "csv")
	if store.save_roster(roster) != OK:
		fails.append("save_roster failed")
	var r2: Dictionary = store.load_roster(rid)
	if str(r2.get("roster_id", "")) != rid:
		fails.append("load_roster mismatch")

	# Bad CSV
	var bad: Dictionary = store.parse_roster_csv("foo,bar\n1,2\n")
	if bool(bad.get("ok", true)):
		fails.append("bad csv should fail")

	# Attempt + grade
	var aid: String = OopaIds.attempt_id(eid, "ENG/2024/001")
	var att: Dictionary = OopaSchemas.attempt(aid, eid, "Ada Okafor", "ENG/2024/001", 15)
	if store.save_attempt(att) != OK:
		fails.append("save_attempt failed")
	var gid: String = OopaIds.grade_id(eid, "ENG/2024/001")
	var gr: Dictionary = OopaSchemas.grade(gid, eid, aid, "ENG/2024/001", 5.0, 3.0, 10.0, "AdminStaff/001")
	if store.save_grade(gr) != OK:
		fails.append("save_grade failed")

	# Manifest adapter
	var labs := OopaManifestLabs.new()
	var available: Array = labs.list_available_labs()
	if available.is_empty():
		fails.append("manifest adapter returned no available labs")

	store.append_audit("smoke_m01", {"ok": fails.is_empty()})
	# cleanup smoke exam optional — leave for inspect
	return fails
