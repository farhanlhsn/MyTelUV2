# 🧪 End-to-End (E2E) Testing Guide — MyTelU V2

Panduan lengkap untuk konfigurasi, eksekusi, dan pemeliharaan seluruh rangkaian pengujian End-to-End (E2E) pada sistem MyTelU V2.

## 📐 Arsitektur Testing

```mermaid
graph TD
    A[scripts/test-e2e.sh] --> B[Docker: PostgreSQL Test DB :5433]
    A --> C[Prisma Migrate + Seed]
    A --> D[Face Recognition :5051 TEST_MODE]
    A --> E[Plate Recognition :5001 TEST_MODE]
    A --> F[Anomaly Detection :5003 TEST_MODE]
    A --> G[Node.js Backend :5050 NODE_ENV=test]
    A --> H[AI Contract Tests - Python unittest]
    A --> I[Backend E2E Tests - Jest + Axios]
```

Rangkaian testing mencakup tiga lapisan:

| Layer | Tools | File | Target |
|---|---|---|---|
| **Unit Tests** | Jest + Mock | `backend/test/*.test.js` | Controller logic, validasi input |
| **Unit Tests** | Flutter test + Mockito | `mobile/test/*.dart` | Service layer, model parsing |
| **AI Contract Tests** | Python unittest | `backend/python-service/tests/test_ai_contract.py` | Flask API schema, ML logic |
| **Backend E2E** | Jest + Axios | `backend/test-e2e/api_e2e.test.js` | User journey end-to-end via real HTTP |
| **Mobile E2E** | Flutter integration_test | `mobile/integration_test/app_e2e_test.dart` | UI flow di emulator/device |

---

## 🐳 Prasyarat (Prerequisites)

| Tool | Versi Minimum | Fungsi |
|---|---|---|
| Docker Desktop | 4.x | PostgreSQL test container |
| Node.js | 18+ | Backend server + Jest |
| npm | 9+ | Package management |
| Python | 3.9+ | AI microservices + contract tests |
| pip | 22+ | Python dependencies |
| Flutter SDK | 3.x | Mobile integration tests |
| curl | any | Service readiness check di script |

---

## ⚙️ Setup Environment (`.env.test`)

File `.env.test` **tidak dicommit** ke repository (ada di `.gitignore`). Buat dari template:

```bash
cp .env.test.example .env.test
# Sesuaikan nilai jika perlu (default sudah cocok untuk test lokal)
```

Isi minimal `.env.test`:

```env
DATABASE_URL="postgresql://test_user:test_password@localhost:5433/myteluv2_test?schema=public"
JWT_SECRET="e2e-testing-super-secret-key-minimum-32-chars"
JWT_REFRESH_SECRET="e2e-testing-refresh-secret-key-minimum-32-chars"
PORT=5050
NODE_ENV="test"
EDGE_DEVICE_SECRET="e2e-testing-edge-device-secret-32-chars"
FACE_API_URL="http://localhost:5051"
PLATE_API_URL="http://localhost:5001"
ANOMALY_SERVICE_URL="http://localhost:5003"
```

---

## 🚀 Menjalankan E2E Test (One Command)

### Windows (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-e2e.ps1
```

### Linux / macOS / Git Bash:
```bash
chmod +x scripts/test-e2e.sh
./scripts/test-e2e.sh
```

Script otomatis akan:
1. Start PostgreSQL test container
2. Migrasi schema & seed data deterministik
3. Start 3 AI services dalam `TEST_MODE`
4. Start Node.js backend dalam `NODE_ENV=test`
5. Tunggu semua service siap via HTTP health check
6. Jalankan AI contract tests
7. Jalankan backend E2E tests
8. Cleanup semua proses & container

---

## 🛠️ Menjalankan Test Secara Manual

### Langkah 1: Start Test Database
```bash
docker compose -f docker-compose.test.yml up -d db-test
# Tunggu sampai healthy
docker exec myteluv2-postgres-test pg_isready -U test_user -d myteluv2_test
```

### Langkah 2: Migrasi & Seed
```bash
# Migrasi schema
npx dotenv -e .env.test -- prisma migrate deploy --schema backend/prisma/schema.prisma

# Generate Prisma client
npx dotenv -e .env.test -- prisma generate --schema backend/prisma/schema.prisma

# Seed data test deterministik
npx dotenv -e .env.test -- node backend/prisma/seed-test-data.js
```

### Langkah 3: Start AI Services (TEST_MODE)
```bash
export TEST_MODE=true
export NODEJS_BACKEND_URL=http://localhost:5050

