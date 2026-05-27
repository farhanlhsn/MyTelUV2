# 🧪 End-to-End (E2E) Testing Guide - MyTelU V2

Panduan lengkap untuk mengonfigurasi, menjalankan, dan memelihara seluruh rangkaian pengujian End-to-End (E2E) pada sistem MyTelU V2.

Rangkaian testing ini mencakup:
1. **AI Microservice Contract Tests (Python)**: Menguji kecocokan API schema, REST endpoints, dan algoritma Isolation Forest/InsightFace/YOLOv8 dalam mode pengujian khusus (`TEST_MODE=true`).
2. **Backend E2E/API Integration Tests (Jest + Axios)**: Memvalidasi seluruh skenario bisnis utama yang menghubungkan Backend Node.js ↔ Database PostgreSQL ↔ Python AI Services secara nyata.
3. **Mobile UI E2E Tests (Flutter integration_test)**: Menguji user journey utama langsung di level UI (Simulasi Login, Geofence Attendance, dan Logout).

---

## 🐳 Persyaratan Utama (Prerequisites)

Sebelum menjalankan pengujian E2E, pastikan *tools* berikut telah terinstal pada mesin lokal Anda:

1. **Docker & Docker Compose**: Untuk menjalankan PostgreSQL test database container.
2. **Node.js (v18+) & npm**: Untuk backend API server dan pengujian Jest.
3. **Python (v3.9+) & pip**: Untuk menjalankan AI Microservices lokal dan `unittest`.
4. **Flutter SDK**: Untuk menjalankan Flutter integration UI tests pada emulator.

---

## ⚙️ Konfigurasi Environment (`.env.test`)

File konfigurasi `.env.test` telah dibuat secara otomatis di root repository untuk mengisolasi database pengujian dari database *development* biasa:

```env
# Database khusus testing (Container PostgreSQL di port 5433)
DATABASE_URL="postgresql://test_user:test_password@localhost:5433/myteluv2_test?schema=public"

# Secrets khusus testing
JWT_SECRET="e2e-testing-super-secret-key-32-chars"
JWT_REFRESH_SECRET="e2e-testing-super-refresh-secret-key-32-chars"
EDGE_DEVICE_SECRET="e2e-testing-edge-device-secret-32-chars"

# Konfigurasi Ports
PORT=5050
NODE_ENV="test"
```

---

## 🚀 Cara Menjalankan Pengujian Terotomasi (Satu Tombol)

Kami telah membuat skrip orkestrasi otomatis yang menangani pengunduhan DB uji, migrasi schema, seeding data deterministik, menjalankan server-server di background, menjalankan semua tes, dan membersihkan semuanya kembali.

### 💻 Di Windows (PowerShell):
Buka PowerShell sebagai Administrator (jika diperlukan untuk proses startup Docker) dan jalankan:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-e2e.ps1
```

### 🐧 Di Linux / macOS / Git Bash:
```bash
chmod +x scripts/test-e2e.sh
./scripts/test-e2e.sh
```

---

## 🛠️ Cara Menjalankan Pengujian Secara Manual (Langkah demi Langkah)

Jika Anda ingin melakukan debugging atau menjalankan modul pengujian tertentu secara terpisah, ikuti langkah-langkah berikut:

### Langkah 1: Jalankan Database Uji
```bash
docker compose -f docker-compose.test.yml up -d db-test
```

### Langkah 2: Jalankan Migrasi & Data Seeding
```bash
# Migrasi schema Prisma
npx dotenv -e .env.test -- prisma migrate dev --schema backend/prisma/schema.prisma

# Seed data uji deterministik
npx dotenv -e .env.test -- node backend/prisma/seed-test-data.js
```

### Langkah 3: Jalankan Python AI Services dalam `TEST_MODE`
```bash
# Set environment variable untuk bypass model berat InsightFace/YOLOv8
export TEST_MODE=true

# Jalankan masing-masing Flask service
python backend/python-service/face_recognition/app.py
python backend/python-service/plate_recognition/app.py
python backend/python-service/anomaly_detection/app.py
```

### Langkah 4: Jalankan Backend Server dalam `NODE_ENV=test`
```bash
export NODE_ENV=test
export PORT=5050
node backend/server.js
```

### Langkah 5: Eksekusi Test Suites

* **Eksekusi AI Contract Tests (Python)**:
  ```bash
  python -m unittest backend/python-service/tests/test_ai_contract.py
  ```

* **Eksekusi Backend E2E API Tests (Jest)**:
  ```bash
  cd backend
  npx jest test-e2e/api_e2e.test.js --runInBand --detectOpenHandles --forceExit
  ```

* **Eksekusi Mobile UI E2E Tests (Flutter)**:
  Nyalakan Android Emulator atau iOS Simulator terlebih dahulu, lalu jalankan:
  ```bash
  cd mobile
  flutter test integration_test/app_e2e_test.dart
  ```

---

## 🛡️ Skenario Penting yang Dicakup dalam Test E2E

### A. Authentication & Session Persistence
* Login sukses menggunakan akun mahasiswa deterministik (`mhs_test` / `password123`) dan dosen (`dosen_test` / `password123`).
* Verifikasi profil `/me` terproteksi dengan header Bearer JWT Token.
* Menjamin pembersihan FCM tokens di basis data saat proses logout.

### B. Geofenced Biometric Attendance (Anti-Cheat Flow)
* Membuka sesi absensi berbatas koordinat lokasi (radius 100m) oleh dosen.
* **Uji GPS Spoofing**: Memastikan server menolak absensi jika aplikasi mobile mengirimkan flag `is_mock_location: true` (Status 400).
* **Uji Liveness Check**: Memastikan server menolak absensi jika user melewati liveness verification (`liveness_verified: false`).
* Absensi biometrik sukses jika seluruh kriteria geofence & liveness check terpenuhi secara sah.

### C. Parking Gate OCR & Database Entry
* Menyintesis pengiriman data plat nomor (`B1234XYZ`) dari edge device simulator ke AI Plate Recognition.
* Memverifikasi AI memforward log masuk tersebut ke Node.js Backend dengan otentikasi edge secret header `X-Edge-Secret` yang valid.
* Memastikan gerbang parkir merespon `"ALLOW"`.

### D. Anomaly Detection ML (Isolation Forest)
* Menguji algoritma pendeteksi pencilan Isolation Forest dalam mengelompokkan anomali kehadiran `TIDAK_HADIR_BERULANG` dan `POLA_WAKTU_TIDAK_WAJAR` berdasarkan input dataset log historis secara deterministik.

---

## 🛑 Pemecahan Masalah (Troubleshooting)

### 1. Error: `PrismaClientInitializationError` / Database Unreachable
* Pastikan container PostgreSQL test telah menyala sempurna dengan memeriksa status docker: `docker ps`.
* Port `5433` harus bebas dan tidak digunakan oleh instansi database native lainnya.

### 2. Error: `InsightFace / YOLO model download failed`
* Uji E2E ini dirancang untuk berjalan cepat tanpa mengunduh bobot model. Pastikan environment `TEST_MODE=true` telah tersetup sempurna di terminal tempat Anda mengeksekusi python service agar Flask menggunakan *contract mock adapter*.

### 3. Flutter Integration Test gagal mencari widget
* Pastikan emulator dalam kondisi tidak terkunci (*unlocked*) dan keyboard virtual mati (*hidden*) karena hal tersebut dapat mengalangi proses input teks otomatis oleh driver testing.
