extends Control
## Interactive digital logic laboratory. All signals use Boolean values (0/1).

const GATE_DEFS := {
    "AND": {"inputs": 2, "expr": "Y = A · B"},
    "OR": {"inputs": 2, "expr": "Y = A + B"},
    "NOT": {"inputs": 1, "expr": "Y = ¬A"},
    "NAND": {"inputs": 2, "expr": "Y = ¬(A · B)"},
    "NOR": {"inputs": 2, "expr": "Y = ¬(A + B)"},
    "XOR": {"inputs": 2, "expr": "Y = A ⊕ B"},
    "XNOR": {"inputs": 2, "expr": "Y = ¬(A ⊕ B)"}
}
const FIREBRICK := Color("#b22222")
const DARK := Color("#17191e")
const BOARD_BG := Color("#101216")
const NODE_W := 136.0
const NODE_H := 76.0

var nodes: Array[Dictionary] = []
var wires: Array[Dictionary] = []
var next_id := 1
var selected_id := -1
var wire_source_id := -1
var wire_mode := false
var board: Control
var status_label: Label
var truth_panel: TextEdit
var challenge_label: Label
var simulation_button: Button
var sidebar_simulation_button: Button
var simulation_running := false
var _node_counter := 0
var _drag_node_id := -1
var _drag_offset := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _drag_moved := false
const DRAG_THRESHOLD := 5.0

func _ready() -> void:
    simulation_running = false
    _build_ui()
    _seed_demo()
    _refresh()
    _update_simulation_controls()

