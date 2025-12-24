#!/bin/bash

# Setup Script for Python Services (Enhanced)
# =================================
# Automated setup for Face Recognition and License Plate Recognition services
# with optional model pre-download

echo "🚀 Setting up Python Services for MyTelUV2..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check Python version
echo -e "${BLUE}Checking Python installation...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed. Please install Python 3.8 or higher.${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓ Found ${PYTHON_VERSION}${NC}"
echo ""

# Function to setup a service
setup_service() {
    local service_name=$1
    local service_dir=$2
    
    echo -e "${BLUE}Setting up ${service_name}...${NC}"
    
    # Navigate to service directory
    cd "${service_dir}" || exit
    
    # Create virtual environment
    echo "  Creating virtual environment..."
    python3 -m venv venv
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    echo "  Upgrading pip..."
    pip install --upgrade pip > /dev/null 2>&1
    
    # Install requirements
    echo "  Installing dependencies..."
    pip install -r requirements.txt
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${service_name} setup complete!${NC}"
    else
        echo -e "${YELLOW}⚠ Some dependencies failed to install for ${service_name}${NC}"
    fi
    
    # Deactivate virtual environment
    deactivate
    
    # Go back to parent directory
    cd ..
    echo ""
}

# Function to pre-download InsightFace models
predownload_face_models() {
    echo -e "${BLUE}Pre-downloading InsightFace models...${NC}"
    echo "  This will download ~300MB of model files to ~/.insightface/"
    
    cd face_recognition || exit
    source venv/bin/activate
    
    # Run a quick test to trigger model download
    python -c "
from insightface.app import FaceAnalysis
print('  Downloading buffalo_l model...')
app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
app.prepare(ctx_id=0, det_size=(640, 640))
print('  ✓ Models downloaded successfully!')
" 2>&1 | grep -E "(Downloading|✓|Applied)" || true
    
    deactivate
    cd ..
    echo -e "${GREEN}✓ Face recognition models ready!${NC}"
    echo ""
}

# Setup Face Recognition Service
setup_service "Face Recognition Service" "face_recognition"

# Setup Plate Recognition Service
setup_service "License Plate Recognition Service" "plate_recognition"

# Ask about pre-downloading face models
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Optional: Pre-download Face Models${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "InsightFace will auto-download models (~300MB) on first run."
echo "You can pre-download them now to save time later."
echo ""
read -p "Pre-download face recognition models now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    predownload_face_models
else
    echo -e "${BLUE}Skipped. Models will download automatically on first service start.${NC}"
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✨ Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "📝 Next Steps:"
echo ""
echo -e "${YELLOW}To run Face Recognition Service (Port 5051):${NC}"
echo "  cd face_recognition"
echo "  source venv/bin/activate"
echo "  python app.py"
echo ""
echo -e "${YELLOW}To run License Plate Recognition Service (Port 5001):${NC}"
echo "  cd plate_recognition"
echo "  source venv/bin/activate"
echo "  python app.py"
echo ""
echo "💡 Tip: Run each service in a separate terminal window"
echo ""
echo "📚 For more information, see README.md"
