extends RefCounted
class_name SingleCellModel
## Phase 1 — pure agent + media engine (BioCell port).
## Media grid (food/waste) + prokaryote-like cells: metabolize, move, divide, die.
## No nodes / drawing. Call step() from the lab.

# ---------------------------------------------------------------------------
# World / tuning (mirrors BioCell CONFIG)
# ---------------------------------------------------------------------------
const WORLD_W: float = 1200.0
const WORLD_H: float = 900.0
const GRID_RES: float = 10.0
const MAX_CELLS: int = 800
const EDGE_PAD: float = 24.0  # keep agents off the extreme border

const BASE_METABOLIC_COST: float = 0.15
const NUTRIENT_UPTAKE_RATE: float = 0.80
const GROWTH_COST: float = 0.05
const MOVEMENT_COST: float = 0.08

const DIVISION_ENERGY: float = 25.0
const DIVISION_SIZE: float = 1.4

const BASE_SPEED: float = 1.80
const TUMBLE_P: float = 0.08
const RUN_BIAS: float = 0.85

const MUTATION_RATE: float = 0.15
const MUTATION_STRENGTH: float = 0.12

const MAX_AGE: int = 1200

## Cell type catalogue: id -> {name, color Color, genome defaults}
const CELL_TYPES: Dictionary = {
	"coccus": {
		"name": "Coccus",
		"color": Color(0.86, 0.24, 0.24),
		"description": "Spherical, balanced generalist",
		"metabolicRate": 1.0,
		"motility": 1.0,
		"divisionThreshold": 1.0,
		"uptakeEfficiency": 1.0,
		"sizeScale": 1.0,
	},
	"bacillus": {
		"name": "Bacillus",
		"color": Color(0.24, 0.55, 1.0),
		"description": "Rod-shaped, efficient metabolizer",
		"metabolicRate": 0.75,
		"motility": 0.85,
		"divisionThreshold": 0.9,
		"uptakeEfficiency": 1.25,
		"sizeScale": 1.15,
	},
	"spirillum": {
		"name": "Spirillum",
		"color": Color(1.0, 0.71, 0.16),
		"description": "Spiral, fast mover",
		"metabolicRate": 1.15,
		"motility": 1.45,
		"divisionThreshold": 1.1,
		"uptakeEfficiency": 0.9,
		"sizeScale": 0.9,
	},
	"vibrio": {
		"name": "Vibrio",
		"color": Color(0.71, 0.27, 0.86),
		"description": "Comma-shaped, hardy specialist",
		"metabolicRate": 0.9,
		"motility": 1.1,
		"divisionThreshold": 1.05,
		"uptakeEfficiency": 1.05,
		"sizeScale": 1.0,
	},
}

# ---------------------------------------------------------------------------
# Live environment (mutated by lab UI)
# ---------------------------------------------------------------------------
var media_type: String = "aqueous"
var temperature: float = 37.0
var pH: float = 7.0
var viscosity: float = 1.0
var oxygen: float = 1.0

var initial_cells: int = 24
var active_types: Array = ["coccus", "bacillus", "spirillum"]

# ---------------------------------------------------------------------------
# Media grid
# ---------------------------------------------------------------------------
var grid_cols: int = 120
var grid_rows: int = 90
var food: PackedFloat32Array = PackedFloat32Array()  # legacy grid (unused for uptake)
var waste: PackedFloat32Array = PackedFloat32Array()
var food_patches: Array = []  # {x, y, radius, amount}

# ---------------------------------------------------------------------------
# Agents — each cell is a Dictionary (explicit keys)
# ---------------------------------------------------------------------------
var cells: Array = []
var next_cell_id: int = 1

var tick: int = 0
var running: bool = false

## Rolling stats (Phase 1 records; charts use later)
var stats_population: Array = []
var stats_avg_energy: Array = []
var stats_by_type: Dictionary = {}


func _init() -> void:
	grid_cols = int(WORLD_W / GRID_RES)
	grid_rows = int(WORLD_H / GRID_RES)
	_alloc_grids()
	reset()


func _alloc_grids() -> void:
	var n: int = grid_cols * grid_rows
	food.resize(n)
	waste.resize(n)
	food.fill(0.0)
	waste.fill(0.0)


