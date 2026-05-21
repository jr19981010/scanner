# Offline OMR Grading System

Classroom-grade, offline-only OMR (Optical Mark Recognition) grading.
Phone scans → laptop records, in real time, with no internet.

```
phone (hotspot ON) ──Wi-Fi──▶ laptop (joined to hotspot)
   Flutter mobile app           Flutter desktop app
   - pair via QR (host+port+code)  - embedded HTTP+WS server (port 4040)
   - scan student QR               - SQLite class record
   - camera OMR (stub) OR          - section/student/exam CRUD
     manual entry (tap bubbles)    - PDF answer-sheet generator
   - preview answers + submit      - live-update class record UI
   - offline queue + replay        - Excel/PDF export, ranking, average %
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design and
[docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) for the phased plan.

## Project layout

| Folder      | What it is                                              |
|-------------|---------------------------------------------------------|
| `shared/`   | Pure-Dart models + WS protocol used by both apps        |
| `desktop/`  | Flutter Desktop teacher app (server + DB + UI + PDF)    |
| `mobile/`   | Flutter Android scanner app (camera + manual entry)     |

## First-run setup

Requires Flutter 3.19+.

```bash
# 1. Generate native platform folders (preserves lib/ and pubspec.yaml)
cd desktop && flutter create . --project-name omr_desktop --platforms=macos && cd ..
cd mobile  && flutter create . --project-name omr_mobile  --platforms=android && cd ..

# 2. Install deps
cd desktop && flutter pub get && cd ..
cd mobile  && flutter pub get && cd ..

# 3. (Android) Add to mobile/android/app/src/main/AndroidManifest.xml
#    just above <application>:
#      <uses-permission android:name="android.permission.CAMERA"/>
#      <uses-permission android:name="android.permission.INTERNET"/>
#      <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
```

## Daily run

Two terminals.

**Terminal 1 — desktop:**
```bash
cd desktop && flutter run -d macos
```
Window opens on the **Pair your phone** tab. It shows a QR encoding host + port
+ pairing code, plus the same info as text.

**Terminal 2 — phone:**
1. Enable phone hotspot.
2. Join the hotspot from the Mac.
3. `cd mobile && flutter run -d <android-device-id>`.

In the phone app:
1. **Scan pairing QR from laptop** → fields auto-fill.
2. **Connect**. Status switches to "Connected & paired".
3. **Start grading** → pick exam → tap **Scan QR + manual entry**.
4. Scan the printed student QR. Tap each answer. **Review & submit**.
5. The score appears on the laptop's Live-scans tab instantly. The class-record
   table updates with average % and rank.

The camera-OMR button works end-to-end but the OMR pipeline is stubbed (it
returns all-blank), so use manual entry until [omr/](mobile/lib/omr/) is
filled in. The plumbing — capture → preview → submit — is fully wired.

## Features

### Desktop
- **Sections / Students / Exams** CRUD with CSV bulk-import for students
- **Answer-key editor**: choose 10/20/40/50/100 items, A–D, A–E, or T/F,
  circle or box bubbles, then tap to set the correct choice per item
- **PDF generator**: corner fiducials, per-student QR, exam-shaped bubble grid;
  preview one student or print/save the whole section in one document
- **Live scans**: shows pairing QR, pairing code, IP, connected device count,
  and a live-updating feed of every score
- **Class record**: pivoted students × exams table with average % and rank;
  Excel and PDF export
- **Pairing-code enforced** on every HTTP request (header) and WS handshake

### Mobile
- **Scan pairing QR** to auto-configure or type IP/port/code manually
- **Exam picker** with cached list (works offline once primed)
- **Camera OMR path** (stubbed) and **manual entry** (tap each bubble)
- **Result preview**: per-item ✓/✗ vs answer key, edit any answer before
  submitting
- **Offline queue**: scans submitted while the socket is down are kept in
  memory and flushed on reconnect; UI shows pending count
- **History**: last 200 scans saved in Hive, with offline tags

## What's still stubbed

Only the **OMR image pipeline** in [mobile/lib/omr/](mobile/lib/omr/):
`perspective.dart`, `fiducials.dart`, `bubble_grid.dart`. Each file has a
detailed comment describing exactly what to implement. The grader entry point
in [grader.dart](mobile/lib/omr/grader.dart) takes an `imagePath`, so the
camera screen already passes a captured still — only the inside of
`runOmrPipeline` is empty.

Manual entry is fully functional and is recommended for production use until
OMR is tuned against real photos of your printed sheets.

## Releases & auto-update

Both apps have a **Check for updates** button that queries the GitHub Releases
API for this repo and offers to download the new build:

- Desktop: top-right of the Live-scans tab.
- Mobile: top-right of the Connect screen.

The mobile app downloads the new `.apk` and triggers Android's system installer
prompt (user has to tap "Install"). The desktop app opens the release page in
the browser so the user can grab the new `.dmg`.

### How to publish a new version

1. Bump `version:` in both [desktop/pubspec.yaml](desktop/pubspec.yaml) and
   [mobile/pubspec.yaml](mobile/pubspec.yaml). Use semver, e.g. `1.0.1`. Mobile
   needs the `+N` build-code suffix bumped too: `1.0.1+2`.
2. Commit and push to `main`.
3. Tag and push:
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```
4. [GitHub Actions](.github/workflows/release.yml) does the rest:
   - Builds the macOS `.dmg` (signed only with an ad-hoc cert — see Gatekeeper
     notes below).
   - Builds the Android release `.apk` (debug-signed; switch to a release
     keystore before publishing publicly).
   - Creates / updates a GitHub Release on the tag and attaches both files.
5. Existing users open the app, hit **Check for updates**, and pull the new
   build.

### Customizing repo coordinates

The updater is hard-coded to look at `jhay-arpilar/omr-scanner`. If your repo
is named differently, change the constants at the top of:

- [desktop/lib/features/about/update_check.dart](desktop/lib/features/about/update_check.dart)
- [mobile/lib/features/about/update_check.dart](mobile/lib/features/about/update_check.dart)

### Gatekeeper / unknown-developer warnings

The `.dmg` is unsigned. First launch on macOS will say "developer cannot be
verified" — right-click the `.app` → **Open** → **Open**, or run:
```bash
xattr -dr com.apple.quarantine /Applications/omr_desktop.app
```
For a smoother experience, sign with an Apple Developer ID ($99/yr) and update
the workflow to embed your signing identity.

The `.apk` is debug-signed. To install, users enable **Install unknown apps**
for their browser / file manager. For Play Store distribution, switch to a
release keystore (the workflow has a clear hook to wire that in).

### Offline-first caveat

Auto-update **requires internet** for the check itself. The check is manual
(button press) so it only happens when the teacher chooses to do it — usually
when on home Wi-Fi, not during a class on the hotspot. If the check fails
(offline), the apps keep working as normal.
