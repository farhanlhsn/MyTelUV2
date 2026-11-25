# MyTelUV2 Hardening & Polish Implementation Plan

## Execution status — 18 October 2026

All planned tasks are complete. Tasks 1–16 and inserted Task 16a were completed in the earlier run; inserted Task 16b and Task 17 were completed in the Codex continuation. Remaining planned tasks: **0**.

Final evidence and validation limits: [completion report](../reports/2026-10-18-myteluv2-hardening-completion.md). The original checklists below record the initial implementation instructions; prior-task completion is recorded in the execution ledger. The continuation uses truthful contributor attribution rather than the earlier Claude-specific commit trailer.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every in-scope finding of the 2026-10-13 review (security, business logic, infra, mobile UX) on branch `improve/full-hardening` without touching secrets.

**Architecture:** Express/Prisma backend (`backend/`), Flask AI services (`backend/python-service/*`), Python edge client (`edge_device/`), Flutter+GetX app (`mobile/`), Docker/Caddy/GitHub Actions deploy. Fixes are done in place, following each file's existing idiom; small shared helpers are added where duplication would otherwise grow (`backend/utils/plate.js`, `backend/utils/timezone.js`, `mobile/lib/utils/date_helper.dart`).

**Tech Stack:** Node 22 / Express 5-style async handlers / Prisma 6 / Jest + supertest-style controller tests with mocked prisma; Python 3.11 Flask + gunicorn; Flutter (Dart 3) + GetX + Dio.

**Spec:** `docs/superpowers/specs/2026-10-13-myteluv2-hardening-design.md` (finding IDs S*, B*, I*, U* referenced below).

## Global Constraints

