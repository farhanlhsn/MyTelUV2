# MyTelUV2

MyTelUV2 adalah aplikasi mobile smart-campus berbasis Flutter yang terhubung ke backend Node.js/Express/Prisma dan beberapa AI microservice untuk absensi biometrik, OCR plat kendaraan, dan analisis anomali kehadiran.

## System Overview

Komponen utama:

- `mobile/`: Flutter + GetX mobile app.
- `backend/`: Express API, Prisma ORM, auth, business logic, Socket.IO, dan integrasi R2.
- `backend/python-service/face_recognition/`: Flask/Gunicorn service untuk face detection dan embedding.
- `backend/python-service/plate_recognition/`: Flask service untuk OCR plat kendaraan dan forwarding edge-device parking flow.
- `backend/python-service/anomaly_detection/`: Flask/Gunicorn service untuk analisis anomali absensi.
- `edge_device/`: Raspberry Pi/edge camera client untuk deteksi plat dan kontrol gate.
- `docker-compose.yml` dan `docker-compose.prod.yml`: orkestrasi backend dan AI services.

Alur data utama:

```text
Mobile -> Backend API -> PostgreSQL
Mobile -> Backend API -> Face AI -> Backend -> PostgreSQL
Edge Device -> Plate AI -> Backend Parking API -> PostgreSQL/Socket.IO
Backend -> Anomaly AI -> Backend -> PostgreSQL
```

## Quick Start

```bash
npm run install-all
npm run python:setup
npm run start:windows
```

Alternatif platform:

```bash
npm run start:macos
npm run start:ios
npm run start:android
npm start
```

Catatan: Flutter secure storage tidak andal untuk flow login di web/browser. Gunakan desktop atau emulator/device mobile untuk testing auth.

## Environment

Copy `.env.example` ke `.env`, lalu isi secret yang sesuai.

```bash
cp .env.example .env
```

Jangan commit `.env`, `.env.production`, `.env.test`, credential Firebase, atau file secret lainnya. Jika file secret pernah ter-commit, rotate secret dan bersihkan history repository.

Mobile app tidak lagi membundel `assets/.env`. API URL dikonfigurasi melalui `--dart-define`:

```bash
cd mobile
flutter run -d windows --dart-define=API_URL_DEV_DEFAULT=http://localhost:5050
flutter run -d android --dart-define=API_URL_DEV=http://10.0.2.2:5050
flutter build apk --dart-define=ENV=prod --dart-define=API_URL_PROD=https://api.example.com
```

Saat `ENV=prod`, `API_URL_PROD` wajib diisi.

## Backend Setup

```bash
cd backend
npm install
npm run prisma:migrate
npm run prisma:generate
npm test
```

Backend default berjalan di port `5050`.

Swagger/OpenAPI docs tersedia di:

```text
http://localhost:5050/api-docs
```

Kalau backend dijalankan dari host lain atau via production compose, sesuaikan host-nya dan buka endpoint `api-docs` yang sama.

## AI Services

Face recognition:

```bash
cd backend/python-service/face_recognition
pip install -r requirements.txt
python app.py
```

Docs:

- `http://localhost:5051/docs`
- `http://localhost:5051/openapi.json`

Plate recognition:

```bash
cd backend/python-service/plate_recognition
pip install -r requirements.txt
python app.py
```

Docs:

- `http://localhost:5001/docs`
- `http://localhost:5001/openapi.json`

Anomaly detection:

```bash
cd backend/python-service/anomaly_detection
pip install -r requirements.txt
python app.py
```

Docs:

- `http://localhost:5003/docs`
- `http://localhost:5003/openapi.json`

Port default:

- Backend API: `5050`
- Face recognition: `5051`
- Plate recognition: `5001`
- Anomaly detection: `5003`

## Docker Compose

Development multi-service:

```bash
docker compose up --build
```

Production compose:

```bash
docker compose -f docker-compose.prod.yml up --build -d
```

Compose production menjalankan backend, face recognition, plate recognition, dan anomaly detection. Backend health check memakai `FACE_API_URL`, `PLATE_API_URL`, dan `ANOMALY_SERVICE_URL`.

### Deploy production

Deploy berjalan otomatis lewat `.github/workflows/deploy-backend.yml` setelah workflow CI sukses untuk **push** ke `main` (CI dari pull request tidak men-deploy; bisa juga manual lewat `workflow_dispatch`). Urutannya di VPS (`/opt/myteluv2`):

1. `git reset --hard <SHA yang diuji CI>` (bukan `origin/main` terbaru).
2. `.env` wajib sudah ada di server. Jika tidak ada, deploy gagal (tidak pernah disalin dari `.env.example`).
3. `docker compose -f docker-compose.prod.yml build`, lalu migrasi database dengan image baru **sebelum** container baru dijalankan:
   `docker compose -f docker-compose.prod.yml run --rm -T --no-deps backend npx prisma migrate deploy --schema prisma/schema.prisma`
   Jika migrasi gagal, deploy berhenti dan container lama tetap berjalan.
4. `docker compose -f docker-compose.prod.yml up -d`, lalu container Caddy dibuat ulang (`up -d --force-recreate --no-deps caddy`) supaya perubahan `deploy/Caddyfile` berlaku: file itu di-bind-mount tunggal dan `git` menggantinya sebagai file baru, sehingga container yang berjalan masih melihat file lama.
5. Health check: `curl -fsS http://127.0.0.1:8880/health` diulang hingga 30 kali tiap 5 detik. Caddy meneruskan `/health` ke backend, yang menjawab `503` bila database tidak tersedia, sehingga deploy dinyatakan gagal. `/health` dibatasi 60 permintaan per menit per IP (`429` jika terlampaui).

