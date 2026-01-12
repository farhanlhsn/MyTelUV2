#!/bin/bash

# Deployment script for Raspberry Pi 2
# License Plate Detection Edge Device

set -e

echo "========================================="
echo "Raspberry Pi License Plate Detector Setup"
echo "========================================="

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install system dependencies
echo "Installing system dependencies..."
sudo apt-get install -y \
    python3-pip \
    python3-dev \
    libopencv-dev \
    python3-opencv \
    libatlas-base-dev \
    libjasper-dev \
    libqtgui4 \
    libqt4-test \
    libhdf5-dev \
    libhdf5-serial-dev \
    libharfbuzz0b \
    libwebp6 \
    libtiff5 \
    libjpeg-dev \
    libpng-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev

# Install Python packages
echo "Installing Python packages..."
pip3 install -r requirements.txt

# Create directories
echo "Creating directories..."
mkdir -p models
mkdir -p detections
mkdir -p logs

# Copy model files
echo ""
echo "========================================="
echo "Manual Steps Required:"
echo "========================================="
echo "1. Copy detection model to: models/license_plate_detection.onnx"
echo "   From your training machine:"
echo "   scp models/detection/license_plate_detection.onnx pi@raspberrypi:~/edge_device/models/"
echo ""
echo "2. Update server URL in config.yaml"
echo "   Edit config.yaml and set server.url to your server address"
echo ""
echo "3. Test the detector:"
echo "   python3 plate_detector.py --test-image test.jpg"
echo ""
echo "4. Run live detection:"
echo "   python3 plate_detector.py"
echo ""
echo "5. (Optional) Setup as systemd service for auto-start:"
echo "   sudo cp plate-detector.service /etc/systemd/system/"
echo "   sudo systemctl enable plate-detector"
echo "   sudo systemctl start plate-detector"
echo "========================================="

# Test camera
echo "Testing camera..."
python3 -c "import cv2; cap = cv2.VideoCapture(0); print('Camera OK' if cap.isOpened() else 'Camera FAILED'); cap.release()"

echo "Setup complete!"
