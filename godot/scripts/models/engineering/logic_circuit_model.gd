extends RefCounted
class_name LogicCircuitModel

signal changed

enum SignalState { UNKNOWN = -1, LOW = 0, HIGH = 1, ERROR = 2 }

const INPUT := "INPUT"
const OUTPUT := "OUTPUT"
const UNKNOWN := -1
const LOW := 0
const HIGH := 1
const ERROR := 2
const MAX_TRUTH_TABLE_INPUTS := 8
const GATES := {
	"AND": {"inputs": 2, "symbol": "∧", "description": "HIGH only when both inputs are HIGH."},
	"OR": {"inputs": 2, "symbol": "∨", "description": "HIGH when either input is HIGH."},
	"NOT": {"inputs": 1, "symbol": "¬", "description": "Inverts its single input."},
	"NAND": {"inputs": 2, "symbol": "NAND", "description": "Inverts the AND result."},
	"NOR": {"inputs": 2, "symbol": "NOR", "description": "Inverts the OR result."},
	"XOR": {"inputs": 2, "symbol": "⊕", "description": "HIGH when the inputs differ."},
	"XNOR": {"inputs": 2, "symbol": "XNOR", "description": "HIGH when the inputs are equal."}
}

var _components: Array[Dictionary] = []
var _connections: Array[Dictionary] = []
var _next_id: int = 1

func supported_kinds() -> Array[String]:
	var result: Array[String] = [INPUT]
	for gate_kind in GATES:
		result.append(str(gate_kind))
	result.append(OUTPUT)
	return result


func input_count(kind: String) -> int:
	if kind == OUTPUT:
		return 1
	if GATES.has(kind):
		return int(GATES[kind]["inputs"])
	return 0


func has_output(kind: String) -> bool:
	return kind == INPUT or GATES.has(kind)


func add_component(kind: String, position: Vector2, label: String = "") -> int:
	if not supported_kinds().has(kind):
		return -1
	var component_id := _next_id
	_next_id += 1
	var actual_label := label.strip_edges()
	if actual_label.is_empty():
		actual_label = _default_label(kind)
	_components.append({
		"id": component_id,
		"kind": kind,
		"position": position,
		"label": actual_label,
		"value": false
	})
	changed.emit()
	return component_id


func component(component_id: int) -> Dictionary:
	var index := _component_index(component_id)
	return _components[index].duplicate(true) if index >= 0 else {}


func components() -> Array[Dictionary]:
	return _components.duplicate(true)


func connections() -> Array[Dictionary]:
	return _connections.duplicate(true)


func set_component_position(component_id: int, position: Vector2) -> bool:
	var index := _component_index(component_id)
	if index < 0:
		return false
	_components[index]["position"] = position
	changed.emit()
	return true


func set_component_label(component_id: int, label: String) -> bool:
	var index := _component_index(component_id)
	var cleaned := label.strip_edges()
	if index < 0 or cleaned.is_empty():
		return false
	_components[index]["label"] = cleaned
	changed.emit()
	return true


func set_input(component_id: int, value: bool) -> bool:
	var index := _component_index(component_id)
	if index < 0 or str(_components[index]["kind"]) != INPUT:
		return false
	_components[index]["value"] = value
	changed.emit()
	return true


func toggle_input(component_id: int) -> bool:
	var item := component(component_id)
	if item.is_empty() or str(item["kind"]) != INPUT:
		return false
	return set_input(component_id, not bool(item["value"]))