# Di terminal terpisah masing-masing:
python backend/python-service/face_recognition/app.py
python backend/python-service/plate_recognition/app.py
python backend/python-service/anomaly_detection/app.py
```

### Langkah 4: Start Backend
```bash
export NODE_ENV=test
node backend/server.js
```

### Langkah 5: Jalankan Tests

**A. Backend Unit Tests saja:**
```bash
cd backend
npm run test:unit
```

**B. AI Contract Tests:**
```bash
python -m pytest backend/python-service/tests/test_ai_contract.py -v
# atau jika pytest tidak tersedia:
python -m unittest backend/python-service/tests/test_ai_contract.py -v
```

**C. Backend E2E Tests:**
```bash
cd backend
npm run test:e2e
```

**D. Semua Backend Tests:**
```bash
cd backend
npm run test:all
```

**E. Mobile Integration Test:**
```bash
# Pastikan emulator Android/iOS sudah berjalan
cd mobile
flutter test integration_test/app_e2e_test.dart
```

---

## 📊 Test Data yang Diseed

File: `backend/prisma/seed-test-data.js`

| Data | Value | Keterangan |
|---|---|---|
| Mahasiswa | username: `mhs_test`, password: `password123`, nim: `1301210001` | User utama untuk E2E test |
| Dosen | username: `dosen_test`, password: `password123` | Untuk test buka sesi absensi |
| Admin | username: `admin_test`, password: `password123` | Untuk test admin operations |
| Kendaraan | plat: `B1234XYZ` (terverifikasi) | Untuk test parkir flow |
| Kelas | IF-45-01, Matakuliah IF301 | Untuk test absensi |
| Biometrik | dummy 512D embedding `[0.02 × 512]` | Untuk test face recognition bypass |
| Parkiran | PARKIRAN_AULA, kapasitas 100 | Untuk test entry/exit parkir |

### Cleanup & Reset:
```bash
# Reset seluruh test database ke state awal
npx dotenv -e .env.test -- node backend/prisma/seed-test-data.js
```
Script seed sudah termasuk cleanup otomatis di awal sebelum insert ulang.

---

## 🧪 Skenario E2E yang Dicakup

### A. Authentication & Authorization
| ID | Skenario | Status |
|---|---|---|
| E2E-001 | Login mahasiswa berhasil, token diterima | ✅ |
| E2E-002 | Login dosen berhasil, token diterima | ✅ |
| E2E-003 | Akses `/auth/me` dengan token valid | ✅ |
| E2E-004 | Akses endpoint protected tanpa token → 401 | ✅ |
| E2E-005 | Akses endpoint protected dengan token invalid → 401 | ✅ |
| E2E-006 | Login dengan password salah → 401 | ✅ |
| E2E-007 | Logout berhasil | ✅ |

### B. Biometrik Absensi (Anti-Cheat)
| ID | Skenario | Status |
|---|---|---|
| E2E-010 | Dosen buka sesi absensi berhasil | ✅ |
| E2E-011 | Absensi ditolak jika `is_mock_location: true` | ✅ |
| E2E-012 | Absensi ditolak jika `liveness_verified: false` | ✅ |
| E2E-013 | Absensi biometrik berhasil (semua checks pass) | ✅ |

### C. Parkir & OCR
| ID | Skenario | Status |
|---|---|---|
| E2E-020 | Edge device kirim plat, gerbang terbuka | ✅ |

### D. Anomaly Detection
| ID | Skenario | Status |
|---|---|---|
| E2E-030 | Dosen bisa lihat laporan anomali kelas | ✅ |

### E. Kendaraan
| ID | Skenario | Status |
|---|---|---|
| E2E-040 | Mahasiswa bisa daftar kendaraan baru | ✅ |
| E2E-041 | Mahasiswa bisa lihat list kendaraannya | ✅ |

### F. Social Posts
| ID | Skenario | Status |
|---|---|---|
| E2E-050 | Mahasiswa bisa buat post | ✅ |
| E2E-051 | Mahasiswa bisa lihat daftar post | ✅ |

### G. AI Contract Tests (Python)
| ID | Skenario | Status |
|---|---|---|
| AI-001 | Face service health check | ✅ |
| AI-002 | Plate service health check | ✅ |
| AI-003 | Anomaly service health check | ✅ |
| AI-004 | Face detect-single (TEST_MODE) | ✅ |
| AI-005 | Face detect tanpa gambar → 400 | ✅ |
| AI-006 | Face compare embedding schema | ✅ |
| AI-007 | Face compare missing field → 400 | ✅ |
| AI-008 | Face find-match schema | ✅ |
| AI-009 | Face find-match missing field → 400 | ✅ |
| AI-010 | Plate recognize (TEST_MODE) | ✅ |
| AI-011 | Anomaly detection logic + Isolation Forest | ✅ |
| AI-012 | Anomaly empty students → count 0 | ✅ |
| AI-013 | Anomaly missing required field → 400 | ✅ |
| AI-014 | Anomaly invalid total_sessions → 400 | ✅ |
| AI-015 | Anomaly non-JSON body → 400 | ✅ |
| AI-016 | Anomaly schema field validation | ✅ |

### H. Mobile UI E2E
| ID | Skenario | Status |
|---|---|---|
| MOB-001 | Login berhasil, navigasi ke home | ✅ |
| MOB-002 | Navigasi ke halaman Biometrik | ✅ |
| MOB-003 | Logout berhasil, kembali ke login | ✅ |

---

## 🤖 AI Service Strategy

### Mode Pengujian vs. Mode Produksi

| Aspek | TEST_MODE | Production |
|---|---|---|
| Face model (InsightFace) | **Dilewati** — return mock embedding | Dijalankan penuh |
| Plate model (YOLOv8) | **Dilewati** — return `B1234XYZ` | Dijalankan penuh |
| Anomaly (Isolation Forest) | **Dijalankan** — scikit-learn ringan | Sama |
| Startup time | ~1 detik | 5-30 detik |

**Kenapa TEST_MODE?** Model InsightFace (~150MB) dan YOLOv8 (~6MB) memerlukan waktu lama untuk loading dan tidak deterministic untuk E2E testing. AI contract tests sudah memvalidasi API schema dan business logic secara penuh; model testing dilakukan terpisah via `test_detection.py` dan `test_recognition.py`.

### Aktivasi TEST_MODE:
```bash
# Environment variable
export TEST_MODE=true

