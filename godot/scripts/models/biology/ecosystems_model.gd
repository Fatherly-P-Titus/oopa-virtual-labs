extends RefCounted
class_name EcosystemsModel
## Simple 4-compartment ecosystem with nutrient recycling.
## N nutrients → P producers → H herbivores → C carnivores → detritus → N

const DT: float = 0.02
const HISTORY_MAX: int = 600
const CAP: float = 1e5

# Rates
var nutrient_input: float = 2.0    # external nutrient influx
var recycle_rate: float = 0.15     # detritus → nutrients
var plant_growth: float = 0.35     # max growth rate of producers
var half_sat: float = 8.0          # Monod half-saturation for N
var graze: float = 0.02            # herbivore grazing rate
var pred: float = 0.025            # carnivore predation rate
var eff_h: float = 0.4             # plant → herbivore efficiency
var eff_c: float = 0.3             # herbivore → carnivore efficiency
var death_p: float = 0.05
var death_h: float = 0.08
var death_c: float = 0.12

# State
var n: float = 20.0   # nutrients
var p: float = 30.0   # producers
var h: float = 12.0   # herbivores
var c: float = 4.0    # carnivores
var d: float = 5.0    # detritus
var t: float = 0.0

var hist_t: Array = []
var hist_n: Array = []
var hist_p: Array = []
var hist_h: Array = []
var hist_c: Array = []
var hist_d: Array = []


func reset(n0: float = 20.0, p0: float = 30.0, h0: float = 12.0, c0: float = 4.0, d0: float = 5.0) -> void:
	n = n0; p = p0; h = h0; c = c0; d = d0
	t = 0.0
	hist_t.clear(); hist_n.clear(); hist_p.clear(); hist_h.clear(); hist_c.clear(); hist_d.clear()
	_record()


func _record() -> void:
	hist_t.append(t)
	hist_n.append(n)
	hist_p.append(p)
	hist_h.append(h)
	hist_c.append(c)
	hist_d.append(d)
	if hist_t.size() > HISTORY_MAX:
		hist_t.remove_at(0)
		hist_n.remove_at(0)
		hist_p.remove_at(0)
		hist_h.remove_at(0)
		hist_c.remove_at(0)
		hist_d.remove_at(0)


func _f(nn: float, pp: float, hh: float, cc: float, dd: float) -> PackedFloat32Array:
	var monod: float = nn / (half_sat + maxf(nn, 0.0))
	var grow: float = plant_growth * monod * pp
	var grazed: float = graze * hh * pp
	var eaten: float = pred * cc * hh
	var dn: float = nutrient_input + recycle_rate * dd - grow
	var dp: float = grow - grazed - death_p * pp
	var dh: float = eff_h * grazed - eaten - death_h * hh
	var dc: float = eff_c * eaten - death_c * cc
	var dd_det: float = death_p * pp + death_h * hh + death_c * cc + (1.0 - eff_h) * grazed + (1.0 - eff_c) * eaten - recycle_rate * dd
	var out := PackedFloat32Array()
	out.resize(5)
	out[0] = dn; out[1] = dp; out[2] = dh; out[3] = dc; out[4] = dd_det
	return out


func step(dt: float = DT) -> void:
	var k1 := _f(n, p, h, c, d)
	var k2 := _f(n + 0.5 * dt * k1[0], p + 0.5 * dt * k1[1], h + 0.5 * dt * k1[2], c + 0.5 * dt * k1[3], d + 0.5 * dt * k1[4])
	var k3 := _f(n + 0.5 * dt * k2[0], p + 0.5 * dt * k2[1], h + 0.5 * dt * k2[2], c + 0.5 * dt * k2[3], d + 0.5 * dt * k2[4])
	var k4 := _f(n + dt * k3[0], p + dt * k3[1], h + dt * k3[2], c + dt * k3[3], d + dt * k3[4])
	n += dt / 6.0 * (k1[0] + 2.0 * k2[0] + 2.0 * k3[0] + k4[0])
	p += dt / 6.0 * (k1[1] + 2.0 * k2[1] + 2.0 * k3[1] + k4[1])
	h += dt / 6.0 * (k1[2] + 2.0 * k2[2] + 2.0 * k3[2] + k4[2])
	c += dt / 6.0 * (k1[3] + 2.0 * k2[3] + 2.0 * k3[3] + k4[3])
	d += dt / 6.0 * (k1[4] + 2.0 * k2[4] + 2.0 * k3[4] + k4[4])
	n = clampf(n, 0.0, CAP)
	p = clampf(p, 0.0, CAP)
	h = clampf(h, 0.0, CAP)
	c = clampf(c, 0.0, CAP)
	d = clampf(d, 0.0, CAP)
	t += dt
	_record()


func advance(years: float) -> void:
	var steps: int = int(ceil(years / DT))
	for i in range(steps):
		step(DT)


func total_biomass() -> float:
	return p + h + c


func status() -> String:
	if p <= 0.05 and h <= 0.05 and c <= 0.05:
		return "Collapse — living biomass nearly gone."
	if c <= 0.05 and h > 1.0:
		return "Carnivores scarce — herbivores may overgraze."
	if h <= 0.05 and p > 1.0:
		return "Herbivores scarce — producers dominate."
	if n < half_sat * 0.5:
		return "Nutrient stress — plant growth limited."
	return "Food web active — energy moving up the chain."


func apply_preset(id: String) -> void:
	match id:
		"grassland":
			nutrient_input = 2.0; recycle_rate = 0.15; plant_growth = 0.4
			half_sat = 8.0; graze = 0.02; pred = 0.025
			eff_h = 0.4; eff_c = 0.3
			death_p = 0.05; death_h = 0.08; death_c = 0.12
			reset(18.0, 35.0, 14.0, 5.0, 6.0)
		"ocean":
			nutrient_input = 1.2; recycle_rate = 0.2; plant_growth = 0.5
			half_sat = 6.0; graze = 0.03; pred = 0.03
			eff_h = 0.35; eff_c = 0.25
			death_p = 0.08; death_h = 0.1; death_c = 0.14
			reset(12.0, 25.0, 10.0, 3.5, 8.0)
		"overfish":
			nutrient_input = 2.0; recycle_rate = 0.12; plant_growth = 0.35
			half_sat = 8.0; graze = 0.025; pred = 0.06
			eff_h = 0.4; eff_c = 0.25
			death_p = 0.05; death_h = 0.08; death_c = 0.25
			reset(20.0, 40.0, 18.0, 2.0, 5.0)
		"bloom":
			nutrient_input = 6.0; recycle_rate = 0.1; plant_growth = 0.55
			half_sat = 5.0; graze = 0.015; pred = 0.02
			eff_h = 0.35; eff_c = 0.3
			death_p = 0.04; death_h = 0.09; death_c = 0.12
			reset(40.0, 15.0, 6.0, 2.0, 4.0)
		_:
			nutrient_input = 2.0; recycle_rate = 0.15; plant_growth = 0.35
			half_sat = 8.0; graze = 0.02; pred = 0.025
			eff_h = 0.4; eff_c = 0.3
			death_p = 0.05; death_h = 0.08; death_c = 0.12
			reset(20.0, 30.0, 12.0, 4.0, 5.0)
