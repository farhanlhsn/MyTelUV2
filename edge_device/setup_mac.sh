#!/bin/bash

# Setup Edge Device for Mac (with venv)
# Run: ./setup_mac.sh

echo "========================================="
echo "🍎 Edge Device Setup for Mac"
echo "========================================="

# Check if in edge_device directory
if [ ! -f "plate_detector.py" ]; then
    echo "❌ Error: Run this script from edge_device directory"
    exit 1
fi

# Create virtual environment
echo ""
echo "📦 Creating virtual environment..."
python3 -m venv venv

# Activate venv
echo "✓ Activating venv..."
source venv/bin/activate

# Upgrade pip
echo ""
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo ""
echo "📚 Installing dependencies..."
echo "This may take a few minutes..."
pip install opencv-python numpy pyyaml requests pillow

# Copy models
echo ""
echo "📁 Copying models..."
if [ -f "../models/detection/license_plate_detection.pt" ]; then
    cp ../models/detection/license_plate_detection.pt models/
    echo "✓ Copied detection.pt"
else
    echo "⚠️  Warning: detection.pt not found"
fi

if [ -f "../models/detection/license_plate_detection.onnx" ]; then
    cp ../models/detection/license_plate_detection.onnx models/
    echo "✓ Copied detection.onnx"
else
    echo "⚠️  Warning: detection.onnx not found"
fi

# Verify
echo ""
echo "✅ Setup Complete!"
echo ""
echo "Models in edge_device/models/:"
ls -lh models/

echo ""
echo "========================================="
echo "Next steps:"
echo "========================================="
echo "1. Make sure venv is activated:"
echo "   source venv/bin/activate"
echo ""
echo "2. Test with image:"
echo "   python plate_detector.py --test-image ../archive/Indonesian\\ License\\ Plate\\ Dataset/images/test/test001.jpg"
echo ""
echo "3. Update config.yaml with server URL"
echo ""
echo "4. Run with camera:"
echo "   python plate_detector.py"
echo "========================================="
