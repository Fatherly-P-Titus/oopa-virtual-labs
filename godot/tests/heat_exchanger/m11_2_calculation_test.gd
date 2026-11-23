extends SceneTree

const Thermal = preload("res://scripts/models/engineering/heat_exchanger/thermal_calculations.gd")
const LMTD = preload("res://scripts/models/engineering/heat_exchanger/lmtd_model.gd")
const NTU = preload("res://scripts/models/engineering/heat_exchanger/effectiveness_ntu_model.gd")
const Fouling = preload("res://scripts/models/engineering/heat_exchanger/fouling_model.gd")
const PressureDrop = preload("res://scripts/models/engineering/heat_exchanger/pressure_drop_model.gd")
const Model = preload("res://scripts/models/engineering/heat_exchanger/heat_exchanger_model.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_energy_and_resistance()
	_test_lmtd()
	_test_ntu_configurations()
	_test_fouling()
	_test_pressure_drop()
	_test_coordinated_design()
	if failures.is_empty():
		print("PASS: M11.2 heat exchanger calculation suite")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (got %.8f, expected %.8f ± %.8f)" % [message, actual, expected, tolerance])

func _test_energy_and_resistance() -> void:
	var duty: Dictionary = Thermal.stream_duty(2.0, 4180.0, 350.0, 360.0)
	_expect(duty.ok, "Valid stream duty should be accepted")
	_near(duty.q_w, 83600.0, 1.0e-6, "Q=m·Cp·ΔT example")
	var balance: Dictionary = Thermal.energy_balance(83600.0, 83000.0, 0.01)
	_expect(balance.ok and balance.balanced, "1% energy imbalance should pass a 2% limit")
	_expect(not Thermal.energy_balance(83600.0, 70000.0, 0.02).balanced, "Material energy discrepancy must be reported")
	_expect(not Thermal.stream_duty(0.0, 4180.0, 350.0, 360.0).ok, "Zero mass flow must be rejected")
	var u: Dictionary = Thermal.overall_u_w_m2_k(1.0, 100.0, 50.0, 0.001)
	_near(u.u_w_m2_k, 1.0 / 0.031, 1.0e-9, "Series thermal resistance U")
	var q: Dictionary = Thermal.duty_from_u_area(500.0, 2.0, 10.0)
	_near(q.q_w, 10000.0, 1.0e-9, "Q=U·A·LMTD example")
	_near(Thermal.duty_from_u_area(500.0, 2.0, 10.0, 0.8).q_w, 8000.0, 1.0e-9, "Corrected LMTD duty")
	_expect(not Thermal.duty_from_u_area(500.0, 2.0, 10.0, 1.1).ok, "Correction factor above one must be rejected")

func _test_lmtd() -> void:
	var parallel: Dictionary = LMTD.calculate(400.0, 350.0, 300.0, 325.0, LMTD.FlowArrangement.PARALLEL)
	_expect(parallel.ok, "Valid parallel-flow terminal differences should be accepted")
	_near(parallel.lmtd_k, 54.101064, 1.0e-5, "Parallel-flow LMTD, ΔT1=100 K and ΔT2=25 K")
	var counter: Dictionary = LMTD.calculate(400.0, 350.0, 300.0, 340.0, LMTD.FlowArrangement.COUNTER_CURRENT)
	_near(counter.lmtd_k, 54.848149, 1.0e-5, "Counter-current LMTD, ΔT1=60 K and ΔT2=50 K")
	var equal: Dictionary = LMTD.calculate(400.0, 390.0, 300.0, 290.0, LMTD.FlowArrangement.PARALLEL)
	_near(equal.lmtd_k, 100.0, 1.0e-8, "Equal terminal-difference limiting case")
	var near_equal: Dictionary = LMTD.calculate(400.0, 390.0, 300.0, 290.000001, LMTD.FlowArrangement.PARALLEL)
	_near(near_equal.lmtd_k, 99.9999995, 1.0e-6, "Nearly equal terminal-difference limiting case")
	_expect(not LMTD.calculate(400.0, 350.0, 300.0, 355.0, LMTD.FlowArrangement.PARALLEL).ok, "Temperature cross in parallel flow must be rejected")
	_expect(not LMTD.calculate(400.0, 350.0, 300.0, 320.0, 99).ok, "Unknown arrangement must be rejected")

func _test_ntu_configurations() -> void:
	var counter: Dictionary = NTU.solve(400.0, 320.0, 1000.0, 1000.0, 1000.0, NTU.Configuration.COUNTER_CURRENT)
	_expect(counter.ok, "Counter-current equal-capacity NTU case should solve")
	_near(counter.effectiveness, 0.5, 1.0e-9, "Counter-current Cr=1, NTU=1 effectiveness")
	_near(counter.q_w, 40000.0, 1.0e-6, "Counter-current known heat duty")
	_near(counter.hot_out_k, 360.0, 1.0e-9, "Counter-current hot outlet")
	_near(counter.cold_out_k, 360.0, 1.0e-9, "Counter-current cold outlet")
	var parallel: Dictionary = NTU.solve(400.0, 320.0, 1000.0, 1000.0, 1000.0, NTU.Configuration.PARALLEL_FLOW)
	_near(parallel.effectiveness, (1.0 - exp(-2.0)) / 2.0, 1.0e-9, "Parallel flow Cr=1, NTU=1 effectiveness")
	_expect(parallel.effectiveness < counter.effectiveness, "Counter-current should outperform parallel flow for this case")
	var small_ratio: Dictionary = NTU.solve(400.0, 320.0, 1.0e9, 1000.0, 1000.0, NTU.Configuration.COUNTER_CURRENT)
	_near(small_ratio.effectiveness, 1.0 - exp(-1.0), 1.0e-6, "Counter-current low capacity-ratio limit")
	var shell: Dictionary = NTU.solve(400.0, 320.0, 1000.0, 1000.0, 1000.0, NTU.Configuration.SHELL_ONE_PASS)
	_expect(shell.ok and shell.effectiveness > 0.0 and shell.effectiveness < 1.0, "One-shell-pass relation should produce bounded effectiveness")
	_expect(not NTU.solve(320.0, 400.0, 1000.0, 1000.0, 1000.0).ok, "Hot inlet below cold inlet must be rejected")
	_expect(not NTU.solve(400.0, 320.0, 1000.0, 1000.0, 1000.0, 99).ok, "Unsupported NTU configuration must be rejected")

func _test_fouling() -> void:
	var clean: Dictionary = Fouling.effective_u(500.0)
	var fouled: Dictionary = Fouling.effective_u(500.0, 0.001, 0.001)
	_near(clean.u_effective_w_m2_k, 500.0, 1.0e-9, "Clean U baseline")
	_near(fouled.u_effective_w_m2_k, 250.0, 1.0e-9, "Two-sided fouling resistance")
	_expect(fouled.reduction_fraction > 0.49, "Fouling should reduce the overall coefficient")
	_expect(not Fouling.effective_u(500.0, -0.1, 0.0).ok, "Negative fouling resistance must be rejected")

func _test_pressure_drop() -> void:
	var laminar: Dictionary = PressureDrop.calculate(0.1, 1000.0, 0.001, 10.0, 0.02, 0.01)
	_expect(laminar.ok and laminar.regime == "laminar", "Laminar passage estimate should be identified")
	_near(laminar.reynolds, 200.0, 1.0e-9, "Laminar Reynolds number")
	_near(laminar.total_drop_pa, 8.0, 1.0e-8, "Laminar Darcy-Weisbach pressure drop")
	var turbulent: Dictionary = PressureDrop.calculate(1.0, 1000.0, 0.001, 10.0, 0.05, 0.01, 0.00005, 2.0)
	_expect(turbulent.ok and turbulent.regime == "turbulent" and turbulent.total_drop_pa > 0.0, "Turbulent Haaland and minor-loss estimate")
	_expect(not PressureDrop.calculate(0.0, 1000.0, 0.001, 10.0, 0.02, 0.01).ok, "Zero mass flow must be rejected")

func _test_coordinated_design() -> void:
	var inputs := {"hot_in_k": 400.0, "cold_in_k": 300.0, "hot_mass_flow_kg_s": 1.0, "cold_mass_flow_kg_s": 1.0, "hot_cp_j_kg_k": 4000.0, "cold_cp_j_kg_k": 4000.0, "area_m2": 10.0, "u_clean_w_m2_k": 400.0, "configuration": NTU.Configuration.COUNTER_CURRENT}
	var result: Dictionary = Model.solve_design(inputs)
	_expect(result.ok, "Valid coordinated design should solve")
	_expect(result.energy_balance.balanced, "Computed outlet temperatures should conserve energy")
	_expect(result.heat_duty_w > 0.0 and result.hot_out_k < 400.0 and result.cold_out_k > 300.0, "Coordinated model outputs should be physical")
	_expect(result.has("lmtd_k") and result.has("ua_lmtd_duty_w"), "Double-pipe arrangements should report LMTD and UA duty")
	var shell_inputs := inputs.duplicate(true)
	shell_inputs["configuration"] = NTU.Configuration.SHELL_ONE_PASS
	var shell_result: Dictionary = Model.solve_design(shell_inputs)
	_expect(shell_result.ok and not shell_result.has("lmtd_k"), "Shell-pass model must not publish uncorrected counter-current LMTD")
	var fouled_inputs := inputs.duplicate(true)
	fouled_inputs["fouling_hot_m2_k_w"] = 0.001
	var fouled_result: Dictionary = Model.solve_design(fouled_inputs)
	_expect(fouled_result.ok and fouled_result.heat_duty_w < result.heat_duty_w, "Fouling must lower calculated heat duty")
	_expect(not Model.solve_design({}).ok, "Missing design inputs must be rejected")