- Work only on branch `improve/full-hardening`. Never push. Never merge.
- Stage files explicitly by path. NEVER `git add -A`, `git add .`, or `git commit -a`. These must stay untracked and uncommitted: `FinalDocumentation.tex`, `backend/test/laporanController.test.js`, `edge_device/detections/`, any `._*` / `.DS_Store` file, `.env*` (except tracked `*.example`).
- Do NOT change secret values anywhere (`edge_device/config.yaml` `server.secret`, any `.env*`). Adding env-var *reading* code is fine.
- Commit message: Conventional Commits (`fix:`, `feat:`, `refactor:`, `test:`, `chore:`, `docs:`, `ci:`), body optional, and the last lines exactly:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```
- Backend test command (must be green after every backend task): `cd backend && npx jest --testPathIgnorePatterns "/\._" "test-e2e"`. Baseline: 108 tests passing.
- Mobile tests cannot run on drive E: (exFAT breaks Flutter symlinks). Run them with: `pwsh -File "C:\Users\MFARHA~1\AppData\Local\Temp\claude\E--02-Projects-MyTelUV2\b03c7cea-456b-491a-8337-912f7f41be43\scratchpad\flutter-test.ps1" [test/file_test.dart]` (mirrors `mobile/` to C: and runs `flutter test`). Baseline: 25 pass, 2 fail (fixed in Task 16).
- Mobile static check: `cd mobile && flutter analyze` — baseline 2 errors (both in `test/akademik_service_test.dart`), 24 warnings, 200 infos. A mobile task must not add new errors or warnings in files it touches.
- Python is NOT installed locally. Python changes are verified by careful reading, keeping `backend/python-service/tests/test_ai_contract.py` semantics consistent, and `node`-free syntax sanity (no tabs/spaces mixing, balanced blocks).
- API response envelope stays `{ status: "success"|"error", message, data? }`.
- All user-facing strings (mobile UI and backend `message`) in Indonesian.
- All business date/time logic uses timezone `Asia/Jakarta` (WIB, UTC+7, no DST).
- No new runtime dependencies unless the task says so. Prefer built-ins (`Intl`, `crypto`).
- Follow the surrounding code's style; do not reformat untouched code.
- Implementers never spawn subagents.

## Review Focus

1. Requests that previously relied on Zod *stripping nothing* (fields read by controllers but absent from schemas) — after Task 1 makes Zod output authoritative, a missing schema field silently becomes `undefined`. Task 1 adds a test per schema/controller pair that the fields controllers read survive validation.
2. Clients that still send `X-Test-Mode` (E2E, Postman) — must get *normal* behaviour, never a bypass. Task 3 tests header-is-ignored.
3. Edge device receiving a DENY or network error — gate must stay closed (fail closed). Task 6 tests both shapes and the exception path.
4. Times around midnight WIB (00:00–07:00 WIB = previous UTC day) — "today" and day-of-week must be the Jakarta day. Task 9 tests 2026-10-13T18:30:00Z => Jakarta 2026-10-14 (Wednesday).
5. Anomaly re-analysis with existing REVIEWED/RESOLVED reports — must keep them and their `catatan`. Task 11 tests it.

---

### Task 1: Single authoritative Zod validation + plate normaliser

Spec: S8, B3 (normaliser only), I8 (jest ignore).

**Files:**
- Modify: `backend/middlewares/validationMiddleware.js` (remove the second `exports.validateZod` at ~line 123; keep one async version that assigns parsed output to `req.body` and returns 400 with Indonesian joined messages; handle Zod v3 `error.errors` and v4 `error.issues`).
- Modify: `backend/middlewares/zodSchemas.js` — audit EVERY schema against the controller that consumes it; add every body field the controller reads (e.g. `is_mock_location`, `kapasitas`, `jam_mulai_ganti`/`jam_berakhir_ganti`, `latitude`/`longitude`, `email`, etc. — read the controllers to get the exact list). Use `z.coerce` for numeric/boolean fields that arrive as multipart strings. Plate fields use `normalizePlate`.
- Create: `backend/utils/plate.js` exporting `normalizePlate(raw)`.
- Modify: `backend/package.json` jest config: `testPathIgnorePatterns: ["/node_modules/", "/\\._", "/test-e2e/"]`; add script `"test:e2e": "jest test-e2e --runInBand"` if not present; keep `"test"` running unit tests only.
- Test: `backend/test/validationMiddleware.test.js`, `backend/test/plate.test.js`.

**Interfaces:**
- Produces: `normalizePlate(raw: string|undefined|null): string` — `String(raw ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '')`. Used by Tasks 5 and 6.
- Produces: `validateZod(schema)` — async middleware; on success `req.body = parsedData` then `next()`; on failure `400 {status:"error", message:"<msg1>, <msg2>"}`.

- [ ] **Step 1: Write failing tests** — `plate.test.js`: `'b 1234-xyz'`→`'B1234XYZ'`, `' D 12 AB '`→`'D12AB'`, `null`→`''`. `validationMiddleware.test.js`: (a) transform applied (`registerKendaraanSchema` with `plat_nomor:'b 1234-xyz'` ⇒ `req.body.plat_nomor === 'B1234XYZ'`); (b) invalid body ⇒ 400 + `status:'error'`; (c) for each schema exported by `zodSchemas.js` that a route uses, a valid sample body containing every field its controller destructures from `req.body` comes out with all those keys still present (one `it` per schema, table-driven).
- [ ] **Step 2: Run** `cd backend && npx jest test/validationMiddleware.test.js test/plate.test.js` — expect FAIL.
- [ ] **Step 3: Implement** the files above.
- [ ] **Step 4: Run full backend suite** (Global Constraints command) — expect all green (≥108 + new).
- [ ] **Step 5: Commit** `fix(validation): make zod output authoritative and normalise plates`.

### Task 2: Auth & account hardening

Spec: S3, S5, S6, S7, S11, S12, B12 (register email only).

**Files:**
- Modify: `backend/controllers/authController.js` — register forces `role = 'MAHASISWA'` (ignore body role); accept optional `email` (validated in Zod, stored lowercased); username/NIM duplicate checks must include soft-deleted rows (match the DB unique constraint) and return 409 with Indonesian message; change-password, reset-password and admin-reset-password each `prisma.refreshToken.deleteMany({ where: { id_user } })` in the same transaction as the password update.
- Modify: `backend/middlewares/zodSchemas.js` — password `min(8)` for register/change/reset/admin-reset with message `"Password minimal 8 karakter"`; register schema: drop `role`, add `email: z.string().email().optional()`.
- Modify: `backend/server.js` — `app.set('trust proxy', process.env.TRUST_PROXY ?? 'loopback, linklocal, uniquelocal')` before any limiter; enable `app.use('/api', generalLimiter)`.
- Modify: `backend/middlewares/rateLimiterMiddleware.js` — `authLimiter` keyGenerator = `${ipKeyGenerator(req.ip)}:${(req.body?.username||'').toLowerCase()}` (use the library's `ipKeyGenerator` with the IP string, fixing the current wrong `ipKeyGenerator(req,res)` call); `generalLimiter` 300 req / 15 min keyed by `req.user?.id_user` if present else IP; new `sensitiveLimiter` 10 req / 15 min per IP for `/refresh`, `/forgot-password`, `/reset-password`.
- Modify: `backend/routes/authRoutes.js` — apply `sensitiveLimiter`.
- Modify: `backend/routes/kendaraanRoutes.js` — `protect` before multer on every upload route.
- Modify: `backend/routes/postRoutes.js` / `backend/middlewares/multerMiddleware.js` — post media: max 5 files, 5 MB each, image/video mimetypes only.
- Test: `backend/test/authController.test.js` (extend), `backend/test/rateLimiter.test.js` (new).

- [ ] **Step 1: Failing tests** — register with `role:'DOSEN'` creates MAHASISWA; register duplicate username of a soft-deleted user ⇒ 409; change password calls `refreshToken.deleteMany` with the user id; reset password likewise; admin reset likewise; password `'1234567'` ⇒ 400; authLimiter keyGenerator returns different keys for same IP/different usernames and is case-insensitive on username.
- [ ] **Step 2: Run them — FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Full backend suite green.**
- [ ] **Step 5: Commit** `fix(auth): restrict public register, revoke sessions on password change, fix rate limiting behind proxy`.

### Task 3: Biometric bypass removal, scan restriction, IDOR fixes

Spec: S1 (backend part), S4, S9, B12 (reactivate).

**Files:**
- Modify: `backend/controllers/biometrikController.js` — `isTestMode = process.env.TEST_MODE === 'true'` only (no header). `/scan`: caller role ADMIN → may scan all or by `id_kelas`; DOSEN → `id_kelas` required and must be a class where `kelas.id_dosen === req.user.id_user` (403 otherwise), candidates limited to that class's active participants. Remove raw `similarity` from responses to non-ADMIN callers (keep a boolean `match`). On add/edit biometric, reject (409 `"Wajah ini sudah terdaftar untuk pengguna lain"`) if the new embedding matches another active user's embedding above the existing verification threshold.
- Modify: `backend/routes/biometrikRoutes.js` — `/scan` gets `authorize('ADMIN','DOSEN')`.
- Modify: `backend/controllers/parkirController.js` — stop forwarding the client `x-test-mode` header (lines ~437-438). If `process.env.TEST_MODE === 'true'` the backend may set `X-Test-Mode: true` itself toward the plate service.
- Modify: `backend/server.js` — at startup: if `NODE_ENV === 'production' && TEST_MODE === 'true'` log an error and `process.exit(1)`.
- Modify: `backend/controllers/anomaliController.js` + `backend/utils/TaskQueue.js` — jobs store `ownerId`; `getJobStatus` returns 404 unless `job.ownerId === req.user.id_user` or role ADMIN.
- Modify: `backend/controllers/akademikController.js` — class participants list (`GET /kelas/:id/peserta`): MAHASISWA only if enrolled (else 403); DOSEN only own class; `getJadwalPengganti`: MAHASISWA only if enrolled, DOSEN only own class.
- Modify: `backend/controllers/authController.js` — reactivate user must NOT restore biometric data that was soft-deleted.
- Modify: `backend/test-e2e/api_e2e.test.js` — remove `X-Test-Mode` headers (E2E runs with `TEST_MODE=true` env already set in `ci-test.yml`).
- Test: `backend/test/biometrikAbsen.test.js` (extend), `backend/test/biometrikScan.test.js` (new), `backend/test/anomaliController.test.js`, `backend/test/akademikController.test.js` (extend).

- [ ] **Step 1: Failing tests** — absen with header `x-test-mode: true` and `TEST_MODE` unset calls the face service (mock) and fails when face service returns no match; `/scan` as DOSEN without `id_kelas` ⇒ 400, with another dosen's class ⇒ 403; MAHASISWA response has no `similarity` key; getJobStatus by a different DOSEN ⇒ 404; peserta list by non-enrolled MAHASISWA ⇒ 403; duplicate-face add ⇒ 409.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Full backend suite green.**
- [ ] **Step 5: Commit** `fix(security): remove client test-mode bypass and close biometric/IDOR gaps`.

### Task 4: Server hygiene + Socket.IO auth

Spec: S10 (health, error leaks, swagger, socket auth), I6, U13.

**Files:**
- Modify: `backend/server.js` — delete the duplicated block (~279-343) keeping one shutdown/404/error handler; add `process.on('unhandledRejection')` and `process.on('uncaughtException')` that log and trigger graceful shutdown; call `io.close()` in shutdown; `/health` returns `{status, db: 'ok'|'error', services:{face,plate,anomaly}}` without raw error text, using `process.env.PYTHON_SERVICE_URL`, `process.env.PLATE_API_URL`, `process.env.ANOMALY_SERVICE_URL` (defaults keep localhost); mount Swagger only when `NODE_ENV !== 'production' || ENABLE_SWAGGER === 'true'`; Socket.IO middleware `io.use` verifying `socket.handshake.auth.token` with the same JWT secret/verification as `authMiddleware` (reject with `new Error('Unauthorized')`).
- Modify: controllers that return `error.message` in 5xx (`authController.js:~607`, `kendaraanController.js:~136`, `anomaliController.js:~245,~467`, plus any other `message: error.message` in a 500 path) — log the error, return generic Indonesian message `"Terjadi kesalahan pada server"`.
- Modify: `mobile/lib/services/parkir_socket_service.dart` — pass the JWT from secure storage via `.setAuth({'token': token})`; on connect error `Unauthorized` stop retrying and report offline.
- Modify: `backend/utils/prisma.js` — remove the dead query-logger code (~280-286) or wire it correctly (pick removal).
- Test: `backend/test/server.health.test.js` (new, require app without listening if server.js exports app; if server.js does not export app, refactor minimal `module.exports = { app, server, io }` guarded by `require.main === module` for listen).

- [ ] **Step 1: Failing tests** — `/health` with prisma `$queryRaw` rejecting `new Error('password authentication failed')` ⇒ body has no substring `password`; socket auth middleware function rejects missing token and accepts a valid signed token (unit-test the exported middleware function).
- [ ] **Step 2: Run — FAIL.** **Step 3: Implement.** **Step 4: Full backend suite green; `flutter analyze` no new issues in `parkir_socket_service.dart`.**
- [ ] **Step 5: Commit** `fix(server): dedupe handlers, harden health/errors, authenticate sockets`.

### Task 5: Kendaraan & parkir business logic

Spec: B2, B3, B4.

**Files:**
- Modify: `backend/controllers/kendaraanController.js` — use `normalizePlate` on register/resubmit/search; delete request only allowed when `status_pengajuan === 'DISETUJUI'` (else 409 `"Hanya kendaraan yang sudah disetujui yang bisa diajukan hapus"`); rejecting a delete request restores `DISETUJUI` (now always correct) and keeps `statusVerif` unchanged; re-registering a plate whose existing row is soft-deleted reuses that row (reassign owner, reset to `MENUNGGU`, clear feedback, clear deletedAt) instead of failing; bounded CSV export (require `start`/`end` or cap at 10,000 rows).
- Modify: `backend/controllers/parkirController.js` — edge lookup uses `normalizePlate`; deny when owner `deletedAt` is set (`"Akun pemilik kendaraan tidak aktif"`); MASUK and KELUAR each run inside `prisma.$transaction` (re-read last log for the vehicle inside the transaction, conditional capacity update, create log) so concurrent duplicates yield one entry; unknown plate ⇒ `auditLogger` entry `PARKIR_PLAT_TIDAK_DIKENAL` with plate + parkiran id; `manualOverride` writes an audit entry with admin id; remove the second `reconcileKapasitas` definition (~937) keeping one.
- Test: `backend/test/kendaraanController.test.js`, `backend/test/parkirController.test.js` (extend).

- [ ] **Step 1: Failing tests** — delete request on MENUNGGU ⇒ 409; reject delete request on DISETUJUI vehicle keeps DISETUJUI; register `'b 1234-xyz'` checks uniqueness against `'B1234XYZ'`; re-register soft-deleted plate updates row; edge entry for deactivated owner ⇒ DENY; edge entry uses `$transaction`; unknown plate calls audit logger.
- [ ] **Step 2: FAIL. Step 3: Implement. Step 4: suite green.**
- [ ] **Step 5: Commit** `fix(parkir): transactional gate entries, plate normalisation, safe delete-request flow`.

### Task 6: Edge device contract fix + strict E2E

Spec: B1, I9 (detections gitignore), I10.

**Files:**
- Modify: `edge_device/plate_detector.py` — add a pure function `parse_server_result(result: dict) -> dict` returning `{gate_action, message, plate_text, ocr_confidence, success}` reading from `result['data']` when present (fallback to top-level for backward compat); `success = result.get('status') == 'success' and gate_action == 'OPEN'`; default `gate_action='DENY'`. Use it in `send_to_server` logging and `process_frame`. On `cap.read()` failure: `time.sleep(0.5)` and after 20 consecutive failures try to reopen the capture.
- Create: `edge_device/test_parse_server_result.py` — plain `unittest` cases: nested OPEN ⇒ OPEN/success True; nested DENY ⇒ DENY; legacy top-level OPEN ⇒ OPEN; `{}` ⇒ DENY; exception dict `{'gate_action':'DENY','error':'x'}` ⇒ DENY.
- Modify: `.gitignore` — add `edge_device/detections/`.
- Modify: `backend/test-e2e/api_e2e.test.js` — assert `res.data.data.gate_action` only (remove the `||` fallback at ~237).
- Modify: `edge_device/README.md` — document response shape.

- [ ] **Step 1: Write `test_parse_server_result.py`** (cannot be run locally — Python missing; keep it dependency-free so CI/dev can run `python -m unittest edge_device/test_parse_server_result.py`).
- [ ] **Step 2: Implement** `parse_server_result` and wire it in.
- [ ] **Step 3: Full backend suite green** (E2E not run locally).
- [ ] **Step 4: Commit** `fix(edge): read nested gate_action so the gate opens; stop busy loop`.

### Task 7: Python AI services hardening

Spec: S1 (plate header), S2 (keys), S10 (root, dev server, debug), I4 (face volume path).

**Files:**
- Modify: `backend/python-service/plate_recognition/app.py` — test mode only from env `TEST_MODE`; API key check (header `X-API-Key`) fail-closed: if `PLATE_API_KEY` unset and not TEST_MODE ⇒ 503 `{"error":"service not configured"}`; compare with `hmac.compare_digest`; `/health` returns 503 when model not loaded (readiness); stop forwarding to backend with the edge secret from the public `/api/parking/process` route unless the request carries a valid API key.
- Modify: `backend/python-service/face_recognition/app.py` — same fail-closed key logic (`FACE_API_KEY`), `hmac.compare_digest`.
- Modify: `backend/python-service/anomaly_detection/app.py` — same (`ANOMALY_API_KEY`); `debug=False`.
- Modify: `backend/python-service/plate_recognition/Dockerfile` — run with gunicorn using existing `gunicorn.conf.py`.
- Modify: `backend/python-service/anomaly_detection/Dockerfile` — non-root `appuser` like the others.
- Modify: `backend/python-service/face_recognition/Dockerfile` and `docker-compose.prod.yml`/`docker-compose.yml` — InsightFace model volume mounted at `/home/appuser/.insightface`.
- Modify: `docker-compose.prod.yml` — pass `PLATE_API_KEY` and `ANOMALY_API_KEY` to both the services and the backend; backend env also gets `FACE_API_KEY`.
- Modify: backend callers — ensure `X-API-Key` header is sent to face (`biometrikController.js` `callPythonService`), plate (`parkirController.js`, already), anomaly (`anomaliController.js`, used from Task 11).
- Modify: `backend/python-service/tests/test_ai_contract.py` — add cases: missing key with key configured ⇒ 401; key unset + TEST_MODE ⇒ allowed.
- [ ] **Step 1: Update contract tests. Step 2: Implement. Step 3: Backend suite green.**
- [ ] **Step 4: Commit** `fix(ai-services): fail-closed API keys, gunicorn, non-root, readiness health`.

### Task 8: Infra, deploy pipeline, migrations

Spec: S2 (Caddy), I1, I2, I3, I4, I5, I7, B6 (schema unique only).

**Files:**
- Modify: `deploy/Caddyfile` — remove `/face/*`, `/plate/*`, `/anomaly/*`; add `handle /socket.io/* { reverse_proxy backend:5050 }`.
- Modify: `.github/workflows/deploy-backend.yml` — fail if `.env` missing (no copy from example); checkout `${{ github.event.workflow_run.head_sha }}`; run `docker compose -f docker-compose.prod.yml run --rm backend npx prisma migrate deploy --schema prisma/schema.prisma` before `up -d`; health check = loop up to 30×5s `curl -fsS http://127.0.0.1:8880/api/v1/health` (or `/health` route that hits backend), fail the job otherwise. (Check `backend/prisma.config.ts`/env for `DIRECT_URL`; if Prisma Accelerate URL is used, migrate needs `DIRECT_URL` — wire `directUrl = env("DIRECT_URL")` only if schema already uses it, otherwise document in README.)
- Modify: `.github/workflows/ci-test.yml` — path filter adds `docker-compose*.yml`, `deploy/**`, `edge_device/**`, `.github/workflows/**`; Node 22; Python 3.11.
- Modify: `backend/Dockerfile` — `node:22-alpine`; `npm ci --omit=dev` in final stage; copy `assets/`; `ENV TZ=Asia/Jakarta` + `tzdata`.
- Create: `backend/.dockerignore`, `backend/python-service/*/.dockerignore` (node_modules, test, `._*`, `.DS_Store`, `__pycache__`, `*.pt` where onnx is used is NOT safe to drop — keep models).
- Modify: `docker-compose.prod.yml` & `docker-compose.yml` — `TZ=Asia/Jakarta`; `logging: { driver: json-file, options: { max-size: "10m", max-file: "3" } }` per service; `mem_limit` (backend 512m, face 2g, plate 1g, anomaly 512m, caddy 128m); named volume for backend `/app/logs`.
- Modify: `backend/utils/auditLogger.js` — log dir from `AUDIT_LOG_DIR` env default `/app/logs`.
- Modify: `backend/controllers/biometrikController.js` (axios-retry block ~27-37) — create a dedicated axios instance for Python calls; retry only idempotent methods (GET/HEAD) — never POST.
- Modify: `backend/prisma/schema.prisma` — add `@@unique([id_user, id_sesi_absensi], map: "uq_absensi_user_sesi")` on `Absensi` (exact field names from schema); create migration `backend/prisma/migrations/20261013000000_system_settings_and_absensi_unique/migration.sql` with `CREATE TABLE IF NOT EXISTS "system_settings" (...)` matching `model SystemSetting` and `CREATE UNIQUE INDEX IF NOT EXISTS "uq_absensi_user_sesi" ...`.
- Delete: `backend/scratch_create_table.js` (superseded by migration).
- Test: `backend/test/pythonClient.test.js` (new) — the dedicated client's retry condition returns false for POST and true for GET network errors.
- [ ] **Step 1: Failing test for retry condition. Step 2: Implement all. Step 3: `npx prisma validate --schema prisma/schema.prisma` (set a dummy `DATABASE_URL` env if required) + full backend suite green.**
- [ ] **Step 4: Commit** `ci(deploy): migrate on deploy, real health checks, hardened compose and caddy`.

### Task 9: Akademik timezone, kelas & sesi correctness

Spec: B5, B6, B7.

**Files:**
- Create: `backend/utils/timezone.js` — `TZ = 'Asia/Jakarta'`; `jakartaParts(date=new Date()) -> {year, month, day, hour, minute, weekday}` via `Intl.DateTimeFormat('en-US',{timeZone:TZ,...}).formatToParts`; `jakartaDayRange(date=new Date()) -> {start: Date, end: Date}` (UTC instants of 00:00:00.000 and 23:59:59.999 WIB, computed as `Date.UTC(y,m-1,d) - 7h`); `jakartaWeekday(date)` returning the same numbering convention the codebase already uses for `Kelas.hari` (read `akademikHelpers.js`/controllers to confirm whether 0=Minggu or 1=Senin and match it); `formatJakarta(date, {withTime})` → `"14/10/2026 01:30"` style used in reports.
- Modify: `backend/controllers/akademikController.js` and `backend/controllers/laporanController.js` — replace every server-local `new Date().getDay()`, `setHours(0,0,0,0)`, `toLocaleString()` without timeZone, etc. with the helpers.
- Modify: `openAbsensi` — 409 if the class already has an open session overlapping the requested window; 400 if `jam_berakhir <= jam_mulai`.
- Modify: `createKelas`/`updateKelas` — validate `jam_berakhir > jam_mulai` (400), honour `kapasitas`, run conflict check whenever `hari`, `jam_*`, `ruangan` or `id_dosen` changes, wrap multi-step update in `$transaction`; return the inserted row (use the created id, not "latest").
- Modify: enrollment (`/kelas/daftar` and bulk add) — capacity check + insert inside `$transaction`.
- Modify: absensi create paths (`createAbsensi`, `biometrikAbsen`) — map Prisma `P2002` to 409 `"Anda sudah melakukan absensi untuk sesi ini"`.
- Modify: stats/history (`getAbsensiStats`, `/absensi/ku/stats`, `/absensi/kelas/:id/stats`, history) — count only closed sessions (`status === false` or end time passed) whose start is on/after the student's enrollment `createdAt`.
- Modify: list endpoints with raw `limit` (~1764, ~1935) — clamp via `paginationHelper`.
- Test: `backend/test/timezone.test.js` (new), `backend/test/akademikController.test.js` (extend).

- [ ] **Step 1: Failing tests** — `jakartaParts(new Date('2026-10-13T18:30:00Z'))` ⇒ `{year:2026,month:10,day:14,hour:1,minute:30}` and weekday Wednesday in the codebase's convention; `jakartaDayRange(new Date('2026-10-13T18:30:00Z')).start.toISOString() === '2026-10-13T17:00:00.000Z'`; overlapping openAbsensi ⇒ 409; createKelas with end<=start ⇒ 400; createKelas honours `kapasitas: 30`; P2002 on absensi ⇒ 409; stats exclude a session dated before enrollment.
- [ ] **Step 2: FAIL. Step 3: Implement. Step 4: suite green.**
- [ ] **Step 5: Commit** `fix(akademik): Asia/Jakarta time, session overlap guard, kelas validation, accurate stats`.

### Task 10: Attendance status + dosen override + jadwal pengganti fix

Spec: B8, B9.

**Files:**
- Modify: `backend/prisma/schema.prisma` — `enum StatusKehadiran { HADIR TELAT IZIN SAKIT ALPHA }`; `Absensi.status StatusKehadiran @default(HADIR)`, `Absensi.keterangan String?`, `Absensi.diubah_oleh Int?` (FK-less is fine). Migration `backend/prisma/migrations/20261013000100_absensi_status/migration.sql`.
- Modify: absensi create paths — set `TELAT` when attendance time is more than `LATE_THRESHOLD_MINUTES` (env, default 15) after session start, else `HADIR`.
- Add endpoint: `PUT /api/v1/akademik/absensi/sesi/:id/mahasiswa/:id_user` (DOSEN of that class or ADMIN) body `{ status: 'HADIR'|'TELAT'|'IZIN'|'SAKIT'|'ALPHA', keterangan?: string(max 255) }` — upsert the Absensi row for (id_user, id_sesi); 404 if student not enrolled; writes `auditLogger` entry `ABSENSI_OVERRIDE` with actor, old status, new status. Response `data` = updated absensi.
- Modify: session detail/stat responses to include `status` and treat IZIN/SAKIT as excused (not counted absent), ALPHA as absent, HADIR/TELAT as present.
- Fix: `POST /kelas/:id/jadwal-pengganti` — `id_kelas` from `req.params.id`; persist `jam_mulai_ganti`/`jam_berakhir_ganti` (or the actual schema column names); validate `tanggal_asli` falls on the class's `hari`; end > start; notify enrolled students via existing firebase helper (respecting Task 11's preference check if already merged — call the shared helper).
- Modify: `backend/routes/akademikRoutes.js`, `backend/middlewares/zodSchemas.js` (`overrideAbsensiSchema`).
- Test: `backend/test/akademikController.test.js` (extend) or new `backend/test/absensiOverride.test.js`.

**Interfaces:** Produces the override endpoint above and `status` field on absensi objects returned by `GET /absensi/sesi/:id` and history endpoints (string enum). Task 15 consumes them.

- [ ] **Step 1: Failing tests** — override by owning dosen ⇒ 200 with status IZIN and audit call; by other dosen ⇒ 403; non-enrolled ⇒ 404; invalid status ⇒ 400; attendance 20 min after start ⇒ TELAT; jadwal pengganti create uses params id and stores jam fields.
- [ ] **Step 2: FAIL. Step 3: Implement + migration. Step 4: `prisma validate` + suite green.**
- [ ] **Step 5: Commit** `feat(absensi): attendance status, dosen override, fixed jadwal pengganti`.

### Task 11: Anomaly engine + notifications + posts/laporan fixes

Spec: B10, B11, B13.

**Files:**
- Modify: `backend/controllers/anomaliController.js` — re-analysis only replaces OPEN reports; for an existing REVIEWED/RESOLVED report with the same `(id_user, id_kelas, type)` keep it untouched; do it in a `$transaction`. Remove the impossible KEHADIRAN_GANDA rule (keep enum value). Call the Python anomaly service (`POST ${ANOMALY_SERVICE_URL}/analyze` — read `anomaly_detection/app.py` for the real path & payload) through `anomalyApiBreaker` with `X-API-Key: process.env.ANOMALY_API_KEY`, mapping its results to `POLA_WAKTU_TIDAK_WAJAR`; if the breaker is open or the call fails, skip that rule and add `warnings: ['Layanan analisis pola waktu tidak tersedia']` to the response. Counting uses only closed sessions on/after enrollment (reuse Task 9 logic/helper). Paginate `getLaporanAnomali`.
- Modify: `backend/utils/TaskQueue.js` + `backend/utils/scheduler.js` — schedule `cleanup()` hourly (timer `unref()`).
- Modify: `backend/utils/firebase.js` — every send helper loads the user's `push_notifications_enabled` and skips when false; on `messaging/registration-token-not-registered` or `messaging/invalid-registration-token` set that user's `fcm_token` to null.
- Modify: `backend/controllers/postController.js` — like is idempotent (P2002 ⇒ treat as already liked, 200); clamp `limit`; feed no longer loads comment id arrays it does not use.
- Modify: `backend/controllers/laporanController.js` — NIM column uses `nim_nip`.
- Test: `backend/test/anomaliController.test.js`, `backend/test/postController.test.js`, `backend/test/firebase.test.js` (new).

- [ ] **Step 1: Failing tests** — re-run keeps RESOLVED report & note; python service failure ⇒ 200 with `warnings`; firebase skip when disabled; invalid token cleared; duplicate like ⇒ 200.
- [ ] **Step 2: FAIL. Step 3: Implement. Step 4: suite green.**
- [ ] **Step 5: Commit** `fix(anomali,notif): preserve reviewed anomalies, use AI service, honour push opt-out`.

### Task 12: Mobile — attendance, home, biometric & anomaly bugs

Spec: U1, U2, U3, U4, U5.

**Files:**
- Modify: `mobile/lib/pages/home/home_page.dart` — render the course title on the "kelas hari ini" card as the headline; badge text `"Absen Wajah"` when the session requires face, `"Absen GPS"` otherwise; GPS-only sessions go straight to the GPS attendance call (`createAbsensi` service method — add to `akademik_service.dart` if missing, posting to `/api/v1/akademik/absensi` with `id_sesi_absensi`, `latitude`, `longitude`, `is_mock_location`); student "Biometrik" grid item opens a page showing `BiometrikStatusWidget` (wrap it in a simple Scaffold page) instead of the verification page.
- Modify: `mobile/lib/pages/biometrik/biometrik_verification_page.dart` — "Mulai Absen" disabled until location acquired (show "Mendapatkan lokasi…"); show distance to geofence centre and in-range state when the session has coordinates; permanently-denied permission shows a "Buka Pengaturan" button calling `Geolocator.openAppSettings()`; location service off shows `Geolocator.openLocationSettings()`; strip `Exception:` prefixes via `ErrorHelper`.
- Modify: `mobile/lib/pages/absensi/absensi_page.dart`, `mobile/lib/pages/dosen/dosen_manage_absensi_page.dart`, `mobile/lib/pages/dosen/dosen_sesi_detail_page.dart` — reset `_errorMessage = null` at the start of each load; show error state with "Coba Lagi" button; user-facing error text via `ErrorHelper`.
- Modify: `mobile/lib/pages/admin/anomali_dashboard_page.dart` — handle both `Map` and model items for the selected class id (normalise to an `int idKelas` helper); `await` each scan in `_scanAllKelas` and show success only if all succeeded (else count failures).
- Test: `mobile/test/home_page_title_test.dart` (widget test for the extracted card widget if extraction is needed to test it) or unit tests of extracted pure helpers (e.g. `kelasIdOf(dynamic item)`, `attendanceBadgeLabel(requireFace)`).

- [ ] **Step 1: Failing tests for the pure helpers. Step 2: FAIL. Step 3: Implement. Step 4: mobile tests (script) — new tests pass; `flutter analyze` no new errors/warnings in touched files.**
- [ ] **Step 5: Commit** `fix(mobile): attendance flow, home card title, retry states, anomaly dashboard crash`.

### Task 13: Mobile — auth pages, kendaraan forms, admin destructive UX, dead code

Spec: U6, U7, U9, U10, U11 (form part), U12 (dead code part), S3/B12 (mobile register).

**Files:**
- Modify: `mobile/lib/pages/auth/register_page.dart` — remove role selector (always MAHASISWA); add optional email field (validated) and confirm-password field; password min 8; Terms link: show an in-app dialog with short terms text instead of TODO; `Text.rich` instead of `RichText`.
- Modify: `mobile/lib/pages/auth/reset_password_page.dart` — confirm-password; distinguish network error vs invalid token (use `ErrorHelper`); single feedback (no double dialogs).
- Modify: `mobile/lib/pages/auth/forgot_password_page.dart` — scrollable layout (no overflow with keyboard); single feedback.
- Modify: `mobile/lib/controllers/auth_controller.dart` — stop showing its own dialog where the page already shows one (pick one place: controller returns result/error, page shows feedback).
- Delete: `mobile/lib/pages/auth/otp_verification_page.dart` and its route; delete orphan routes `pengajuanList`, `anomaliResult` if their pages are unreachable (verify with grep before deleting; if a page is still referenced, keep it).
- Modify: `mobile/lib/utils/ui_helpers.dart` — MENUNGGU amber `0xFFF59E0B` + `Icons.hourglass_top`, DITOLAK red `0xFFDC2626` + `Icons.cancel`, DISETUJUI green `0xFF16A34A` + `Icons.check_circle`; labels `"Menunggu"`, `"Ditolak"`, `"Disetujui"`.
- Modify: `mobile/lib/pages/kendaraan/historyPengajuan/userhistoripengajuan.dart` — every submission opens a detail; detail shows status timeline (diajukan → status sekarang + feedback).
- Modify: `mobile/lib/pages/kendaraan/historyPengajuan/detailuserhistoripengajuan.dart` — remove `main()`/lorem ipsum.
- Modify: `mobile/lib/pages/kendaraan/registerplat.dart`, `resubmit_kendaraan_page.dart` — `TextFormField` with labels + per-field validators; plate uppercased as typed and validated `^[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3}$` (after trimming); one shared success page widget (keep one `RegisterPlatBerhasilPage`, delete the duplicate); tappable back.
- Modify: `mobile/lib/pages/admin/tabs/admin_kelas_tab.dart` — move "Hapus Semua Kelas" into an AppBar/overflow `PopupMenuButton`; confirm dialog requires typing `HAPUS`.
- Modify: `mobile/lib/pages/dosen/dosen_manage_absensi_page.dart` — duration validator (1–240 menit), zero-padded times, helper text when the open button is disabled.
- Modify: `mobile/lib/pages/jadwal/jadwal_mingguan_page.dart` — remove "Riwayat Perubahan" placeholder.
- Remove unused `FaceOvalPainter` if unused after Task 12.
- Test: `mobile/test/ui_helpers_test.dart` (status color/label), `mobile/test/plate_validator_test.dart` (extract validator to `mobile/lib/utils/validators.dart`).

- [ ] **Step 1: Failing tests. Step 2: FAIL. Step 3: Implement. Step 4: mobile tests + analyze.**
- [ ] **Step 5: Commit** `fix(mobile): auth & vehicle forms, clear status colors, safer admin actions, remove dead code`.

### Task 14: Mobile — notifications deep links, push preference, per-user inbox

Spec: U8, B11 (client side).

**Files:**
- Modify: `mobile/lib/services/notification_service.dart` — route by `message.data['type']` on `FirebaseMessaging.onMessageOpenedApp` and `getInitialMessage()` (cold start after app is ready): `sesi_dibuka`/absensi types → attendance page; parkir types → parking history; kendaraan status → vehicle submission history; social (like/comment) → post/comments page if id present; unknown → notification list. Read the backend `utils/firebase.js` for the exact `type` strings sent and map those.
- Modify: `mobile/lib/pages/home/notification_list_page.dart` — inbox cards tappable using the same router.
- Create: `mobile/lib/utils/notification_router.dart` — pure `String? routeForNotification(Map<String, dynamic> data)` + navigation wrapper.
- Modify: `mobile/lib/pages/settings/notification_page.dart` — toggle state from the user profile (`push_notifications_enabled` from `/api/v1/auth/me`), saved via `PUT /api/v1/auth/preferences` `{push_notifications_enabled: bool}`; revert + error snackbar on failure.
- Modify: inbox persistence — SharedPreferences key namespaced by user id (`notifications_<id_user>`) and cleared on logout in `auth_controller.dart`.
- Test: `mobile/test/notification_router_test.dart`.

- [ ] **Step 1: Failing router tests. Step 2: FAIL. Step 3: Implement. Step 4: mobile tests + analyze.**
- [ ] **Step 5: Commit** `feat(mobile): notification deep links, real push preference, per-user inbox`.

### Task 15: Mobile — dosen attendance override UI & status display

Spec: U11 (override), B8 client.

**Files:**
- Modify: `mobile/lib/services/dosen_service.dart` — `Future<Map<String,dynamic>> overrideAbsensi({required int idSesi, required int idUser, required String status, String? keterangan})` → `PUT /api/v1/akademik/absensi/sesi/$idSesi/mahasiswa/$idUser`.
- Modify: `mobile/lib/pages/dosen/dosen_sesi_detail_page.dart` — per-student status chip; tap opens bottom sheet with the 5 statuses + optional note; optimistic update with rollback on error.
- Modify: `mobile/lib/models/absensi.dart` — parse `status` (default `HADIR`) and `keterangan`.
- Modify: `mobile/lib/pages/absensi/absensi_page.dart` (student history/detail) — show status label/color (`Hadir`, `Telat`, `Izin`, `Sakit`, `Alpha`).
- Create: `mobile/lib/utils/attendance_status.dart` — label + color mapping.
- Test: `mobile/test/attendance_status_test.dart`, extend `mobile/test/absensi_model_test.dart` (create if absent).

- [ ] **Step 1: Failing tests. Step 2: FAIL. Step 3: Implement. Step 4: mobile tests + analyze.**
- [ ] **Step 5: Commit** `feat(mobile): dosen attendance override and status display`.

### Task 16: Mobile — consistency, i18n, accessibility, caching, stale tests

Spec: U12, I8 (mobile tests).

**Files:**
- Modify: `mobile/pubspec.yaml` — add `flutter_localizations: { sdk: flutter }` (SDK package, allowed).
- Modify: `mobile/lib/app/app.dart` / `mobile/lib/main.dart` — `locale: Locale('id','ID')`, `supportedLocales`, `localizationsDelegates` (Global*), `Intl.defaultLocale = 'id_ID'`, `initializeDateFormatting('id_ID')`.
- Create: `mobile/lib/utils/date_helper.dart` — `toWib(DateTime)` (convert UTC → UTC+7 regardless of device tz), `formatTanggal`, `formatJam`, `formatTanggalJam` using `intl` `id_ID`; replace hand-rolled formatters (`absensi_page.dart:~883-896`, `dosen_manage_absensi_page.dart:~611`, `notification_list_page.dart:~36`, and others found by grep for `DateFormat(` / manual month arrays).
- Mechanical: replace `Color(0xFFE63946)` with `AppColors.primary` (define in `app_theme.dart` if missing) across `mobile/lib`; replace other near-duplicate reds only if they are clearly the brand color.
- Replace back-button `GestureDetector` + small icon with `IconButton(icon: Icon(Icons.arrow_back), tooltip: 'Kembali', onPressed: ...)` everywhere found by grep.
- `Image.network` → `CachedNetworkImage` (dependency already present) in `histori_parkir_page.dart`, `admin_biometrik_page.dart` and any other occurrence.
- Raw `$e`/`e.toString()` shown in UI → `ErrorHelper` message; English user-facing strings → Indonesian (`HomeController` snackbars, "Register Your Plat", admin `LivenessConfig` messages if configurable).
- Font sizes below 11 → 11; `RichText` → `Text.rich`.
- Fix stale tests: `mobile/test/akademik_service_test.dart` (service now returns a record `(List<KelasHariIniModel>, bool)`) and `mobile/test/auth_controller_test.dart` (login success) so the whole suite passes; remove unused imports flagged by analyze in `test/`.
- Test: `mobile/test/date_helper_test.dart` — `toWib(DateTime.utc(2026,10,13,18,30))` ⇒ 2026-10-14 01:30; `formatTanggal` ⇒ `"Rabu, 14 Oktober 2026"` (or the chosen pattern, stated in the test).

- [ ] **Step 1: Failing date helper tests. Step 2: FAIL. Step 3: Implement all. Step 4: ENTIRE mobile suite green (0 failures) + `flutter analyze` 0 errors and warnings ≤ baseline.**
- [ ] **Step 5: Commit** `refactor(mobile): id_ID locale, WIB dates, theme colors, accessible back buttons, cached images`.

### Task 16b: Indonesian backend messages and mobile follow-ups (inserted)

- [x] Translate remaining backend response messages and update explicit validation/error messages and affected tests. Preserve machine codes, status/envelope, logs, Socket.IO `Unauthorized`, and edge gate decisions.
- [x] Support both Indonesian responses and legacy English fallbacks in mobile, including dynamic vehicle and attendance messages.
- [x] Clear user-scoped controllers before storing a new login session, remove unused `LogParkirModel.localTimestamp`, and reuse the WIB relative-time helper in posts/comments.
- [x] Complete tests, analyzer checks, and independent specification/code-quality review. See the completion report for exact evidence.

### Task 17: CI gates, repo hygiene, docs

Spec: I3 (CI parts not done in Task 8), I8, I9.

**Files:**
- Modify: `.github/workflows/build-apk.yml` — `flutter analyze --no-fatal-infos` without `continue-on-error`; add `flutter test` step before build.
- Modify: `.github/workflows/ci-test.yml` — backend unit step uses `npm test` (unit only after Task 1); E2E step uses `npm run test:e2e`; coverage `collectCoverageFrom` includes `controllers/**`, `middlewares/**`, `utils/**` (configure in `backend/package.json`), no threshold enforcement beyond current numbers (set `coverageThreshold` global lines to current measured value rounded down to the nearest 5).
- Add `python -m unittest edge_device/test_parse_server_result.py` step in the contract job (Python already set up there).
- Delete: `backend/test-push.js` (sends real pushes). Keep root `test_detection.py`/`test_recognition.py` (documented model tests).
- Remove root `google-services.json` only if nothing references it (grep build files/workflows); otherwise keep.
- Modify: `README.md` — `/api/docs` path, correct data flow (Edge → Backend → Plate AI; Backend → Anomaly AI now true), Node 22, test commands, TZ note, attendance statuses, mobile test note.
- Modify: `TESTING_E2E.md` — remove `X-Test-Mode` header instructions; explain env `TEST_MODE`.
- Modify: `MyTelUV2_Postman_Collection.json` — add requests: absensi override, liveness token, anomaly job status, preferences (match exact paths).
- [x] **Step 1: Implement. Step 2: Run backend suite with coverage `npx jest --coverage --testPathIgnorePatterns "/\._" "test-e2e"` to measure and set threshold; YAML sanity (`node -e "require('js-yaml')"` only if available, else careful review).** Final tracked-only coverage: 731 tests passed, exit 0, 72.91% lines; threshold 70%. Coverage also excludes macOS `._*` sidecars.
- [x] **Step 3: Commit** `ci: gate mobile tests and coverage; docs and repo hygiene`.
