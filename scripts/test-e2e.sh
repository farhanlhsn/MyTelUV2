#!/bin/bash
# ==============================================================================
# End-to-End Testing Orchestrator (Bash/CI/CD)
# ==============================================================================
# Spins up PostgreSQL test container, runs database migration/seeding,
# starts Python AI services and Node.js backend in TEST_MODE, executes contract
# and E2E API tests, and cleans up everything on exit.

# Exit immediately if any command fails
set -e

echo "🚀 Starting End-to-End Testing Orchestrator..."

# 1. Start Docker Container for Test Database
echo "🐳 Starting PostgreSQL Test Container..."
docker compose -f docker-compose.test.yml up -d db-test

# Wait for DB to be healthy
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker exec myteluv2-postgres-test pg_isready -U test_user -d myteluv2_test; do
  sleep 1
done
echo "✅ PostgreSQL is ready!"

# 2. Database Migration & Seeding
echo "📦 Running Prisma Migrations on Test Database..."
cd backend
npx dotenv -e ../.env.test -- prisma migrate deploy --schema prisma/schema.prisma

echo "📦 Generating Prisma Client..."
npx dotenv -e ../.env.test -- prisma generate --schema prisma/schema.prisma
cd ..

echo "🌱 Seeding deterministic E2E test data..."
npx dotenv -e .env.test -- node backend/prisma/seed-test-data.js

# 3. Start Python AI services in TEST_MODE
echo "🤖 Starting AI Microservices in TEST_MODE..."
export TEST_MODE=true
export NODEJS_BACKEND_URL=http://localhost:5050

backend/python-service/face_recognition/venv/bin/python backend/python-service/face_recognition/app.py > face_service.log 2>&1 &
FACE_PID=$!

backend/python-service/plate_recognition/venv/bin/python backend/python-service/plate_recognition/app.py > plate_service.log 2>&1 &
PLATE_PID=$!

backend/python-service/anomaly_detection/venv/bin/python backend/python-service/anomaly_detection/app.py > anomaly_service.log 2>&1 &
ANOMALY_PID=$!

# Wait for AI services to boot
sleep 4

# 4. Start Node.js Backend Server
echo "🌐 Starting Backend API Server in Test Mode..."
export NODE_ENV=test
export PORT=5050
node backend/server.js > backend_server.log 2>&1 &
BACKEND_PID=$!

# Wait for Backend to boot
sleep 4

# 5. Run AI Service Contract Tests
echo "🧪 Running AI Service Contract Tests..."
python -m unittest backend/python-service/tests/test_ai_contract.py

# 6. Run Backend E2E API Tests (Jest)
echo "🧪 Running Backend E2E API Tests (Jest)..."
cd backend
npx jest test-e2e/api_e2e.test.js --runInBand --detectOpenHandles --forceExit
cd ..

# 7. Cleanup background services and containers
cleanup() {
  echo "🧹 Cleaning up background services..."
  kill $BACKEND_PID 2>/dev/null || true
  kill $FACE_PID 2>/dev/null || true
  kill $PLATE_PID 2>/dev/null || true
  kill $ANOMALY_PID 2>/dev/null || true
  
  echo "🐳 Stopping Docker Test Container..."
  docker compose -f docker-compose.test.yml down -v
  
  # Remove temporary logs
  rm -f face_service.log plate_service.log anomaly_service.log backend_server.log
  
  echo "🏁 E2E Testing Orchestrator finished!"
}

# Register cleanup on shell exit
trap cleanup EXIT
