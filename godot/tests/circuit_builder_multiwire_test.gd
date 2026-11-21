extends SceneTree

const CircuitModelScript = preload("res://scripts/models/engineering/circuit_model.gd")

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_parallel_five_leds()
	_test_series_three_leds()
	_test_capacitor_transient_charge()
	_test_inductor_transient_current()
	_test_potentiometer_wiper_control()
	_test_fuse_overcurrent_trip()
	_test_motor_startup_and_back_emf()
	_test_lamp_thermal_warmup()
	_test_npn_transistor_switching()
	if failures == 0:
		print("PASS: Circuit Builder multi-wire regression tests")
	else:
		push_error("FAIL: %d Circuit Builder regression test(s) failed" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _test_parallel_five_leds() -> void:
	var model = CircuitModelScript.new()
	var battery: Dictionary = model.add_chip(CircuitModelScript.Kind.BAT, 0, 0, 9.0)
	var leds: Array = []
	for i in range(5):
		leds.append(model.add_chip(CircuitModelScript.Kind.LEDO, i + 1, 0))
	for led in leds:
		var w_pos: Dictionary = model.add_wire(model.port_id(int(battery.id), 0), model.port_id(int(led.id), 0))
		var w_neg: Dictionary = model.add_wire(model.port_id(int(led.id), 1), model.port_id(int(battery.id), 1))
		_check(not w_pos.is_empty() and not w_neg.is_empty(), "parallel branch wires accepted")
	_check(model.port_connection_count(model.port_id(int(battery.id), 0)) == 5, "one port accepts five wires")
	_check(model.port_connection_count(model.port_id(int(battery.id), 1)) == 5, "second port accepts five wires")
	var all_lit: bool = true
	for led in leds:
		all_lit = all_lit and bool(led.get("lit", false))
	_check(all_lit, "five parallel LED branches solve and illuminate")

func _test_series_three_leds() -> void:
	var model = CircuitModelScript.new()
	var battery: Dictionary = model.add_chip(CircuitModelScript.Kind.BAT, 0, 0, 9.0)
	var l1: Dictionary = model.add_chip(CircuitModelScript.Kind.LEDO, 1, 0)
	var l2: Dictionary = model.add_chip(CircuitModelScript.Kind.LEDO, 2, 0)
	var l3: Dictionary = model.add_chip(CircuitModelScript.Kind.LEDO, 3, 0)
	var ports: Array = [
		[model.port_id(int(battery.id), 0), model.port_id(int(l1.id), 0)],
		[model.port_id(int(l1.id), 1), model.port_id(int(l2.id), 0)],
		[model.port_id(int(l2.id), 1), model.port_id(int(l3.id), 0)],
		[model.port_id(int(l3.id), 1), model.port_id(int(battery.id), 1)],
	]
	var connected: bool = true
	for pair in ports:
		connected = connected and not model.add_wire(str(pair[0]), str(pair[1])).is_empty()
	_check(connected, "series loop wires accepted")
	_check(bool(l1.get("lit", false)) and bool(l2.get("lit", false)) and bool(l3.get("lit", false)), "three series LEDs solve and illuminate")


func _test_capacitor_transient_charge() -> void:
	var model = CircuitModelScript.new()
	var battery: Dictionary = model.add_chip(CircuitModelScript.Kind.BAT, 0, 0, 9.0)
	var resistor: Dictionary = model.add_chip(CircuitModelScript.Kind.R, 1, 0, 330.0)
	var capacitor: Dictionary = model.add_chip(CircuitModelScript.Kind.CAP, 2, 0, 100.0)
	var connected: bool = true
	connected = connected and not model.add_wire(model.port_id(int(battery.id), 0), model.port_id(int(resistor.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(resistor.id), 1), model.port_id(int(capacitor.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(capacitor.id), 1), model.port_id(int(battery.id), 1)).is_empty()
	_check(connected, "capacitor charging loop wires accepted")
	var initial_voltage: float = float(model.capacitor_voltage.get(int(capacitor.id), 0.0))
	model.step(0.016)
	var first_voltage: float = float(model.chip_v.get(int(capacitor.id), 0.0))
	var first_current: float = absf(float(model.chip_i.get(int(capacitor.id), 0.0)))
	_check(first_voltage > initial_voltage, "capacitor voltage rises during charging")
	_check(first_current > 0.001, "capacitor draws transient charging current")
	for _i in range(300):
		model.step(0.016)
	var final_voltage: float = float(model.chip_v.get(int(capacitor.id), 0.0))
	var final_current: float = absf(float(model.chip_i.get(int(capacitor.id), 0.0)))
	_check(final_voltage > first_voltage and final_voltage <= 9.1, "capacitor voltage approaches battery voltage")
	_check(final_current < first_current, "capacitor current decays as it charges")

func _test_inductor_transient_current() -> void:
	var model = CircuitModelScript.new()
	var battery: Dictionary = model.add_chip(CircuitModelScript.Kind.BAT, 0, 0, 9.0)
	var resistor: Dictionary = model.add_chip(CircuitModelScript.Kind.R, 1, 0, 10.0)
	var inductor: Dictionary = model.add_chip(CircuitModelScript.Kind.IND, 2, 0, 100.0)
	var connected: bool = true
	connected = connected and not model.add_wire(model.port_id(int(battery.id), 0), model.port_id(int(resistor.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(resistor.id), 1), model.port_id(int(inductor.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(inductor.id), 1), model.port_id(int(battery.id), 1)).is_empty()
	_check(connected, "inductor series loop wires accepted")
	model.step(0.001)
	var first_current: float = absf(float(model.chip_i.get(int(inductor.id), 0.0)))
	_check(first_current > 0.001, "inductor current begins rising after power is applied")
	for _i in range(20):
		model.step(0.001)
	var later_current: float = absf(float(model.chip_i.get(int(inductor.id), 0.0)))
	_check(later_current > first_current, "inductor current rises progressively during energization")
	_check(later_current < 1.0, "inductor current remains within the circuit's steady-state limit")


func _test_potentiometer_wiper_control() -> void:
	var model = CircuitModelScript.new()
	var battery: Dictionary = model.add_chip(CircuitModelScript.Kind.BAT, 0, 0, 9.0)
	var pot: Dictionary = model.add_chip(CircuitModelScript.Kind.POT, 1, 0, 10000.0)
	var load: Dictionary = model.add_chip(CircuitModelScript.Kind.R, 2, 0, 100000.0)
	var connected: bool = true
	connected = connected and not model.add_wire(model.port_id(int(battery.id), 0), model.port_id(int(pot.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(pot.id), 1), model.port_id(int(battery.id), 1)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(pot.id), 2), model.port_id(int(load.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(load.id), 1), model.port_id(int(battery.id), 1)).is_empty()
	_check(model.port_count(CircuitModelScript.Kind.POT) == 3, "potentiometer exposes two track ends and a wiper")
	_check(connected, "potentiometer divider loop wires accepted")
	pot["wiper"] = 0.25
	model.solve()
	var quarter_voltage: float = absf(float(model.chip_v.get(int(load.id), 0.0)))
	pot["wiper"] = 0.75
	model.solve()
	var three_quarter_voltage: float = absf(float(model.chip_v.get(int(load.id), 0.0)))
	_check(quarter_voltage > three_quarter_voltage, "moving potentiometer wiper changes divider output voltage")
	_check(quarter_voltage > 4.0 and three_quarter_voltage < 4.0, "potentiometer output responds across wiper positions")


func _test_fuse_overcurrent_trip() -> void:
	var model = CircuitModelScript.new()
	var battery: Dictionary = model.add_chip(CircuitModelScript.Kind.BAT, 0, 0, 9.0)
	var fuse: Dictionary = model.add_chip(CircuitModelScript.Kind.FUSE, 1, 0, 0.5)
	var resistor: Dictionary = model.add_chip(CircuitModelScript.Kind.R, 2, 0, 10.0)
	var connected: bool = true
	connected = connected and not model.add_wire(model.port_id(int(battery.id), 0), model.port_id(int(fuse.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(fuse.id), 1), model.port_id(int(resistor.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(resistor.id), 1), model.port_id(int(battery.id), 1)).is_empty()
	_check(model.port_count(CircuitModelScript.Kind.FUSE) == 2, "fuse exposes two terminals")
	_check(connected, "fuse series loop wires accepted")
	_check(bool(fuse.get("blown", false)), "fuse opens automatically when current exceeds its rating")
	_check(absf(float(model.chip_i.get(int(fuse.id), 0.0))) < 0.001, "blown fuse interrupts branch current")
	fuse["blown"] = false
	resistor.value = 100.0
	model.solve()
	_check(not bool(fuse.get("blown", false)), "fuse remains intact below its current rating")
	_check(absf(float(model.chip_i.get(int(fuse.id), 0.0))) < 0.5, "safe current passes through intact fuse")


func _test_motor_startup_and_back_emf() -> void:
	var model = CircuitModelScript.new()
	var battery: Dictionary = model.add_chip(CircuitModelScript.Kind.BAT, 0, 0, 9.0)
	var motor: Dictionary = model.add_chip(CircuitModelScript.Kind.MOTOR, 1, 0, 12.0)
	var connected: bool = true
	connected = connected and not model.add_wire(model.port_id(int(battery.id), 0), model.port_id(int(motor.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(motor.id), 1), model.port_id(int(battery.id), 1)).is_empty()
	_check(model.port_count(CircuitModelScript.Kind.MOTOR) == 2, "motor exposes two electrical terminals")
	_check(connected, "motor supply loop wires accepted")
	model.step(0.016)
	var first_current: float = absf(float(model.chip_i.get(int(motor.id), 0.0)))
	var first_speed: float = float(model.motor_speed.get(int(motor.id), 0.0))
	_check(first_current > 0.1, "motor draws startup current")
	_check(first_speed > 0.0, "motor rotor begins accelerating when powered")
	for _i in range(120):
		model.step(0.016)
	var later_current: float = absf(float(model.chip_i.get(int(motor.id), 0.0)))
	var later_speed: float = float(model.motor_speed.get(int(motor.id), 0.0))
	_check(later_speed > first_speed, "motor speed increases during startup")
	_check(later_current < first_current, "motor current decreases as back-EMF builds")
	_check(later_speed <= 1.0, "motor speed remains within the normalized limit")


func _test_lamp_thermal_warmup() -> void:
	var model = CircuitModelScript.new()
	var battery: Dictionary = model.add_chip(CircuitModelScript.Kind.BAT, 0, 0, 9.0)
	var lamp: Dictionary = model.add_chip(CircuitModelScript.Kind.LAMP, 1, 0, 12.0)
	var connected: bool = true
	connected = connected and not model.add_wire(model.port_id(int(battery.id), 0), model.port_id(int(lamp.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(lamp.id), 1), model.port_id(int(battery.id), 1)).is_empty()
	_check(model.port_count(CircuitModelScript.Kind.LAMP) == 2, "lamp exposes two electrical terminals")
	_check(connected, "lamp supply loop wires accepted")
	model.step(0.016)
	var first_temp: float = float(model.lamp_temperature.get(int(lamp.id), 0.0))
	var first_current: float = absf(float(model.chip_i.get(int(lamp.id), 0.0)))
	_check(first_temp > 0.0, "lamp filament begins warming when powered")
	_check(first_current > 0.1, "cold lamp draws startup current")
	for _i in range(120):
		model.step(0.016)
	var later_temp: float = float(model.lamp_temperature.get(int(lamp.id), 0.0))
	var later_current: float = absf(float(model.chip_i.get(int(lamp.id), 0.0)))
	_check(later_temp > first_temp, "lamp filament temperature rises over time")
	_check(bool(lamp.get("lit", false)), "lamp visibly reaches glowing state")
	_check(later_current < first_current, "lamp current falls as filament resistance rises")
	var hot_temp: float = later_temp
	model.remove_wire(int(model.wires[0].id))
	for _i in range(30):
		model.step(0.016)
	_check(float(model.lamp_temperature.get(int(lamp.id), 0.0)) < hot_temp, "lamp cools after power is disconnected")


func _test_npn_transistor_switching() -> void:
	var model = CircuitModelScript.new()
	var battery: Dictionary = model.add_chip(CircuitModelScript.Kind.BAT, 0, 0, 9.0)
	var base_resistor: Dictionary = model.add_chip(CircuitModelScript.Kind.R, 1, 0, 4700.0)
	var collector_resistor: Dictionary = model.add_chip(CircuitModelScript.Kind.R, 2, 0, 100.0)
	var transistor: Dictionary = model.add_chip(CircuitModelScript.Kind.TRANSISTOR, 3, 0, 100.0)
	var connected: bool = true
	connected = connected and not model.add_wire(model.port_id(int(battery.id), 0), model.port_id(int(base_resistor.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(base_resistor.id), 1), model.port_id(int(transistor.id), 1)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(battery.id), 0), model.port_id(int(collector_resistor.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(collector_resistor.id), 1), model.port_id(int(transistor.id), 0)).is_empty()
	connected = connected and not model.add_wire(model.port_id(int(transistor.id), 2), model.port_id(int(battery.id), 1)).is_empty()
	_check(model.port_count(CircuitModelScript.Kind.TRANSISTOR) == 3, "NPN transistor exposes collector, base, and emitter terminals")
	_check(connected, "transistor common-emitter circuit wiring accepted")
	_check(float(model.transistor_base_current.get(int(transistor.id), 0.0)) > 0.0001, "base-emitter junction conducts when forward biased")
	_check(float(model.transistor_collector_current.get(int(transistor.id), 0.0)) > 0.01, "base drive controls collector current through load")
	var driven_current: float = float(model.transistor_collector_current.get(int(transistor.id), 0.0))
	base_resistor.value = 100000.0
	model.solve()
	_check(float(model.transistor_collector_current.get(int(transistor.id), 0.0)) < driven_current, "reducing base drive reduces transistor collector current")
