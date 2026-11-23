extends RefCounted
class_name HeatExchangerPressureDrop

static func calculate(mass_flow_kg_s: float, density_kg_m3: float, viscosity_pa_s: float, length_m: float, hydraulic_diameter_m: float, area_flow_m2: float, roughness_m: float = 0.0, minor_loss_k: float = 0.0) -> Dictionary:
	for value in [mass_flow_kg_s, density_kg_m3, viscosity_pa_s, length_m, hydraulic_diameter_m, area_flow_m2, roughness_m, minor_loss_k]:
		if not is_finite(value): return _fail("All pressure-drop inputs must be finite.")
	if mass_flow_kg_s <= 0.0 or density_kg_m3 <= 0.0 or viscosity_pa_s <= 0.0 or length_m < 0.0 or hydraulic_diameter_m <= 0.0 or area_flow_m2 <= 0.0 or roughness_m < 0.0 or minor_loss_k < 0.0:
		return _fail("Require positive flow, density, viscosity, diameter and area; length, roughness and minor-loss K cannot be negative.")
	var velocity := mass_flow_kg_s / (density_kg_m3 * area_flow_m2)
	var reynolds := density_kg_m3 * velocity * hydraulic_diameter_m / viscosity_pa_s
	var friction := 0.0
	if reynolds < 2300.0:
		friction = 64.0 / reynolds
	else:
		# Haaland explicit approximation to Darcy friction factor for turbulent flow.
		friction = pow(-1.8 * log(pow(roughness_m / (3.7 * hydraulic_diameter_m), 1.11) + 6.9 / reynolds) / log(10.0), -2.0)
	var dynamic_pressure := 0.5 * density_kg_m3 * velocity * velocity
	var major := friction * length_m / hydraulic_diameter_m * dynamic_pressure
	var minor := minor_loss_k * dynamic_pressure
	var regime := "laminar" if reynolds < 2300.0 else ("transitional; estimate uncertain" if reynolds < 4000.0 else "turbulent")
	return {"ok": true, "velocity_m_s": velocity, "reynolds": reynolds, "darcy_friction_factor": friction, "major_drop_pa": major, "minor_drop_pa": minor, "total_drop_pa": major + minor, "regime": regime, "assumption": "Single straight equivalent passage using Darcy–Weisbach; laminar f=64/Re, turbulent Haaland correlation, and user-supplied aggregate minor-loss K. Not a detailed shell-and-tube rating method."}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
