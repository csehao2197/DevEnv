# ============================================
# Script: create-docker-ubuntu.ps1
# Description: Use free Codex OSS or Codex Remote AI (Mac Studio) depending on the environment variables.
# ============================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

# ============================================
# 1. Variables
# ============================================

$CodebasePath = "C:\Code"
$UbuntuWorkspace = "workspace"
$Image = "ubuntu:24.04"

$MacOllamaUrl = "http://192.168.1.28:11434"
$CodexOssBaseUrl = "$MacOllamaUrl/v1"

$CodexCommand = "codex --oss -m qwen3-coder-next:q4_K_M"

# ============================================
# 2. Validate Project Path
# ============================================

$ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
$CodebasePath = [System.IO.Path]::GetFullPath($CodebasePath)

if (-not $ProjectPath.StartsWith(
    $CodebasePath.TrimEnd('\') + '\',
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "ProjectPath must be inside $CodebasePath"
}

if (-not (Test-Path $ProjectPath -PathType Container)) {
    throw "Project directory does not exist: $ProjectPath"
}

$ProjectRelativePath = $ProjectPath.Substring($CodebasePath.Length)
$LinuxRelativePath = $ProjectRelativePath.TrimStart('\').Replace('\', '/')
$LinuxProjectPath = "/${UbuntuWorkspace}/${LinuxRelativePath}"

# ============================================
# 3. Display Configuration
# ============================================

Write-Host "`n============================================"
Write-Host "Container Name : $ContainerName"
Write-Host "Project Path   : $ProjectPath"
Write-Host "Linux Path     : $LinuxProjectPath"
Write-Host "Mac Ollama URL : $MacOllamaUrl"
Write-Host "Codex API URL  : $CodexOssBaseUrl"
Write-Host "============================================"

# ============================================
# 4. Check Existing Container
# ============================================

Write-Host "`nChecking existing container..."

$ExistingContainer = docker ps -aq -f "name=^${ContainerName}$"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to check existing containers."
}

if ($ExistingContainer) {
    Write-Host ""
    Write-Host "ERROR: Container '$ContainerName' already exists!" -ForegroundColor Red
    Write-Host "Please use another container name or remove the existing container manually."
    exit 1
}

# ============================================
# 5. Create Docker Container
# ============================================

Write-Host "`nCreating Docker Container..."

docker run -d `
    --name $ContainerName `
    -e "OLLAMA_HOST=$MacOllamaUrl" `
    -e "CODEX_OSS_BASE_URL=$CodexOssBaseUrl" `
    -v "${CodebasePath}:/${UbuntuWorkspace}" `
    $Image `
    sleep infinity

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create Docker Container."
}

# ============================================
# 6. Verify Docker Environment Variables
# ============================================

Write-Host "`nChecking Docker environment variables..."

$ContainerEnv = docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' $ContainerName

if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect Docker environment."
}

if ($ContainerEnv -notmatch [regex]::Escape("OLLAMA_HOST=$MacOllamaUrl")) {
    throw "OLLAMA_HOST missing from Docker configuration."
}

if ($ContainerEnv -notmatch [regex]::Escape("CODEX_OSS_BASE_URL=$CodexOssBaseUrl")) {
    throw "CODEX_OSS_BASE_URL missing from Docker configuration."
}

Write-Host "Docker environment variables verified."

# ============================================
# 7. Install Dependencies
# ============================================

Write-Host "`nInstalling dependencies..."

docker exec $ContainerName bash -c `
    "apt update && apt install -y curl git ca-certificates"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to install dependencies."
}

# ============================================
# 8. Test Remote Ollama API
# ============================================

Write-Host "`nTesting Mac Studio Ollama API..."

docker exec $ContainerName bash -c `
    "curl -fsS '$MacOllamaUrl/api/tags'"

if ($LASTEXITCODE -ne 0) {
    throw "Cannot connect to Mac Studio Ollama API."
}

Write-Host "`nRemote Ollama API connection successful!"

# ============================================
# 9. Install Codex
# ============================================

Write-Host "`nInstalling Codex..."

docker exec $ContainerName bash -c `
    "curl -fsSL https://chatgpt.com/codex/install.sh | sh"

if ($LASTEXITCODE -ne 0) {
    throw "Codex installation failed."
}

# ============================================
# 10. Create /root/.bashrc
# ============================================

Write-Host "`nCreating /root/.bashrc..."

$BashrcConfig = @"
export PATH="/root/.local/bin:`$PATH"
export OLLAMA_HOST="$MacOllamaUrl"
export CODEX_OSS_BASE_URL="$CodexOssBaseUrl"

export HISTFILE=/root/.bash_history
export HISTSIZE=10000
export HISTFILESIZE=20000
shopt -s histappend

cd "$LinuxProjectPath" || exit 1
"@

$BashrcConfig | docker exec -i $ContainerName bash -c "cat > /root/.bashrc"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create /root/.bashrc"
}

# ============================================
# 11. Create /root/launch.sh
# ============================================

Write-Host "`nCreating /root/launch.sh..."

$LaunchScript = @"
#!/bin/bash
export PATH="/root/.local/bin:`$PATH"
export OLLAMA_HOST="$MacOllamaUrl"
export CODEX_OSS_BASE_URL="$CodexOssBaseUrl"

cd "$LinuxProjectPath" || exit 1

codex --oss -m qwen3-coder-next:q4_K_M
"@

$LaunchScript | docker exec -i $ContainerName bash -c "cat > /root/launch.sh"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create /root/launch.sh"
}

docker exec $ContainerName chmod +x /root/launch.sh

if ($LASTEXITCODE -ne 0) {
    throw "Failed to chmod launch.sh"
}

# ============================================
# 12. Configure Bash History
# ============================================

Write-Host "`nConfiguring Bash history..."

docker exec $ContainerName bash -c `
    "touch /root/.bash_history && printf '%s\n' '$CodexCommand' >> /root/.bash_history"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to configure Bash history."
}

# ============================================
# 13. Verify Configuration Files
# ============================================

Write-Host "`nVerifying configuration files..."

docker exec $ContainerName bash -c `
    "ls -la /root && echo '===== .bashrc =====' && cat /root/.bashrc && echo '===== launch.sh =====' && cat /root/launch.sh && echo '===== bash_history =====' && cat /root/.bash_history"

if ($LASTEXITCODE -ne 0) {
    throw "Configuration file verification failed."
}

# ============================================
# 14. Verify Environment Variables
# ============================================

Write-Host "`nTesting environment variables..."

docker exec $ContainerName bash -c `
    "source /root/.bashrc && printf 'OLLAMA_HOST=%s\nCODEX_OSS_BASE_URL=%s\n' `"`$OLLAMA_HOST`" `"`$CODEX_OSS_BASE_URL`""

if ($LASTEXITCODE -ne 0) {
    throw "Environment variable verification failed."
}

# ============================================
# 15. Enter Container
# ============================================

Write-Host "`n============================================"
Write-Host "Container setup completed!"
Write-Host "Remote Ollama configured!"
Write-Host "launch.sh created!"
Write-Host "Entering Container..."
Write-Host "============================================"

docker exec -it $ContainerName bash -i
