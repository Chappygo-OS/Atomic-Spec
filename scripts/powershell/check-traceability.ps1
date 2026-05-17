#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reverse-traceability check (v0.2+).

.DESCRIPTION
    Walks every file touched by the current feature branch and verifies it
    appears in <FEATURE_DIR>/traceability.md. Files that don't (the "Docker
    without asking" class) are reported as orphans.

    Per the v0.2 proposal, this gate is WARN-ONLY by default on v0.2.0. Pass
    -Enforce to make orphans a hard failure (non-zero exit). Promote to
    default-enforce in v0.2.1.

.PARAMETER Enforce
    If set, exits with code 1 when orphans are found. Default: warn-only.

.PARAMETER Json
    Emit a structured JSON report instead of human-readable text.

.EXAMPLE
    .\check-traceability.ps1
    .\check-traceability.ps1 -Enforce
    .\check-traceability.ps1 -Json | ConvertFrom-Json
#>

[CmdletBinding()]
param(
    [switch]$Enforce,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

. "$PSScriptRoot/common.ps1"

$paths = Get-FeaturePathsEnv

if (-not (Test-FeatureBranch -Branch $paths.CURRENT_BRANCH -HasGit:$paths.HAS_GIT)) {
    exit 2
}

$traceability = $paths.TRACEABILITY
if (-not (Test-Path $traceability -PathType Leaf)) {
    if ($Json) {
        @{ error = "traceability.md not found"; feature_dir = $paths.FEATURE_DIR } | ConvertTo-Json -Compress
    } else {
        Write-Output "ERROR: $traceability not found"
        Write-Output "Run /atomicspec.tasks first — traceability.md is generated there."
    }
    exit 2
}

# Find the merge base with the main branch. Fall back to HEAD~1 if neither
# main nor master exists, then to working-tree only if there's no parent.
$mergeBase = $null
foreach ($base in @('main', 'master')) {
    try {
        & git rev-parse --verify $base *> $null
        if ($LASTEXITCODE -eq 0) {
            # `git merge-base` can return multiple lines in criss-cross merge
            # cases — take the first line only.
            $mb = (& git merge-base HEAD $base 2>$null) | Select-Object -First 1
            if ($LASTEXITCODE -eq 0 -and $mb) {
                $mergeBase = $mb.Trim()
                break
            }
        }
    } catch { }
}

if (-not $mergeBase) {
    try {
        $headPrev = (& git rev-parse HEAD~1 2>$null)
        if ($LASTEXITCODE -eq 0 -and $headPrev) {
            $mergeBase = $headPrev.Trim()
        }
    } catch {
        $mergeBase = $null
    }
}

$changedSet = New-Object System.Collections.Generic.HashSet[string]

if ($mergeBase) {
    $diffOutput = & git diff --name-only $mergeBase HEAD 2>$null
    foreach ($line in $diffOutput) {
        if ($line) { [void]$changedSet.Add($line.Trim()) }
    }
} else {
    if (-not $Json) {
        Write-Warning "Cannot determine merge base; comparing against working tree only."
    }
}

# Add uncommitted changes too — these are files the AI just touched.
# Handle rename rows specially: "R  src/old.ts -> src/new.ts" — we want the
# destination (new) path, not the source.
$statusOutput = & git status --porcelain 2>$null
foreach ($line in $statusOutput) {
    if (-not $line) { continue }
    # Rename row
    if ($line -match '^R\s+(?<src>\S+)\s+->\s+(?<dst>.+)$') {
        [void]$changedSet.Add($Matches.dst.Trim())
        continue
    }
    # Regular row: two-char status code + space + path
    if ($line -match '^\s*\S+\s+(?<path>.+)$') {
        [void]$changedSet.Add($Matches.path.Trim())
    }
}

$changed = @($changedSet | Sort-Object)

# Exempt patterns — feature artifacts, framework, CI, registry, release docs.
function Test-IsExempt {
    param([string]$Path)
    $exempt = @(
        '^specs/',
        '^\.specify/',
        '^\.claude/',
        '^\.github/',
        '^\.cursor/',
        '^\.gemini/',
        '^\.windsurf/',
        '^memory/',
        '^\.gitignore$',
        '^\.gitattributes$',
        '^CHANGELOG\.md$',
        '^README\.md$',
        '^package-lock\.json$',
        '^yarn\.lock$',
        '^pnpm-lock\.yaml$',
        '^Cargo\.lock$',
        '^go\.sum$',
        '^uv\.lock$',
        '^poetry\.lock$'
    )
    $normalized = $Path -replace '\\', '/'
    foreach ($pattern in $exempt) {
        if ($normalized -match $pattern) { return $true }
    }
    return $false
}

$traceabilityText = Get-Content -LiteralPath $traceability -Raw

# Capture only structured-table-row lines (start with `|`) so prose,
# comments, and inline mentions can't spoof a mapping.
$tableRowLines = ($traceabilityText -split "`n") | Where-Object { $_ -match '^\|' }
$tableRows = ($tableRowLines -join "`n")

function Test-IsMapped {
    param([string]$Path)
    $normalized = $Path -replace '\\', '/'

    # IndexOf with Ordinal comparison is safe against `-like` wildcard
    # characters in the path (`[`, `]`, `*`, `?`).
    if ($tableRows.IndexOf($normalized, [System.StringComparison]::Ordinal) -ge 0) {
        return $true
    }
    # Basename match — require a leading "/" so foo.ts in a different
    # directory doesn't false-match a different foo.ts.
    $base = Split-Path -Leaf $normalized
    if ($tableRows.IndexOf("/$base", [System.StringComparison]::Ordinal) -ge 0) {
        return $true
    }
    return $false
}

$total = 0
$mapped = 0
$exemptCount = 0
$orphans = New-Object System.Collections.Generic.List[string]

foreach ($f in $changed) {
    if (-not $f) { continue }
    $total++
    if (Test-IsExempt $f) {
        $exemptCount++
        continue
    }
    if (Test-IsMapped $f) {
        $mapped++
    } else {
        $orphans.Add($f)
    }
}

if ($Json) {
    [PSCustomObject]@{
        total    = $total
        mapped   = $mapped
        exempt   = $exemptCount
        orphans  = $orphans
        enforced = [bool]$Enforce
    } | ConvertTo-Json -Compress
} else {
    Write-Output ""
    Write-Output "════════════════════════════════════════════════════════════"
    Write-Output "🔍 REVERSE-TRACEABILITY CHECK"
    Write-Output "════════════════════════════════════════════════════════════"
    Write-Output "  Total files changed:        $total"
    Write-Output "  Mapped to traceability.md:  $mapped"
    Write-Output "  Exempt (framework/spec):    $exemptCount"
    Write-Output "  Orphans:                    $($orphans.Count)"

    if ($orphans.Count -gt 0) {
        Write-Output ""
        Write-Output "Orphan files (modified but not referenced in traceability.md):"
        foreach ($f in $orphans) { Write-Output "  X $f" }
        Write-Output ""
        Write-Output "Per Constitution Directive 7 (v0.2 amendment), structural files"
        Write-Output "should have been gated by AskUserQuestion during /atomicspec.implement."
        Write-Output ""
        Write-Output "Fix options:"
        Write-Output "  1. Amend $traceability to map each orphan to a task ID + FR"
        Write-Output "  2. Delete the orphan file (it shouldn't have been created)"
        Write-Output "  3. Add the file's pattern to the exempt list (rare; document why)"
        Write-Output ""

        if ($Enforce) {
            Write-Output "BLOCKED: $($orphans.Count) orphan file(s) found and -Enforce is set."
            Write-Output "════════════════════════════════════════════════════════════"
            exit 1
        } else {
            Write-Output "WARN-ONLY: orphans reported but not blocking (v0.2.0 default)."
            Write-Output "Pass -Enforce to make this a hard failure in v0.2.1+."
        }
    } else {
        Write-Output ""
        Write-Output "OK: All non-exempt files map to traceability.md."
    }
    Write-Output "════════════════════════════════════════════════════════════"
    Write-Output ""
}

exit 0