func _idx(col: int, row: int) -> int:
	return row * grid_cols + col


func grid_index(col: int, row: int) -> int:
	return _idx(col, row)


func _clamp_cell(col: int, row: int) -> Vector2i:
	return Vector2i(clampi(col, 0, grid_cols - 1), clampi(row, 0, grid_rows - 1))


func world_to_cell(x: float, y: float) -> Vector2i:
	var c: int = int(floor(x / GRID_RES))
	var r: int = int(floor(y / GRID_RES))
	return _clamp_cell(c, r)


# ---------------------------------------------------------------------------
# Environment factors (peak ~37 °C, pH 7)
# ---------------------------------------------------------------------------
func media_factors() -> Dictionary:
	var tf: float = exp(-0.5 * pow((temperature - 37.0) / 12.0, 2.0))
	tf = clampf(tf, 0.15, 1.0)
	var pf: float = exp(-0.5 * pow((pH - 7.0) / 1.8, 2.0))
	pf = clampf(pf, 0.15, 1.0)
	var of: float = clampf(oxygen, 0.0, 1.5)
	var vf: float = 1.0 / maxf(viscosity, 0.25)
	return {
		"tempFactor": tf,
		"pHFactor": pf,
		"oxygenFactor": of,
		"viscosityFactor": vf,
	}


# ---------------------------------------------------------------------------
# Media sampling / diffusion / interventions
# ---------------------------------------------------------------------------
func sample_at(x: float, y: float) -> Dictionary:
	var rc: Vector2i = world_to_cell(x, y)
	var i: int = _idx(rc.x, rc.y)
	var w: float = waste[i]
	var conc: float = 0.0
	var gx: float = 0.0
	var gy: float = 0.0
	for p in food_patches:
		var px: float = float(p["x"])
		var py: float = float(p["y"])
		var rad: float = maxf(float(p["radius"]), 1.0)
		var amt: float = maxf(float(p["amount"]), 0.0)
		if amt <= 0.01:
			continue
		var dx: float = px - x
		var dy: float = py - y
		var dist: float = sqrt(dx * dx + dy * dy)
		if dist >= rad:
			continue
		var fall: float = 1.0 - dist / rad
		var dens: float = (amt / (PI * rad * rad)) * 80.0 * fall
		conc += dens
		if dist > 0.5:
			var pull: float = dens / dist
			gx += dx * pull
			gy += dy * pull
	return {
		"concentration": conc,
		"waste": w,
		"gradientX": gx,
		"gradientY": gy,
	}



func consume_food(x: float, y: float, amount: float) -> void:
	if amount <= 0.0 or food_patches.is_empty():
		return
	var weights: Array = []
	var wsum: float = 0.0
	for p in food_patches:
		var dx: float = float(p["x"]) - x
		var dy: float = float(p["y"]) - y
		var rad: float = maxf(float(p["radius"]), 1.0)
		var dist: float = sqrt(dx * dx + dy * dy)
		var w: float = 0.0
		if dist < rad and float(p["amount"]) > 0.0:
			w = (1.0 - dist / rad) * float(p["amount"])
		weights.append(w)
		wsum += w
	if wsum <= 1e-9:
		return
	for i in range(food_patches.size()):
		var share: float = amount * float(weights[i]) / wsum
		food_patches[i]["amount"] = maxf(0.0, float(food_patches[i]["amount"]) - share)
	if tick % 30 == 0:
		var kept: Array = []
		for p2 in food_patches:
			if float(p2["amount"]) > 0.15:
				kept.append(p2)
		food_patches = kept



func add_waste(x: float, y: float, amount: float) -> void:
	var rc: Vector2i = world_to_cell(x, y)
	var i: int = _idx(rc.x, rc.y)
	waste[i] = minf(waste[i] + amount, 50.0)


func add_food_amount(amount: float, cx: float = -1.0, cy: float = -1.0) -> void:
	## Spawn a circular food patch (radius 50–75 world px).
	var x: float = cx if cx >= 0.0 else WORLD_W * 0.5
	var y: float = cy if cy >= 0.0 else WORLD_H * 0.5
	var rad: float = 50.0 + randf() * 25.0
	x = clampf(x, EDGE_PAD + rad, WORLD_W - EDGE_PAD - rad)
	y = clampf(y, EDGE_PAD + rad, WORLD_H - EDGE_PAD - rad)
	food_patches.append({
		"x": x,
		"y": y,
		"radius": rad,
		"amount": maxf(amount, 5.0),
	})