func _build_ui() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color("#f5f3f1")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var outer := VBoxContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("separation", 0)
    add_child(outer)
    var header := PanelContainer.new()
    var hs := StyleBoxFlat.new(); hs.bg_color = Color("#ffffff"); hs.content_margin_left = 22; hs.content_margin_right = 22; hs.content_margin_top = 12; hs.content_margin_bottom = 12
    header.add_theme_stylebox_override("panel", hs)
    outer.add_child(header)
    var hrow := HBoxContainer.new(); header.add_child(hrow)
    var title_box := VBoxContainer.new(); title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hrow.add_child(title_box)
    var title := Label.new(); title.text = "LOGIC GATE BUILDER"; title.add_theme_font_size_override("font_size", 25); title.add_theme_color_override("font_color", Color("#1b1b1b")); title_box.add_child(title)
    var subtitle := Label.new(); subtitle.text = "Digital logic · Boolean signals · Interactive circuit experiments"; subtitle.add_theme_color_override("font_color", Color("#686868")); title_box.add_child(subtitle)
    simulation_button = _button("▶ Play Simulation", true); simulation_button.custom_minimum_size.x = 160; simulation_button.pressed.connect(_toggle_simulation); hrow.add_child(simulation_button)
    var reset_btn := _button("Reset Circuit"); reset_btn.pressed.connect(_reset_circuit); hrow.add_child(reset_btn)
    var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 0); outer.add_child(body)
    var sidebar := PanelContainer.new(); sidebar.custom_minimum_size.x = 238
    var ss := StyleBoxFlat.new(); ss.bg_color = Color("#ffffff"); ss.content_margin_left = 14; ss.content_margin_right = 14; ss.content_margin_top = 14; ss.content_margin_bottom = 14; sidebar.add_theme_stylebox_override("panel", ss); body.add_child(sidebar)
    var side := VBoxContainer.new(); side.add_theme_constant_override("separation", 7); sidebar.add_child(side)
    _section_label(side, "ADD COMPONENT")
    _add_component_button(side, "Input Switch", "INPUT")
    for gate in ["AND", "OR", "NOT", "NAND", "NOR", "XOR", "XNOR"]: _add_component_button(side, gate + " Gate", gate)
    _add_component_button(side, "Output Indicator", "OUTPUT")
    var sep := HSeparator.new(); side.add_child(sep)
    _section_label(side, "EDIT & SIMULATE")
    sidebar_simulation_button = _button("▶ Play Simulation", true); sidebar_simulation_button.pressed.connect(_toggle_simulation); side.add_child(sidebar_simulation_button)
    var wire_btn := _button("Wire: OFF"); wire_btn.pressed.connect(func(): wire_mode = not wire_mode; wire_source_id = -1; wire_btn.text = "Wire: ON" if wire_mode else "Wire: OFF"; _set_status("Wire mode: click a source output, then a destination input." if wire_mode else "Wire mode disabled.")); side.add_child(wire_btn)
    var delete_btn := _button("Delete Selected"); delete_btn.pressed.connect(_delete_selected); side.add_child(delete_btn)
    var move_row := HBoxContainer.new(); side.add_child(move_row)
    for pair in [["←", Vector2(-24,0)],["↑", Vector2(0,-24)],["↓", Vector2(0,24)],["→", Vector2(24,0)]]:
        var move_btn := _button(pair[0]); move_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var delta: Vector2 = pair[1]; move_btn.pressed.connect(func(): _move_selected(delta)); move_row.add_child(move_btn)
    var truth_btn := _button("Generate Truth Table", true); truth_btn.pressed.connect(_show_truth_table); side.add_child(truth_btn)
    var challenge_btn := _button("Half-Adder Challenge"); challenge_btn.pressed.connect(_half_adder_challenge); side.add_child(challenge_btn)
    var instructions := Label.new(); instructions.text = "HOW TO USE\n1. Add components; drag their bodies to arrange them.\n2. Click an input switch to toggle 0/1.\n3. Enable Wire mode: click green Y output, then yellow A/B input.\n4. Invalid feedback cycles are rejected.\n5. Play/Pause simulation; generate a truth table anytime."; instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; instructions.add_theme_font_size_override("font_size", 12); instructions.add_theme_color_override("font_color", Color("#666666")); side.add_child(instructions)
    var work := VBoxContainer.new(); work.size_flags_horizontal = Control.SIZE_EXPAND_FILL; work.size_flags_vertical = Control.SIZE_EXPAND_FILL; work.add_theme_constant_override("separation", 0); body.add_child(work)
    status_label = Label.new(); status_label.text = "Ready"; status_label.custom_minimum_size.y = 30; status_label.add_theme_color_override("font_color", Color("#5a2424")); status_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new()); status_label.add_theme_constant_override("margin_left", 12); work.add_child(status_label)
    board = Control.new(); board.name = "LogicCanvas"; board.size_flags_horizontal = Control.SIZE_EXPAND_FILL; board.size_flags_vertical = Control.SIZE_EXPAND_FILL; board.custom_minimum_size = Vector2(600, 460); board.mouse_filter = Control.MOUSE_FILTER_STOP; board.draw.connect(_draw_board); board.gui_input.connect(_on_board_input); work.add_child(board)
    var footer := PanelContainer.new(); var fs := StyleBoxFlat.new(); fs.bg_color = Color("#ffffff"); fs.content_margin_left = 12; fs.content_margin_right = 12; fs.content_margin_top = 8; fs.content_margin_bottom = 8; footer.add_theme_stylebox_override("panel", fs); work.add_child(footer)
    challenge_label = Label.new(); challenge_label.text = "Challenge: Build any circuit and verify its truth table."; challenge_label.add_theme_color_override("font_color", Color("#333333")); footer.add_child(challenge_label)

func _button(text_value: String, primary: bool = false) -> Button:
    var b := Button.new(); b.text = text_value; b.custom_minimum_size.y = 30
    var normal := StyleBoxFlat.new(); normal.bg_color = FIREBRICK if primary else Color("#f4f1ef"); normal.set_corner_radius_all(6); normal.content_margin_left = 8; normal.content_margin_right = 8; normal.content_margin_top = 5; normal.content_margin_bottom = 5
    var hover := normal.duplicate(); hover.bg_color = Color("#8f1b1b") if primary else Color("#e7dfdb")
    b.add_theme_stylebox_override("normal", normal); b.add_theme_stylebox_override("hover", hover); b.add_theme_stylebox_override("pressed", hover)
    b.add_theme_color_override("font_color", Color.WHITE if primary else Color("#262626")); return b

