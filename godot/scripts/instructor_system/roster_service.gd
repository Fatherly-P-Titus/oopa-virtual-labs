extends RefCounted
class_name OopaRosterService
## Student whitelist create / CSV / edit / eligibility.


func list_for_session(session: Dictionary) -> Array:
	var store := OopaLocalStore.new()
	var auth := OopaAuthService.new()
	var out: Array = []
	for r in store.list_rosters():
		if auth.can_access_hub(session, str(r.get("hub_id", ""))):
			out.append(r)
	return out


func create_roster(session: Dictionary, hub_id: String, label: String, students: Array = [], source: String = "manual") -> Dictionary:
	var auth := OopaAuthService.new()
	if not auth.can_access_hub(session, hub_id):
		return {"ok": false, "message": "Not authorized for hub.", "roster": {}}
	var rid: String = OopaIds.roster_id(hub_id)
	var roster: Dictionary = OopaSchemas.roster(rid, hub_id, label.strip_edges() if not label.strip_edges().is_empty() else rid, students, source)
	var verr: PackedStringArray = OopaSchemas.validate_roster(roster)
	if verr.size() > 0:
		return {"ok": false, "message": ",".join(verr), "roster": {}}
	var store := OopaLocalStore.new()
	if store.save_roster(roster) != OK:
		return {"ok": false, "message": "Save failed.", "roster": {}}
	store.append_audit("roster_created", {"roster_id": rid})
	return {"ok": true, "message": "Saved", "roster": roster}


func save_roster(session: Dictionary, roster: Dictionary) -> Dictionary:
	var auth := OopaAuthService.new()
	if not auth.can_access_hub(session, str(roster.get("hub_id", ""))):
		return {"ok": false, "message": "Not authorized.", "roster": {}}
	roster["updated_at"] = Time.get_datetime_string_from_system(true)
	var verr: PackedStringArray = OopaSchemas.validate_roster(roster)
	if verr.size() > 0:
		return {"ok": false, "message": ",".join(verr), "roster": {}}
	var store := OopaLocalStore.new()
	if store.save_roster(roster) != OK:
		return {"ok": false, "message": "Save failed.", "roster": {}}
	return {"ok": true, "message": "Saved", "roster": roster}


func delete_roster(session: Dictionary, roster_id: String) -> Dictionary:
	var store := OopaLocalStore.new()
	var r: Dictionary = store.load_roster(roster_id)
	if r.is_empty():
		return {"ok": false, "message": "Not found."}
	if not OopaAuthService.new().can_access_hub(session, str(r.get("hub_id", ""))):
		return {"ok": false, "message": "Not authorized."}
	store.delete_roster(roster_id)
	store.append_audit("roster_deleted", {"roster_id": roster_id})
	return {"ok": true, "message": "Deleted"}


func import_csv_text(session: Dictionary, hub_id: String, label: String, csv_text: String) -> Dictionary:
	var store := OopaLocalStore.new()
	var parsed: Dictionary = store.parse_roster_csv(csv_text)
	if not bool(parsed.get("ok", false)):
		var errs: PackedStringArray = parsed.get("errors", PackedStringArray())
		return {"ok": false, "message": ",".join(errs), "roster": {}}
	return create_roster(session, hub_id, label, parsed.get("students", []), "csv")


func is_eligible(exam: Dictionary, matric: String) -> bool:
	var rid: String = str(exam.get("roster_id", ""))
	if rid.is_empty():
		return false  # must have whitelist in v1
	var roster: Dictionary = OopaLocalStore.new().load_roster(rid)
	if roster.is_empty():
		return false
	var m: String = OopaIds.normalize_matric(matric)
	for s in roster.get("students", []):
		if OopaIds.normalize_matric(str(s.get("matric", ""))) == m:
			return true
	return false


func find_student(roster: Dictionary, matric: String) -> Dictionary:
	var m: String = OopaIds.normalize_matric(matric)
	for s in roster.get("students", []):
		if OopaIds.normalize_matric(str(s.get("matric", ""))) == m:
			return s
	return {}