func connect_components(source_id: int, target_id: int, input_index: int) -> Dictionary:
	var source := component(source_id)
	var target := component(target_id)
	if source.is_empty() or target.is_empty():
		return _failure("Connection rejected: a component reference is no longer valid.")
	if source_id == target_id:
		return _failure("Connection rejected: a component cannot connect to itself.")
	if not has_output(str(source["kind"])):
		return _failure("Connection rejected: choose an input switch or gate output as the source.")
	var port_count := input_count(str(target["kind"]))
	if input_index < 0 or input_index >= port_count:
		return _failure("Connection rejected: the destination input port does not exist.")
	for wire in _connections:
		if int(wire["to"]) == target_id and int(wire["input"]) == input_index and int(wire["from"]) == source_id:
			return _failure("That exact connection already exists.")
	if _would_create_cycle(source_id, target_id):
		return _failure("Connection rejected: this would create a combinational feedback cycle.")
	var replaced := false
	for i in range(_connections.size() - 1, -1, -1):
		if int(_connections[i]["to"]) == target_id and int(_connections[i]["input"]) == input_index:
			_connections.remove_at(i)
			replaced = true
	_connections.append({"from": source_id, "to": target_id, "input": input_index})
	changed.emit()
	var port_name := "Y" if str(target["kind"]) == OUTPUT else ("A" if input_index == 0 else "B")
	var message := "Connected %s to %s input %s." % [str(source["label"]), str(target["label"]), port_name]
	if replaced:
		message = "Replaced the existing driver on %s input %s." % [str(target["label"]), port_name]
	return {"ok": true, "message": message, "replaced": replaced}


func remove_connection(connection_index: int) -> bool:
	if connection_index < 0 or connection_index >= _connections.size():
		return false
	_connections.remove_at(connection_index)
	changed.emit()
	return true


func remove_component(component_id: int) -> bool:
	var index := _component_index(component_id)
	if index < 0:
		return false
	_components.remove_at(index)
	for i in range(_connections.size() - 1, -1, -1):
		if int(_connections[i]["from"]) == component_id or int(_connections[i]["to"]) == component_id:
			_connections.remove_at(i)
	changed.emit()
	return true


func clear() -> void:
	_components.clear()
	_connections.clear()
	_next_id = 1
	changed.emit()


func reset_to_starter() -> void:
	clear()
	var input_a := add_component(INPUT, Vector2(100.0, 100.0), "A")
	var input_b := add_component(INPUT, Vector2(100.0, 300.0), "B")
	var gate := add_component("AND", Vector2(400.0, 200.0), "G1")
	var output_y := add_component(OUTPUT, Vector2(720.0, 200.0), "Y")
	connect_components(input_a, gate, 0)
	connect_components(input_b, gate, 1)
	connect_components(gate, output_y, 0)


func load_half_adder() -> void:
	clear()
	var input_a := add_component(INPUT, Vector2(90.0, 100.0), "A")
	var input_b := add_component(INPUT, Vector2(90.0, 330.0), "B")
	var xor_gate := add_component("XOR", Vector2(420.0, 90.0), "SUM")
	var and_gate := add_component("AND", Vector2(420.0, 350.0), "CARRY")
	var sum_output := add_component(OUTPUT, Vector2(760.0, 90.0), "SUM")
	var carry_output := add_component(OUTPUT, Vector2(760.0, 350.0), "CARRY")
	connect_components(input_a, xor_gate, 0)
	connect_components(input_b, xor_gate, 1)
	connect_components(input_a, and_gate, 0)
	connect_components(input_b, and_gate, 1)
	connect_components(xor_gate, sum_output, 0)
	connect_components(and_gate, carry_output, 0)


func evaluate() -> Dictionary:
	var by_id: Dictionary = {}
	var incoming: Dictionary = {}
	var errors: Array[String] = []
	var warnings: Array[String] = []
	for item in _components:
		by_id[int(item["id"])] = item
	for wire in _connections:
		var source_id := int(wire["from"])
		var target_id := int(wire["to"])
		var input_index := int(wire["input"])
		if not by_id.has(source_id) or not by_id.has(target_id):
			_append_unique(errors, "A connection points to a missing component.")
			continue
		var key := _port_key(target_id, input_index)
		if incoming.has(key):
			_append_unique(errors, "Input %s has more than one driver." % key)
		else:
			incoming[key] = source_id
	var values: Dictionary = {}
	var visiting: Dictionary = {}
	for item in _components:
		_evaluate_component(int(item["id"]), by_id, incoming, values, visiting, errors, warnings)
	var complete := true
	for value in values.values():
		if int(value) == UNKNOWN or int(value) == ERROR:
			complete = false
	return {
		"valid": errors.is_empty(),
		"complete": complete and warnings.is_empty(),
		"values": values,
		"errors": errors,
		"warnings": warnings
	}


