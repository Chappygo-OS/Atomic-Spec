#!/usr/bin/env pwsh
# Initialize a new project with Custom Speckit (Atomic Traceability Model)
#
# Usage:
#   .\init-project.ps1 -TargetPath "D:\MyNewProject"
#   .\init-project.ps1 -TargetPath "D:\MyNewProject" -AIAgent "claude"

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet("claude", "gemini", "copilot", "cursor", "windsurf")]
    [string]$AIAgent = "claude"
)

$ErrorActionPreference = "Stop"
$SourcePath = $PSScriptRoot

Write-Host "🚀 Initializing Custom Speckit (Atomic Traceability Model)" -ForegroundColor Cyan
Write-Host "   Source: $SourcePath" -ForegroundColor Gray
Write-Host "   Target: $TargetPath" -ForegroundColor Gray
Write-Host ""

# Create target directory if it doesn't exist
if (-not (Test-Path $TargetPath)) {
    Write-Host "📁 Creating directory: $TargetPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
}

# Initialize git if not already a repo
$gitDir = Join-Path $TargetPath ".git"
if (-not (Test-Path $gitDir)) {
    Write-Host "📦 Initializing git repository..." -ForegroundColor Yellow
    Push-Location $TargetPath
    git init
    Pop-Location
}

# Copy framework directories
$directories = @(
    ".specify",
    "templates",
    "memory",
    "scripts"
)

foreach ($dir in $directories) {
    $sourceDirPath = Join-Path $SourcePath $dir
    $targetDirPath = Join-Path $TargetPath $dir

    if (Test-Path $sourceDirPath) {
        Write-Host "📋 Copying $dir..." -ForegroundColor Green
        if (Test-Path $targetDirPath) {
            Remove-Item $targetDirPath -Recurse -Force
        }
        Copy-Item $sourceDirPath -Destination $targetDirPath -Recurse
    }
}

# Copy agent-specific command files based on selected AI agent
$agentDirs = @{
    "claude" = ".claude"
    "gemini" = ".gemini"
    "copilot" = ".github"
    "cursor" = ".cursor"
    "windsurf" = ".windsurf"
}

$agentDir = $agentDirs[$AIAgent]
$sourceAgentPath = Join-Path $SourcePath $agentDir
$targetAgentPath = Join-Path $TargetPath $agentDir

if (Test-Path $sourceAgentPath) {
    Write-Host "🤖 Copying $AIAgent agent configuration..." -ForegroundColor Green
    if (Test-Path $targetAgentPath) {
        Remove-Item $targetAgentPath -Recurse -Force
    }
    Copy-Item $sourceAgentPath -Destination $targetAgentPath -Recurse
}

# Create specs directory
$specsDir = Join-Path $TargetPath "specs"
if (-not (Test-Path $specsDir)) {
    Write-Host "📁 Creating specs directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $specsDir | Out-Null
}

# Create a basic .gitignore if it doesn't exist
$gitignorePath = Join-Path $TargetPath ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    Write-Host "📝 Creating .gitignore..." -ForegroundColor Yellow
    @"
# Dependencies
node_modules/
vendor/
.venv/
venv/

# Build outputs
dist/
build/
*.egg-info/

# Environment
.env
.env.local
.env.*.local

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/
"@ | Set-Content $gitignorePath
}

Write-Host ""
Write-Host "✅ Custom Speckit initialized successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "   1. cd `"$TargetPath`"" -ForegroundColor White
Write-Host "   2. git checkout -b 001-your-feature-name" -ForegroundColor White
Write-Host "   3. Run: /speckit.specify `"Your feature description`"" -ForegroundColor White
Write-Host ""
Write-Host "📚 Available commands:" -ForegroundColor Cyan
Write-Host "   /speckit.specify  - Create feature specification" -ForegroundColor Gray
Write-Host "   /speckit.plan     - Create implementation plan" -ForegroundColor Gray
Write-Host "   /speckit.tasks    - Generate atomic task files" -ForegroundColor Gray
Write-Host "   /speckit.implement - Execute with Context Pinning" -ForegroundColor Gray
Write-Host ""
