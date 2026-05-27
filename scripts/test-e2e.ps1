# ==============================================================================
# End-to-End Testing Orchestrator (PowerShell/Windows Local)
# ==============================================================================
# Spins up PostgreSQL test container, runs database migration/seeding,
# starts Python AI services and Node.js backend in TEST_MODE, executes contract
# and E2E API tests, and cleans up everything on exit.

$ErrorActionPreference = "Stop"

Write-Host "[START] Starting End-to-End Testing Orchestrator for Windows..." -ForegroundColor Green

# 1. Start Docker Container for Test Database
Write-Host "[DOCKER] Starting PostgreSQL Test Container..." -ForegroundColor Cyan
docker compose -f docker-compose.test.yml up -d db-test

# Wait for DB to be healthy
Write-Host "[WAIT] Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
while ($true) {
    $dbReady = docker exec myteluv2-postgres-test pg_isready -U test_user -d myteluv2_test 2>$null
    if ($LASTEXITCODE -eq 0) {
        break
    }
    Start-Sleep -Seconds 1
}
Write-Host "[SUCCESS] PostgreSQL is ready!" -ForegroundColor Green

# 2. Database Migration & Seeding
Write-Host "[PRISMA] Running Prisma Migrations on Test Database..." -ForegroundColor Cyan
$env:DATABASE_URL="postgresql://test_user:test_password@localhost:5433/myteluv2_test?schema=public"
$originalDir = Get-Location
Set-Location backend
npx prisma migrate deploy --schema prisma/schema.prisma

Write-Host "[PRISMA] Generating Prisma Client..." -ForegroundColor Cyan
npx prisma generate --schema prisma/schema.prisma
Set-Location $originalDir

Write-Host "[SEED] Seeding deterministic E2E test data..." -ForegroundColor Cyan
node backend/prisma/seed-test-data.js

# 3. Start Python AI services in TEST_MODE
Write-Host "[AI] Starting AI Microservices in TEST_MODE..." -ForegroundColor Cyan
$env:TEST_MODE="true"
$env:NODEJS_BACKEND_URL="http://localhost:5050"

$faceJob = Start-Process "backend/python-service/face_recognition/venv/Scripts/python.exe" -ArgumentList "backend/python-service/face_recognition/app.py" -PassThru -NoNewWindow
$plateJob = Start-Process "backend/python-service/plate_recognition/venv/Scripts/python.exe" -ArgumentList "backend/python-service/plate_recognition/app.py" -PassThru -NoNewWindow
$anomalyJob = Start-Process "backend/python-service/anomaly_detection/venv/Scripts/python.exe" -ArgumentList "backend/python-service/anomaly_detection/app.py" -PassThru -NoNewWindow

Start-Sleep -Seconds 4

# 4. Start Node.js Backend Server
Write-Host "[BACKEND] Starting Backend API Server in Test Mode..." -ForegroundColor Cyan
$env:NODE_ENV="test"
$env:PORT="5050"
$backendJob = Start-Process node -ArgumentList "backend/server.js" -PassThru -NoNewWindow

Start-Sleep -Seconds 4

# 5. Run AI Service Contract Tests
Write-Host "[TEST] Running AI Service Contract Tests..." -ForegroundColor Cyan
python -m unittest backend/python-service/tests/test_ai_contract.py

# 6. Run Backend E2E API Tests (Jest)
Write-Host "[TEST] Running Backend E2E API Tests (Jest)..." -ForegroundColor Cyan
$originalDir = Get-Location
Set-Location backend
npx jest test-e2e/api_e2e.test.js --runInBand --detectOpenHandles --forceExit
Set-Location $originalDir

# 7. Cleanup background services and containers
Write-Host "[CLEANUP] Cleaning up background processes..." -ForegroundColor Cyan
try {
    Stop-Process -Id $backendJob.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $faceJob.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $plateJob.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $anomalyJob.Id -Force -ErrorAction SilentlyContinue
} catch {}

Write-Host "[CLEANUP] Stopping Docker Test Container..." -ForegroundColor Cyan
docker compose -f docker-compose.test.yml down -v

Write-Host "[FINISH] E2E Testing Orchestrator finished successfully!" -ForegroundColor Green
