# Implementation Plan

Tracked roughly in dependency order. Each step is sized to be testable on its own.

## Phase 0 — Scaffolding (this session)
- [x] Folder layout for `shared/`, `mobile/`, `desktop/`
- [x] `pubspec.yaml` for each package with the production dependencies pinned
- [x] Shared models + protocol so both apps compile against the same types
- [x] Desktop entry point that boots the embedded server and shows a stub dashboard
- [x] Mobile entry point with a Connect screen and a "fake scan submit" button
      that proves the socket path end-to-end

## Phase 1 — Real DB + server
- [ ] `desktop/lib/db/database.dart` opens SQLite via `sqflite_common_ffi`,
      runs migrations from `db/migrations/`
- [ ] Seed data: one section, a handful of students, one demo exam + key
- [ ] `desktop/lib/server/handlers.dart` implements `/exams`, `/exams/:id`, `/scans`
- [ ] `desktop/lib/server/broadcast.dart` fan-out for `ScoreBroadcast`
- [ ] Connectivity dashboard: bound IP, port, connected devices, pairing code

## Phase 2 — Sheet generator + QR
- [ ] `desktop/lib/pdf/answer_sheet.dart` lays out header, fiducials, QR, bubble grid
- [ ] `desktop/lib/pdf/bubble_layout.dart` computes circle/box positions for n items × c choices
- [ ] "Generate sheets" screen: pick exam → produces one PDF per section, prints

## Phase 3 — Mobile scan pipeline
- [ ] Connect screen: scan desktop pairing QR (URL + code) → save in Hive
- [ ] Capture screen: camera preview, capture full-res still
- [ ] `omr/perspective.dart` paper detect + warp (OpenCV via `opencv_dart`)
- [ ] `omr/fiducials.dart` corner-square detect → grid anchor
- [ ] `omr/bubble_grid.dart` ROI crop + dark-pixel ratio per cell
- [ ] `omr/grader.dart` compare to cached answer key → score
- [ ] Result screen: preview answers, confirm, submit via `sync_socket.dart`

## Phase 4 — Class record + export
- [ ] `class_record` screen: pivoted DataTable, students × exams, totals/avg/rank
- [ ] Live updates via `ScoreBroadcast` stream
- [ ] Excel export (`excel` package), PDF export (`printing` + `pdf`)

## Phase 5 — Hardening
- [ ] Pairing code enforcement on `hello`
- [ ] Rescans: UPSERT on `(exam_id, student_id)`, surface "replaced" in UI
- [ ] Offline queue on mobile when socket is down; replay on reconnect
- [ ] OMR threshold tuning UI per exam
- [ ] Multi-device live feed: tag broadcasts with `device_id`, show in UI
