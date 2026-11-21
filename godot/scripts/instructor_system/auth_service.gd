extends RefCounted
class_name OopaAuthService
## Individual instructor credentials from seed / override. Fail closed.


func authenticate(staff_id: String, passcode: String) -> Dictionary:
	## Returns {ok, message, instructor} where instructor is a session-ready dict.
	var sid: String = staff_id.strip_edges()
	var pc: String = passcode
	if sid.is_empty() or pc.is_empty():
		return {"ok": false, "message": "Staff ID and passcode are required.", "instructor": {}}

	var store := OopaLocalStore.new()
	var list: Array = store.load_instructors()
	for row in list:
		if str(row.get("staff_id", "")) != sid:
			continue
		if not bool(row.get("active", true)):
			return {"ok": false, "message": "This account is inactive.", "instructor": {}}
		if str(row.get("passcode", "")) != pc:
			return {"ok": false, "message": "Invalid Staff ID or passcode.", "instructor": {}}
		var hubs: Array = []
		for h in row.get("hubs", []):
			hubs.append(str(h))
		var inst: Dictionary = {
			"staff_id": sid,
			"role": str(row.get("role", "instructor")),
			"hubs": hubs,
			"display_name": str(row.get("display_name", sid)),
		}
		store.append_audit("login_success", {"staff_id": sid, "role": inst["role"]})
		return {"ok": true, "message": "OK", "instructor": inst}

	store.append_audit("login_failed", {"staff_id": sid})
	return {"ok": false, "message": "Invalid Staff ID or passcode.", "instructor": {}}


func can_access_hub(session: Dictionary, hub_id: String) -> bool:
	if session.is_empty():
		return false
	if str(session.get("role", "")) == "admin":
		return true
	for h in session.get("hubs", []):
		if str(h) == hub_id:
			return true
	return false


func allowed_hubs(session: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if session.is_empty():
		return out
	if str(session.get("role", "")) == "admin":
		var store := OopaLocalStore.new()
		for h in store.load_hubs():
			out.append(str(h.get("id", "")))
		return out
	for h in session.get("hubs", []):
		out.append(str(h))
	return out
