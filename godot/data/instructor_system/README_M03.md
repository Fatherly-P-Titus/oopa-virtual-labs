# Milestone 03 — Exam creation & student registration

## Paths
- Exam editor: res://scenes/instructor_system/exam_editor.tscn
- Roster manager: res://scenes/instructor_system/roster_manager.tscn
- Services: exam_service.gd, roster_service.gd

## Flow
1. Login as instructor
2. Dashboard → Student registration → import CSV or create empty list
3. Dashboard → Exams → set title, hub, lab, duration, code, bind roster → Create
4. Exam listed with access code; eligibility = roster membership (M04 will enforce at entry)

## CSV format
S/N,Student Name,Matric Number
