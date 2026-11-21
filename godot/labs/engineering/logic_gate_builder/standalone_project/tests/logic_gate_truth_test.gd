extends SceneTree
## Run with: godot --headless --path standalone_project --script res://tests/logic_gate_truth_test.gd
func _initialize() -> void:
    assert(_gate("AND", false, false) == false)
    assert(_gate("AND", true, true) == true)
    assert(_gate("OR", false, true) == true)
    assert(_gate("NOT", false) == true)
    assert(_gate("NAND", true, true) == false)
    assert(_gate("NOR", false, false) == true)
    assert(_gate("XOR", false, true) == true)
    assert(_gate("XOR", true, true) == false)
    assert(_gate("XNOR", true, true) == true)
    print("Logic gate truth tests passed.")
    quit()
func _gate(kind: String, a: bool, b: bool = false) -> bool:
    match kind:
        "AND": return a and b
        "OR": return a or b
        "NOT": return not a
        "NAND": return not (a and b)
        "NOR": return not (a or b)
        "XOR": return a != b
        "XNOR": return a == b
    return false
