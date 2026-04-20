#!/usr/bin/env pwsh
# Common PowerShell functions analogous to common.sh

function Get-RepoRoot {
    try {
        $result = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }
    
    # Fall back to script location for non-git repos
    return (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
}

function Get-CurrentBranch {
    # First check if SPECIFY_FEATURE environment variable is set
    if ($env:SPECIFY_FEATURE) {
        # Defense-in-depth: reject unsafe characters early
        if ($env:SPECIFY_FEATURE -notmatch '^[0-9]{3}-[a-z0-9-]+$') {
            Write-Error "SPECIFY_FEATURE contains invalid characters: $($env:SPECIFY_FEATURE). Expected pattern: ^[0-9]{3}-[a-z0-9-]+$ (e.g., 001-my-feature)"
            exit 1
        }
        return $env:SPECIFY_FEATURE
    }
    
    # Then check git if available
    try {
        $result = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }
    
    # For non-git repos, try to find the latest feature directory
    $repoRoot = Get-RepoRoot
    $specsDir = Join-Path $repoRoot "specs"
    
    if (Test-Path $specsDir) {
        $latestFeature = ""
        $highest = 0
        
        Get-ChildItem -Path $specsDir -Directory | ForEach-Object {
            if ($_.Name -match '^(\d{3})-') {
                $num = [int]$matches[1]
                if ($num -gt $highest) {
                    $highest = $num
                    $latestFeature = $_.Name
                }
            }
        }
        
        if ($latestFeature) {
            return $latestFeature
        }
    }
    
    # Final fallback
    return "main"
}

function Test-HasGit {
    try {
        git rev-parse --show-toplevel 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-FeatureBranch {
    param(
        [string]$Branch,
        [bool]$HasGit = $true
    )
    
    # For non-git repos, we can't enforce branch naming but still provide output
    if (-not $HasGit) {
        Write-Warning "[specify] Warning: Git repository not detected; skipped branch validation"
        return $true
    }
    
    if ($Branch -notmatch '^[0-9]{3}-') {
        Write-Output "ERROR: Not on a feature branch. Current branch: $Branch"
        Write-Output "Feature branches should be named like: 001-feature-name"
        return $false
    }
    return $true
}

function Get-FeatureDir {
    param([string]$RepoRoot, [string]$Branch)
    Join-Path $RepoRoot "specs/$Branch"
}

function Get-FeaturePathsEnv {
    # Per Constitution Article IX (Directive 2: Atomic Injunction), this function
    # does NOT expose a TASKS path for a single tasks.md file. The canonical task
    # artifact is the tasks/ directory of T-XXX-[name].md files, exposed as TASKS_DIR.
    $repoRoot = Get-RepoRoot
    $currentBranch = Get-CurrentBranch
    $hasGit = Test-HasGit
    $featureDir = Get-FeatureDir -RepoRoot $repoRoot -Branch $currentBranch

    [PSCustomObject]@{
        REPO_ROOT      = $repoRoot
        CURRENT_BRANCH = $currentBranch
        HAS_GIT        = $hasGit
        FEATURE_DIR    = $featureDir
        FEATURE_SPEC   = Join-Path $featureDir 'spec.md'
        IMPL_PLAN      = Join-Path $featureDir 'plan.md'
        TASKS_DIR      = Join-Path $featureDir 'tasks'
        INDEX          = Join-Path $featureDir 'index.md'
        TRACEABILITY   = Join-Path $featureDir 'traceability.md'
        RESEARCH       = Join-Path $featureDir 'research.md'
        DATA_MODEL     = Join-Path $featureDir 'data-model.md'
        QUICKSTART     = Join-Path $featureDir 'quickstart.md'
        CONTRACTS_DIR  = Join-Path $featureDir 'contracts'
    }
}

#==============================================================================
# Template Resolution Functions
#==============================================================================

function Resolve-Template {
    <#
    .SYNOPSIS
    Resolves template path, checking primary then legacy locations.

    .DESCRIPTION
    Checks templates/<name> first, falls back to .specify/templates/<name>.
    Returns $null if neither exists.
    #>
    param([string]$TemplateName)

    $repoRoot = Get-RepoRoot
    $primaryPath = Join-Path $repoRoot "templates/$TemplateName"
    $legacyPath = Join-Path $repoRoot ".specify/templates/$TemplateName"

    if (Test-Path $primaryPath) { return $primaryPath }
    if (Test-Path $legacyPath) { return $legacyPath }
    return $null
}

function Copy-TemplateWithGuard {
    <#
    .SYNOPSIS
    Safely copies a template to target, with fail-safe guards.

    .DESCRIPTION
    - NEVER overwrites a file that has content with empty content
    - If template found and target empty/missing: copies template
    - If template found and target has content: warns, keeps existing
    - If template missing and target has content: warns, keeps existing
    - If template missing and target empty/missing: ERROR, returns false

    .PARAMETER TemplateName
    Name of template file (e.g., "plan-template.md")

    .PARAMETER TargetPath
    Full path to target file

    .PARAMETER Context
    Context string for error messages (e.g., "setup-plan")

    .OUTPUTS
    $true on success (including skip), $false on failure
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TemplateName,

        [Parameter(Mandatory=$true)]
        [string]$TargetPath,

        [Parameter(Mandatory=$true)]
        [string]$Context
    )

    $templatePath = Resolve-Template $TemplateName
    $targetExists = Test-Path $TargetPath
    $targetHasContent = $targetExists -and ((Get-Item $TargetPath).Length -gt 0)

    if ($templatePath) {
        if ($targetHasContent) {
            Write-Warning "[$Context] Target already has content at $TargetPath. Skipping template copy."
            return $true  # Success - preserved existing
        }
        Copy-Item $templatePath $TargetPath -Force
        Write-Output "[$Context] Copied template to $TargetPath"
        return $true
    }
    else {
        # Template not found
        if ($targetHasContent) {
            Write-Warning "[$Context] Template '$TemplateName' not found, but target has content. Keeping existing file."
            return $true  # Success - preserved existing
        }
        else {
            Write-Error "[$Context] Template '$TemplateName' not found at templates/ or .specify/templates/"
            Write-Error "[$Context] Cannot create $TargetPath without template. Aborting."
            return $false  # Failure - would create empty file
        }
    }
}

#==============================================================================
# File/Directory Check Functions
#==============================================================================

function Test-FileExists {
    param([string]$Path, [string]$Description)
    if (Test-Path -Path $Path -PathType Leaf) {
        Write-Output "  ✓ $Description"
        return $true
    } else {
        Write-Output "  ✗ $Description"
        return $false
    }
}

function Test-DirHasFiles {
    param([string]$Path, [string]$Description)
    if ((Test-Path -Path $Path -PathType Container) -and (Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1)) {
        Write-Output "  ✓ $Description"
        return $true
    } else {
        Write-Output "  ✗ $Description"
        return $false
    }
}