# Atau per-request via header (untuk backend forwarding)
X-Test-Mode: true
```

---

## 🔄 CI/CD Integration

File workflow: `.github/workflows/ci-test.yml`

Pipeline berjalan otomatis pada:
- Push ke `main`, `develop`, `staging`
- Pull Request yang target branch tersebut

**Jobs:**
1. `backend-unit-tests` — Jest unit tests + coverage upload
2. `ai-contract-tests` — Python AI contract tests (parallel dengan job 1)
3. `backend-e2e-tests` — Full stack E2E (hanya jika unit tests lulus)

Mobile E2E test **tidak** dijalankan di CI otomatis karena memerlukan emulator Android/iOS (resource intensif). Jalankan manual sebelum release.

---

## 🛑 Troubleshooting

### PostgreSQL Container Tidak Siap
```bash
# Cek status container
docker ps
docker logs myteluv2-postgres-test

# Pastikan port 5433 tidak dipakai
netstat -an | grep 5433  # Linux/macOS
netstat -ano | findstr 5433  # Windows
```

### AI Service Tidak Mau Start
```bash
# Cek apakah venv sudah dibuat
ls backend/python-service/face_recognition/venv/

# Install dependencies jika belum
cd backend/python-service/face_recognition
python -m venv venv
venv/bin/pip install -r requirements.txt
# Ulangi untuk plate_recognition dan anomaly_detection
```

### Backend E2E Tests Gagal dengan "Connection Refused"
Pastikan:
1. Backend server sudah berjalan di port 5050
2. Semua AI services sudah berjalan
3. Test data sudah di-seed
4. `.env.test` sudah ada dan benar

### Jest "Cannot find module '../generated/prisma'"
```bash
cd backend
npx dotenv -e ../.env.test -- prisma generate --schema prisma/schema.prisma
```

### InsightFace / YOLO Error
E2E test tidak memerlukan model berat. Pastikan `TEST_MODE=true` sudah diset sebelum menjalankan Python services.

### Flutter Integration Test Gagal
- Pastikan emulator dalam kondisi unlocked
- Nonaktifkan keyboard virtual (software keyboard)
- Pastikan backend sedang berjalan dan dapat diakses dari emulator
  - Android Emulator: `http://10.0.2.2:5050`
  - iOS Simulator: `http://localhost:5050`

---

## 📋 Batasan Testing yang Belum Dicakup

| Area | Keterangan | Rekomendasi |
|---|---|---|
| Mobile E2E (CI) | Hanya bisa dijalankan manual | Tambahkan emulator di CI (Reactivecircus/android-emulator-runner) |
| Face recognition real model | Dilewati di E2E (TEST_MODE) | Test terpisah via `test_detection.py` |
| Plate recognition real model | Dilewati di E2E (TEST_MODE) | Test terpisah via `test_recognition.py` |
| Load testing | Belum ada | Implementasikan dengan k6 atau locust |
| Push notification (Firebase) | Belum ada | Gunakan Firebase emulator |
| File upload ke R2 | Belum ada | Mock R2 di test environment |
| WebSocket events | Belum ada | Tambahkan socket.io-client di test |
| Refresh token flow | Belum ada | Tambahkan ke backend E2E tests |
| Admin endpoints | Belum ada | Tambahkan test untuk endpoint admin |
