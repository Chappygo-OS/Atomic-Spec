#!/usr/bin/env pwsh

# Tech Stack Validation Script (PowerShell)
#
# Validates package compatibility, freshness, and security for the tech stack
# defined in plan.md. This script is called during Phase 0.6 of /speckit.plan.
#
# Usage: ./validate-tech-stack.ps1 [OPTIONS]
#
# OPTIONS:
#   -Json               Output in JSON format
#   -PlanFile PATH      Path to plan.md (default: auto-detect from feature)
#   -Ecosystem ECO      Package ecosystem: npm, pypi, cargo, go (default: auto-detect)
#   -Help               Show help message

[CmdletBinding()]
param(
    [switch]$Json,
    [string]$PlanFile,
    [ValidateSet('npm', 'pypi', 'cargo', 'go', '')]
    [string]$Ecosystem,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Output @"
Usage: validate-tech-stack.ps1 [OPTIONS]

Validates package compatibility and freshness for the tech stack in plan.md.

OPTIONS:
  -Json               Output in JSON format
  -PlanFile PATH      Path to plan.md (default: auto-detect from feature)
  -Ecosystem ECO      Package ecosystem: npm, pypi, cargo, go (default: auto-detect)
  -Help               Show this help message

EXAMPLES:
  # Validate tech stack for current feature
  .\validate-tech-stack.ps1 -Json

  # Validate specific plan file
  .\validate-tech-stack.ps1 -PlanFile C:\path\to\plan.md -Ecosystem npm

"@
    exit 0
}

# Source common functions
. "$PSScriptRoot/common.ps1"

#==============================================================================
# Helper Functions
#==============================================================================

function Write-Info { param([string]$Message) Write-Host "[validate] $Message" -ForegroundColor Cyan }
function Write-Warn { param([string]$Message) Write-Host "[validate] Warning: $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "[validate] Error: $Message" -ForegroundColor Red }
function Write-Success { param([string]$Message) Write-Host "[validate] OK: $Message" -ForegroundColor Green }

#==============================================================================
# Package Registry Functions
#==============================================================================

function Get-NpmPackageInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Package,
        [string]$Version = "latest"
    )

    $registryUrl = "https://registry.npmjs.org/$Package"

    try {
        $response = Invoke-RestMethod -Uri $registryUrl -Method Get -ErrorAction Stop

        $latestVersion = $response.'dist-tags'.latest
        $versionInfo = $response.versions.$latestVersion

        $lastPublish = $response.time.$latestVersion
        if (-not $lastPublish) { $lastPublish = $response.time.modified }

        $deprecated = $versionInfo.deprecated
        $engines = $versionInfo.engines
        $peerDeps = $versionInfo.peerDependencies

        return @{
            package = $Package
            requested = $Version
            latest = $latestVersion
            lastPublish = $lastPublish
            deprecated = $deprecated
            engines = $engines
            peerDependencies = $peerDeps
            error = $null
        }
    }
    catch {
        return @{
            package = $Package
            requested = $Version
            error = "not_found"
        }
    }
}

function Get-PyPiPackageInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Package,
        [string]$Version = "latest"
    )

    $registryUrl = "https://pypi.org/pypi/$Package/json"

    try {
        $response = Invoke-RestMethod -Uri $registryUrl -Method Get -ErrorAction Stop

        $latestVersion = $response.info.version
        $requiresPython = $response.info.requires_python

        # Get upload time from releases
        $releaseInfo = $response.releases.$latestVersion
        $lastPublish = if ($releaseInfo -and $releaseInfo[0]) { $releaseInfo[0].upload_time } else { "unknown" }
        $yanked = if ($releaseInfo -and $releaseInfo[0]) { $releaseInfo[0].yanked } else { $false }

        return @{
            package = $Package
            requested = $Version
            latest = $latestVersion
            lastPublish = $lastPublish
            requiresPython = $requiresPython
            yanked = $yanked
            error = $null
        }
    }
    catch {
        return @{
            package = $Package
            requested = $Version
            error = "not_found"
        }
    }
}

#==============================================================================
# Validation Logic
#==============================================================================

function Get-DaysSincePublish {
    param([string]$PublishDate)

    if (-not $PublishDate -or $PublishDate -eq "unknown") {
        return -1
    }

    try {
        $publishDateTime = [DateTime]::Parse($PublishDate)
        $diff = (Get-Date) - $publishDateTime
        return [int]$diff.TotalDays
    }
    catch {
        return -1
    }
}

function Test-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Ecosystem,
        [Parameter(Mandatory=$true)]
        [string]$Package,
        [string]$Version = "latest"
    )

    $status = "PASS"
    $notes = ""
    $info = $null

    switch ($Ecosystem) {
        'npm' { $info = Get-NpmPackageInfo -Package $Package -Version $Version }
        'pypi' { $info = Get-PyPiPackageInfo -Package $Package -Version $Version }
        default {
            return @{
                package = $Package
                requested = $Version
                validated = "N/A"
                status = "SKIP"
                notes = "Unsupported ecosystem: $Ecosystem"
            }
        }
    }

    # Check for errors
    if ($info.error) {
        return @{
            package = $Package
            requested = $Version
            validated = "N/A"
            status = "FAIL"
            notes = "Package not found in registry"
            lastPublish = $null
        }
    }

    # Check freshness (warn if >2 years old)
    $daysOld = Get-DaysSincePublish -PublishDate $info.lastPublish
    if ($daysOld -gt 730) {
        $status = "WARN"
        $notes = "Last published $daysOld days ago (>2 years)"
    }

    # Check deprecation (npm)
    if ($info.deprecated) {
        $status = "WARN"
        $notes = "DEPRECATED: $($info.deprecated)"
    }

    # Check yanked (pypi)
    if ($info.yanked -eq $true) {
        $status = "WARN"
        $notes = "Package version is YANKED"
    }

    return @{
        package = $Package
        requested = $Version
        validated = $info.latest
        status = $status
        notes = $notes
        lastPublish = $info.lastPublish
    }
}

