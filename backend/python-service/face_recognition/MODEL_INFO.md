# Face Recognition Models - InsightFace

## 🤖 Model: buffalo_l

InsightFace menggunakan model `buffalo_l` yang **otomatis download** saat pertama kali service dijalankan.

### Auto-Download Behavior

Model akan didownload ke `~/.insightface/models/buffalo_l/` meliputi:
- `det_10g.onnx` - Face detection model
- `w600k_r50.onnx` - Face recognition/embedding model  
- `1k3d68.onnx` - 3D landmark detection
- `2d106det.onnx` - 2D landmark detection
- `genderage.onnx` - Gender & age estimation

**Total size**: ~300MB

### First Run Download

Saat pertama kali menjalankan face recognition service:

```bash
cd face_recognition
source venv/bin/activate
python app.py
```

Output akan menunjukkan:
```
Applied providers: ['CPUExecutionProvider']
find model: ~/.insightface/models/buffalo_l/det_10g.onnx detection
find model: ~/.insightface/models/buffalo_l/w600k_r50.onnx recognition
...
🚀 Face Recognition API Server starting...
```

### Pre-Download Models (Optional)

Jika ingin download models sebelum first run, jalankan:

```bash
cd face_recognition
source venv/bin/activate
python -c "from insightface.app import FaceAnalysis; app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider']); app.prepare(ctx_id=0, det_size=(640, 640))"
```

Atau gunakan enhanced setup script:
```bash
bash setup.sh
# Pilih 'y' saat ditanya "Pre-download face recognition models now?"
```

### Location

Models tersimpan di:
```
~/.insightface/
└── models/
    └── buffalo_l/
        ├── det_10g.onnx
        ├── w600k_r50.onnx
        ├── 1k3d68.onnx
        ├── 2d106det.onnx
        └── genderage.onnx
```

### Cache Behavior

- Model hanya download sekali
- Subsequent runs langsung pakai cache
- Shared across semua projects yang pakai InsightFace

## 💡 Catatan

**Tidak perlu manual download** - InsightFace handle semuanya otomatis. Model akan ready saat service pertama kali start (tambah ~30 detik untuk download).