func _section_label(parent: VBoxContainer, value: String) -> void:
    var l := Label.new(); l.text = value; l.add_theme_font_size_override("font_size", 12); l.add_theme_color_override("font_color", FIREBRICK); parent.add_child(l)

func _add_component_button(parent: VBoxContainer, label: String, kind: String) -> void:
    var b := _button("+ " + label); b.pressed.connect(func(): _add_node(kind)); parent.add_child(b)

func _seed_demo() -> void:
    nodes.clear(); wires.clear(); next_id = 1
    _create_node("INPUT", Vector2(70, 100), "A", false)
    _create_node("INPUT", Vector2(70, 240), "B", false)
    _create_node("AND", Vector2(340, 160), "", false)
    _create_node("OUTPUT", Vector2(610, 160), "Y", false)
    wires.append({"from": 1, "to": 3, "input": 0})
    wires.append({"from": 2, "to": 3, "input": 1})
    wires.append({"from": 3, "to": 4, "input": 0})

func _create_node(kind: String, pos: Vector2, label: String = "", refresh: bool = true) -> int:
    var id := next_id; next_id += 1
    var node := {"id": id, "kind": kind, "pos": pos, "label": label if label != "" else ("X" + str(id) if kind == "INPUT" else ("Y" if kind == "OUTPUT" else "")), "value": false, "output": false}
    nodes.append(node)
    if refresh: _refresh()
    return id

func _add_node(kind: String) -> void:
    var p := Vector2(250 + (nodes.size() % 3) * 180, 80 + int(nodes.size() / 3) * 105)
    var id := _create_node(kind, p, "", false); selected_id = id; _refresh(); _set_status("Added " + kind + ". Use Wire mode to connect ports.")

func _node_index(id: int) -> int:
    for i in range(nodes.size()):
        if int(nodes[i].id) == id: return i
    return -1

func _get_node(id: int) -> Dictionary:
    var i := _node_index(id); return nodes[i] if i >= 0 else {}

func _on_board_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_board_pointer(event.position)
        else:
            _finish_board_pointer(event.position)
        return
    if event is InputEventMouseMotion and _drag_node_id >= 0:
        var motion := event as InputEventMouseMotion
        if not _drag_moved and motion.position.distance_to(_drag_origin) >= DRAG_THRESHOLD:
            _drag_moved = true
        if _drag_moved:
            var idx := _node_index(_drag_node_id)
            if idx >= 0:
                var next_pos: Vector2 = motion.position - _drag_offset
                next_pos.x = clampf(next_pos.x, 12.0, maxf(12.0, board.size.x - NODE_W - 12.0))
                next_pos.y = clampf(next_pos.y, 36.0, maxf(36.0, board.size.y - NODE_H - 12.0))
                nodes[idx].pos = next_pos
                board.queue_redraw()
        return

func _begin_board_pointer(p: Vector2) -> void:
    var hit_id := _node_at(p)
    if hit_id < 0:
        selected_id = -1
        wire_source_id = -1 if wire_mode else wire_source_id
        _refresh()
        return

    selected_id = hit_id
    var n := _get_node(hit_id)
    var port_info := _port_at(n, p)

    if wire_mode:
        if port_info.port_type == "output":
            if str(n.kind) == "OUTPUT":
                _set_status("Invalid source: output indicators cannot send signals. Choose an input switch or gate output (green port).")
                _refresh()
                return
            wire_source_id = hit_id
            _set_status("Source selected: " + _node_caption(n) + " (Y). Now click a labelled destination input (A or B).")
            _refresh()
            return
        if port_info.port_type == "input":
            _connect_to_input(hit_id, int(port_info.index))
            _refresh()
            return
        if wire_source_id >= 0:
            _set_status("Choose a labelled input port (A/B) to complete the connection, or click a green output port to select a new source.")
        else:
            _set_status("Wire mode: click a green output port (Y) first, then a yellow input port (A/B).")
        _refresh()
        return

    # Outside wire mode, a node body can be dragged directly.
    if port_info.port_type == "none":
        _drag_node_id = hit_id
        _drag_offset = p - Vector2(n.pos)
        _drag_origin = p
        _drag_moved = false
    _refresh()

