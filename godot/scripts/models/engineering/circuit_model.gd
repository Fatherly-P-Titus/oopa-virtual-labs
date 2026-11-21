extends RefCounted
class_name CircuitModel
## BASELINE LOCK v2 2026-10-23 — 4-port switch ON/OFF works.
## Ports are multi-connection junctions; four or more wires are supported per port.
## Switch: in+(0) in−(1) out+(2) out−(3). ON connects 0↔2 and 1↔3. OFF opens both.

const SLOTS: int = 8
const SLOT_PX: float = 50.0

const R_WIRE: float = 0.05       # Small finite wire resistance enables branch-current measurement.
const R_SW_ON: float = 0.05      # Closed-contact resistance.
const R_INDUCTOR_COIL: float = 0.2 # Small winding resistance for a realistic DC path.
const R_OPEN: float = 1.0e12
const R_DIODE_ON: float = 5.0    # Piecewise-linear dynamic resistance.
const G_DIODE_OFF: float = 1.0e-9
const V_DIODE_BREAKDOWN: float = 5.0
const I_ON: float = 0.002
const I_LIVE: float = 0.001
const MAX_NEWTON_ITERATIONS: int = 80
const SOLVER_TOLERANCE: float = 1.0e-7

enum Kind { BAT, R, LEDW, LEDO, SWITCH, DIODE, CAP, IND, POT, FUSE, MOTOR, LAMP, TRANSISTOR }

const DEFS: Dictionary = {
	Kind.BAT:    {"label": "BAT",  "value": 9.0, "ports": 2},
	Kind.R:      {"label": "R",    "value": 330.0, "ports": 2},
	Kind.LEDW:   {"label": "LEDW", "value": 3.0, "ports": 2},
	Kind.LEDO:   {"label": "LEDO", "value": 2.0, "ports": 2},
	Kind.SWITCH: {"label": "SW",   "value": 0.0, "ports": 4},
	Kind.DIODE:  {"label": "DIODE", "value": 0.7, "ports": 2},
	Kind.CAP:    {"label": "CAP", "value": 100.0, "ports": 2}, # capacitance in µF
	Kind.IND:    {"label": "IND", "value": 100.0, "ports": 2}, # inductance in mH
	Kind.POT:    {"label": "POT", "value": 10000.0, "ports": 3}, # total resistance in ohms
	Kind.FUSE:   {"label": "FUSE", "value": 0.5, "ports": 2}, # current rating in amperes
	Kind.MOTOR:  {"label": "MOTOR", "value": 12.0, "ports": 2}, # armature resistance in ohms
	Kind.LAMP:   {"label": "LAMP", "value": 12.0, "ports": 2}, # nominal hot-filament resistance in ohms
	Kind.TRANSISTOR: {"label": "NPN", "value": 100.0, "ports": 3}, # approximate DC current gain (beta)
}

var chips: Array = []
var wires: Array = []
var next_id: int = 1

var chip_i: Dictionary = {}
var chip_v: Dictionary = {}
var wire_i: Dictionary = {}
var wire_v: Dictionary = {}
var ok: bool = true
var message: String = "Place BAT + parts, wire ports. Switch has 4 ports: in+/in− and out+/out−."
var total_power: float = 0.0
## Last solved capacitor terminal voltage, keyed by component id (volts).
var capacitor_voltage: Dictionary = {}
## Previous inductor branch current, keyed by component id (amperes).
var inductor_current: Dictionary = {}
## Normalized motor speed (0..1), keyed by component id.
var motor_speed: Dictionary = {}
## Normalized filament temperature (0=cold, 1=hot), keyed by lamp id.
var lamp_temperature: Dictionary = {}
## Last estimated base and collector currents for each transistor.
var transistor_base_current: Dictionary = {}
var transistor_collector_current: Dictionary = {}


func clear() -> void:
	chips.clear()
	wires.clear()
	next_id = 1
	chip_i.clear()
	chip_v.clear()
	wire_i.clear()
	wire_v.clear()
	capacitor_voltage.clear()
	inductor_current.clear()
	motor_speed.clear()
	lamp_temperature.clear()
	transistor_base_current.clear()
	transistor_collector_current.clear()
	ok = true
	message = "Board cleared."
	total_power = 0.0


