# Instructor System — Milestone 01 (Foundation)

## Locked decisions
- Storage: local (`user://oopa/` + `res://data/instructor_system/` seeds)
- Exam scope: all **available** labs in `labs_manifest.json`
- Credentials: individual staff records
- Grading: hybrid (schemas support mcq/numeric/short_text/manual/lab_task)

## Seed logins
| Staff ID | Passcode | Role |
|----------|----------|------|
| AdminStaff/001 | 12346 | admin (all hubs) |
| ChemStaff/001 | Chem#2026 | chemistry |
| BioStaff/001 | Bio#2026 | biology |
| PhysStaff/001 | Phys#2026 | physics |
| EngStaff/001 | Eng#2026 | engineering |

## Scripts
- `scripts/instructor_system/ids.gd` — IDs, access codes, matric normalize
- `scripts/instructor_system/schemas.gd` — record factories + validation
- `scripts/instructor_system/storage/local_store.gd` — load/save/list/delete
- `scripts/instructor_system/lab_adapters/manifest_labs.gd` — available labs
- `scripts/instructor_system/foundation_smoke.gd` — acceptance checks

## Runtime dirs (created on demand)
`user://oopa/{exams,rosters,attempts,grades,audit}/`

## Next
Milestone 02 — Instructor authentication and dashboard UI.
