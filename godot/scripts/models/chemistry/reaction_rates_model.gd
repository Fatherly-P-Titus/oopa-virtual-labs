extends RefCounted
class_name ReactionRatesModel
## A → products. Rate = k [A]^n for n = 0, 1, 2.
## Optional Arrhenius: k = Af · exp(-Ea / RT)

const R: float = 8.314  # J/(mol·K)

var order: int = 1  # 0 | 1 | 2
var a0: float = 1.0  # mol/L
var k: float = 0.05  # units depend on order
var t_kelvin: float = 298.0
var ea: float = 50_000.0  # J/mol
var af: float = 0.0
var use_arrhenius: bool = false

func effective_k() -> float:
	if use_arrhenius and af > 0.0:
		return af * exp(-ea / (R * maxf(t_kelvin, 1.0)))
	return k

func concentration(t: float) -> float:
	t = maxf(t, 0.0)
	var kk := effective_k()
	match order:
		0:
			return maxf(0.0, a0 - kk * t)
		1:
			return a0 * exp(-kk * t)
		2:
			return a0 / (1.0 + kk * a0 * t)
	return a0

func half_life() -> float:
	var kk := effective_k()
	if kk <= 0.0:
		return INF
	match order:
		0:
			return a0 / (2.0 * kk)
		1:
			return log(2.0) / kk
		2:
			return 1.0 / (kk * a0)
	return INF

func rate_at(t: float) -> float:
	var a := concentration(t)
	var kk := effective_k()
	match order:
		0:
			return kk if a > 0.0 else 0.0
		1:
			return kk * a
		2:
			return kk * a * a
	return 0.0

func series(t_max: float, n: int = 200) -> Array:
	t_max = maxf(t_max, 1e-6)
	var out: Array = []
	for i in range(n + 1):
		var t := (float(i) / float(n)) * t_max
		out.append({"t": t, "a": concentration(t), "rate": rate_at(t)})
	return out

func auto_t_max() -> float:
	var hl := half_life()
	if not is_finite(hl) or hl <= 0.0:
		return 60.0
	return clampf(hl * 4.0, 10.0, 300.0)

func calibrate_arrhenius(t_ref: float = -1.0) -> void:
	if t_ref < 0.0:
		t_ref = t_kelvin
	af = k * exp(ea / (R * maxf(t_ref, 1.0)))
	use_arrhenius = true

func set_order(n: int) -> void:
	order = clampi(n, 0, 2)
	# sensible default k per order (web parity)
	match order:
		0:
			k = 0.02
		1:
			k = 0.05
		2:
			k = 0.1
	if use_arrhenius:
		calibrate_arrhenius()

func k_units() -> String:
	match order:
		0:
			return "mol·L⁻¹·s⁻¹"
		1:
			return "s⁻¹"
		2:
			return "L·mol⁻¹·s⁻¹"
	return ""

func order_name() -> String:
	match order:
		0:
			return "Zero-order"
		1:
			return "First-order"
		2:
			return "Second-order"
	return ""
