# Python Services

Layanan Python untuk MyTelUV2 yang terdiri dari dua service terpisah:
1. **Face Recognition** - Deteksi dan pengenalan wajah menggunakan InsightFace
2. **License Plate Recognition** - Pengenalan plat nomor kendaraan menggunakan YOLOv8

## Struktur Folder

```
python-service/
├── face_recognition/          # Service face recognition
│   ├── __init__.py
│   ├── app.py                # Flask server (port 5051)
│   ├── face_processor.py     # Logika face detection & embedding
│   ├── requirements.txt      # Dependencies untuk face recognition
│   └── models/               # Face recognition models (if any)
│
├── plate_recognition/         # Service license plate recognition
│   ├── __init__.py
│   ├── app.py                # Flask server (port 5001)
│   ├── requirements.txt      # Dependencies untuk plate recognition
│   └── models/               # Plate recognition models
│       ├── license_plate_recognition.pt
│       ├── license_plate_recognition.onnx
│       └── classes.names
│
├── shared/                    # Utilities bersama (bila ada)
│   └── __init__.py
│
├── README.md                  # Dokumentasi ini
└── setup.sh                   # Script setup otomatis
```

## Service 1: Face Recognition

### Port: 5051

### Endpoints:
- `GET /health` - Health check
- `POST /detect-face` - Deteksi single face dan ekstrak embedding
- `POST /detect-multiple` - Deteksi multiple faces (untuk CCTV)
- `POST /compare` - Bandingkan dua embeddings
- `POST /find-match` - Cari match terbaik dari list embeddings

### Cara Menjalankan:

```bash
cd face_recognition

# Install dependencies
pip install -r requirements.txt

# Jalankan server
python app.py
```

Server akan berjalan di `http://localhost:5051`

### Contoh Penggunaan:

```bash
# Detect single face
curl -X POST http://localhost:5051/detect-face \
  -F "image=@path/to/face.jpg"

# Compare embeddings
curl -X POST http://localhost:5051/compare \
  -H "Content-Type: application/json" \
  -d '{"embedding1": [...], "embedding2": [...]}'
```

## Service 2: License Plate Recognition

### Port: 5001

### Model Requirements:
This service requires trained YOLO models in `plate_recognition/models/`:
- `license_plate_recognition.pt` - YOLOv8 PyTorch model
- `license_plate_recognition.onnx` - ONNX format (optional)
- `classes.names` - Character class names (0-9, A-Z)

**To get the models:**
1. Train using `license-plate-recognition-training.ipynb` in project root
2. Copy trained models:
   ```bash
   cp /path/to/models/recognition/* backend/python-service/plate_recognition/models/
   ```

### Endpoints:
- `GET /health` - Health check
- `POST /api/recognize-plate` - Recognize characters dari gambar plat
- `POST /api/parking/entry` - Log parking entry dengan plate recognition

### Cara Menjalankan:

```bash
cd plate_recognition

# Install dependencies
pip install -r requirements.txt

# Jalankan server
python app.py
```

Server akan berjalan di `http://localhost:5001`

### Model Requirements:
Service ini membutuhkan model YOLOv8 di lokasi:
- `../models/recognition/license_plate_recognition.pt`
- `../models/recognition/classes.names`

### Contoh Penggunaan:

```bash
# Recognize plate
curl -X POST http://localhost:5001/api/recognize-plate \
  -F "image=@path/to/plate.jpg"

# Parking entry
curl -X POST http://localhost:5001/api/parking/entry \
  -F "image=@path/to/plate.jpg"
```

## Setup Otomatis

Gunakan script `setup.sh` untuk setup kedua service sekaligus:

```bash
bash setup.sh
```

Script akan:
1. Membuat virtual environment untuk masing-masing service
2. Install dependencies yang diperlukan
3. Memberikan instruksi cara menjalankan service

## Development

### Menjalankan Kedua Service Secara Bersamaan

Untuk development, Anda bisa menjalankan kedua service di terminal terpisah:

**Terminal 1 (Face Recognition):**
```bash
cd face_recognition
source venv/bin/activate  # jika pakai venv
python app.py
```

**Terminal 2 (Plate Recognition):**
```bash
cd plate_recognition
source venv/bin/activate  # jika pakai venv
python app.py
```

### Running dengan Docker (Optional)

Setiap service bisa dijalankan dengan Docker container terpisah untuk isolasi yang lebih baik.

## Integration dengan Backend

Backend Node.js memanggil service-service ini via HTTP:

### Face Recognition Integration:
```javascript
const faceApiUrl = 'http://localhost:5051';

// Detect face
const formData = new FormData();
formData.append('image', imageFile);
const response = await axios.post(`${faceApiUrl}/detect-face`, formData);
```

### Plate Recognition Integration:
```javascript
const plateApiUrl = 'http://localhost:5001';

// Recognize plate
const formData = new FormData();
formData.append('image', plateImage);
const response = await axios.post(`${plateApiUrl}/api/recognize-plate`, formData);
```

## Troubleshooting

### InsightFace Model Download
Pada run pertama, InsightFace akan download model `buffalo_l` (~300MB). Pastikan koneksi internet stabil.

### YOLOv8 Model Not Found
Pastikan model `license_plate_recognition.pt` ada di folder `models/recognition/`.

### Port Already in Use
Jika port sudah digunakan, ubah port di `app.py`:
```python
app.run(host='0.0.0.0', port=XXXX, debug=True)
```

## Dependencies

### Face Recognition
- Flask & Flask-CORS
- InsightFace (deep learning face recognition)
- ONNX Runtime
- OpenCV
- NumPy
- Pillow

### Plate Recognition
- Flask & Flask-CORS
- Ultralytics (YOLOv8)
- ONNX Runtime (alternative)
- OpenCV
- NumPy
- Pillow
- PyYAML

## License

Part of MyTelUV2 Project
