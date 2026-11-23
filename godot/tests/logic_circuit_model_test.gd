extends SceneTree

const Model = preload("res://scripts/models/engineering/logic_circuit_model.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_all_gate_truth_tables()
	_test_multi_gate_and_outputs()
	_test_unknown_inputs_and_truth_table_block()
	_test_connection_rules_and_cycle_rejection()
	_test_replacement_and_duplicate_rules()
	_test_component_deletion_cleanup()
	_test_truth_table_order_and_input_restore()
	_test_starter_and_reset()
	_test_default_labels()
	if failures.is_empty():
		print("PASS: LogicCircuitModel regression suite")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_all_gate_truth_tables() -> void:
	var expected := {
		"AND": [0, 0, 0, 1],
		"OR": [0, 1, 1, 1],
		"NAND": [1, 1, 1, 0],
		"NOR": [1, 0, 0, 0],
		"XOR": [0, 1, 1, 0],
		"XNOR": [1, 0, 0, 1]
	}
	for gate_kind in expected:
		for row in range(4):
			var model = Model.new()
			var a: int = model.add_component("INPUT", Vector2.ZERO, "A")
			var b: int = model.add_component("INPUT", Vector2.ZERO, "B")
			var gate: int = model.add_component(str(gate_kind), Vector2.ZERO, "G")
			var output: int = model.add_component("OUTPUT", Vector2.ZERO, "Y")
			model.connect_components(a, gate, 0)
			model.connect_components(b, gate, 1)
			model.connect_components(gate, output, 0)
			model.set_input(a, (row & 2) != 0)
			model.set_input(b, (row & 1) != 0)
			var result: Dictionary = model.evaluate()
			_expect(bool(result["valid"]) and bool(result["complete"]), "%s row %d should evaluate completely" % [str(gate_kind), row])
			_expect(int(result["values"][output]) == int(expected[gate_kind][row]), "%s row %d returned the wrong Boolean value" % [str(gate_kind), row])
	for value in [false, true]:
		var model = Model.new()
		var source: int = model.add_component("INPUT", Vector2.ZERO, "A")
		var inverter: int = model.add_component("NOT", Vector2.ZERO, "N1")
		var output: int = model.add_component("OUTPUT", Vector2.ZERO, "Y")
		model.connect_components(source, inverter, 0)
		model.connect_components(inverter, output, 0)
		model.set_input(source, value)
		var result: Dictionary = model.evaluate()
		_expect(int(result["values"][output]) == (0 if value else 1), "NOT gate returned the wrong Boolean value")


func _test_multi_gate_and_outputs() -> void:
	var model = Model.new()
	var a: int = model.add_component("INPUT", Vector2.ZERO, "A")
	var b: int = model.add_component("INPUT", Vector2.ZERO, "B")
	var xor_gate: int = model.add_component("XOR", Vector2.ZERO, "SUM")
	var and_gate: int = model.add_component("AND", Vector2.ZERO, "CARRY")
	var sum_output: int = model.add_component("OUTPUT", Vector2.ZERO, "S")
	var carry_output: int = model.add_component("OUTPUT", Vector2.ZERO, "C")
	for result in [model.connect_components(a, xor_gate, 0), model.connect_components(b, xor_gate, 1), model.connect_components(a, and_gate, 0), model.connect_components(b, and_gate, 1), model.connect_components(xor_gate, sum_output, 0), model.connect_components(and_gate, carry_output, 0)]:
		_expect(bool(result["ok"]), "Half-adder topology should connect successfully")
	model.set_input(a, true)
	model.set_input(b, true)
	var evaluation: Dictionary = model.evaluate()
	_expect(int(evaluation["values"][sum_output]) == 0, "Half-adder sum should be LOW for 1+1")
	_expect(int(evaluation["values"][carry_output]) == 1, "Half-adder carry should be HIGH for 1+1")


func _test_unknown_inputs_and_truth_table_block() -> void:
	var model = Model.new()
	var a: int = model.add_component("INPUT", Vector2.ZERO, "A")
	var gate: int = model.add_component("AND", Vector2.ZERO, "G1")
	var output: int = model.add_component("OUTPUT", Vector2.ZERO, "Y")
	model.connect_components(a, gate, 0)
	model.connect_components(gate, output, 0)
	var evaluation: Dictionary = model.evaluate()
	_expect(int(evaluation["values"][gate]) == Model.UNKNOWN, "An unconnected gate input must remain UNKNOWN")
	_expect(int(evaluation["values"][output]) == Model.UNKNOWN, "UNKNOWN must propagate to the output")
	_expect(not bool(evaluation["complete"]), "An incomplete circuit must not be marked complete")
	_expect(not bool(model.generate_truth_table()["ok"]), "An incomplete circuit must not produce a truth table")


func _test_connection_rules_and_cycle_rejection() -> void:
	var model = Model.new()
	var source: int = model.add_component("INPUT", Vector2.ZERO, "A")
	var gate_a: int = model.add_component("AND", Vector2.ZERO, "G1")
	var gate_b: int = model.add_component("OR", Vector2.ZERO, "G2")
	var output: int = model.add_component("OUTPUT", Vector2.ZERO, "Y")
	_expect(bool(model.connect_components(source, gate_a, 0)["ok"]), "Valid output-to-input wire should be accepted")
	_expect(not bool(model.connect_components(output, gate_a, 1)["ok"]), "Output indicator cannot drive a gate")
	_expect(not bool(model.connect_components(gate_a, gate_a, 0)["ok"]), "Self connection must be rejected")
	_expect(not bool(model.connect_components(source, gate_a, 2)["ok"]), "Invalid input index must be rejected")
	model.connect_components(gate_a, gate_b, 0)
	_expect(not bool(model.connect_components(gate_b, gate_a, 1)["ok"]), "Feedback cycle must be rejected")
	model.connect_components(gate_b, output, 0)
	var evaluation: Dictionary = model.evaluate()
	_expect(bool(evaluation["valid"]), "Rejected cycles must leave a valid acyclic graph")


func _test_replacement_and_duplicate_rules() -> void:
	var model = Model.new()
	var a: int = model.add_component("INPUT", Vector2.ZERO, "A")
	var b: int = model.add_component("INPUT", Vector2.ZERO, "B")
	var gate: int = model.add_component("NOT", Vector2.ZERO, "N1")
	model.connect_components(a, gate, 0)
	_expect(not bool(model.connect_components(a, gate, 0)["ok"]), "Exact duplicate wire must be rejected")
	var replacement: Dictionary = model.connect_components(b, gate, 0)
	_expect(bool(replacement["ok"]) and bool(replacement["replaced"]), "Occupied input should be explicitly replaced")
	_expect(model.connections().size() == 1 and int(model.connections()[0]["from"]) == b, "Replacement must leave one driver")


func _test_component_deletion_cleanup() -> void:
	var model = Model.new()
	var a: int = model.add_component("INPUT", Vector2.ZERO, "A")
	var gate: int = model.add_component("NOT", Vector2.ZERO, "N1")
	var output: int = model.add_component("OUTPUT", Vector2.ZERO, "Y")
	model.connect_components(a, gate, 0)
	model.connect_components(gate, output, 0)
	_expect(model.remove_component(gate), "Existing component should be removable")
	_expect(model.connections().is_empty(), "Deleting a component must delete inbound and outbound wires")


func _test_truth_table_order_and_input_restore() -> void:
	var model = Model.new()
	var a: int = model.add_component("INPUT", Vector2.ZERO, "A")
	var b: int = model.add_component("INPUT", Vector2.ZERO, "B")
	var gate: int = model.add_component("XOR", Vector2.ZERO, "G1")
	var output: int = model.add_component("OUTPUT", Vector2.ZERO, "Y")
	model.connect_components(a, gate, 0)
	model.connect_components(b, gate, 1)
	model.connect_components(gate, output, 0)
	model.set_input(a, true)
	model.set_input(b, false)
	var table: Dictionary = model.generate_truth_table()
	_expect(bool(table["ok"]), "Complete circuit should generate a truth table")
	_expect(table["rows"].size() == 4, "Two input switches must generate four rows")
	if bool(table["ok"]):
		var expected := [[0], [1], [1], [0]]
		for row in range(4):
			_expect(table["rows"][row]["outputs"] == expected[row], "Truth table row %d differs from XOR results" % row)
	_expect(bool(model.component(a)["value"]) and not bool(model.component(b)["value"]), "Truth table generation must restore the current input settings")


func _test_starter_and_reset() -> void:
	var model = Model.new()
	model.reset_to_starter()
	_expect(model.components().size() == 4, "Starter circuit should have A, B, AND and output")
	_expect(model.connections().size() == 3, "Starter circuit should contain its three wires")
	model.clear()
	_expect(model.components().is_empty() and model.connections().is_empty(), "Clear must empty the circuit")
	model.reset_to_starter()
	_expect(model.connections().size() == 3, "Reset must restore the starter topology")


func _test_default_labels() -> void:
	var model = Model.new()
	var input_a: int = model.add_component("INPUT", Vector2.ZERO)
	var input_b: int = model.add_component("INPUT", Vector2.ZERO)
	var gate: int = model.add_component("AND", Vector2.ZERO)
	var output: int = model.add_component("OUTPUT", Vector2.ZERO)
	_expect(model.component(input_a)["label"] == "A", "First input should receive label A")
	_expect(model.component(input_b)["label"] == "B", "Second input should receive label B")
	_expect(model.component(gate)["label"] == "AND1", "First gate should receive a descriptive default label")
	_expect(model.component(output)["label"] == "Y", "First output should receive label Y")
