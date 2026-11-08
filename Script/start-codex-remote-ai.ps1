
# ============================================
# Launch Codex using Mac Studio Ollama API
# Preload model with permanent keep_alive
# ============================================

$ErrorActionPreference = "Stop"

# Mac Studio Ollama API
# $OLLAMA_HOST = "http://100.67.114.30:11434"
$OLLAMA_HOST = "http://192.168.1.28:11434"

# Model
$MODEL = "qwen3-coder-next:q4_K_M"

# Project directory
$PROJECT_PATH = "C:\DevEnv\Script"

# Keep Alive -1 = keep alive
$KEEP_ALIVE = -1

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  Codex - Mac Studio AI" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 1. Check Ollama API
# ============================================

Write-Host "Checking Mac Studio Ollama API..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod `
        -Uri "$OLLAMA_HOST/api/tags" `
        -TimeoutSec 5

    Write-Host "Ollama API Connected!" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Cannot connect to Mac Studio Ollama!" -ForegroundColor Red
    Write-Host "API: $OLLAMA_HOST"
    Read-Host "Press Enter to exit"
    exit 1
}

# ============================================
# 2. Preload Model with Keep Alive Forever
# ============================================

Write-Host ""
Write-Host "Preloading model..." -ForegroundColor Yellow
Write-Host "Model: $MODEL"

$BODY = @{
    model      = $MODEL
    prompt     = ""
    keep_alive = $KEEP_ALIVE
    stream     = $false
} | ConvertTo-Json -Compress

try {
    $loadResponse = Invoke-RestMethod `
        -Uri "$OLLAMA_HOST/api/generate" `
        -Method Post `
        -ContentType "application/json" `
        -Body $BODY `
        -TimeoutSec 180

    Write-Host "Model loaded and Keep Alive set to Forever!" `
        -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to preload model!" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Read-Host "Press Enter to exit"
    exit 1
}

# ============================================
# 3. Set Codex Environment
# ============================================

$env:CODEX_OSS_BASE_URL = "$OLLAMA_HOST/v1"
$env:OPENAI_API_KEY = "ollama"

# ============================================
# 4. Enter Project Directory
# ============================================

Set-Location $PROJECT_PATH

# ============================================
# 5. Launch Codex
# ============================================

Write-Host ""
Write-Host "Launching Codex..." -ForegroundColor Green
Write-Host "Model: $MODEL"
Write-Host ""

codex --oss -m $MODEL --yolo