func _evaluate_component(component_id: int, by_id: Dictionary, incoming: Dictionary, values: Dictionary, visiting: Dictionary, errors: Array[String], warnings: Array[String]) -> int:
	if values.has(component_id):
		return int(values[component_id])
	if visiting.has(component_id):
		_append_unique(errors, "Cycle detected while evaluating component %s." % component_id)
		return ERROR
	if not by_id.has(component_id):
		_append_unique(errors, "Cannot evaluate a missing component.")
		return ERROR
	visiting[component_id] = true
	var item: Dictionary = by_id[component_id]
	var kind := str(item["kind"])
	var result := UNKNOWN
	if kind == INPUT:
		result = HIGH if bool(item["value"]) else LOW
	elif kind == OUTPUT or GATES.has(kind):
		var input_values: Array[int] = []
		for port in range(input_count(kind)):
			var key := _port_key(component_id, port)
			if not incoming.has(key):
				_append_unique(warnings, "%s input %s is unconnected." % [str(item["label"]), _port_name(kind, port)])
				input_values.append(UNKNOWN)
				continue
			var source_id := int(incoming[key])
			input_values.append(_evaluate_component(source_id, by_id, incoming, values, visiting, errors, warnings))
		if kind == OUTPUT:
			result = input_values[0] if not input_values.is_empty() else UNKNOWN
		else:
			result = _evaluate_gate(kind, input_values)
	visiting.erase(component_id)
	values[component_id] = result
	return result


func _evaluate_gate(kind: String, inputs: Array[int]) -> int:
	if inputs.size() != input_count(kind):
		return ERROR
	for state in inputs:
		if state == ERROR:
			return ERROR
		if state == UNKNOWN:
			return UNKNOWN
	var a := inputs[0] == HIGH
	var b := inputs[1] == HIGH if inputs.size() > 1 else false
	var high := false
	match kind:
		"AND": high = a and b
		"OR": high = a or b
		"NOT": high = not a
		"NAND": high = not (a and b)
		"NOR": high = not (a or b)
		"XOR": high = a != b
		"XNOR": high = a == b
		_:
			return ERROR
	return HIGH if high else LOW


func generate_truth_table(max_inputs: int = MAX_TRUTH_TABLE_INPUTS) -> Dictionary:
	var inputs: Array[Dictionary] = []
	var outputs: Array[Dictionary] = []
	for item in _components:
		if str(item["kind"]) == INPUT:
			inputs.append(item.duplicate(true))
		elif str(item["kind"]) == OUTPUT:
			outputs.append(item.duplicate(true))
	if inputs.is_empty() or outputs.is_empty():
		return _failure("Add at least one input switch and one output indicator before generating a truth table.")
	if inputs.size() > max_inputs:
		return _failure("Truth table limit is %d independent inputs (%d rows)." % [max_inputs, 1 << max_inputs])
	var before := evaluate()
	if not bool(before["valid"]):
		return _failure("Truth table unavailable: the circuit contains an invalid dependency or cycle.")
	if not bool(before["complete"]):
		return _failure("Truth table unavailable: connect every gate input and output path first.")
	var saved: Dictionary = {}
	for input_component in inputs:
		saved[int(input_component["id"])] = bool(input_component["value"])
	var rows: Array[Dictionary] = []
	for mask in range(1 << inputs.size()):
		for index in range(inputs.size()):
			var component_index := _component_index(int(inputs[index]["id"]))
			_components[component_index]["value"] = (mask & (1 << (inputs.size() - 1 - index))) != 0
		var row_result := evaluate()
		if not bool(row_result["valid"]) or not bool(row_result["complete"]):
			rows.clear()
			break
		var row_inputs: Array[int] = []
		var row_outputs: Array[int] = []
		for input_component in inputs:
			row_inputs.append(HIGH if bool(_components[_component_index(int(input_component["id"]))]["value"]) else LOW)
		for output_component in outputs:
			row_outputs.append(int(row_result["values"].get(int(output_component["id"]), UNKNOWN)))
		rows.append({"inputs": row_inputs, "outputs": row_outputs})
	for input_component in inputs:
		_components[_component_index(int(input_component["id"]))]["value"] = bool(saved[int(input_component["id"])])
	if rows.is_empty():
		return _failure("Truth table unavailable: the circuit could not be evaluated for every input combination.")
	return {"ok": true, "inputs": inputs, "outputs": outputs, "rows": rows}