func diffuse() -> void:
	## Waste diffuses on the grid; food lives in fixed circular patches.
	var rate: float = 0.15
	var new_w: PackedFloat32Array = waste.duplicate()
	for r in range(grid_rows):
		for c in range(grid_cols):
			var i: int = _idx(c, r)
			var acc_w: float = waste[i]
			var cnt: float = 1.0
			if c > 0:
				acc_w += waste[_idx(c - 1, r)]; cnt += 1.0
			if c < grid_cols - 1:
				acc_w += waste[_idx(c + 1, r)]; cnt += 1.0
			if r > 0:
				acc_w += waste[_idx(c, r - 1)]; cnt += 1.0
			if r < grid_rows - 1:
				acc_w += waste[_idx(c, r + 1)]; cnt += 1.0
			new_w[i] = waste[i] * (1.0 - rate) + (acc_w / cnt) * rate * 0.9
	waste = new_w



func seed_media(food_hint: float = 30.0, waste_hint: float = 0.0) -> void:
	_alloc_grids()
	for i in range(waste.size()):
		waste[i] = waste_hint * 0.1 + randf() * waste_hint * 0.02
		food[i] = 0.0
	food_patches.clear()
	var n_patches: int = clampi(int(food_hint / 6.0) + 3, 4, 14)
	for _i in range(n_patches):
		var rad: float = 50.0 + randf() * 25.0
		var amt: float = food_hint * (0.6 + randf() * 0.8)
		food_patches.append({
			"x": EDGE_PAD + rad + randf() * (WORLD_W - 2.0 * (EDGE_PAD + rad)),
			"y": EDGE_PAD + rad + randf() * (WORLD_H - 2.0 * (EDGE_PAD + rad)),
			"radius": rad,
			"amount": amt,
		})



# ---------------------------------------------------------------------------
# Genome helpers
# ---------------------------------------------------------------------------
func _default_genome(type_id: String) -> Dictionary:
	var t: Dictionary = CELL_TYPES.get(type_id, CELL_TYPES["coccus"])
	return {
		"metabolicRate": float(t["metabolicRate"]),
		"motility": float(t["motility"]),
		"divisionThreshold": float(t["divisionThreshold"]),
		"uptakeEfficiency": float(t["uptakeEfficiency"]),
		"sizeScale": float(t["sizeScale"]),
	}


func _mutate_genome(g: Dictionary) -> Dictionary:
	var out: Dictionary = g.duplicate()
	for key in out.keys():
		if randf() < MUTATION_RATE:
			var noise: float = 1.0 + (randf() * 2.0 - 1.0) * MUTATION_STRENGTH
			out[key] = clampf(float(out[key]) * noise, 0.2, 3.0)
	return out


# ---------------------------------------------------------------------------
# Cells
# ---------------------------------------------------------------------------
func _make_cell(x: float, y: float, type_id: String, genome: Dictionary = {}, energy: float = 12.0, size: float = 1.0) -> Dictionary:
	if genome.is_empty():
		genome = _default_genome(type_id)
	if not CELL_TYPES.has(type_id):
		type_id = "coccus"
	var id: int = next_cell_id
	next_cell_id += 1
	return {
		"id": id,
		"x": x,
		"y": y,
		"typeId": type_id,
		"genome": genome,
		"energy": energy,
		"size": size,
		"age": 0,
		"alive": true,
		"angle": randf() * TAU,
		"state": "active",
	}


func seed_cells() -> void:
	cells.clear()
	var types: Array = []
	for tid in active_types:
		if CELL_TYPES.has(str(tid)):
			types.append(str(tid))
	if types.is_empty():
		types.append("coccus")
	var n: int = clampi(initial_cells, 1, MAX_CELLS)
	var per: int = int(n / types.size())
	var remaining: int = n
	for ti in range(types.size()):
		var count: int = remaining if ti == types.size() - 1 else per
		remaining -= count
		var type_id: String = str(types[ti])
		for _k in range(count):
			cells.append(_make_cell(EDGE_PAD + randf() * (WORLD_W - 2.0 * EDGE_PAD), EDGE_PAD + randf() * (WORLD_H - 2.0 * EDGE_PAD), type_id))