func label_of(kind: int) -> String:
	return str(DEFS[kind]["label"])


func port_count(kind: int) -> int:
	return int(DEFS[kind]["ports"])


func port_id(chip_id: int, which: int) -> String:
	return "c%d_%d" % [chip_id, which]


## Port roles for SWITCH: 0=in+, 1=in−, 2=out+, 3=out−
## For 2-port chips: 0=+, 1=−
func port_is_positive(kind: int, which: int) -> bool:
	if kind == Kind.SWITCH:
		return which == 0 or which == 2
	return which == 0


func slot_free(sr: int, sc: int, ignore_id: int = -1) -> bool:
	if sr < 0 or sc < 0 or sr >= SLOTS or sc >= SLOTS:
		return false
	for c in chips:
		if int(c.id) == ignore_id:
			continue
		if int(c.slot_r) == sr and int(c.slot_c) == sc:
			return false
	return true


func add_chip(kind: int, slot_r: int, slot_c: int, value: float = -1.0) -> Dictionary:
	if not DEFS.has(kind):
		message = "Unknown component type."
		return {}
	if not slot_free(slot_r, slot_c):
		return {}
	var def: Dictionary = DEFS[kind]
	var ch := {
		"id": next_id,
		"kind": kind,
		"slot_r": slot_r,
		"slot_c": slot_c,
		"rot": 0,
		"value": float(def["value"]) if value < 0.0 else value,
		"closed": true,
		"lit": false,
		"wiper": 0.5,
		"blown": false,
	}
	next_id += 1
	chips.append(ch)
	if kind == Kind.CAP:
		capacitor_voltage[next_id - 1] = 0.0
	elif kind == Kind.IND:
		inductor_current[next_id - 1] = 0.0
	elif kind == Kind.MOTOR:
		motor_speed[next_id - 1] = 0.0
	elif kind == Kind.LAMP:
		lamp_temperature[next_id - 1] = 0.0
	elif kind == Kind.TRANSISTOR:
		transistor_base_current[next_id - 1] = 0.0
		transistor_collector_current[next_id - 1] = 0.0
	solve()
	return ch


func chip_has_wires(cid: int) -> bool:
	var prefix := "c%d_" % cid
	for w in wires:
		if str(w.port_a).begins_with(prefix) or str(w.port_b).begins_with(prefix):
			return true
	return false


func rotate_chip(cid: int, clockwise: bool) -> bool:
	var ch: Dictionary = chip_by_id(cid)
	if ch.is_empty() or chip_has_wires(cid):
		return false
	var r: int = int(ch.rot)
	ch.rot = (r + 1) % 4 if clockwise else (r + 3) % 4
	return true


func remove_chip(cid: int) -> void:
	for i in range(chips.size() - 1, -1, -1):
		if int(chips[i].id) == cid:
			chips.remove_at(i)
			break
	var prefix := "c%d_" % cid
	for i in range(wires.size() - 1, -1, -1):
		if str(wires[i].port_a).begins_with(prefix) or str(wires[i].port_b).begins_with(prefix):
			wires.remove_at(i)
	capacitor_voltage.erase(cid)
	inductor_current.erase(cid)
	motor_speed.erase(cid)
	lamp_temperature.erase(cid)
	transistor_base_current.erase(cid)
	transistor_collector_current.erase(cid)
	solve()


func chip_by_id(cid: int) -> Dictionary:
	for c in chips:
		if int(c.id) == cid:
			return c
	return {}


func wire_count_on_port(port: String) -> int:
	var n: int = 0
	for w in wires:
		if str(w.port_a) == port or str(w.port_b) == port:
			n += 1
	return n


func port_connection_count(port: String) -> int:
	var n: int = 0
	for w in wires:
		if str(w.port_a) == port or str(w.port_b) == port:
			n += 1
	return n


func port_can_accept_wire(port: String) -> bool:
	# Ports are electrical junctions, not single-use sockets. Four connections
	# are explicitly supported, and there is no artificial four-wire ceiling.
	return _port_exists(port)


