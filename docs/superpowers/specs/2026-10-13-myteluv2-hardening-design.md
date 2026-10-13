# MyTelUV2 Hardening & Polish — Design / Findings Spec

Date: 2026-10-13. Source of truth branch: `main` (e74e214). Work branch: `improve/full-hardening`.

Owner intent (verbatim, Indonesian): "secret biarin aja dulu, soalnya ini juga ga bakal dipakai lagi, hanya pengen diperbagus. lanjut perbaiki semuanya."
=> The project will not be operated in production again; goal is to make the codebase *better* (security posture, correctness, UX, ops hygiene) as a showcase. Secrets are explicitly OUT of scope.

## Out of scope (owner decision or infeasible)
- Rotating/removing secrets: `edge_device/config.yaml` secret value, `.env*` history, git history rewrite. Do NOT edit secret values.
- Git LFS migration / history rewriting of committed model binaries.
- Play Integrity / App Attest / server-side anti-spoof liveness model (requires external accounts/models).
- Postgres backup service (DB is external / Prisma Accelerate; no DB container in compose).
- Full dark theme and splitting every 800+ line Flutter page (large, low value without a running device). Partial extraction allowed when a task touches the code anyway.
- New product features beyond what findings require (e.g. post report/flag queue, notification history table on server).

## Findings to fix (authority list)

### Security
S1. `backend/controllers/biometrikController.js:666-687` client header `X-Test-Mode: true` bypasses face verification. Also `parkirController.js:437-438` forwards client header to plate service; `plate_recognition/app.py:555` honours header. Test mode must come only from env `TEST_MODE=true`, and the backend must refuse to start when `NODE_ENV=production` and `TEST_MODE=true`.
S2. `deploy/Caddyfile` exposes `/face/*`, `/plate/*`, `/anomaly/*` publicly; Python services must not be internet-reachable. Python services must fail closed when their API key env is unset (except `TEST_MODE=true`), compare keys with `hmac.compare_digest`; anomaly service must receive `ANOMALY_API_KEY` in prod compose; backend must send `X-API-Key` to every Python service.
S3. Public register can choose role DOSEN (`authController.js:14-15`, mobile `register_page.dart`). Public register = MAHASISWA only.
S4. `/api/v1/biometrik/scan` open to any logged-in user and matches against all embeddings. Restrict to ADMIN and DOSEN; DOSEN must pass `id_kelas` of a class they teach and matching is limited to that class's participants.
S5. No `trust proxy` => rate limiter keys on Caddy IP; auth limiter (5/5min) shared campus-wide. Set trust proxy (`loopback, linklocal, uniquelocal`, overridable by env `TRUST_PROXY`), key auth limiter by IP+username.
S6. Password change/reset/admin-reset does not revoke refresh tokens.
S7. `generalLimiter` disabled; `/refresh`, `/forgot-password`, `/reset-password` unlimited; post upload 10 files x 10MB in memory.
S8. Duplicate `validateZod` (`validationMiddleware.js:21` and `:123`); the active one discards parse output, so Zod transforms (plate normalisation) never apply.
S9. Liveness/similarity oracle: similarity score returned to client; `getJobStatus` lacks ownership; class roster readable by any MAHASISWA; `getJadwalPengganti` lacks ownership.
S10. multer runs before `protect` on kendaraan upload; `/health` leaks DB error text; `error.message` returned in prod responses; Swagger enabled in prod; Socket.IO unauthenticated; anomaly container runs as root; plate service on Flask dev server; anomaly `debug=True`.
S11. Password policy min 6 chars -> raise to 8.
S12. Username/NIM uniqueness check ignores soft-deleted users while DB unique constraint does not => 500 instead of 409.

### Business logic
B1. Edge gate never opens: backend returns `{status, message, data:{gate_action,...}}` (`parkirController.js:638-649`); edge reads top-level `gate_action`/`success` (`edge_device/plate_detector.py:487,561,571`). E2E accepts both shapes (`backend/test-e2e/api_e2e.test.js:237`).
B2. Rejecting a vehicle *delete request* sets status DISETUJUI + statusVerif=true regardless of prior state (`kendaraanController.js:393-401`); delete request can be filed from any status.
B3. Plates not normalised (see S8); edge lookup only strips spaces. Single normaliser: uppercase, remove all non-alphanumerics.
B4. Parking MASUK/KELUAR capacity update + log creation not in one transaction (double entry race); unknown plates leave no audit trail; deactivated owners' vehicles still open the gate; `reconcileKapasitas` defined twice; `manualOverride` not audited; CSV export unbounded; soft-deleted plates can never be re-registered.
B5. Timezone: server TZ unset; "today"/day-of-week/report times computed in server-local time. All business date logic must use Asia/Jakarta explicitly.
B6. Sessions: `openAbsensi` allows overlapping open sessions per class; stats count sessions before student enrollment and still-open sessions; absensi unique index exists only in a migration (`uq_absensi_user_sesi`), not in `schema.prisma`; P2002 race becomes 500 instead of 409.
B7. Kelas CRUD: no `jam_berakhir > jam_mulai` validation; `kapasitas` ignored on create; conflict check skipped when only `hari`/`id_dosen` changes; multi-step updates not transactional; enrollment capacity check racy.
B8. No attendance status (only presence). Need `StatusKehadiran` enum {HADIR, TELAT, IZIN, SAKIT, ALPHA} and a DOSEN/ADMIN manual override endpoint (audited) so students are not stuck when Face AI is down.
B9. Jadwal pengganti create is broken (`id_kelas` read from body/params incorrectly; `jam_*_ganti` never saved — `akademikController.js:2296-2323`); participants not notified.
B10. Anomaly re-run soft-deletes all previous reports incl. REVIEWED/RESOLVED with dosen notes (`anomaliController.js:177-199`); KEHADIRAN_GANDA rule impossible under unique index; Python anomaly service (IsolationForest, POLA_WAKTU_TIDAK_WAJAR) never called; TaskQueue never cleaned (memory leak); counts include open sessions / pre-enrollment sessions.
B11. Push: `push_notifications_enabled` ignored by `utils/firebase.js`; invalid FCM tokens never cleared.
B12. Auth lifecycle: no email at register (forgot-password can never send); OTP page is a mock with no backend; reactivate restores biometric deleted on purpose.
B13. Posts: like race -> 500 (should be idempotent); unbounded `limit`; laporan uses username as NIM.

