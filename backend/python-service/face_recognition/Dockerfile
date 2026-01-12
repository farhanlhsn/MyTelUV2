# Face Recognition Service Dockerfile
# Uses InsightFace for face detection and embedding

FROM python:3.11-slim

WORKDIR /app

# Install system dependencies required for OpenCV and InsightFace compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools for compiling InsightFace
    build-essential \
    g++ \
    gcc \
    # OpenCV dependencies
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    # Utilities
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY *.py ./

# Create models directory (InsightFace will download models here on first run)
RUN mkdir -p /root/.insightface

# Expose port
EXPOSE 5051

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5051/health || exit 1

# Start the application
CMD ["python", "app.py"]