func _finish_board_pointer(p: Vector2) -> void:
    if _drag_node_id < 0:
        return
    var dragged_id := _drag_node_id
    var did_move := _drag_moved
    _drag_node_id = -1
    _drag_moved = false
    if not did_move:
        var n := _get_node(dragged_id)
        if not n.is_empty() and str(n.kind) == "INPUT" and not wire_mode:
            var idx := _node_index(dragged_id)
            if idx >= 0:
                nodes[idx].value = not bool(nodes[idx].value)
                _set_status("Input " + _node_caption(n) + " set to " + ("1" if bool(nodes[idx].value) else "0") + ".")
    _refresh()

func _node_at(p: Vector2) -> int:
    for i in range(nodes.size() - 1, -1, -1):
        var n: Dictionary = nodes[i]
        if Rect2(Vector2(n.pos), Vector2(NODE_W, NODE_H)).has_point(p):
            return int(n.id)
    return -1

func _port_at(n: Dictionary, p: Vector2) -> Dictionary:
    var pos: Vector2 = n.pos
    var kind := str(n.kind)
    # Ports occupy a compact, explicit hit target at the edges.
    if p.x >= pos.x + NODE_W - 18.0 and (kind == "INPUT" or GATE_DEFS.has(kind)):
        return {"port_type": "output", "index": 0}
    if p.x <= pos.x + 18.0:
        var port_idx := _nearest_input_port(n, p.y)
        if _input_count(kind) > 0 and port_idx >= 0:
            var expected_y := pos.y + NODE_H * 0.5 if _input_count(kind) <= 1 else (pos.y + NODE_H * 0.32 if port_idx == 0 else pos.y + NODE_H * 0.72)
            if absf(p.y - expected_y) <= 14.0:
                return {"port_type": "input", "index": port_idx}
    return {"port_type": "none", "index": -1}

func _connect_to_input(target_id: int, input_port: int) -> void:
    if wire_source_id < 0:
        _set_status("No source selected. Click a green Y output port first.")
        return
    if wire_source_id == target_id:
        _set_status("Connection rejected: a component cannot connect to itself.")
        wire_source_id = -1
        return
    var source := _get_node(wire_source_id)
    var target := _get_node(target_id)
    if source.is_empty() or target.is_empty():
        _set_status("Connection rejected: source or destination no longer exists.")
        wire_source_id = -1
        return
    var source_kind := str(source.kind)
    var target_kind := str(target.kind)
    if not (source_kind == "INPUT" or GATE_DEFS.has(source_kind)):
        _set_status("Connection rejected: only input switches and logic gates have output ports.")
        wire_source_id = -1
        return
    var target_count := _input_count(target_kind)
    if target_count <= 0 or input_port < 0 or input_port >= target_count:
        _set_status("Connection rejected: destination must be a valid A/B input port on a gate or Y output indicator.")
        wire_source_id = -1
        return
    if _would_create_cycle(wire_source_id, target_id):
        _set_status("Connection rejected: this wire would create a feedback cycle. Connect the circuit in a directed, acyclic path.")
        wire_source_id = -1
        return

    var replaced := false
    for w in wires:
        if int(w.to) == target_id and int(w.input) == input_port and int(w.from) != wire_source_id:
            replaced = true
            break
    _remove_wire_to_port(target_id, input_port)
    wires.append({"from": wire_source_id, "to": target_id, "input": input_port})
    var port_name := _input_port_name(target_kind, input_port)
    if replaced:
        _set_status("Connection replaced at " + _node_caption(target) + " input " + port_name + ".")
    else:
        _set_status("Connected " + _node_caption(source) + " (Y) → " + _node_caption(target) + " (" + port_name + ").")
    wire_source_id = -1