### Infra / quality
I1. Deploy never runs `prisma migrate deploy`; `system_settings` table has no migration (only `backend/scratch_create_table.js`).
I2. Caddy lacks `/socket.io/*` route.
I3. Deploy: health check `grep "healthy\|Up"`; deploys `origin/main` not the CI-tested SHA; copies `.env.example` when `.env` missing; CI path filter only `backend/**`.
I4. Face model volume mounted at `/root/.insightface` but service runs as `appuser`; audit logs written to unmounted `/app/logs`; no log rotation / mem limits; no per-context `.dockerignore`; backend image misses `assets/` (PDF logo).
I5. `axiosRetry` installed on the global axios instance, retries POST with consumed FormData streams.
I6. `/health` hardcodes `localhost:5051/5001`, ignores anomaly; `server.js:279-343` duplicates `:213-277`; no `unhandledRejection` handler; `io.close()` not called on shutdown.
I7. Node 20 EOL -> Node 22 (Dockerfile + CI).
I8. Tests: jest picks up macOS `._*` files and `test-e2e`; coverage only controllers; mobile CI has `flutter analyze` continue-on-error and no `flutter test`; two pre-existing failing mobile tests (`test/akademik_service_test.dart` compile error, `test/auth_controller_test.dart` login success).
I9. Repo hygiene: scratch files (`backend/scratch_create_table.js`, `backend/test-push.js`); `edge_device/detections/` (PII photos) not gitignored; README drift (`/api-docs` vs `/api/docs`, wrong data-flow lines); TESTING_E2E.md documents the `X-Test-Mode` header.
I10. Edge device busy-loops on camera read failure (`plate_detector.py:637-640`).

### Mobile UI/UX
U1. Home card never renders course title (`home_page.dart:439`); badge says "Absen GPS" but flow always forces selfie; GPS-only sessions (require_face=false) must use the GPS-only endpoint.
U2. `_errorMessage` never reset -> retry never recovers (`absensi_page.dart:92-112`, `dosen_manage_absensi_page.dart:54-68`, `dosen_sesi_detail_page.dart:57-71`); raw errors shown with no retry.
U3. Anomaly dashboard crashes for DOSEN (`anomali_dashboard_page.dart:168` treats Map as model); `_scanAllKelas` not awaited but shows success.
U4. Student "Biometrik" grid item opens verification page without a session (dead end) — show biometric status instead (`biometrik_status_widget.dart` exists, unused).
U5. Attendance flow: start button enabled before location known; no "Buka Pengaturan" for permanently denied permission; "Exception:" prefix shown; no distance-to-geofence shown.
U6. Status colors: MENUNGGU vs DITOLAK nearly identical red (`ui_helpers.dart:9-14`); label "Selesai" should be "Disetujui"; only rejected submissions open a detail.
U7. "Hapus Semua Kelas" full-width button right under "Tambah Kelas" with one confirm (`admin_kelas_tab.dart:661-678`).
U8. Notifications: no deep link on push tap / cold start / inbox tap; push toggle is a local fake (`settings/notification_page.dart:12`); inbox in SharedPreferences not cleared on logout (leaks across users).
U9. Auth pages: double dialogs on error; reset always says "Token tidak valid" even on network error; no confirm-password (register, reset); forgot-password page overflows with keyboard; OTP mock route; Terms TODO link; roles shown raw.
U10. Kendaraan forms: no per-field validation, hint-only fields, plate not uppercased, raw exceptions; duplicated `RegisterPlatBerhasilPage`; lorem-ipsum `main()` in `detailuserhistoripengajuan.dart`.
U11. Dosen session form: duration not validated, disabled button without reason, hour not zero-padded; no manual attendance override UI (pairs with B8).
U12. Consistency/i18n/a11y: `Color(0xFFE63946)` hardcoded ~170x while `AppColors` unused; English strings mixed in; ~53 raw `$e` in UI; no `flutter_localizations`/`id_ID` locale; dates hand-formatted, not WIB; back buttons are 20px `GestureDetector`s; 9-10px text; `RichText` ignores text scaling; `Image.network` without cache though `cached_network_image` is a dependency; dead code (`FaceOvalPainter`, orphan routes `pengajuanList`, `otpVerification`, `anomaliResult`; "Riwayat Perubahan" placeholder).
U13. Parking socket must authenticate (pairs with S10 Socket.IO auth).