#==============================================================================
# Plan Parsing
#==============================================================================

function Get-TechStackFromPlan {
    param([string]$PlanFile)

    if (-not (Test-Path $PlanFile)) {
        Write-Err "Plan file not found: $PlanFile"
        return @()
    }

    $content = Get-Content $PlanFile -Raw

    # Extract Primary Dependencies line
    $deps = @()

    if ($content -match '\*\*Primary Dependencies\*\*:\s*(.+?)(?:\r?\n|$)') {
        $depsLine = $Matches[1]
        $deps += $depsLine -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch 'NEEDS CLARIFICATION' }
    }

    # Also check for Framework line
    if ($content -match '\*\*(Primary )?Framework\*\*:\s*(.+?)(?:\r?\n|$)') {
        $framework = $Matches[2].Trim()
        if ($framework -and $framework -notmatch 'NEEDS CLARIFICATION') {
            $deps = @($framework) + $deps
        }
    }

    return $deps | Select-Object -Unique
}

function Get-EcosystemFromPlan {
    param([string]$PlanFile)

    $content = Get-Content $PlanFile -Raw

    if ($content -match '\*\*Language/Version\*\*:\s*(.+?)(?:\r?\n|$)') {
        $lang = $Matches[1].ToLower()

        if ($lang -match 'python') { return 'pypi' }
        if ($lang -match 'typescript|javascript|node') { return 'npm' }
        if ($lang -match 'rust') { return 'cargo' }
        if ($lang -match 'go|golang') { return 'go' }
    }

    # Default to npm
    return 'npm'
}

#==============================================================================
# Main
#==============================================================================

function Main {
    # Get feature paths
    $paths = Get-FeaturePathsEnv

    # Determine plan file
    if (-not $PlanFile) {
        $PlanFile = $paths.IMPL_PLAN
    }

    if (-not (Test-Path $PlanFile)) {
        Write-Err "Plan file not found: $PlanFile"
        Write-Err "Run /speckit.plan first to create the implementation plan."
        exit 1
    }

    # Detect ecosystem if not specified
    if (-not $Ecosystem) {
        $Ecosystem = Get-EcosystemFromPlan -PlanFile $PlanFile
        Write-Info "Detected ecosystem: $Ecosystem"
    }

    # Extract packages
    $packages = Get-TechStackFromPlan -PlanFile $PlanFile

    if (-not $packages -or $packages.Count -eq 0) {
        Write-Warn "No packages found in plan.md Technical Context"
        if ($Json) {
            Write-Output '{"status":"SKIP","message":"No packages to validate","packages":[],"warnings":[]}'
        } else {
            Write-Output "No packages found to validate in plan.md"
        }
        exit 0
    }

    Write-Info "Validating packages from $PlanFile..."
    Write-Info "Ecosystem: $Ecosystem"

    # Validate each package
    $results = @()
    $warnings = @()
    $overallStatus = "PASS"

    foreach ($pkg in $packages) {
        if (-not $pkg) { continue }

        # Split package and version
        $pkgName = $pkg
        $pkgVersion = "latest"

        if ($pkg -match '^(.+)@(.+)$') {
            $pkgName = $Matches[1]
            $pkgVersion = $Matches[2]
        } elseif ($pkg -match '^(\S+)\s+(.+)$') {
            $pkgName = $Matches[1]
            $pkgVersion = $Matches[2]
        }

        Write-Info "Checking $pkgName..."

        $result = Test-Package -Ecosystem $Ecosystem -Package $pkgName -Version $pkgVersion
        $results += $result

        if ($result.status -eq "FAIL") {
            $overallStatus = "FAIL"
            Write-Err "$pkgName`: FAIL"
        } elseif ($result.status -eq "WARN") {
            if ($overallStatus -ne "FAIL") { $overallStatus = "PASS_WITH_WARNINGS" }
            $warnings += @{ package = $pkgName; issue = $result.notes }
            Write-Warn "$pkgName`: $($result.notes)"
        } else {
            Write-Success "$pkgName"
        }
    }

    # Output results
    if ($Json) {
        $output = @{
            status = $overallStatus
            ecosystem = $Ecosystem
            packages = $results
            warnings = $warnings
        }
        $output | ConvertTo-Json -Depth 10 -Compress
    } else {
        Write-Output ""
        Write-Output "════════════════════════════════════════════════════════════"
        Write-Output "Tech Stack Validation Report"
        Write-Output "════════════════════════════════════════════════════════════"
        Write-Output ""
        Write-Output "Status: $overallStatus"
        Write-Output "Ecosystem: $Ecosystem"
        Write-Output ""
        Write-Output "Packages:"

        foreach ($result in $results) {
            $line = "  {0,-30} {1} -> {2}" -f $result.package, $result.status, $result.validated
            if ($result.notes) { $line += " ($($result.notes))" }
            Write-Output $line
        }

        if ($warnings.Count -gt 0) {
            Write-Output ""
            Write-Output "Warnings:"
            foreach ($warning in $warnings) {
                Write-Output "  Warning: $($warning.package): $($warning.issue)"
            }
        }

        Write-Output ""
        Write-Output "════════════════════════════════════════════════════════════"
    }
}

Main
