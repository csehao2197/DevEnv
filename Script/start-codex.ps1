#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$Proxy = "http://127.0.0.1:10808"

Write-Host ""
Write-Host "=============================" -ForegroundColor Cyan
Write-Host " Codex Proxy Launcher" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

#
# 1. Verify local proxy port
#
Write-Host "[1/3] Checking local proxy..." -ForegroundColor Yellow

$listener = Get-NetTCPConnection `
    -LocalAddress 127.0.0.1 `
    -LocalPort 10808 `
    -State Listen `
    -ErrorAction SilentlyContinue

if (-not $listener) {
    Write-Host ""
    Write-Host "ERROR: Nothing is listening on 127.0.0.1:10808" -ForegroundColor Red
    Write-Host "Please start V2RayN first." -ForegroundColor Red
    exit 1
}

Write-Host "OK: Proxy port detected." -ForegroundColor Green

#
# 2. Configure environment
#
Write-Host ""
Write-Host "[2/3] Setting proxy environment..." -ForegroundColor Yellow

$env:HTTP_PROXY  = $Proxy
$env:HTTPS_PROXY = $Proxy
$env:NO_PROXY    = "localhost,127.0.0.1,::1"

Write-Host "HTTP_PROXY  = $env:HTTP_PROXY"
Write-Host "HTTPS_PROXY = $env:HTTPS_PROXY"

#
# 3. Verify external connectivity through proxy
#
Write-Host ""
Write-Host "[3/3] Testing outbound IP through proxy..." -ForegroundColor Yellow

$ip = curl.exe `
    --silent `
    --show-error `
    --fail `
    --proxy $Proxy `
    --noproxy "" `
    -4 `
    --connect-timeout 10 `
    --max-time 20 `
    https://api.ipify.org

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Proxy connectivity test failed." -ForegroundColor Red
    exit 1
}

$ip = $ip.Trim()

if ($ip -notmatch '^(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})){3}$') {
    Write-Host ""
    Write-Host "ERROR: Invalid IP returned." -ForegroundColor Red
    Write-Host "Received: $ip" -ForegroundColor Red
    exit 1
}

if ($ip -eq "127.0.0.1") {
    Write-Host ""
    Write-Host "ERROR: Proxy returned localhost." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host "Proxy Exit IP: $ip" -ForegroundColor Green

Start-Sleep -Seconds 5

#
# Launch Codex
#
Write-Host ""
Write-Host "Starting Codex..." -ForegroundColor Green
Write-Host ""

codex

$ExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "Codex exited with code: $ExitCode"
exit $ExitCode