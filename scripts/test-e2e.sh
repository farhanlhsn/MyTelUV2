#!/bin/bash
# ==============================================================================
# End-to-End Testing Orchestrator (Bash/Linux/macOS/CI)
# ==============================================================================
# Menjalankan seluruh pipeline E2E testing:
# 1. Start PostgreSQL test container
# 2. Migrasi schema & seed test data
# 3. Start Python AI services dalam TEST_MODE
# 4. Start Node.js backend dalam test mode
# 5. Jalankan AI contract tests (Python unittest)
# 6. Jalankan backend E2E tests (Jest)
# 7. Cleanup semua proses dan container
# ==============================================================================

set -e

echo "🚀 Starting E2E Testing Orchestrator..."

# --- Prerequisite Checks ---
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "❌ '$1' tidak ditemukan. Pastikan sudah terinstall."
    exit 1
  fi
}

check_command docker
check_command node
check_command python3

# --- Helper: wait for HTTP service ---
wait_for_service() {
  local name="$1"
  local url="$2"
  local max_retries=30
  local retry=0

  echo "⏳ Menunggu $name siap di $url..."
  until curl -sf "$url" > /dev/null 2>&1; do
    retry=$((retry + 1))
    if [ $retry -ge $max_retries ]; then
      echo "❌ $name tidak merespons setelah $max_retries percobaan. Abort."
      exit 1
    fi
    sleep 1
  done
  echo "✅ $name siap!"
}

# --- 1. Start Docker Test Database ---
echo "🐳 Starting PostgreSQL Test Container..."
docker compose -f docker-compose.test.yml up -d db-test

echo "⏳ Menunggu PostgreSQL siap..."
until docker exec myteluv2-postgres-test pg_isready -U test_user -d myteluv2_test 2>/dev/null; do
  sleep 1
done
echo "✅ PostgreSQL siap!"

# --- 2. Database Migration & Seeding ---
echo "📦 Menjalankan Prisma Migrations..."
cd backend
npx dotenv -e ../.env.test -- prisma migrate deploy --schema prisma/schema.prisma

echo "📦 Generating Prisma Client..."
npx dotenv -e ../.env.test -- prisma generate --schema prisma/schema.prisma
cd ..

echo "🌱 Seeding test data..."
npx dotenv -e .env.test -- node backend/prisma/seed-test-data.js

# --- 3. Start Python AI Services dalam TEST_MODE ---
echo "🤖 Starting AI Microservices dalam TEST_MODE..."
export TEST_MODE=true
export NODEJS_BACKEND_URL=http://localhost:5050

PYTHON_BIN_FACE="backend/python-service/face_recognition/venv/bin/python3"
PYTHON_BIN_PLATE="backend/python-service/plate_recognition/venv/bin/python3"
PYTHON_BIN_ANOMALY="backend/python-service/anomaly_detection/venv/bin/python3"

# Fallback ke python3 system jika venv belum dibuat
[ -f "$PYTHON_BIN_FACE" ] || PYTHON_BIN_FACE="python3"
[ -f "$PYTHON_BIN_PLATE" ] || PYTHON_BIN_PLATE="python3"
[ -f "$PYTHON_BIN_ANOMALY" ] || PYTHON_BIN_ANOMALY="python3"

$PYTHON_BIN_FACE backend/python-service/face_recognition/app.py > /tmp/face_service.log 2>&1 &
FACE_PID=$!

$PYTHON_BIN_PLATE backend/python-service/plate_recognition/app.py > /tmp/plate_service.log 2>&1 &
PLATE_PID=$!

$PYTHON_BIN_ANOMALY backend/python-service/anomaly_detection/app.py > /tmp/anomaly_service.log 2>&1 &
ANOMALY_PID=$!

# Tunggu AI services siap (HTTP health check, bukan sleep)
wait_for_service "Face Recognition Service" "http://localhost:5051/health"
wait_for_service "Plate Recognition Service" "http://localhost:5001/health"
wait_for_service "Anomaly Detection Service" "http://localhost:5003/health"

# --- 4. Start Node.js Backend ---
echo "🌐 Starting Backend API Server..."
export NODE_ENV=test
export PORT=5050
export DATABASE_URL=$(grep DATABASE_URL .env.test | cut -d '"' -f2)
export JWT_SECRET=$(grep JWT_SECRET .env.test | head -1 | cut -d '"' -f2)
export JWT_REFRESH_SECRET=$(grep JWT_REFRESH_SECRET .env.test | cut -d '"' -f2)
export EDGE_DEVICE_SECRET=$(grep EDGE_DEVICE_SECRET .env.test | cut -d '"' -f2)
export FACE_API_URL=http://localhost:5051
export PLATE_API_URL=http://localhost:5001
export ANOMALY_SERVICE_URL=http://localhost:5003

node backend/server.js > /tmp/backend_server.log 2>&1 &
BACKEND_PID=$!

# Tunggu backend siap
wait_for_service "Node.js Backend" "http://localhost:5050/health"

# --- 5. Run AI Contract Tests ---
echo ""
echo "======================================"
echo "🧪 Menjalankan AI Contract Tests..."
echo "======================================"
python3 -m pytest backend/python-service/tests/test_ai_contract.py -v 2>/dev/null || \
python3 -m unittest backend/python-service/tests/test_ai_contract.py -v

# --- 6. Run Backend E2E Tests ---
echo ""
echo "======================================"
echo "🧪 Menjalankan Backend E2E Tests..."
echo "======================================"
cd backend
npx jest test-e2e/api_e2e.test.js --runInBand --detectOpenHandles --forceExit --verbose
TEST_EXIT_CODE=$?
cd ..

# --- Cleanup ---
cleanup() {
  echo ""
  echo "🧹 Membersihkan proses background..."
  kill $BACKEND_PID 2>/dev/null || true
  kill $FACE_PID 2>/dev/null || true
  kill $PLATE_PID 2>/dev/null || true
  kill $ANOMALY_PID 2>/dev/null || true

  echo "🐳 Menghentikan Docker Test Container..."
  docker compose -f docker-compose.test.yml down -v

  echo "🏁 E2E Testing Orchestrator selesai!"
}

trap cleanup EXIT

exit ${TEST_EXIT_CODE:-0}