Catatan penting:

- **`DATABASE_URL` harus URL Postgres langsung** (`postgresql://...`) karena `prisma migrate deploy` membutuhkan koneksi langsung. `backend/prisma/schema.prisma` belum memakai `directUrl`; jika produksi memakai Prisma Accelerate (`prisma://...`), tambahkan `directUrl = env("DIRECT_URL")` pada datasource, isi `DIRECT_URL` dengan URL Postgres langsung di `.env`, dan sesuaikan `backend/prisma.config.ts`.
- **Sebelum deploy pertama lewat pipeline ini**, periksa status migrasi produksi dari VPS:
  `docker compose -f docker-compose.prod.yml run --rm -T --no-deps backend npx prisma migrate status --schema prisma/schema.prisma`
  Jika skema produksi dulu dibuat dengan `prisma db push` (tidak ada tabel `_prisma_migrations`, atau migrasi lama dilaporkan belum diterapkan padahal tabelnya sudah ada), `migrate deploy` akan gagal dengan "already exists". Lakukan baselining: tandai setiap migrasi yang strukturnya sudah ada di database dengan
  `docker compose -f docker-compose.prod.yml run --rm -T --no-deps backend npx prisma migrate resolve --applied <nama_folder_migrasi> --schema prisma/schema.prisma`
  (nama folder ada di `backend/prisma/migrations/`), lalu jalankan ulang `migrate status` sampai hanya migrasi baru yang tersisa. Migrasi `20261013000000_system_settings_and_absensi_unique` bersifat idempoten dan aman diterapkan di database yang sudah punya tabel/indeks tersebut.
- **Cek plat ganda sebelum deploy.** Migrasi `20261013000100_normalize_kendaraan_plates` menyeragamkan `kendaraan.plat_nomor` (huruf besar, hanya huruf dan angka) tetapi sengaja melewati baris yang hasil normalisasinya bentrok dengan baris lain, sehingga plat itu tetap dalam penulisan lama sampai dirapikan manual. Daftar kandidat bentrok (jalankan di Postgres produksi):
  ```sql
  SELECT upper(regexp_replace(plat_nomor, '[^A-Za-z0-9]', '', 'g')) AS plat_normal,
         count(*) AS jumlah,
         array_agg(id_kendaraan ORDER BY id_kendaraan) AS id_kendaraan,
         array_agg(plat_nomor ORDER BY id_kendaraan) AS penulisan_asli
  FROM kendaraan
  GROUP BY 1
  HAVING count(*) > 1;
  ```
- Image backend sengaja tetap membawa Prisma CLI (`npm ci --omit=dev` mempertahankannya karena dependensi opsional `@prisma/client`), dan build gagal bila CLI itu hilang.
- Caddy (`deploy/Caddyfile`) hanya meneruskan `/api/*`, `/socket.io/*`, dan `/health` ke backend. Layanan AI (face, plate, anomaly) tidak dibuka ke luar; backend memanggilnya lewat jaringan Docker dengan header `X-API-Key`.
- Log audit backend ditulis ke `AUDIT_LOG_DIR` (default `/app/logs`, volume `myteluv2-backend-logs`). Log container dirotasi (`json-file`, 10 MB x 3 file), setiap service punya batas memori (`mem_limit`), dan semua container memakai `TZ=Asia/Jakarta`.

## Key API Areas

Auth:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/auth/me`

Biometrik:

- `POST /api/v1/biometrik/request-liveness-token`
- `POST /api/v1/biometrik/absen`
- `POST /api/v1/biometrik/verify`
- `POST /api/v1/biometrik/scan`

Catatan: absensi biometrik wajib membawa `id_sesi_absensi` eksplisit dari sesi yang dipilih user.

Parkir:

- `GET /api/v1/parkir/all`
- `GET /api/v1/parkir/histori`
- `POST /api/v1/parkir/edge-entry`

Anomali:

- `POST /api/v1/anomali/analyze/:id_kelas`
- `GET /api/v1/anomali/:id_kelas`

## Security Notes

- R2 upload tidak memakai `public-read` secara default. Jika memakai private bucket, simpan object key dan layani file lewat signed URL/authenticated route.
- Jangan log token, refresh token, raw response yang memuat PII, atau foto/biometrik.
- `EDGE_DEVICE_SECRET`, `JWT_SECRET`, `FACE_API_KEY`, dan R2 credentials wajib unik per environment.
- Untuk production, set CORS `FRONTEND_URL`/domain yang spesifik.

## Testing

Backend unit/API tests:

```bash
cd backend
npm test
```

Targeted tests:

```bash
cd backend
node ../node_modules/jest/bin/jest.js test/parkirController.test.js --runInBand
node ../node_modules/jest/bin/jest.js test/biometrikAbsen.test.js --runInBand --coverage=false
node ../node_modules/jest/bin/jest.js test/anomaliController.test.js --runInBand
```

Mobile tests:

```bash
cd mobile
flutter test
flutter analyze
```

E2E orchestration:

```bash
powershell -ExecutionPolicy Bypass -File .\scripts\test-e2e.ps1
```

## Troubleshooting

Jika health check backend menunjukkan AI service `unreachable`, cek nilai:

- `FACE_API_URL`
- `PLATE_API_URL`
- `ANOMALY_SERVICE_URL`

Untuk Android emulator, backend host machine biasanya `http://10.0.2.2:5050`.

Jika InsightFace model belum ada, jalankan `npm run python:setup` atau lihat `backend/python-service/face_recognition/MODEL_INFO.md`.