func add_wire(port_a: String, port_b: String) -> Dictionary:
	if not _port_exists(port_a) or not _port_exists(port_b):
		message = "Invalid connection: choose two existing component ports."
		return {}
	if port_a == "" or port_b == "" or port_a == port_b:
		message = "Choose two different ports."
		return {}
	for w in wires:
		if (str(w.port_a) == port_a and str(w.port_b) == port_b) or (str(w.port_a) == port_b and str(w.port_b) == port_a):
			message = "Those ports are already directly connected."
			return {}
	if not port_can_accept_wire(port_a) or not port_can_accept_wire(port_b):
		message = "Invalid port connection. Choose two existing component ports."
		return {}
	var w2 := {"id": next_id, "port_a": port_a, "port_b": port_b}
	next_id += 1
	wires.append(w2)
	solve()
	return w2





func _port_exists(port: String) -> bool:
	var parts: PackedStringArray = port.split("_")
	if parts.size() != 2 or not parts[0].begins_with("c"):
		return false
	var cid_text: String = parts[0].substr(1)
	if not cid_text.is_valid_int() or not parts[1].is_valid_int():
		return false
	var ch: Dictionary = chip_by_id(int(cid_text))
	if ch.is_empty():
		return false
	var pi: int = int(parts[1])
	return pi >= 0 and pi < port_count(int(ch.kind))


func remove_wire(wid: int) -> void:
	for i in range(wires.size() - 1, -1, -1):
		if int(wires[i].id) == wid:
			wires.remove_at(i)
			break
	solve()


func set_switch_closed(cid: int, is_closed: bool) -> void:
	for i in range(chips.size()):
		if int(chips[i]["id"]) == cid and int(chips[i]["kind"]) == Kind.SWITCH:
			chips[i]["closed"] = is_closed
			break
	solve()


func _find(x: String, parent: Dictionary) -> String:
	var r: String = x
	while str(parent.get(r, r)) != r:
		r = str(parent[r])
	var cur: String = x
	while cur != r:
		var nxt: String = str(parent.get(cur, cur))
		parent[cur] = r
		cur = nxt
	return r


func _unite(a: String, b: String, parent: Dictionary) -> void:
	var ra := _find(a, parent)
	var rb := _find(b, parent)
	if ra != rb:
		parent[rb] = ra


func has_capacitor() -> bool:
	for c in chips:
		if int(c.kind) == Kind.CAP:
			return true
	return false


func has_inductor() -> bool:
	for c in chips:
		if int(c.kind) == Kind.IND:
			return true
	return false


func has_motor() -> bool:
	for c in chips:
		if int(c.kind) == Kind.MOTOR:
			return true
	return false


func has_lamp() -> bool:
	for c in chips:
		if int(c.kind) == Kind.LAMP:
			return true
	return false


func has_transient_component() -> bool:
	return has_capacitor() or has_inductor() or has_motor() or has_lamp()


func step(delta: float) -> void:
	# Advance transient state only on simulation ticks. Static UI edits call solve()
	# without a timestep, preserving capacitor voltage and inductor current.
	if delta <= 0.0 or not has_transient_component():
		return
	solve(clampf(delta, 0.0001, 0.1))


