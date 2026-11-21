extends RefCounted
class_name FluidDynamicsModel
## Steady incompressible pipe / venturi: continuity + Bernoulli + optional head loss.
## Continuity: Q = A1 v1 = A2 v2
## Bernoulli: p/ρ + v²/2 + g z = const (+ head loss)

const RHO: float = 1000.0  # kg/m³ water
const G: float = 9.81
const MU: float = 1.0e-3   # Pa·s water ~20°C

var d1: float = 0.08   # m inlet diameter
var d2: float = 0.04   # m throat / section 2
var z1: float = 0.0    # m elevation
var z2: float = 0.0
var q: float = 0.005   # m³/s volumetric flow
var p1: float = 150_000.0  # Pa gauge-ish absolute for teaching
var f: float = 0.02    # Darcy friction factor (0 = inviscid)
var length: float = 2.0  # m between stations


func area(d: float) -> float:
	return PI * d * d * 0.25


func apply_preset(id: String) -> void:
	match id:
		"venturi":
			d1 = 0.08
			d2 = 0.04
			z1 = 0.0
			z2 = 0.0
			q = 0.006
			p1 = 180_000.0
			f = 0.0
			length = 1.0
		"pipe_loss":
			d1 = 0.05
			d2 = 0.05
			z1 = 0.0
			z2 = 0.0
			q = 0.004
			p1 = 200_000.0
			f = 0.025
			length = 12.0
		"uphill":
			d1 = 0.06
			d2 = 0.06
			z1 = 0.0
			z2 = 4.0
			q = 0.003
			p1 = 250_000.0
			f = 0.02
			length = 8.0
		"nozzle":
			d1 = 0.10
			d2 = 0.03
			z1 = 0.0
			z2 = 0.0
			q = 0.008
			p1 = 220_000.0
			f = 0.0
			length = 0.5
		_:
			d1 = 0.08
			d2 = 0.04
			z1 = 0.0
			z2 = 0.0
			q = 0.005
			p1 = 150_000.0
			f = 0.02
			length = 2.0


func solve() -> Dictionary:
	var a1: float = area(d1)
	var a2: float = area(d2)
	var v1: float = q / maxf(a1, 1e-12)
	var v2: float = q / maxf(a2, 1e-12)
	var d_avg: float = 0.5 * (d1 + d2)
	var v_avg: float = 0.5 * (v1 + v2)
	var h_l: float = 0.0
	if f > 1e-8 and length > 0.0:
		h_l = f * (length / maxf(d_avg, 1e-6)) * (v_avg * v_avg) / (2.0 * G)
	# Bernoulli → p2
	var p2: float = p1 + RHO * (0.5 * (v1 * v1 - v2 * v2) + G * (z1 - z2) - G * h_l)
	var h1: float = p1 / (RHO * G) + v1 * v1 / (2.0 * G) + z1
	var h2: float = p2 / (RHO * G) + v2 * v2 / (2.0 * G) + z2
	var re1: float = RHO * v1 * d1 / MU
	var re2: float = RHO * v2 * d2 / MU
	return {
		"A1": a1, "A2": a2,
		"v1": v1, "v2": v2,
		"p1": p1, "p2": p2,
		"hL": h_l,
		"H1": h1, "H2": h2,
		"Q": q,
		"dp": p1 - p2,
		"rho": RHO, "g": G,
		"Re1": re1, "Re2": re2,
		"d1": d1, "d2": d2,
		"z1": z1, "z2": z2,
		"f": f, "L": length,
	}
