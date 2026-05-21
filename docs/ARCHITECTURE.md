# Offline OMR Grading System — Architecture

## 1. Overview
Three components, all offline:

- **mobile/** — Flutter Android app. Scans printed answer sheets, decodes the student QR, runs OMR on shaded bubbles, computes the score, and submits it.
- **desktop/** — Flutter Desktop app. Hosts an embedded local server (HTTP + WebSocket), owns the SQLite database, generates printable PDF answer sheets, and displays the class record in real time.
- **shared/** — Pure-Dart package with the data models and wire protocol used by both apps. Single source of truth.

Network path: phone is the **hotspot**, laptop joins the hotspot Wi-Fi, mobile app talks to `ws://<laptop-ip>:4040/sync`.

## 2. Data Flow

```
[Camera frame] → [Perspective correct] → [QR decode] → [Bubble pixel ratio]
       → [Score vs answer key] → [WebSocket /sync] → [Desktop writes scan row]
       → [Desktop broadcasts score] → [Class record UI updates]
```

## 3. Database (SQLite, owned by desktop)

```sql
sections(id, name, school_year, created_at)
students(id, student_no UNIQUE, full_name, section_id → sections, created_at)
exams(id, title, subject, exam_type, section_id → sections,
      item_count, choice_count, bubble_style, total_points, created_at)
answer_keys(exam_id, item_no, correct, points, PRIMARY KEY (exam_id, item_no))
scans(id, exam_id, student_id, device_id, raw_answers JSON, score, total, scanned_at,
      UNIQUE (exam_id, student_id))   -- rescans UPSERT
```

A `class_record` view joins students × scans × exams for the desktop UI and for
Excel export.

## 4. Wire Protocol

Encoded as JSON. See [shared/lib/protocol/ws_messages.dart](../shared/lib/protocol/ws_messages.dart).

**HTTP** (shelf on desktop):
| Method | Path           | Purpose                              |
|--------|----------------|--------------------------------------|
| GET    | `/health`      | liveness + protocol version          |
| GET    | `/exams`       | list active exams                    |
| GET    | `/exams/:id`   | exam, answer key, student roster     |
| POST   | `/scans`       | submit one scan (fallback to socket) |

**WebSocket** `/sync`:
```
client → server:  { "type": "hello", "device": "<id>" }
client → server:  { "type": "scan",  "payload": ScanSubmission }
server → all:     { "type": "score", "payload": ScoreBroadcast }
server → all:     { "type": "exam_updated", "exam_id": <int> }
```

`ScanSubmission`:
```json
{ "exam_id": 17, "student_no": "2026-00042",
  "answers": [0,2,1,3,0,...], "device_id": "pixel-7" }
```

`ScoreBroadcast`:
```json
{ "exam_id": 17, "student_no": "2026-00042",
  "full_name": "Dela Cruz, Juan", "score": 42, "total": 50,
  "percentage": 84.0, "scanned_at": "2026-05-21T14:30:00" }
```

## 5. QR Payload (printed on each sheet)

Compact JSON, base64'd into the QR:
```json
{ "v": 1, "sid": "<student_no>", "eid": <exam_id>, "n": <items>, "c": <choices> }
```
`n` and `c` let the mobile app sanity-check the OMR grid against the sheet
before grading.

## 6. OMR Pipeline (mobile)

1. Capture full-resolution still from `camera`.
2. Grayscale → Gaussian blur 5×5 → adaptive threshold.
3. Find largest 4-point contour → paper boundary.
4. `cv2.warpPerspective` to canonical A4 ratio.
5. Detect 3 fiducial squares (top-left, top-right, bottom-left, printed by the
   PDF generator). These pin the bubble grid coordinates.
6. Decode QR (top-right region) — `google_mlkit_barcode_scanning`.
7. For each `(item_no, choice_index)` cell, crop the bubble ROI and compute
   `dark_ratio = #pixels_below_threshold / #total_pixels`.
8. Pick the choice with max `dark_ratio` per item. Mark as **confident** if
   `max > 0.45` and `max - second_max > 0.15`; otherwise blank / ambiguous.
9. Compare to the cached answer key → score.
10. Show preview, then submit over WebSocket.

Thresholds are configurable from the desktop per exam (so dark/light shading
variations can be tuned per class).

## 7. Sheet Generator (desktop)

Inputs: section, exam settings. For each enrolled student, generates one page:
- Header: school, section, exam title, subject, date.
- Student block: name, student_no, section.
- QR code (top-right): the payload from §5.
- Three black fiducial squares (top-left, top-right, bottom-left) — sized 8mm,
  placed at fixed positions so the OMR pipeline can register the grid.
- Bubble grid: items × choices, either circles or squares, with the item
  number printed to the left.

Output: single PDF, one student per page, ready to print.

## 8. Real-Time Sync

- Desktop server broadcasts every accepted `scan` to all connected sockets.
- Class record screen subscribes to broadcasts and patches the in-memory
  table; no polling, no manual refresh.
- Mobile app keeps a small Hive cache of (exam_id → answer_key) so it can
  grade offline even if the socket drops, and replays queued scans when
  the socket reconnects.

## 9. Security

- Server binds to the hotspot subnet only (`0.0.0.0` but the only reachable
  interface is the hotspot one in this setup).
- Optional shared pairing code: desktop generates a 6-digit code; mobile
  must send it in the `hello` message. Stops a stranger on the same
  hotspot from impersonating a scanner.
- Database file lives under the desktop user's app-support directory.

## 10. Out of Scope (for now)
- Cloud sync.
- Multi-teacher collaboration.
- Handwritten-answer OCR.
- Item analysis / psychometrics.