func boolean_expression(component_id: int) -> String:
	var incoming: Dictionary = {}
	for wire in _connections:
		incoming[_port_key(int(wire["to"]), int(wire["input"]))] = int(wire["from"])
	var visiting: Dictionary = {}
	return _expression_for(component_id, incoming, visiting)


func _expression_for(component_id: int, incoming: Dictionary, visiting: Dictionary) -> String:
	if visiting.has(component_id):
		return "CYCLE"
	var item := component(component_id)
	if item.is_empty():
		return "?"
	var kind := str(item["kind"])
	if kind == INPUT:
		return str(item["label"])
	visiting[component_id] = true
	var parts: Array[String] = []
	for port in range(input_count(kind)):
		var key := _port_key(component_id, port)
		parts.append(_expression_for(int(incoming[key]), incoming, visiting) if incoming.has(key) else "?")
	visiting.erase(component_id)
	if kind == OUTPUT:
		return str(item["label"]) + " = " + (parts[0] if not parts.is_empty() else "?")
	if kind == "NOT":
		return "¬(" + parts[0] + ")"
	var op := "∧"
	match kind:
		"OR": op = "∨"
		"NAND": op = "NAND"
		"NOR": op = "NOR"
		"XOR": op = "⊕"
		"XNOR": op = "XNOR"
	return "(" + parts[0] + " " + op + " " + parts[1] + ")"


func signal_text(state: int) -> String:
	match state:
		LOW: return "LOW · 0"
		HIGH: return "HIGH · 1"
		ERROR: return "ERROR"
		_: return "UNCONNECTED · ?"


func gate_description(kind: String) -> String:
	return str(GATES.get(kind, {}).get("description", ""))


func input_state(component_id: int, port: int, evaluation: Dictionary) -> int:
	for wire in _connections:
		if int(wire["to"]) == component_id and int(wire["input"]) == port:
			return int(evaluation.get("values", {}).get(int(wire["from"]), UNKNOWN))
	return UNKNOWN


func _default_label(kind: String) -> String:
	var count := 0
	for item in _components:
		if str(item["kind"]) == kind:
			count += 1
	if kind == INPUT:
		return String.chr(65 + count) if count < 26 else "IN%d" % (count + 1)
	if kind == OUTPUT:
		return "Y" if count == 0 else "Y%d" % (count + 1)
	return "%s%d" % [kind, count + 1]


func _component_index(component_id: int) -> int:
	for index in range(_components.size()):
		if int(_components[index]["id"]) == component_id:
			return index
	return -1


func _would_create_cycle(source_id: int, target_id: int) -> bool:
	var pending: Array[int] = [target_id]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current: int = pending.pop_back()
		if current == source_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		for wire in _connections:
			if int(wire["from"]) == current:
				pending.append(int(wire["to"]))
	return false


func _port_key(component_id: int, port: int) -> String:
	return "%d:%d" % [component_id, port]


func _port_name(kind: String, port: int) -> String:
	if kind == OUTPUT:
		return "Y"
	return "A" if port == 0 else "B"


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}


func _append_unique(list: Array[String], message: String) -> void:
	if not list.has(message):
		list.append(message)
