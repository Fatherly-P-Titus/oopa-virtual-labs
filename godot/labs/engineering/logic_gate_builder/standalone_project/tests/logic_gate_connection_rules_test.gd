extends SceneTree
## Lightweight graph-rule regression test for the wiring validation contract.
## Run: godot --headless --path standalone_project --script res://tests/logic_gate_connection_rules_test.gd

func _initialize() -> void:
    assert(_would_create_cycle(3, 1, [{"from": 1, "to": 2}, {"from": 2, "to": 3}]))
    assert(not _would_create_cycle(1, 3, [{"from": 1, "to": 2}, {"from": 2, "to": 3}]))
    assert(_would_create_cycle(1, 1, []))
    assert(not _would_create_cycle(4, 1, [{"from": 1, "to": 2}, {"from": 2, "to": 3}]))
    print("Logic gate connection graph-rule tests passed.")
    quit()

func _would_create_cycle(source_id: int, target_id: int, wires: Array) -> bool:
    var stack: Array[int] = [target_id]
    var visited := {}
    while not stack.is_empty():
        var current: int = stack.pop_back()
        if current == source_id:
            return true
        if visited.has(current):
            continue
        visited[current] = true
        for wire in wires:
            if int(wire.from) == current:
                stack.append(int(wire.to))
    return false
