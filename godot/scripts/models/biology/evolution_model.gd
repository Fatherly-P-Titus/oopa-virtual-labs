extends RefCounted
class_name EvolutionModel
## Finite population evolving a continuous trait under selection, mutation, and drift.
## Fitness: w(z) = exp( −(z − z_opt)² / (2 σ²) )
## Each generation: soft selection → reproduce → mutate.

const HISTORY_MAX: int = 400
const TRAIT_MIN: float = 0.0
const TRAIT_MAX: float = 1.0

var pop_size: int = 80
var mutation_rate: float = 0.15
var mutation_sd: float = 0.06
var selection_sigma: float = 0.18  # smaller = stronger selection
var optimum: float = 0.5
var optimum_speed: float = 0.0     # drift of optimum per generation
var elitism: float = 0.0           # fraction of top individuals copied unchanged

var generation: int = 0
## individuals: Array of {trait: float, fitness: float}
var individuals: Array = []

var hist_gen: Array = []
var hist_mean: Array = []
var hist_var: Array = []
var hist_opt: Array = []
var hist_mean_fit: Array = []


func reset() -> void:
	generation = 0
	individuals.clear()
	hist_gen.clear()
	hist_mean.clear()
	hist_var.clear()
	hist_opt.clear()
	hist_mean_fit.clear()
	_seed_population()
	_evaluate()
	_record()


func _seed_population() -> void:
	individuals.clear()
	for i in range(pop_size):
		# Start dispersed around 0.35 (not at optimum) so selection has work to do
		var z: float = clampf(0.35 + (randf() - 0.5) * 0.5, TRAIT_MIN, TRAIT_MAX)
		individuals.append({"trait": z, "fitness": 1.0})


func _fitness(z: float) -> float:
	var d: float = z - optimum
	var s2: float = maxf(selection_sigma * selection_sigma, 1e-6)
	return exp(-0.5 * d * d / s2)


func _evaluate() -> void:
	for i in range(individuals.size()):
		var z: float = float(individuals[i]["trait"])
		individuals[i]["fitness"] = _fitness(z)


func mean_trait() -> float:
	if individuals.is_empty():
		return 0.0
	var s: float = 0.0
	for ind in individuals:
		s += float(ind["trait"])
	return s / float(individuals.size())


func variance_trait() -> float:
	if individuals.size() < 2:
		return 0.0
	var mu: float = mean_trait()
	var s: float = 0.0
	for ind in individuals:
		var d: float = float(ind["trait"]) - mu
		s += d * d
	return s / float(individuals.size())


func mean_fitness() -> float:
	if individuals.is_empty():
		return 0.0
	var s: float = 0.0
	for ind in individuals:
		s += float(ind["fitness"])
	return s / float(individuals.size())


func _record() -> void:
	hist_gen.append(generation)
	hist_mean.append(mean_trait())
	hist_var.append(variance_trait())
	hist_opt.append(optimum)
	hist_mean_fit.append(mean_fitness())
	if hist_gen.size() > HISTORY_MAX:
		hist_gen.remove_at(0)
		hist_mean.remove_at(0)
		hist_var.remove_at(0)
		hist_opt.remove_at(0)
		hist_mean_fit.remove_at(0)


func _pick_parent() -> int:
	## Roulette wheel on fitness
	var total: float = 0.0
	for ind in individuals:
		total += maxf(float(ind["fitness"]), 1e-9)
	var r: float = randf() * total
	var acc: float = 0.0
	for i in range(individuals.size()):
		acc += maxf(float(individuals[i]["fitness"]), 1e-9)
		if acc >= r:
			return i
	return individuals.size() - 1


func step_generation() -> void:
	_evaluate()
	# Sort indices by fitness for optional elitism
	var order: Array = []
	for i in range(individuals.size()):
		order.append(i)
	order.sort_custom(func(a, b): return float(individuals[a]["fitness"]) > float(individuals[b]["fitness"]))

	var next_pop: Array = []
	var n_elite: int = int(floor(float(pop_size) * clampf(elitism, 0.0, 0.5)))
	for e in range(n_elite):
		var src: Dictionary = individuals[int(order[e])]
		next_pop.append({"trait": float(src["trait"]), "fitness": 1.0})

	while next_pop.size() < pop_size:
		var pi: int = _pick_parent()
		var z: float = float(individuals[pi]["trait"])
		if randf() < mutation_rate:
			z += randfn(0.0, mutation_sd)
		z = clampf(z, TRAIT_MIN, TRAIT_MAX)
		next_pop.append({"trait": z, "fitness": 1.0})

	individuals = next_pop
	# Moving optimum (environmental change)
	optimum = clampf(optimum + optimum_speed, TRAIT_MIN, TRAIT_MAX)
	generation += 1
	_evaluate()
	_record()


func advance(gens: int) -> void:
	for i in range(maxi(gens, 1)):
		step_generation()


func histogram(bins: int = 20) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(bins)
	counts.fill(0)
	for ind in individuals:
		var z: float = float(ind["trait"])
		var b: int = int(floor(z * float(bins)))
		b = clampi(b, 0, bins - 1)
		counts[b] = counts[b] + 1
	return counts


func status() -> String:
	var gap: float = absf(mean_trait() - optimum)
	if gap < 0.05:
		return "Population tracks the optimum closely."
	if gap < 0.15:
		return "Adapting — mean trait approaching optimum."
	if selection_sigma > 0.35:
		return "Weak selection — drift and mutation dominate."
	return "Strong mismatch — selection should pull the mean toward the optimum."


func apply_preset(id: String) -> void:
	match id:
		"strong_selection":
			pop_size = 80
			mutation_rate = 0.12
			mutation_sd = 0.05
			selection_sigma = 0.10
			optimum = 0.75
			optimum_speed = 0.0
			elitism = 0.0
			reset()
		"weak_drift":
			pop_size = 30
			mutation_rate = 0.2
			mutation_sd = 0.08
			selection_sigma = 0.40
			optimum = 0.5
			optimum_speed = 0.0
			elitism = 0.0
			reset()
		"moving_target":
			pop_size = 100
			mutation_rate = 0.2
			mutation_sd = 0.07
			selection_sigma = 0.14
			optimum = 0.2
			optimum_speed = 0.008
			elitism = 0.05
			reset()
		"stabilizing":
			pop_size = 90
			mutation_rate = 0.08
			mutation_sd = 0.04
			selection_sigma = 0.12
			optimum = 0.5
			optimum_speed = 0.0
			elitism = 0.0
			# seed already around 0.35; optimum at center
			reset()
		_:
			pop_size = 80
			mutation_rate = 0.15
			mutation_sd = 0.06
			selection_sigma = 0.18
			optimum = 0.5
			optimum_speed = 0.0
			elitism = 0.0
			reset()
