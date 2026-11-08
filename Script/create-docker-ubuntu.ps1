# ============================================
# Script: create-docker-ubuntu.ps1
# Description: This script creates a Docker container with Ubuntu, installs Codex, and sets up the environment for development.
# Can use free Codex OSS or Codex Remote AI (Mac Studio) depending on the environment variables.
# ============================================
param(
    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$ProjectPath
)

# ============================================
# 1. Variables
# ============================================

$CodebasePath = "C:\Code"

$UbuntuWorkspace = "workspace"

$Image = "ubuntu:24.04"


# ============================================
# 2. Get ProjectRelativePath
# ============================================

$ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
$CodebasePath = [System.IO.Path]::GetFullPath($CodebasePath)

if (-not $ProjectPath.StartsWith(
    $CodebasePath.TrimEnd('\') + '\',
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    Write-Error "ProjectPath must be inside $CodebasePath"
    exit 1
}

$ProjectRelativePath = $ProjectPath.Substring($CodebasePath.Length)

$LinuxRelativePath = $ProjectRelativePath.TrimStart('\').Replace('\', '/')

$LinuxProjectPath = "/${UbuntuWorkspace}/${LinuxRelativePath}"


# ============================================
# 3. Display Configuration
# ============================================

Write-Host "============================================"
Write-Host "Container Name        : $ContainerName"
Write-Host "Project Path          : $ProjectPath"
Write-Host "Project Relative Path : $ProjectRelativePath"
Write-Host "Linux Project Path    : $LinuxProjectPath"
Write-Host "Docker Image          : $Image"
Write-Host "============================================"


# ============================================
# 4. Validate Project Directory
# ============================================

if (-not (Test-Path $ProjectPath -PathType Container)) {
    Write-Error "Project directory does not exist: $ProjectPath"
    exit 1
}


# ============================================
# 5. Create Docker Container
# ============================================

docker run -it -d `
    --name $ContainerName `
    -v "${CodebasePath}:/${UbuntuWorkspace}" `
    $Image

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create Docker Container."
    exit 1
}


# ============================================
# 6. Install Dependencies
# ============================================

Write-Host "`nInstalling curl and git..."

docker exec $ContainerName bash -c `
    "apt update && apt install -y curl git"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install dependencies."
    exit 1
}


# ============================================
# 7. Install Codex
# ============================================

Write-Host "`nInstalling Codex..."

docker exec $ContainerName bash -c `
    "curl -fsSL https://chatgpt.com/codex/install.sh | sh"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Codex installation failed."
    exit 1
}


# ============================================
# 8. Create Custom Bash RC File
# ============================================

Write-Host "`nCreating custom Bash RC file..."

$BashrcConfig = @"
source /root/.bashrc

export PATH="/root/.local/bin:`$PATH"

cd "$LinuxProjectPath" || exit 1
"@

# Remove Windows CRLF characters
$BashrcConfig = $BashrcConfig -replace "`r", ""

# Write custom Bash RC file into container
$BashrcConfig | docker exec -i $ContainerName bash -c `
    "cat > /root/.codex_bashrc"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create .codex_bashrc."
    exit 1
}

Write-Host "Custom Bash RC file created successfully."


# ============================================
# 9. Enter Container
# ============================================

Write-Host "`n============================================"
Write-Host "Container setup completed!"
Write-Host "Entering Container..."
Write-Host "============================================"

docker exec -it $ContainerName bash --rcfile /root/.codex_bashrc
