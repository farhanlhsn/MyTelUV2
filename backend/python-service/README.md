# Face Recognition Python Service

Python Flask API service untuk face detection dan recognition menggunakan InsightFace.

## 🚀 Quick Start

### 1. Setup Virtual Environment
```bash
cd backend/python-service
python3 -m venv venv
source venv/bin/activate  # Mac/Linux
# atau
venv\Scripts\activate  # Windows
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

**Note**: First installation akan download InsightFace models (~300MB). Ini normal dan hanya terjadi sekali.

### 3. Run Service
```bash
python app.py
```

Service akan berjalan di `http://localhost:5051`

---

## 📡 API Endpoints

### Health Check
```http
GET /health
```

### Detect Single Face
```http
POST /detect-face
Content-Type: multipart/form-data

Body:
- image: file (jpg/png)

Response:
{
  "success": true,
  "embedding": [512D float array],
  "bbox": [x1, y1, x2, y2],
  "face_score": 0.99
}
```

### Detect Multiple Faces (CCTV)
```http
POST /detect-multiple
Content-Type: multipart/form-data

Body:
- image: file (jpg/png)

Response:
{
  "success": true,
  "faces": [
    {
      "embedding": [512D float array],
      "bbox": [x1, y1, x2, y2],
      "face_score": 0.99
    }
  ],
  "count": 5
}
```

### Compare Embeddings
```http
POST /compare
Content-Type: application/json

Body:
{
  "embedding1": [512D array],
  "embedding2": [512D array]
}

Response:
{
  "similarity": 0.87,
  "is_same_person": true,
  "threshold": 0.6
}
```

### Find Best Match
```http
POST /find-match
Content-Type: application/json

Body:
{
  "target_embedding": [512D array],
  "embeddings_list": [[512D array], ...]
}

Response:
{
  "best_match_index": 2,
  "similarity": 0.85,
  "is_match": true,
  "threshold": 0.6
}
```

---

## 🔧 Technical Details

### Model
- **InsightFace buffalo_l**: Accurate & fast model
- **Face Detection**: RetinaFace/SCRFD
- **Face Recognition**: ArcFace (512D embeddings)

### Similarity Threshold
- **> 0.6**: Same person (match)
- **0.4 - 0.6**: Uncertain
- **< 0.4**: Different person

### Performance
- Single face detection: ~100-200ms
- Multiple faces (10 faces): ~500-800ms
- CPU mode (dapat upgrade ke GPU untuk faster processing)

---

## 🐛 Troubleshooting

### Error: `No module named 'insightface'`
```bash
pip install -r requirements.txt
```

### Error: Model download failed
Coba install ulang dengan koneksi internet yang stabil:
```bash
pip uninstall insightface
pip install insightface==0.7.3
```

### Error: `ONNX Runtime error`
```bash
pip install onnxruntime==1.17.0
```

---

## 📝 Notes

- Service ini **harus running** bersamaan dengan Node.js backend
- Default port: 5051 (dapat diubah di `app.py`)
- CORS sudah enabled untuk komunikasi dengan Node.js