func _cell_metabolize(cell: Dictionary) -> void:
	var sample: Dictionary = sample_at(float(cell["x"]), float(cell["y"]))
	var factors: Dictionary = media_factors()
	var g: Dictionary = cell["genome"]
	var uptake: float = (
		float(sample["concentration"])
		* NUTRIENT_UPTAKE_RATE
		* float(g["uptakeEfficiency"])
		* float(cell["size"])
		* float(factors["tempFactor"])
		* float(factors["pHFactor"])
		* float(factors["oxygenFactor"])
	)
	var waste_v: float = float(sample["waste"])
	uptake *= 1.0 / (1.0 + waste_v * 0.8)
	consume_food(float(cell["x"]), float(cell["y"]), uptake)
	var cost_mult: float = 1.2 - 0.4 * float(factors["tempFactor"])
	var cost: float = (
		BASE_METABOLIC_COST * float(g["metabolicRate"])
		+ MOVEMENT_COST * float(g["motility"])
		+ GROWTH_COST * float(cell["size"])
	) * cost_mult
	cell["energy"] = float(cell["energy"]) + uptake - cost
	add_waste(float(cell["x"]), float(cell["y"]), cost * 0.25)
	if float(cell["energy"]) > 5.0:
		cell["size"] = float(cell["size"]) + 0.008 * float(g["sizeScale"]) * float(factors["tempFactor"])


func _cell_move(cell: Dictionary) -> void:
	var sample: Dictionary = sample_at(float(cell["x"]), float(cell["y"]))
	var factors: Dictionary = media_factors()
	var g: Dictionary = cell["genome"]
	var angle: float = float(cell["angle"])
	if randf() < TUMBLE_P:
		angle = randf() * TAU
	else:
		var desired: float = atan2(float(sample["gradientY"]), float(sample["gradientX"]))
		var diff: float = desired - angle
		while diff > PI:
			diff -= TAU
		while diff < -PI:
			diff += TAU
		angle += diff * RUN_BIAS * 0.3
	var speed: float = BASE_SPEED * float(g["motility"]) * float(factors["viscosityFactor"]) * float(factors["tempFactor"])
	cell["angle"] = angle
	cell["x"] = clampf(float(cell["x"]) + cos(angle) * speed, EDGE_PAD, WORLD_W - EDGE_PAD)
	cell["y"] = clampf(float(cell["y"]) + sin(angle) * speed, EDGE_PAD, WORLD_H - EDGE_PAD)


func _cell_try_divide(cell: Dictionary) -> Dictionary:
	## Returns daughter dict or empty if no division.
	var g: Dictionary = cell["genome"]
	var energy_ready: bool = float(cell["energy"]) >= DIVISION_ENERGY * float(g["divisionThreshold"])
	var size_ready: bool = float(cell["size"]) >= DIVISION_SIZE
	if not energy_ready or not size_ready:
		return {}
	if cells.size() >= MAX_CELLS:
		return {}
	var half_e: float = float(cell["energy"]) * 0.5
	var half_s: float = float(cell["size"]) * 0.5
	cell["energy"] = half_e
	cell["size"] = half_s
	var daughter: Dictionary = _make_cell(
		float(cell["x"]) + (randf() - 0.5) * 4.0,
		float(cell["y"]) + (randf() - 0.5) * 4.0,
		str(cell["typeId"]),
		_mutate_genome(g),
		half_e,
		half_s
	)
	daughter["angle"] = float(cell["angle"]) + (randf() - 0.5)
	return daughter


func _cell_check_death(cell: Dictionary) -> void:
	cell["age"] = int(cell["age"]) + 1
	if float(cell["energy"]) <= 0.0 or int(cell["age"]) >= MAX_AGE:
		cell["alive"] = false


func _cell_update(cell: Dictionary) -> Dictionary:
	## One tick for one cell; returns optional daughter.
	if not bool(cell["alive"]):
		return {}
	_cell_metabolize(cell)
	_cell_move(cell)
	var daughter: Dictionary = _cell_try_divide(cell)
	_cell_check_death(cell)
	return daughter


