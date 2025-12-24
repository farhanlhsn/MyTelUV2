# 🧪 Testing Models - Quick Guide

Panduan cepat untuk testing model detection & recognition yang sudah di-training.

## ✅ Models Ready!

Models sudah tersedia di:
- `models/detection/license_plate_detection.pt` (3.7MB)
- `models/detection/license_plate_detection.onnx` (7.1MB)
- `models/recognition/license_plate_recognition.pt` (5.9MB)
- `models/recognition/license_plate_recognition.onnx` (12MB)

## 🚀 Quick Start

### 1. Install Dependencies

```bash
pip install ultralytics opencv-python numpy
```

### 2. Test Detection Model

Test deteksi plat nomor dari foto mobil:

```bash
# Using PyTorch model
python test_detection.py --image path/to/car_image.jpg

# Using ONNX model (faster, for edge devices)
python test_detection.py --image path/to/car_image.jpg --onnx
```

**Output:**
```
✅ DETECTION RESULTS
Detections found: 1
Inference time: 45.23 ms
FPS: 22.11
Plate 1: bbox=[234, 456, 567, 512], conf=0.945
```

### 3. Test Recognition Model (OCR)

Test OCR pada gambar plat nomor yang sudah di-crop:

```bash
python test_recognition.py --image path/to/cropped_plate.jpg
```

**Output:**
```
✅ OCR RESULTS
📋 Plate Text: "B1234XYZ"
🎯 Confidence: 0.892 (89.2%)
🔢 Characters detected: 8
⚡ Inference time: 52.11 ms
```

### 4. Full Pipeline Demo

Test end-to-end dari foto mobil langsung ke teks plat nomor:

```bash
python demo_full_pipeline.py --image path/to/car_image.jpg
```

**Output:**
```
🚗 LICENSE PLATE DETECTION & RECOGNITION DEMO
STEP 1: LICENSE PLATE DETECTION
⚡ Detection time: 45.23 ms
📋 Plates detected: 1

STEP 2: OCR
⚡ OCR time: 52.11 ms
✅ RESULT: "B1234XYZ"
🎯 OCR confidence: 0.892 (89.2%)

📊 PERFORMANCE SUMMARY
Total pipeline time: 97.34 ms
Pipeline FPS: 10.27
```

## 📸 Get Test Images

### Option 1: From Dataset

```bash
# Use images from your training dataset
python test_detection.py --image archive/Indonesian\ License\ Plate\ Dataset/images/test/test001.jpg
```

### Option 2: Download Sample

```bash
# Find Indonesian car images online or take your own photos
# Make sure plat nomor visible dan tidak terlalu miring
```

### Option 3: Use Webcam (Coming Soon)

```bash
python demo_webcam.py  # Real-time detection
```

## 🔧 Advanced Options

### Detection with Custom Confidence

```bash
python test_detection.py --image car.jpg --conf 0.3  # Lower threshold
```

### Recognition with Different Model

```bash
python test_recognition.py --image plate.jpg --model models/recognition/license_plate_recognition.onnx
```

### Save Results

Results are automatically saved with suffix:
- Detection: `*_detection.jpg`
- Recognition: `*_ocr.jpg`
- Full pipeline: `*_full_result.jpg`

## 📊 Expected Performance

### Detection Model (YOLOv5n)
- **Accuracy**: mAP@0.5 > 90%
- **Speed**: 40-60 ms on laptop, ~500ms on Raspberry Pi 2
- **Model size**: 3.7MB (PT), 7.1MB (ONNX)

### Recognition Model (YOLOv8n)
- **Accuracy**: ~85-90% per character
- **Full plate**: 70-80% exact match
- **Speed**: 50-80 ms on laptop, ~200ms on server
- **Model size**: 5.9MB (PT), 12MB (ONNX)

## 🐛 Troubleshooting

### Error: "No module named 'ultralytics'"

```bash
pip install ultralytics
```

### Error: "Failed to load image"

Check image path is correct:
```bash
ls -lh path/to/image.jpg
```

### Low Confidence Scores

- Try different `--conf` threshold
- Check image quality (resolution, lighting, angle)
- Plat nomor harus visible dan tidak terlalu blur

### No Detection

- Lower confidence threshold: `--conf 0.3`
- Check if plate is visible in image
- Try different image

## 📝 Script Parameters

### test_detection.py
```
--image   : Path to test image (required)
--model   : Model path (default: models/detection/license_plate_detection.pt)
--conf    : Confidence threshold (default: 0.5)
--onnx    : Use ONNX inference
```

### test_recognition.py
```
--image   : Path to cropped plate (required)
--model   : Model path (default: models/recognition/license_plate_recognition.pt)
--classes : Classes file (default: models/recognition/classes.names)
--conf    : Confidence threshold (default: 0.25)
```

### demo_full_pipeline.py
```
--image              : Path to car image (required)
--detection-model    : Detection model path
--recognition-model  : Recognition model path
--classes            : Classes names file
--no-save            : Don't save result image
```

## 🎯 Next Steps

1. **Test dengan berbagai gambar** - Coba foto dengan berbagai kondisi
2. **Adjust confidence thresholds** - Fine-tune untuk use case Anda
3. **Collect failed cases** - Simpan gambar yang gagal untuk improvement
4. **Deploy to Raspberry Pi** - Follow PARKING_SYSTEM_README.md
5. **Setup server** - Deploy recognition API

## 📚 More Info

- Full documentation: [PARKING_SYSTEM_README.md](PARKING_SYSTEM_README.md)
- Deployment guide: [QUICKSTART.md](QUICKSTART.md)
- Edge device: [edge_device/README.md](edge_device/README.md)

---

**Happy Testing! 🚀**
