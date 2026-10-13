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

## Server Response Contract

The detector posts the plate (and face) image to `POST /api/v1/parkir/edge-entry`
with the `X-Edge-Secret` header. The backend answers **every** outcome (open or
deny) in the standard envelope, with the gate decision nested under `data`:

```json
{
  "status": "success",
  "message": "Selamat datang Budi! Kendaraan B1234XYZ masuk.",
  "data": {
    "gate_action": "OPEN",
    "plate_text": "B1234XYZ",
    "owner": "Budi",
    "parkiran": "Parkiran Utama",
    "slot_tersisa": 12,
    "ocr_confidence": 0.93
  }
}
```

A rejection looks like `{"status": "error", "message": "...", "data": {"gate_action": "DENY"}}`
(HTTP 400, 401, 403 or 404). `owner`, `parkiran` and `slot_tersisa` are only present
on `OPEN`; `slot_tersisa` is only sent for `MASUK`.

`server_result.parse_server_result()` turns the raw body into
`{gate_action, message, plate_text, ocr_confidence, success}`. It reads `data` first and
falls back to the top level of the body (legacy flat shape).

**The gate fails closed.** It opens only when `gate_action` is exactly `OPEN`. A `DENY`,
a missing or unknown value, a body that is not a JSON object, a network error, a timeout
or an invalid JSON response (the client then uses `{"gate_action": "DENY", "error": "..."}`)
all leave the gate closed. A body whose `status` is present but not `success` is treated
as `DENY` even if it claims `OPEN`.

A repeat detection of the same plate position (bbox IoU > 0.5) is not sent to the server
again for 5 seconds after an `OPEN` and for 10 seconds after a `DENY`
(`OPEN_COOLDOWN_SECONDS` / `DENY_COOLDOWN_SECONDS` in `plate_detector.py`).

If the camera cannot be read, the detector waits 0.5s between attempts and re-opens the
capture device after 20 consecutive failures.

### Tests

The parser has no third-party dependencies, so its tests run without OpenCV or a camera:

```bash
python -m unittest edge_device/test_parse_server_result.py   # from the repository root
python -m unittest test_parse_server_result                  # from inside edge_device/
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
- `server_result.py` - Parses the backend response into a gate decision (pure, no dependencies)
- `test_parse_server_result.py` - Unit tests for `server_result.py`
- `config.yaml` - Configuration
- `requirements.txt` - Python dependencies
- `deploy.sh` - Deployment script
- `models/` - Model files (copy here after training)
