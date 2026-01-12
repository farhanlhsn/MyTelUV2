# Edge Device - License Plate Detector

Raspberry Pi 2 license plate detection system.

## Quick Setup

```bash
# 1. Run deployment script
chmod +x deploy.sh
./deploy.sh

# 2. Copy detection model
# From your training machine:
# scp models/detection/license_plate_detection.onnx pi@raspberrypi:~/edge_device/models/

# 3. Update server URL
nano config.yaml
# Set server.url to your server IP

# 4. Test
python3 plate_detector.py --test-image test.jpg

# 5. Run live
python3 plate_detector.py
```

## Configuration

Edit `config.yaml` to customize:
- Model path and confidence threshold
- Server URL and timeout
- Camera settings (resolution, FPS)
- Processing frequency

## Usage

### Test Mode
```bash
python3 plate_detector.py --test-image /path/to/image.jpg
```

### Live Camera Mode
```bash
python3 plate_detector.py
```

### With Custom Config
```bash
python3 plate_detector.py --config my_config.yaml
```

## Performance Tips

For better performance on Raspberry Pi 2:

1. **Lower resolution**: Set camera width/height to 320x240
2. **Process fewer frames**: Increase `process_every_n_frames` to 10-15
3. **Disable preview**: Set `show_preview: false`
4. **Use ONNX model**: Faster than PyTorch
5. **Increase swap**: Add 2GB swap space

## Troubleshooting

See [../PARKING_SYSTEM_README.md](../PARKING_SYSTEM_README.md#troubleshooting) for detailed troubleshooting guide.

## Files

- `plate_detector.py` - Main detection script
- `config.yaml` - Configuration
- `requirements.txt` - Python dependencies
- `deploy.sh` - Deployment script
- `models/` - Model files (copy here after training)