func solve(delta: float = 0.0) -> void:
	chip_i.clear()
	chip_v.clear()
	wire_i.clear()
	wire_v.clear()
	total_power = 0.0
	for c in chips:
		c["lit"] = false
		chip_i[int(c.id)] = 0.0
		chip_v[int(c.id)] = 0.0
	for w in wires:
		wire_i[int(w.id)] = 0.0
		wire_v[int(w.id)] = 0.0

	if chips.is_empty():
		ok = true
		message = "Place a battery and components, then connect the ports."
		return

	var battery: Dictionary = {}
	var battery_count := 0
	for c in chips:
		if int(c.kind) == Kind.BAT:
			battery_count += 1
			if battery.is_empty():
				battery = c
	if battery.is_empty():
		ok = false
		message = "Add a battery to power the circuit."
		return
	if battery_count > 1:
		ok = false
		message = "This DC solver supports one battery at a time. Remove extra batteries."
		return

	# Every terminal remains its own node. Wires and closed switches have small,
	# finite resistance so the solver can report meaningful branch currents.
	var nodes: Array = []
	var known: Dictionary = {}
	for c in chips:
		for pi in range(port_count(int(c.kind))):
			nodes.append(port_id(int(c.id), pi))
	var bat_pos := port_id(int(battery.id), 0)
	var bat_neg := port_id(int(battery.id), 1)
	var battery_v: float = clampf(float(battery.value), 0.0, 24.0)
	known[bat_pos] = battery_v
	known[bat_neg] = 0.0

	var edges: Array = []
	for w in wires:
		var a := str(w.port_a)
		var b := str(w.port_b)
		if not _port_exists(a) or not _port_exists(b):
			ok = false
			message = "Invalid wire endpoint detected. Remove and reconnect that wire."
			return
		edges.append({"type": "resistor", "na": a, "nb": b, "r": R_WIRE, "wid": int(w.id)})

	for c in chips:
		var cid := int(c.id)
		var kind := int(c.kind)
		if kind == Kind.BAT:
			continue
		if kind == Kind.SWITCH:
			if bool(c.get("closed", true)):
				edges.append({"type": "resistor", "na": port_id(cid, 0), "nb": port_id(cid, 2), "r": R_SW_ON, "cid": cid, "kind": kind, "leg": 0})
				edges.append({"type": "resistor", "na": port_id(cid, 1), "nb": port_id(cid, 3), "r": R_SW_ON, "cid": cid, "kind": kind, "leg": 1})
			continue
		var a := port_id(cid, 0)
		var b := port_id(cid, 1)
		match kind:
			Kind.R:
				edges.append({"type": "resistor", "na": a, "nb": b, "r": maxf(float(c.value), 0.1), "cid": cid, "kind": kind})
			Kind.LEDW:
				edges.append({"type": "diode", "na": a, "nb": b, "vf": 3.0, "rd": R_DIODE_ON, "cid": cid, "kind": kind})
			Kind.LEDO:
				edges.append({"type": "diode", "na": a, "nb": b, "vf": maxf(float(c.value), 1.6), "rd": R_DIODE_ON, "cid": cid, "kind": kind})
			Kind.DIODE:
				edges.append({"type": "diode", "na": a, "nb": b, "vf": 0.7, "rd": 2.0, "cid": cid, "kind": kind})
			Kind.CAP:
				edges.append({"type": "capacitor", "na": a, "nb": b, "cid": cid, "kind": kind, "c": maxf(float(c.value), 0.1) * 1.0e-6})
			Kind.IND:
				edges.append({"type": "inductor", "na": a, "nb": b, "cid": cid, "kind": kind, "l": maxf(float(c.value), 0.1) * 1.0e-3})
			Kind.FUSE:
				# A blown fuse is modeled as an open circuit; intact fuse has small series resistance.
				var fuse_r := R_OPEN if bool(c.get("blown", false)) else 0.1
				edges.append({"type": "resistor", "na": a, "nb": b, "r": fuse_r, "cid": cid, "kind": kind})
			Kind.MOTOR:
				edges.append({"type": "motor", "na": a, "nb": b, "r": clampf(float(c.value), 1.0, 100.0), "cid": cid, "kind": kind})
			Kind.LAMP:
				var nominal_r := clampf(float(c.value), 1.0, 100.0)
				var lamp_temp := clampf(float(lamp_temperature.get(cid, 0.0)), 0.0, 1.0)
				var filament_r := nominal_r * lerpf(0.12, 1.0, lamp_temp)
				edges.append({"type": "lamp", "na": a, "nb": b, "r": maxf(filament_r, 0.12), "cid": cid, "kind": kind})
			Kind.TRANSISTOR:
				# Educational NPN model: base-emitter junction plus beta-controlled collector current.
				var base := port_id(cid, 1)
				var emitter := port_id(cid, 2)
				edges.append({"type": "transistor_base", "na": base, "nb": emitter, "vf": 0.65, "rd": 25.0, "cid": cid, "kind": kind})
				edges.append({"type": "transistor_ce", "na": a, "nb": emitter, "base": base, "emitter": emitter, "beta": clampf(float(c.value), 20.0, 300.0), "cid": cid, "kind": kind})
			Kind.POT:
				# Three-terminal voltage divider: 0 and 1 are track ends; 2 is the wiper.
				var total_r := clampf(float(c.value), 100.0, 100000.0)
				var position := clampf(float(c.get("wiper", 0.5)), 0.0, 1.0)
				var low_r := maxf(total_r * position, 0.1)
				var high_r := maxf(total_r * (1.0 - position), 0.1)
				edges.append({"type": "resistor", "na": a, "nb": port_id(cid, 2), "r": low_r, "cid": cid, "kind": kind, "leg": 0})
				edges.append({"type": "resistor", "na": port_id(cid, 2), "nb": b, "r": high_r, "cid": cid, "kind": kind, "leg": 1})

	if battery_v <= 0.000001:
		if delta > 0.0:
			for c in chips:
				if int(c.kind) == Kind.MOTOR:
					var motor_id := int(c.id)
					motor_speed[motor_id] = move_toward(float(motor_speed.get(motor_id, 0.0)), 0.0, 0.75 * delta)
		ok = true
		message = "Battery is at 0 V — no current can flow."
		return

	var unknown: Array = []
	var index: Dictionary = {}
	for node in nodes:
		var n := str(node)
		if known.has(n):
			continue
		index[n] = unknown.size()
		unknown.append(n)

	# A tiny leakage conductance prevents floating, disconnected subcircuits from
	# making the nodal matrix singular. It is many orders smaller than real paths.
	var voltage: Dictionary = {}
	for key in known.keys():
		voltage[str(key)] = float(known[key])
	for n in unknown:
		voltage[str(n)] = 0.0

	var converged := false
	for iteration in range(MAX_NEWTON_ITERATIONS):
		var n_unknown := unknown.size()
		var matrix: Array = []
		var rhs: Array = []
		for i in range(n_unknown):
			var row: Array = []
			for j in range(n_unknown):
				row.append(0.0)
			row[i] = 1.0e-12
			matrix.append(row)
			rhs.append(0.0)

		for edge in edges:
			var na := str(edge.na)
			var nb := str(edge.nb)
			var va := float(voltage.get(na, 0.0))
			var vb := float(voltage.get(nb, 0.0))
			var dv := va - vb
			var conductance: float
			var equivalent_current := 0.0
			if str(edge.type) == "transistor_ce":
				# A controlled current source couples base-emitter drive to collector current.
				var vbe := float(voltage.get(str(edge.base), 0.0)) - float(voltage.get(str(edge.emitter), 0.0))
				var vce := float(voltage.get(na, 0.0)) - float(voltage.get(str(edge.emitter), 0.0))
				var ibase := maxf((vbe - 0.65) / 25.0, 0.0)
				var active_current := minf(ibase * float(edge.beta), 2.0)
				var saturation_current := maxf((vce - 0.1) / 0.5, 0.0)
				if saturation_current < active_current:
					# Saturation branch: I_C ≈ (V_CE - 0.1 V) / 0.5 Ω.
					conductance = 2.0
					equivalent_current = -0.2
				else:
					conductance = 1.0e-12
					equivalent_current = active_current
			elif str(edge.type) == "diode" or str(edge.type) == "transistor_base":
				var vf := float(edge.vf)
				var rd := maxf(float(edge.rd), 0.1)
				var diode_current := 0.0
				if dv >= vf:
					conductance = 1.0 / rd
					diode_current = (dv - vf) / rd
				elif dv <= -V_DIODE_BREAKDOWN:
					# Approximate reverse breakdown; current remains small until the
					# breakdown knee, then rises with a finite dynamic resistance.
					conductance = 1.0 / 100.0
					diode_current = (dv + V_DIODE_BREAKDOWN) * conductance
				else:
					conductance = G_DIODE_OFF
					diode_current = dv * G_DIODE_OFF
				equivalent_current = diode_current - conductance * dv
			elif str(edge.type) == "capacitor":
				if delta > 0.0:
					# Backward-Euler companion model: I = C/dt * (V - V_previous).
					conductance = float(edge.c) / maxf(delta, 0.0001)
					var prev_v := float(capacitor_voltage.get(int(edge.cid), 0.0))
					equivalent_current = -conductance * prev_v
				else:
					# At a static edit/solve, a capacitor is open circuit at DC.
					conductance = 1.0e-12
			elif str(edge.type) == "inductor":
				if delta > 0.0:
					# Backward-Euler RL companion: L*di/dt + Rcoil*i = v.
					var inductance := float(edge.l)
					var dt := maxf(delta, 0.0001)
					conductance = 1.0 / (R_INDUCTOR_COIL + inductance / dt)
					var old_i := float(inductor_current.get(int(edge.cid), 0.0))
					equivalent_current = -old_i * (inductance / dt) * conductance
				else:
					# At DC the inductor approaches a short, limited by winding resistance.
					conductance = 1.0 / R_INDUCTOR_COIL
			elif str(edge.type) == "lamp":
				conductance = 1.0 / maxf(float(edge.r), 0.12)
			elif str(edge.type) == "motor":
				conductance = 1.0 / maxf(float(edge.r), 1.0)
				var speed_fraction := clampf(float(motor_speed.get(int(edge.cid), 0.0)), 0.0, 1.0)
				var back_emf := 6.0 * speed_fraction * signf(dv)
				equivalent_current = -conductance * back_emf
			else:
				conductance = 1.0 / maxf(float(edge.r), 1.0e-9)
			_stamp_nodal(matrix, rhs, index, voltage, na, nb, conductance, equivalent_current)

		var solution := _gauss(matrix, rhs) if n_unknown > 0 else []
		if n_unknown > 0 and solution.size() != n_unknown:
			ok = false
			message = "Circuit solver could not converge: check for invalid or conflicting connections."
			return
		var max_delta := 0.0
		for i in range(unknown.size()):
			var node := str(unknown[i])
			var next_v := float(solution[i])
			max_delta = maxf(max_delta, absf(next_v - float(voltage[node])))
			# Damping stabilizes diode state changes around the forward knee.
			voltage[node] = lerpf(float(voltage[node]), next_v, 0.75)
		if max_delta < SOLVER_TOLERANCE:
			converged = true
			break

	if not converged and unknown.size() > 0:
		ok = false
		message = "Circuit solver did not converge. Check for shorts or extreme component values."
		return

	# Record component terminal voltages and signed branch currents (positive from
	# port 0 to port 1; switch current is the larger absolute leg current).
	var switch_currents: Dictionary = {}
	var battery_current := 0.0
	for edge in edges:
		var na := str(edge.na)
		var nb := str(edge.nb)
		var dv := float(voltage.get(na, 0.0)) - float(voltage.get(nb, 0.0))
		var current: float
		if str(edge.type) == "transistor_ce":
			var vbe_final := float(voltage.get(str(edge.base), 0.0)) - float(voltage.get(str(edge.emitter), 0.0))
			var vce_final := float(voltage.get(na, 0.0)) - float(voltage.get(str(edge.emitter), 0.0))
			var ibase_final := maxf((vbe_final - 0.65) / 25.0, 0.0)
			current = minf(minf(ibase_final * float(edge.beta), 2.0), maxf((vce_final - 0.1) / 0.5, 0.0))
			transistor_base_current[int(edge.cid)] = ibase_final
			transistor_collector_current[int(edge.cid)] = current
		elif str(edge.type) == "diode" or str(edge.type) == "transistor_base":
			current = _diode_current(dv, float(edge.vf), float(edge.rd))
		elif str(edge.type) == "capacitor":
			var previous_v := float(capacitor_voltage.get(int(edge.cid), 0.0))
			current = float(edge.c) / maxf(delta, 0.0001) * (dv - previous_v) if delta > 0.0 else 0.0
			if delta > 0.0:
				capacitor_voltage[int(edge.cid)] = dv
		elif str(edge.type) == "inductor":
			if delta > 0.0:
				var inductance2 := float(edge.l)
				var dt2 := maxf(delta, 0.0001)
				var old_i2 := float(inductor_current.get(int(edge.cid), 0.0))
				current = (dv + (inductance2 / dt2) * old_i2) / (R_INDUCTOR_COIL + inductance2 / dt2)
				inductor_current[int(edge.cid)] = current
			else:
				current = dv / R_INDUCTOR_COIL
		elif str(edge.type) == "lamp":
			current = dv / maxf(float(edge.r), 0.12)
		elif str(edge.type) == "motor":
			var speed_fraction2 := clampf(float(motor_speed.get(int(edge.cid), 0.0)), 0.0, 1.0)
			var back_emf2 := 6.0 * speed_fraction2 * signf(dv)
			current = (dv - back_emf2) / maxf(float(edge.r), 1.0)
		else:
			current = dv / maxf(float(edge.r), 1.0e-9)
		if edge.has("wid"):
			wire_i[int(edge.wid)] = absf(current)
			wire_v[int(edge.wid)] = dv
		if edge.has("cid"):
			var cid := int(edge.cid)
			var kind := int(edge.kind)
			if kind == Kind.TRANSISTOR:
				if str(edge.type) == "transistor_ce":
					chip_i[cid] = current
					chip_v[cid] = dv
				elif str(edge.type) == "transistor_base":
					transistor_base_current[cid] = current
					chip_v[cid] = maxf(absf(float(chip_v.get(cid, 0.0))), absf(dv))
			elif kind == Kind.POT:
				chip_i[cid] = maxf(absf(float(chip_i.get(cid, 0.0))), absf(current))
				chip_v[cid] = maxf(absf(float(chip_v.get(cid, 0.0))), absf(dv))
			elif kind == Kind.SWITCH:
				var old := float(switch_currents.get(cid, 0.0))
				switch_currents[cid] = maxf(old, absf(current))
				chip_v[cid] = maxf(float(chip_v.get(cid, 0.0)), absf(dv))
			else:
				chip_i[cid] = current
				chip_v[cid] = dv
				if kind == Kind.LEDW or kind == Kind.LEDO:
					var chip := chip_by_id(cid)
					if not chip.is_empty():
						chip["lit"] = current >= I_ON and dv > 0.0
		if na == bat_pos:
			battery_current += current
		elif nb == bat_pos:
			battery_current -= current

	# Simplified DC motor dynamics: armature current produces acceleration,
	# back-EMF rises with speed, and the rotor coasts down when current disappears.
	if delta > 0.0:
		for c in chips:
			if int(c.kind) != Kind.MOTOR:
				continue
			var motor_id := int(c.id)
			var old_speed := clampf(float(motor_speed.get(motor_id, 0.0)), 0.0, 1.0)
			var motor_i := absf(float(chip_i.get(motor_id, 0.0)))
			var motor_v := absf(float(chip_v.get(motor_id, 0.0)))
			var target_speed := clampf(motor_v / 6.0, 0.0, 1.0) if motor_i > 0.001 else 0.0
			var response_rate := 1.4 if target_speed > old_speed else 0.75
			motor_speed[motor_id] = move_toward(old_speed, target_speed, response_rate * delta)

	# Educational incandescent-lamp thermal response. Filament temperature rises
	# with electrical power and cools gradually after power is removed.
	if delta > 0.0:
		for c in chips:
			if int(c.kind) != Kind.LAMP:
				continue
			var lamp_id := int(c.id)
			var old_temp := clampf(float(lamp_temperature.get(lamp_id, 0.0)), 0.0, 1.0)
			var lamp_i := absf(float(chip_i.get(lamp_id, 0.0)))
			var lamp_v := absf(float(chip_v.get(lamp_id, 0.0)))
			var lamp_power := lamp_i * lamp_v
			var target_temp := clampf(lamp_power / 6.0, 0.0, 1.0)
			var thermal_rate := 2.8 if target_temp > old_temp else 0.65
			lamp_temperature[lamp_id] = move_toward(old_temp, target_temp, thermal_rate * delta)
			var lamp := chip_by_id(lamp_id)
			if not lamp.is_empty():
				lamp["lit"] = float(lamp_temperature[lamp_id]) > 0.08

	# One-shot educational fuse behavior: if the steady branch current exceeds
	# the selected current rating, latch the fuse open and re-solve the circuit.
	var fuse_tripped := false
	for c in chips:
		if int(c.kind) != Kind.FUSE or bool(c.get("blown", false)):
			continue
		var fuse_id := int(c.id)
		if absf(float(chip_i.get(fuse_id, 0.0))) > maxf(float(c.value), 0.01):
			c["blown"] = true
			fuse_tripped = true
	if fuse_tripped:
		solve(0.0)
		return

	for cid in switch_currents.keys():
		chip_i[int(cid)] = float(switch_currents[cid])
	chip_i[int(battery.id)] = battery_current
	chip_v[int(battery.id)] = battery_v
	total_power = absf(battery_v * battery_current)
	ok = true
	var lit_count := 0
	for c in chips:
		if bool(c.get("lit", false)):
			lit_count += 1
	var blown_count := 0
	for c in chips:
		if int(c.kind) == Kind.FUSE and bool(c.get("blown", false)):
			blown_count += 1	
	if blown_count > 0:
		message = "%d fuse(s) blown — replace/reset the fuse and check for overcurrent." % blown_count
		return
	var current_magnitude := absf(battery_current)
	if current_magnitude < I_LIVE:
		message = "No significant current — check the return path, switch, and diode polarity."
	else:
		var motor_count := 0
		for c in chips:
			if int(c.kind) == Kind.MOTOR and float(motor_speed.get(int(c.id), 0.0)) > 0.02:
				motor_count += 1
		message = "DC solution: Ibat=%.3f A · %d LED(s) lit · %d motor(s) running · P=%.3f W" % [battery_current, lit_count, motor_count, total_power]


