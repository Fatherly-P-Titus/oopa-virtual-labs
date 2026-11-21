# OOPA Instructor & Examination System — Operator Guide

**Milestones M01–M06 complete** · Local storage · Individual credentials · Hybrid grading · All available labs

## Quick start

### Instructor
1. Main Menu → **Instructor Login**
2. Sign in (see credentials below)
3. **Student registration** → import CSV or create list
4. **Exams** → title, lab, duration, access code, bind roster → Create
5. Give students the **6-digit access code**
6. After attempts: **Grading** → open attempt → manual score → Save → Export CSV

### Student
1. Main Menu → **Student Exam**
2. Access code + name + matric (must be on whitelist)
3. Work within the timer; Submit (or auto-submit at 0:00)

## Credentials (seed)

| Staff ID | Passcode | Scope |
|----------|----------|--------|
| AdminStaff/001 | 12346 | All hubs (admin) |
| ChemStaff/001 | Chem#2026 | Chemistry |
| BioStaff/001 | Bio#2026 | Biology |
| PhysStaff/001 | Phys#2026 | Physics |
| EngStaff/001 | Eng#2026 | Engineering |

Change passcodes in `res://data/instructor_system/instructors.json` or override via `user://oopa/instructors_override.json`.

## CSV roster format

```
S/N,Student Name,Matric Number
1,Ada Okafor,CHEM/2024/001
```

## Data locations (`user://oopa/`)

| Folder | Contents |
|--------|----------|
| exams/ | Exam definitions |
| rosters/ | JSON + CSV mirrors |
| attempts/{exam_id}/ | Student submissions |
| grades/{exam_id}/ | Grade JSON + results.csv |
| audit/ | Login and action log |

## Security note

Local credentials and access codes are **classroom trust controls**, not cryptographic security. Protect devices and codes accordingly.

## Smoke tests (in-engine)

```gdscript
print(OopaFoundationSmoke.new().run())  # M01
print(OopaLifecycleSmoke.new().run())   # M06 full path — empty PackedStringArray = pass
```

## Science labs

Unchanged. All available labs remain selectable for exams (hub-scoped for instructors).


## Web deployment

See **SHIP_TODAY.md** in the project root.