func _would_create_cycle(source_id: int, target_id: int) -> bool:
    # Adding source → target creates a cycle iff source is already reachable
    # by following existing outgoing edges from target.
    var stack: Array[int] = [target_id]
    var visited := {}
    while not stack.is_empty():
        var current: int = stack.pop_back()
        if current == source_id:
            return true
        if visited.has(current):
            continue
        visited[current] = true
        for w in wires:
            if int(w.from) == current:
                stack.append(int(w.to))
    return false

func _input_port_name(kind: String, port: int) -> String:
    if kind == "OUTPUT":
        return "Y input"
    return "A" if port == 0 else "B"

func _nearest_input_port(n: Dictionary, y: float) -> int:
    var count := _input_count(str(n.kind))
    if count <= 1: return 0
    return 0 if y < float(n.pos.y) + NODE_H * 0.5 else 1

func _input_count(kind: String) -> int:
    if kind == "OUTPUT": return 1
    if GATE_DEFS.has(kind): return int(GATE_DEFS[kind].inputs)
    return 0

func _remove_wire_to_port(to_id: int, port: int) -> void:
    for i in range(wires.size() - 1, -1, -1):
        if int(wires[i].to) == to_id and int(wires[i].input) == port: wires.remove_at(i)

func _evaluate(id: int, visiting: Dictionary, cache: Dictionary) -> bool:
    if cache.has(id): return bool(cache[id])
    if visiting.has(id): return false
    visiting[id] = true
    var n := _get_node(id)
    if n.is_empty():
        visiting.erase(id)
        return false
    var kind := str(n.kind); var result := false
    if kind == "INPUT": result = bool(n.value)
    elif kind == "OUTPUT" or GATE_DEFS.has(kind):
        var vals: Array[bool] = []
        for port in range(_input_count(kind)):
            var source_id := -1
            for w in wires:
                if int(w.to) == id and int(w.input) == port: source_id = int(w.from); break
            vals.append(_evaluate(source_id, visiting, cache) if source_id >= 0 else false)
        if kind == "OUTPUT": result = vals[0] if vals.size() > 0 else false
        elif kind == "NOT": result = not vals[0]
        elif kind == "AND": result = vals[0] and vals[1]
        elif kind == "OR": result = vals[0] or vals[1]
        elif kind == "NAND": result = not (vals[0] and vals[1])
        elif kind == "NOR": result = not (vals[0] or vals[1])
        elif kind == "XOR": result = vals[0] != vals[1]
        elif kind == "XNOR": result = vals[0] == vals[1]
    visiting.erase(id); cache[id] = result; return result

func _snapshot(force_evaluate: bool = false) -> Dictionary:
    var values := {}
    if not simulation_running and not force_evaluate:
        # Inputs can be configured while stopped, but no downstream signal is active.
        for n in nodes:
            values[int(n.id)] = bool(n.value) if str(n.kind) == "INPUT" else false
        return values
    var cache := {}; var visiting := {}
    for n in nodes: values[int(n.id)] = _evaluate(int(n.id), visiting, cache)
    return values

