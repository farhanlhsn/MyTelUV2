#!/bin/bash

echo "🚀 Setting up Python Face Recognition Service..."
echo ""

# Check if python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8 or higher."
    exit 1
fi

echo "✅ Python 3 found: $(python3 --version)"
echo ""

# Create virtual environment
echo "📦 Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📥 Installing dependencies (this may take a few minutes)..."
echo "⚠️  First time setup will download InsightFace models (~300MB)"
pip install -r requirements.txt

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start the service:"
echo "  1. cd backend/python-service"
echo "  2. source venv/bin/activate"
echo "  3. python app.py"
echo ""
echo "Service will run on http://localhost:5051"
