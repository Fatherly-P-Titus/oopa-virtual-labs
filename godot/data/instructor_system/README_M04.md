# Milestone 04 — Student examination runtime

## Flow
1. Instructor creates exam + roster (M03)
2. Student: Main Menu → Student Exam
3. Enter access code, name, matric
4. Eligibility + duplicate-submit checks
5. Timed session; save progress every 5s; Submit or auto-submit on expiry
6. Attempt JSON under user://oopa/attempts/{exam_id}/

## Rules
- Roster required (not on list → denied)
- Already submitted/expired for same matric → denied
- Timer auto-submit reason = expired