func _draw_board() -> void:
    if board == null: return
    board.draw_rect(Rect2(Vector2.ZERO, board.size), BOARD_BG)
    for x in range(20, int(board.size.x), 24):
        for y in range(18, int(board.size.y), 24): board.draw_circle(Vector2(x,y), 1.0, Color("#2b3038"))
    var values := _snapshot()
    for w in wires:
        var a := _get_node(int(w.from))
        var b := _get_node(int(w.to))
        if a.is_empty() or b.is_empty():
            continue
        var start := Vector2(a.pos.x + NODE_W, a.pos.y + NODE_H * 0.5)
        var port_idx := int(w.input); var count := _input_count(str(b.kind)); var offset := NODE_H * 0.5 if count <= 1 else (NODE_H * 0.32 if port_idx == 0 else NODE_H * 0.72)
        var finish := Vector2(b.pos.x, b.pos.y + offset)
        var wire_color := Color("#47d7a0") if simulation_running and bool(values.get(int(w.from), false)) else Color("#67717e")
        board.draw_line(start, Vector2((start.x + finish.x) * 0.5, start.y), wire_color, 3.0, true)
        board.draw_line(Vector2((start.x + finish.x) * 0.5, start.y), Vector2((start.x + finish.x) * 0.5, finish.y), wire_color, 3.0, true)
        board.draw_line(Vector2((start.x + finish.x) * 0.5, finish.y), finish, wire_color, 3.0, true)
    for n in nodes:
        var id := int(n.id); var kind := str(n.kind); var pos: Vector2 = n.pos; var rect := Rect2(pos, Vector2(NODE_W, NODE_H))
        var active := bool(values.get(id, false)); var fill := Color("#273b39") if active else Color("#252a33")
        if kind == "INPUT": fill = Color("#285b46") if bool(n.value) else Color("#30343c")
        if kind == "OUTPUT": fill = Color("#236a4b") if active else Color("#30343c")
        board.draw_rect(rect, fill, true)
        var outline := Color("#ffcb68") if id == wire_source_id else (Color("#e9eeee") if id == selected_id else Color("#4c5664"))
        board.draw_rect(rect, outline, false, 3.0 if id == wire_source_id else 2.0)
        board.draw_string(ThemeDB.fallback_font, pos + Vector2(12, 23), _node_caption(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
        var sub := "INPUT " + ("1" if bool(n.value) else "0") if kind == "INPUT" else ("OUTPUT " + ("1" if active else "0") if kind == "OUTPUT" else str(GATE_DEFS[kind].expr))
        board.draw_string(ThemeDB.fallback_font, pos + Vector2(12, 48), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#c7d0d7"))
        if _input_count(kind) > 0:
            for port_idx in range(_input_count(kind)):
                var py := pos.y + NODE_H * 0.5 if _input_count(kind) == 1 else (pos.y + NODE_H * 0.32 if port_idx == 0 else pos.y + NODE_H * 0.72)
                board.draw_circle(Vector2(pos.x, py), 5.5, Color("#f3c969"))
                var input_label := "Y" if kind == "OUTPUT" else ("A" if port_idx == 0 else "B")
                board.draw_string(ThemeDB.fallback_font, Vector2(pos.x + 8, py + 4), input_label, HORIZONTAL_ALIGNMENT_LEFT, 14, 10, Color("#f3c969"))
        if kind == "INPUT" or GATE_DEFS.has(kind):
            board.draw_circle(Vector2(pos.x + NODE_W, pos.y + NODE_H * 0.5), 5.5, Color("#49d5a0") if active else Color("#657080"))
            board.draw_string(ThemeDB.fallback_font, Vector2(pos.x + NODE_W - 20, pos.y + NODE_H * 0.5 - 9), "Y", HORIZONTAL_ALIGNMENT_LEFT, 12, 10, Color("#49d5a0"))
        if kind == "OUTPUT":
            board.draw_circle(Vector2(pos.x + NODE_W - 15, pos.y + NODE_H * 0.5), 7.0, Color("#52f0a9") if active else Color("#59616c"))
    if wire_mode:
        board.draw_string(ThemeDB.fallback_font, Vector2(14, 22), "WIRE MODE: select source output → destination input", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffcb68"))

func _node_caption(n: Dictionary) -> String:
    var kind := str(n.kind); var label := str(n.label)
    return label if kind in ["INPUT", "OUTPUT"] else kind

func _refresh() -> void:
    if board != null: board.queue_redraw()
    if status_label != null:
        var values := _snapshot(); var output_count := 0; var active_outputs := 0
        for n in nodes:
            if str(n.kind) == "OUTPUT":
                output_count += 1
                if bool(values.get(int(n.id), false)):
                    active_outputs += 1
        var run_state := "RUNNING" if simulation_running else "STOPPED — press Play to evaluate"
        status_label.text = "%s   |   Components: %d   Connections: %d   Outputs HIGH: %d/%d" % [run_state, nodes.size(), wires.size(), active_outputs, output_count]
    _update_simulation_controls()

func _set_status(message: String) -> void:
    if status_label != null: status_label.text = message

func _toggle_simulation() -> void:
    simulation_running = not simulation_running
    _refresh()
    if simulation_running:
        _set_status("Simulation running. Toggle inputs to observe live signal propagation.")
    else:
        _set_status("Simulation paused. Inputs and wiring can be edited before resuming.")

func _update_simulation_controls() -> void:
    var button_text := "Ⅱ Pause Simulation" if simulation_running else "▶ Play Simulation"
    if simulation_button != null: simulation_button.text = button_text
    if sidebar_simulation_button != null: sidebar_simulation_button.text = button_text

func _delete_selected() -> void:
    if selected_id < 0: _set_status("Select a component first."); return
    for i in range(nodes.size()-1, -1, -1):
        if int(nodes[i].id) == selected_id: nodes.remove_at(i)
    for i in range(wires.size()-1, -1, -1):
        if int(wires[i].from) == selected_id or int(wires[i].to) == selected_id: wires.remove_at(i)
    selected_id = -1; wire_source_id = -1; _refresh(); _set_status("Component deleted.")

func _move_selected(delta: Vector2) -> void:
    var i := _node_index(selected_id)
    if i < 0: _set_status("Select a component first."); return
    nodes[i].pos = Vector2(nodes[i].pos) + delta; nodes[i].pos.x = clampf(nodes[i].pos.x, 12.0, maxf(12.0, board.size.x - NODE_W - 12.0)); nodes[i].pos.y = clampf(nodes[i].pos.y, 36.0, maxf(36.0, board.size.y - NODE_H - 12.0)); _refresh()

func _reset_circuit() -> void:
    simulation_running = false
    _seed_demo(); selected_id = -1; wire_source_id = -1; wire_mode = false; _refresh(); _set_status("Starter AND circuit restored. Press Play Simulation to run it.")

func _show_truth_table() -> void:
    var inputs: Array[Dictionary] = []
    var outputs: Array[Dictionary] = []
    for n in nodes:
        if str(n.kind) == "INPUT": inputs.append(n)
        elif str(n.kind) == "OUTPUT": outputs.append(n)
    if inputs.size() == 0 or outputs.size() == 0: _set_status("Add at least one input switch and one output indicator."); return
    if inputs.size() > 8: _set_status("Truth table is limited to 8 input switches (256 rows)."); return
    var lines := "TRUTH TABLE\nInputs: "
    for n in inputs: lines += str(n.label) + "  "
    lines += " | Outputs: "
    for n in outputs: lines += str(n.label) + "  "
    lines += "\n" + "─".repeat(mini(70, inputs.size() * 5 + outputs.size() * 5 + 4)) + "\n"
    var saved := {}
    for n in inputs: saved[int(n.id)] = bool(n.value)
    for mask in range(1 << inputs.size()):
        for i in range(inputs.size()):
            var ni := _node_index(int(inputs[i].id)); nodes[ni].value = (mask & (1 << (inputs.size() - 1 - i))) != 0
        var vals := _snapshot(true)
        for n in inputs: lines += ("1  " if bool(n.value) else "0  ")
        lines += " | "
        for n in outputs: lines += ("1  " if bool(vals.get(int(n.id), false)) else "0  ")
        lines += "\n"
    for n in inputs:
        var ni := _node_index(int(n.id)); nodes[ni].value = bool(saved[int(n.id)])
    var dialog := AcceptDialog.new(); dialog.title = "Generated Truth Table"; dialog.dialog_text = lines; dialog.min_size = Vector2i(520, 420); add_child(dialog); dialog.popup_centered(); _refresh()

func _half_adder_challenge() -> void:
    challenge_label.text = "Challenge: Half-adder — build SUM = A XOR B and CARRY = A AND B using two inputs and two outputs."
    _set_status("Half-adder challenge loaded. Build the XOR and AND paths, then press Play Simulation to test them.")
