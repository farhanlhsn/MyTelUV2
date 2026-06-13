# ==============================================================================
# End-to-End Testing Orchestrator (PowerShell/Windows)
# ==============================================================================
# Menjalankan seluruh pipeline E2E testing di Windows.
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host "[START] Memulai E2E Testing Orchestrator untuk Windows..." -ForegroundColor Green

# --- Helper: tunggu HTTP service siap ---
function Wait-ForService {
    param(
        [string]$Name,
        [string]$Url,
        [int]$MaxRetries = 30
    )
    Write-Host "[WAIT] Menunggu $Name siap di $Url..." -ForegroundColor Yellow
    $retry = 0
    while ($retry -lt $MaxRetries) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -lt 500) {
                Write-Host "[OK] $Name siap!" -ForegroundColor Green
                return
            }
        } catch {}
        $retry++
        Start-Sleep -Seconds 1
    }
    throw "ERROR: $Name tidak merespons setelah $MaxRetries percobaan. Periksa log."
}

# --- 1. Start Docker Test Database ---
Write-Host "[DOCKER] Starting PostgreSQL Test Container..." -ForegroundColor Cyan
docker compose -f docker-compose.test.yml up -d db-test

Write-Host "[WAIT] Menunggu PostgreSQL siap..." -ForegroundColor Yellow
$dbReady = $false
for ($i = 0; $i -lt 30; $i++) {
    $result = docker exec myteluv2-postgres-test pg_isready -U test_user -d myteluv2_test 2>$null
    if ($LASTEXITCODE -eq 0) { $dbReady = $true; break }
    Start-Sleep -Seconds 1
}
if (-not $dbReady) { throw "PostgreSQL tidak siap setelah 30 detik!" }
Write-Host "[OK] PostgreSQL siap!" -ForegroundColor Green

# --- 2. Database Migration & Seeding ---
Write-Host "[PRISMA] Menjalankan Prisma Migrations..." -ForegroundColor Cyan
$env:DATABASE_URL = "postgresql://test_user:test_password@127.0.0.1:5433/myteluv2_test?schema=public"
$env:JWT_SECRET = "e2e-testing-super-secret-key-minimum-32-chars"
$env:JWT_REFRESH_SECRET = "e2e-testing-refresh-secret-key-minimum-32-chars"
$env:EDGE_DEVICE_SECRET = "e2e-testing-edge-device-secret-32-chars"

$originalDir = Get-Location
Set-Location backend
npx prisma db push --schema prisma/schema.prisma --accept-data-loss
npx prisma generate --schema prisma/schema.prisma
Set-Location $originalDir

Write-Host "[SEED] Seeding test data..." -ForegroundColor Cyan
node backend/prisma/seed-test-data.js

# --- 3. Start Python AI Services dalam TEST_MODE ---
Write-Host "[AI] Starting AI Microservices dalam TEST_MODE..." -ForegroundColor Cyan
$env:TEST_MODE = "true"
$env:NODEJS_BACKEND_URL = "http://127.0.0.1:5050"
$env:FACE_API_URL = "http://127.0.0.1:5051"
$env:PLATE_API_URL = "http://127.0.0.1:5001"
$env:ANOMALY_SERVICE_URL = "http://127.0.0.1:5003"
$env:NODE_ENV = "test"

# Clear PORT variable if set to prevent Python services from binding to wrong port
if (Test-Path Env:\PORT) { Remove-Item Env:\PORT }

# Tentukan Python binary (gunakan venv jika ada, fallback ke system)
$PythonFace = "backend/python-service/face_recognition/venv/Scripts/python.exe"
$PythonPlate = "backend/python-service/plate_recognition/venv/Scripts/python.exe"
$PythonAnomaly = "backend/python-service/anomaly_detection/venv/Scripts/python.exe"

if (-not (Test-Path $PythonFace)) { $PythonFace = "python" }
if (-not (Test-Path $PythonPlate)) { $PythonPlate = "python" }
if (-not (Test-Path $PythonAnomaly)) { $PythonAnomaly = "python" }

$faceJob = Start-Process $PythonFace -ArgumentList "backend/python-service/face_recognition/app.py" -PassThru -NoNewWindow -RedirectStandardOutput "face_service.log" -RedirectStandardError "face_service_err.log"
$plateJob = Start-Process $PythonPlate -ArgumentList "backend/python-service/plate_recognition/app.py" -PassThru -NoNewWindow -RedirectStandardOutput "plate_service.log" -RedirectStandardError "plate_service_err.log"
$anomalyJob = Start-Process $PythonAnomaly -ArgumentList "backend/python-service/anomaly_detection/app.py" -PassThru -NoNewWindow -RedirectStandardOutput "anomaly_service.log" -RedirectStandardError "anomaly_service_err.log"

# Tunggu AI services siap dengan HTTP health check
Wait-ForService -Name "Face Recognition" -Url "http://127.0.0.1:5051/health"
Wait-ForService -Name "Plate Recognition" -Url "http://127.0.0.1:5001/health"
Wait-ForService -Name "Anomaly Detection" -Url "http://127.0.0.1:5003/health"

# --- 4. Start Node.js Backend ---
Write-Host "[BACKEND] Starting Backend API Server..." -ForegroundColor Cyan
$env:PORT = "5050"
$backendJob = Start-Process node -ArgumentList "backend/server.js" -PassThru -NoNewWindow -RedirectStandardOutput "backend_server.log" -RedirectStandardError "backend_server_err.log"

Wait-ForService -Name "Node.js Backend" -Url "http://127.0.0.1:5050/health"

# --- 5. Run AI Contract Tests ---
Write-Host ""
Write-Host "======================================" -ForegroundColor White
Write-Host "[TEST] Menjalankan AI Contract Tests..." -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor White

# Coba pytest dulu, fallback ke unittest
$pytestCommand = Get-Command pytest -ErrorAction SilentlyContinue
$pytestPath = $null
if ($pytestCommand) {
    $pytestPath = $pytestCommand.Path
}
if ($pytestPath) {
    python -m pytest backend/python-service/tests/test_ai_contract.py -v
} else {
    python -m unittest backend/python-service/tests/test_ai_contract.py -v
}

# --- 6. Run Backend E2E Tests ---
Write-Host ""
Write-Host "======================================" -ForegroundColor White
Write-Host "[TEST] Menjalankan Backend E2E Tests..." -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor White

Set-Location backend
$testResult = 0
try {
    npx jest test-e2e/api_e2e.test.js --runInBand --detectOpenHandles --forceExit --verbose
} catch {
    $testResult = 1
}
Set-Location $originalDir

# --- 7. Cleanup ---
Write-Host "[CLEANUP] Membersihkan proses background..." -ForegroundColor Cyan
try {
    Stop-Process -Id $backendJob.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $faceJob.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $plateJob.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $anomalyJob.Id -Force -ErrorAction SilentlyContinue
} catch {}

# Hapus log temporer
# Remove-Item -Path "face_service*.log", "plate_service*.log", "anomaly_service*.log", "backend_server*.log" -Force -ErrorAction SilentlyContinue

Write-Host "[CLEANUP] Menghentikan Docker Test Container..." -ForegroundColor Cyan
docker compose -f docker-compose.test.yml down -v

if ($testResult -eq 0) {
    Write-Host "[FINISH] Semua E2E tests berhasil!" -ForegroundColor Green
} else {
    Write-Host "[FINISH] Ada E2E tests yang gagal. Periksa output di atas." -ForegroundColor Red
    exit 1
}
