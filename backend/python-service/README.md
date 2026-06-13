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

Service dapat dilindungi dengan `FACE_API_KEY`; backend mengirim header `X-API-Key`.

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

## Test Mode

Untuk contract/E2E tests, beberapa service mendukung `TEST_MODE=true` agar model berat tidak perlu dimuat.

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
