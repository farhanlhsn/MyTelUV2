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

## AI Services

Face recognition:

```bash
cd backend/python-service/face_recognition
pip install -r requirements.txt
python app.py
```

Plate recognition:

```bash
cd backend/python-service/plate_recognition
pip install -r requirements.txt
python app.py
```

Anomaly detection:

```bash
cd backend/python-service/anomaly_detection
pip install -r requirements.txt
python app.py
```

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
