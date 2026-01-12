#!/bin/bash

# Run Both Services Script
# =========================
# Runs both Face Recognition and Plate Recognition services

echo "🚀 Starting Python Services..."
echo ""

# Function to run service in background
run_service() {
    local service_name=$1
    local service_dir=$2
    local port=$3
    
    echo "Starting ${service_name} on port ${port}..."
    
    cd "${service_dir}" || exit
    source venv/bin/activate
    python app.py &
    SERVICE_PID=$!
    cd ..
    
    echo "${service_name} PID: ${SERVICE_PID}"
}

# Run Face Recognition Service (Port 5051)
run_service "Face Recognition" "face_recognition" "5051"

# Run Plate Recognition Service (Port 5001)
run_service "Plate Recognition" "plate_recognition" "5001"

echo ""
echo "✨ Both services are running!"
echo ""
echo "Face Recognition API: http://localhost:5051"
echo "Plate Recognition API: http://localhost:5001"
echo ""
echo "Press Ctrl+C to stop all services"
echo ""

# Wait for all background processes
wait
