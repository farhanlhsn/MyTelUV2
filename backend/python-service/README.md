# Python Services

Folder ini berisi AI microservices untuk MyTelUV2.

## Services

| Service | Folder | Port | Fungsi |
| --- | --- | --- | --- |
| Face Recognition | `face_recognition/` | `5051` | Deteksi wajah, ekstraksi embedding, dan face matching |
| Plate Recognition | `plate_recognition/` | `5001` | OCR plat kendaraan dan forwarding parking flow |
| Anomaly Detection | `anomaly_detection/` | `5003` | Analisis anomali absensi berbasis rule/statistik/Isolation Forest |

## Face Recognition

```bash
cd backend/python-service/face_recognition
pip install -r requirements.txt
python app.py
```

Endpoints:

- `GET /health`
- `POST /detect-face`
- `POST /detect-multiple`
- `POST /compare`
- `POST /find-match`

Service dilindungi dengan `FACE_API_KEY`; backend mengirim header `X-API-Key` (lihat "API key" di bawah).

## Plate Recognition

```bash
cd backend/python-service/plate_recognition
pip install -r requirements.txt
python app.py
```

Endpoints:

- `GET /health`
- `POST /api/recognize-plate`
- `POST /api/parking/process`
- `POST /api/parking/entry` legacy alias

Model yang dibutuhkan ada di `plate_recognition/models/`:

- `license_plate_recognition.pt`
- `license_plate_recognition.onnx`
- `classes.names`

Set `NODEJS_BACKEND_URL` dan `EDGE_DEVICE_SECRET` agar forwarding ke backend parkir aman.
`POST /api/parking/process` (dan alias `entry`) meneruskan ke backend dengan secret edge, sehingga hanya
dilayani jika request membawa `X-API-Key` yang valid (`PLATE_API_KEY` wajib diset, juga saat `TEST_MODE`).
`GET /health` mengembalikan 503 selama model belum termuat. Container menjalankan service dengan gunicorn
(`gunicorn.conf.py`).

## Anomaly Detection

```bash
cd backend/python-service/anomaly_detection
pip install -r requirements.txt
python app.py
```

Endpoints:

- `GET /health`
- `POST /detect-anomalies`

Payload utama:

```json
{
  "students": [{ "id_user": 1, "nama": "User" }],
  "attendance": [
    {
      "id_user": 1,
      "id_sesi": 10,
      "timestamp": "2026-05-25T08:05:00Z",
      "latitude": -6.97,
      "longitude": 107.63
    }
  ],
  "sessions": [
    {
      "id_sesi": 10,
      "mulai": "2026-05-25T08:00:00Z",
      "selesai": "2026-05-25T09:00:00Z",
      "latitude": -6.97,
      "longitude": 107.63
    }
  ],
  "total_sessions": 1,
  "threshold": 0.5,
  "contamination": 0.1
}
```

## Docker

Semua service dapat dijalankan via compose dari root repository:

```bash
docker compose up --build
docker compose -f docker-compose.prod.yml up --build -d
```

Production compose menjalankan ketiga AI service dan backend menggunakan service URL:

- `FACE_API_URL=http://face-recognition:5051`
- `PLATE_API_URL=http://plate-recognition:5001`
- `ANOMALY_SERVICE_URL=http://anomaly-detection:5003`

## API key

Setiap endpoint (kecuali `/health`) memerlukan header `X-API-Key` yang sama dengan env service:
`FACE_API_KEY`, `PLATE_API_KEY`, `ANOMALY_API_KEY`. Aturannya fail-closed:

- key belum diset dan bukan `TEST_MODE` -> `503 {"error": "service not configured"}`
- key diset tetapi header kosong/salah -> `401`
- key belum diset dan `TEST_MODE=true` -> diizinkan (CI/lokal)

Pembandingan key memakai `hmac.compare_digest`. Backend membangun header ini di
`backend/utils/pythonServiceHeaders.js`.

Untuk run lokal tanpa Docker: service plate membaca `.env` di root proyek, sedangkan face dan anomaly hanya
membaca environment proses, jadi ekspor key yang sama dengan backend (atau jalankan dengan `TEST_MODE=true`).

## Test Mode

Untuk contract/E2E tests, beberapa service mendukung `TEST_MODE=true` agar model berat tidak perlu dimuat.
Mode ini hanya ditentukan oleh env `TEST_MODE` pada service itu sendiri; header `X-Test-Mode` dari client
tidak lagi berpengaruh.

```bash
set TEST_MODE=true
python backend/python-service/face_recognition/app.py
python backend/python-service/plate_recognition/app.py
python backend/python-service/anomaly_detection/app.py
```

## Notes

- Face recognition akan mengunduh InsightFace model `buffalo_l` pada run pertama.
- Jangan commit model/secret baru tanpa memastikan `.gitignore` dan ukuran artifact sesuai.
- Untuk production, jalankan service melalui Gunicorn/Docker, bukan Flask debug server.