func _stamp_nodal(matrix: Array, rhs: Array, index: Dictionary, voltage: Dictionary, na: String, nb: String, g: float, ieq: float) -> void:
	var a_unknown: bool = index.has(na)
	var b_unknown: bool = index.has(nb)
	if a_unknown:
		var ia := int(index[na])
		matrix[ia][ia] = float(matrix[ia][ia]) + g
		if b_unknown:
			var ib := int(index[nb])
			matrix[ia][ib] = float(matrix[ia][ib]) - g
		else:
			rhs[ia] = float(rhs[ia]) + g * float(voltage.get(nb, 0.0))
		rhs[ia] = float(rhs[ia]) - ieq
	if b_unknown:
		var ib2 := int(index[nb])
		matrix[ib2][ib2] = float(matrix[ib2][ib2]) + g
		if a_unknown:
			var ia2 := int(index[na])
			matrix[ib2][ia2] = float(matrix[ib2][ia2]) - g
		else:
			rhs[ib2] = float(rhs[ib2]) + g * float(voltage.get(na, 0.0))
		rhs[ib2] = float(rhs[ib2]) + ieq


func _diode_current(vd: float, vf: float, rd: float) -> float:
	if vd >= vf:
		return (vd - vf) / maxf(rd, 0.1)
	if vd <= -V_DIODE_BREAKDOWN:
		return (vd + V_DIODE_BREAKDOWN) / 100.0
	return vd * G_DIODE_OFF


func _gauss(G: Array, rhs: Array) -> Array:
	var n: int = rhs.size()
	if n == 0:
		return []
	var A: Array = []
	for i in range(n):
		var row: Array = []
		for j in range(n):
			row.append(float(G[i][j]))
		row.append(float(rhs[i]))
		A.append(row)
	for col in range(n):
		var piv: int = col
		var best: float = absf(float(A[col][col]))
		for r in range(col + 1, n):
			var v: float = absf(float(A[r][col]))
			if v > best:
				best = v
				piv = r
		if best < 1e-14:
			return []
		if piv != col:
			var tmp = A[col]
			A[col] = A[piv]
			A[piv] = tmp
		var div: float = float(A[col][col])
		for j in range(col, n + 1):
			A[col][j] = float(A[col][j]) / div
		for r in range(n):
			if r == col:
				continue
			var f: float = float(A[r][col])
			if absf(f) < 1e-18:
				continue
			for j in range(col, n + 1):
				A[r][j] = float(A[r][j]) - f * float(A[col][j])
	var x: Array = []
	for i in range(n):
		x.append(float(A[i][n]))
	return x
