extends RefCounted
class_name OopaLifecycleSmoke
## Full offline lifecycle check for M06. Returns failure messages (empty = pass).


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	var store := OopaLocalStore.new()
	store.ensure_dirs()

	# Auth
	var auth := OopaAuthService.new()
	var bad: Dictionary = auth.authenticate("nope", "wrong")
	if bool(bad.get("ok", true)):
		fails.append("auth should fail for bad credentials")
	var admin: Dictionary = auth.authenticate("AdminStaff/001", "12346")
	if not bool(admin.get("ok", false)):
		fails.append("admin login failed")
		return fails
	var session: Dictionary = admin.get("instructor", {})

	# Roster
	var csv := "S/N,Student Name,Matric Number\n1,Test Student,TEST/2026/001\n"
	var rost: Dictionary = OopaRosterService.new().import_csv_text(session, "chemistry", "M06 Smoke Roster", csv)
	if not bool(rost.get("ok", false)):
		fails.append("roster import: " + str(rost.get("message", "")))
		return fails
	var roster: Dictionary = rost.get("roster", {})
	var rid: String = str(roster.get("roster_id", ""))

	# Exam
	var labs: Array = OopaManifestLabs.new().list_available_labs(PackedStringArray(["chemistry"]))
	if labs.is_empty():
		fails.append("no chemistry labs in manifest")
		return fails
	var lab_id: String = str(labs[0].get("lab_id", "gas_laws"))
	var code: String = OopaIds.access_code_6()
	var ex: Dictionary = OopaExamService.new().create_exam(
		session, "M06 Lifecycle Exam", "chemistry", lab_id, 10, code, rid, [], "published"
	)
	if not bool(ex.get("ok", false)):
		fails.append("exam create: " + str(ex.get("message", "")))
		return fails
	var exam: Dictionary = ex.get("exam", {})
	var eid: String = str(exam.get("exam_id", ""))

	# Ineligible
	var deny: Dictionary = OopaAttemptService.new().start_attempt(code, "Outsider", "NOPE/000")
	if bool(deny.get("ok", true)):
		fails.append("ineligible student should be denied")

	# Eligible attempt
	var start: Dictionary = OopaAttemptService.new().start_attempt(code, "Test Student", "TEST/2026/001")
	if not bool(start.get("ok", false)):
		fails.append("attempt start: " + str(start.get("message", "")))
		return fails
	var attempt: Dictionary = start.get("attempt", {})
	attempt["answers"] = {"_practical_notes": "Observed Boyle trend under smoke test."}
	var sub: Dictionary = OopaAttemptService.new().submit_attempt(attempt, "submitted")
	if not bool(sub.get("ok", false)):
		fails.append("submit failed")

	# Duplicate submit blocked
	var dup: Dictionary = OopaAttemptService.new().start_attempt(code, "Test Student", "TEST/2026/001")
	if bool(dup.get("ok", true)):
		fails.append("duplicate attempt should be blocked")

	# Grade
	var gr: Dictionary = OopaGradeService.new().save_grade_record(
		session, exam, sub.get("attempt", attempt), 8.0, "Solid notes"
	)
	if not bool(gr.get("ok", false)):
		fails.append("grade save: " + str(gr.get("message", "")))

	# CSV export
	var csv_out: Dictionary = OopaGradeService.new().export_results_csv(eid)
	if not bool(csv_out.get("ok", false)):
		fails.append("csv export failed")
	elif "TEST/2026/001" not in str(csv_out.get("text", "")):
		fails.append("csv missing matric")

	# Hub isolation: chem instructor cannot use physics hub for exam
	var chem: Dictionary = auth.authenticate("ChemStaff/001", "Chem#2026")
	if bool(chem.get("ok", false)):
		var cs: Dictionary = chem.get("instructor", {})
		var bad_exam: Dictionary = OopaExamService.new().create_exam(
			cs, "Should Fail", "physics", "projectile_motion", 10, "", "", [], "published"
		)
		if bool(bad_exam.get("ok", true)):
			fails.append("chem instructor must not create physics exam")

	store.append_audit("lifecycle_smoke_m06", {"ok": fails.is_empty(), "exam_id": eid})
	return fails
