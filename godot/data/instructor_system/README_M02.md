# Milestone 02 — Authentication & Dashboard

## Entry
Main Menu → **Instructor Login**

## Credentials (seed)
- AdminStaff/001 / 12346 — all hubs
- ChemStaff/001 / Chem#2026 — chemistry only
- BioStaff/001 / Bio#2026 — biology
- PhysStaff/001 / Phys#2026 — physics
- EngStaff/001 / Eng#2026 — engineering

## Behaviour
- Fail closed on bad credentials
- Session stored in AppState.instructor_session
- Dashboard lists authorized hubs and available labs in scope
- Sign out clears session
- Exam / Roster / Grading cards are placeholders until M03–M05
- Student Exam menu button opens M04 stub

## Scenes
- res://scenes/instructor_system/login.tscn
- res://scenes/instructor_system/dashboard.tscn