# ---------------------------------------------------------------------------
# Simulation API
# ---------------------------------------------------------------------------
func reset(food_hint: float = 30.0, waste_hint: float = 0.0) -> void:
	next_cell_id = 1
	tick = 0
	running = false
	stats_population.clear()
	stats_avg_energy.clear()
	stats_by_type.clear()
	seed_media(food_hint, waste_hint)
	seed_cells()


func step() -> void:
	diffuse()
	var newborns: Array = []
	for i in range(cells.size()):
		var cell: Dictionary = cells[i]
		var daughter: Dictionary = _cell_update(cell)
		cells[i] = cell
		if not daughter.is_empty():
			newborns.append(daughter)
	for d in newborns:
		cells.append(d)
	# Filter dead
	var alive: Array = []
	for c in cells:
		if bool(c["alive"]):
			alive.append(c)
	cells = alive

	if tick % 5 == 0:
		stats_population.append(cells.size())
		var sum_e: float = 0.0
		var counts: Dictionary = {}
		for c in cells:
			sum_e += float(c["energy"])
			var tid: String = str(c["typeId"])
			counts[tid] = int(counts.get(tid, 0)) + 1
		stats_by_type = counts
		var avg: float = sum_e / maxf(float(cells.size()), 1.0)
		stats_avg_energy.append(avg)
		if stats_population.size() > 200:
			stats_population.remove_at(0)
			stats_avg_energy.remove_at(0)
	tick += 1


func cell_count() -> int:
	return cells.size()


func count_by_type() -> Dictionary:
	var counts: Dictionary = {}
	for c in cells:
		var tid: String = str(c["typeId"])
		counts[tid] = int(counts.get(tid, 0)) + 1
	return counts


func type_color(type_id: String) -> Color:
	var t: Dictionary = CELL_TYPES.get(type_id, CELL_TYPES["coccus"])
	return t["color"] as Color


func type_ids() -> Array:
	return CELL_TYPES.keys()

func apply_preset(data: Dictionary) -> void:
	## data matches BioCell preset JSON shape (media + cells).
	var media: Dictionary = data.get("media", {})
	var cells_cfg: Dictionary = data.get("cells", {})
	media_type = str(media.get("type", "aqueous"))
	temperature = float(media.get("temperature", 37.0))
	pH = float(media.get("pH", 7.0))
	viscosity = float(media.get("viscosity", 1.0))
	oxygen = float(media.get("oxygen", 1.0))
	var types: Array = cells_cfg.get("activeTypes", ["coccus", "bacillus", "spirillum"])
	active_types = []
	for tid in types:
		if CELL_TYPES.has(str(tid)):
			active_types.append(str(tid))
	if active_types.is_empty():
		active_types = ["coccus"]
	initial_cells = int(cells_cfg.get("initialCells", 24))
	var food_hint: float = float(media.get("initialFoodHint", 30.0))
	var waste_hint: float = float(media.get("initialWasteHint", 0.0))
	reset(food_hint, waste_hint)


func apply_preset_id(id: String) -> void:
	match id:
		"hot_spring":
			apply_preset({
				"media": {"type": "hot_spring", "temperature": 48.0, "pH": 6.2, "viscosity": 0.85, "oxygen": 0.7, "initialFoodHint": 22.0, "initialWasteHint": 2.0},
				"cells": {"activeTypes": ["bacillus", "vibrio"], "initialCells": 20},
			})
		"agar":
			apply_preset({
				"media": {"type": "agar", "temperature": 37.0, "pH": 7.2, "viscosity": 2.4, "oxygen": 1.1, "initialFoodHint": 40.0, "initialWasteHint": 0.0},
				"cells": {"activeTypes": ["coccus", "bacillus", "spirillum", "vibrio"], "initialCells": 16},
			})
		_:
			apply_preset({
				"media": {"type": "aqueous", "temperature": 37.0, "pH": 7.0, "viscosity": 1.0, "oxygen": 1.0, "initialFoodHint": 30.0, "initialWasteHint": 0.0},
				"cells": {"activeTypes": ["coccus", "bacillus", "spirillum"], "initialCells": 24},
			})


func food_total() -> float:
	var s: float = 0.0
	for p in food_patches:
		s += maxf(float(p["amount"]), 0.0)
	return s
