# M11.2 Calculation Engine — Inputs, Validation, and Evidence

All calculations are pure static model functions under `res://scripts/models/engineering/heat_exchanger/`. They use SI units: temperatures in K, mass flow in kg/s, heat capacity in J/(kg·K), area in m², U in W/(m²·K), heat duty in W, hydraulic properties in SI, and pressure drop in Pa. Invalid or non-finite inputs return `{ "ok": false, "error": ... }`; they do not return fabricated values.

## Implemented models

- `thermal_calculations.gd`: signed stream heat `Q = ṁ Cp (Tout − Tin)`; hot/cold duty discrepancy `|Qh−Qc|`; resistance-series `U = 1 / (1/hh + Rwall + 1/hc + Rf,h + Rf,c)`; and `Q = U A F ΔTlm`, requiring `0 < F ≤ 1`.
- `lmtd_model.gd`: parallel and counter-current terminal differences and `ΔTlm = (ΔT1−ΔT2)/ln(ΔT1/ΔT2)`. Nearly equal endpoints use the arithmetic-mean limit. Non-positive terminal differences and absolute temperatures at/below zero are rejected.
- `effectiveness_ntu_model.gd`: `C = ṁCp`, `Cmin`, `Cmax`, `Cr`, `NTU = UA/Cmin`, `Qmax = Cmin(Th,in−Tc,in)`, supported effectiveness relations, heat duty and both outlet temperatures. Configurations are counter-current, parallel-flow and ideal one-shell-pass.
- `fouling_model.gd`: `Ueff = 1/(1/Uclean + Rf,h + Rf,c)`. Fouling resistances must be finite and non-negative.
- `pressure_drop_model.gd`: a single equivalent straight passage using Darcy–Weisbach, laminar Darcy factor `64/Re`, turbulent Haaland explicit factor, and an optional aggregate minor-loss K. Geometry is supplied through flow area and hydraulic diameter.
- `heat_exchanger_model.gd`: coordinates inlet/flow/property/area/U inputs, fouling-adjusted UA, the selected supported E-NTU relation, outlet-derived energy balance, and LMTD/UA-duty cross-check for parallel and counter-current configurations.

## Known-value regression cases

Run `godot --headless --path . --script res://tests/heat_exchanger/m11_2_calculation_test.gd` from the Godot project root.

| Case | Inputs | Expected / tolerance |
| --- | --- | --- |
| Stream heat | 2 kg/s, 4180 J/(kg·K), ΔT=10 K | 83,600 W; 1e-6 W |
| Series U | hh=100, hc=50 W/(m²·K), Rwall=0.001 m²K/W | 32.2580645 W/(m²·K); 1e-9 |
| LMTD, parallel | ΔT1=100 K, ΔT2=25 K | 54.101064 K; 1e-5 K |
| LMTD, counter-current | ΔT1=60 K, ΔT2=50 K | 54.848149 K; 1e-5 K |
| LMTD limit | ΔT1=ΔT2=100 K | 100 K; 1e-8 K |
| E-NTU, counter-current | Cr=1, NTU=1, inlet ΔT=80 K | ε=0.5, Q=40,000 W, both outlets 360 K |
| E-NTU, parallel | Cr=1, NTU=1 | ε=(1−e⁻²)/2≈0.432332 |
| Fouling | Uclean=500, Rf,h=Rf,c=0.001 m²K/W | Ueff=250 W/(m²·K) |
| Laminar passage | ṁ=.1 kg/s, ρ=1000 kg/m³, μ=.001 Pa·s, L=10 m, Dh=.02 m, A=.01 m² | Re=200, ΔP=8 Pa |

The suite also checks invalid flow, temperature crossing, unsupported configurations, non-physical correction factors, negative fouling, pressure input validation, capacity-ratio limiting behavior, energy balance, fouling response, and coordinated output consistency.

## Assumptions and limitations

- Steady-state, single-phase, adiabatic exchanger streams with constant user-supplied heat capacities and properties. Phase change, heat loss to ambient, variable properties, viscosity/thermal-conductivity property tables, and transient storage are not modeled.
- The one-shell-pass effectiveness relation is the supported ideal shell-side relation. No multi-shell, multipass tube-side correction, Bell–Delaware rating, or LMTD correction-factor chart is implemented. The coordinator therefore uses E-NTU for one-shell-pass and deliberately omits an uncorrected counter-current LMTD result for that configuration.
- The pressure-drop correlation estimates a single equivalent passage. Transitional flow (2300≤Re<4000) is flagged uncertain. It is not a detailed shell-and-tube hydraulic rating; baffle-window/crossflow, tube-pass partition, nozzle, entrance, exit and distributed fitting losses are not inferred. Users must supply equivalent passage geometry and aggregate minor-loss K.
- Design inputs are not yet exposed in the M11.1 scene. M11.2 is a calculation-engine phase only; equipment views, instruments and student-facing controls remain future work.
