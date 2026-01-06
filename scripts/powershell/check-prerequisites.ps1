#!/usr/bin/env pwsh

# Consolidated prerequisite checking script (PowerShell)
#
# This script provides unified prerequisite checking for Spec-Driven Development workflow.
# It replaces the functionality previously spread across multiple scripts.
#
# Usage: ./check-prerequisites.ps1 [OPTIONS]
#
# OPTIONS:
#   -Json               Output in JSON format
#   -RequireTasks       Require tasks/ directory to exist (for implementation phase)
#   -IncludeTasks       Include tasks/ in AVAILABLE_DOCS list
#   -PathsOnly          Only output path variables (no validation)
#   -CheckGates         Validate Knowledge Station gate criteria (blocks on failure)
#   -GateContext CTX    Gate context: 'tasks' or 'implement' (which gates to check)
#   -Help               Show help message

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$RequireTasks,
    [switch]$IncludeTasks,
    [switch]$PathsOnly,
    [switch]$CheckGates,
    [ValidateSet('tasks', 'implement')]
    [string]$GateContext,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Output @"
Usage: check-prerequisites.ps1 [OPTIONS]

Consolidated prerequisite checking for Spec-Driven Development workflow.

OPTIONS:
  -Json               Output in JSON format
  -RequireTasks       Require tasks/ directory to exist (for implementation phase)
  -IncludeTasks       Include tasks/ in AVAILABLE_DOCS list
  -PathsOnly          Only output path variables (no prerequisite validation)
  -CheckGates         Validate Knowledge Station gate criteria (blocks on failure)
  -GateContext CTX    Gate context: 'tasks' or 'implement' (which gates to check)
  -Help               Show this help message

EXAMPLES:
  # Check task prerequisites (plan.md required)
  .\check-prerequisites.ps1 -Json

  # Check with gate validation (Plan -> Tasks transition)
  .\check-prerequisites.ps1 -Json -CheckGates -GateContext tasks

  # Check implementation prerequisites (plan.md + tasks/ required)
  .\check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks

  # Get feature paths only (no validation)
  .\check-prerequisites.ps1 -PathsOnly

"@
    exit 0
}

# Source common functions
. "$PSScriptRoot/common.ps1"

# Get feature paths and validate branch
$paths = Get-FeaturePathsEnv

if (-not (Test-FeatureBranch -Branch $paths.CURRENT_BRANCH -HasGit:$paths.HAS_GIT)) {
    exit 1
}

# If paths-only mode, output paths and exit (support combined -Json -PathsOnly)
if ($PathsOnly) {
    if ($Json) {
        [PSCustomObject]@{
            REPO_ROOT    = $paths.REPO_ROOT
            BRANCH       = $paths.CURRENT_BRANCH
            FEATURE_DIR  = $paths.FEATURE_DIR
            FEATURE_SPEC = $paths.FEATURE_SPEC
            IMPL_PLAN    = $paths.IMPL_PLAN
            TASKS        = $paths.TASKS
            TASKS_DIR    = $paths.TASKS_DIR
        } | ConvertTo-Json -Compress
    } else {
        Write-Output "REPO_ROOT: $($paths.REPO_ROOT)"
        Write-Output "BRANCH: $($paths.CURRENT_BRANCH)"
        Write-Output "FEATURE_DIR: $($paths.FEATURE_DIR)"
        Write-Output "FEATURE_SPEC: $($paths.FEATURE_SPEC)"
        Write-Output "IMPL_PLAN: $($paths.IMPL_PLAN)"
        Write-Output "TASKS: $($paths.TASKS)"
        Write-Output "TASKS_DIR: $($paths.TASKS_DIR)"
    }
    exit 0
}

# Validate required directories and files
if (-not (Test-Path $paths.FEATURE_DIR -PathType Container)) {
    Write-Output "ERROR: Feature directory not found: $($paths.FEATURE_DIR)"
    Write-Output "Run /speckit.specify first to create the feature structure."
    exit 1
}

if (-not (Test-Path $paths.IMPL_PLAN -PathType Leaf)) {
    Write-Output "ERROR: plan.md not found in $($paths.FEATURE_DIR)"
    Write-Output "Run /speckit.plan first to create the implementation plan."
    exit 1
}

#==============================================================================
# Gate Validation (Knowledge Station Prerequisites)
#==============================================================================

function Test-Gates {
    param(
        [string]$Context,
        [PSCustomObject]$Paths
    )

    $gateFailures = 0

    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════"
    Write-Host "🛑 GATE VALIDATION - $Context"
    Write-Host "════════════════════════════════════════════════════════════"

    switch ($Context) {
        'tasks' {
            # Plan → Tasks gate criteria

            # Check if spec.md exists and has requirements
            if ((Test-Path $Paths.FEATURE_SPEC) -and
                (Select-String -Path $Paths.FEATURE_SPEC -Pattern "^## (Functional Requirements|User Stories)" -Quiet)) {
                Write-Host "✓ GATE PASS: spec.md has requirements defined"
            } else {
                Write-Host "✗ GATE FAIL: spec.md missing or lacks requirements section"
                $gateFailures++
            }

            # Check if plan.md has tech stack defined
            if ((Test-Path $Paths.IMPL_PLAN) -and
                (Select-String -Path $Paths.IMPL_PLAN -Pattern "^\*\*Language/Version\*\*:" -Quiet)) {
                Write-Host "✓ GATE PASS: plan.md has tech stack defined"
            } else {
                Write-Host "✗ GATE FAIL: plan.md missing tech stack (Language/Version)"
                $gateFailures++
            }

            # Check Tech Stack Approval (HITL checkpoint)
            if ((Test-Path $Paths.IMPL_PLAN) -and
                (Select-String -Path $Paths.IMPL_PLAN -Pattern "^\*\*Approval Status\*\*: Approved" -Quiet)) {
                Write-Host "✓ GATE PASS: Tech Stack approved by user"
            } else {
                Write-Host "✗ GATE FAIL: Tech Stack not approved (HITL checkpoint)"
                Write-Host "  → Run /speckit.plan and complete Phase 0.5 approval"
                $gateFailures++
            }

            # Check Tech Stack Validation (Phase 0.6/0.7)
            if ((Test-Path $Paths.IMPL_PLAN) -and
                (Select-String -Path $Paths.IMPL_PLAN -Pattern "^\*\*Validation Status\*\*: (PASS|PASS_WITH_WARNINGS|PASS_WITH_OVERRIDES)" -Quiet)) {
                Write-Host "✓ GATE PASS: Tech Stack validation completed"
            } else {
                Write-Host "✗ GATE FAIL: Tech Stack validation not completed"
                Write-Host "  → Run /speckit.plan and complete Phase 0.6/0.7 validation"
                $gateFailures++
            }
        }

        'implement' {
            # Tasks → Implementation gate criteria

            # Check for atomic task structure
            if ((Test-Path $Paths.TASKS_DIR -PathType Container) -and
                (Get-ChildItem -Path $Paths.TASKS_DIR -ErrorAction SilentlyContinue | Select-Object -First 1)) {
                Write-Host "✓ GATE PASS: tasks/ directory exists with task files"
            } else {
                Write-Host "✗ GATE FAIL: tasks/ directory missing or empty"
                $gateFailures++
            }

            # Check for index.md
            if (Test-Path $Paths.INDEX -PathType Leaf) {
                Write-Host "✓ GATE PASS: index.md exists"
            } else {
                Write-Host "✗ GATE FAIL: index.md missing (required for navigation)"
                $gateFailures++
            }

            # Check for traceability.md
            if (Test-Path $Paths.TRACEABILITY -PathType Leaf) {
                Write-Host "✓ GATE PASS: traceability.md exists"
            } else {
                Write-Host "✗ GATE FAIL: traceability.md missing (required for coverage)"
                $gateFailures++
            }
        }

        default {
            Write-Host "WARNING: Unknown gate context '$Context'. Skipping validation."
            return $true
        }
    }

    Write-Host "════════════════════════════════════════════════════════════"

    if ($gateFailures -gt 0) {
        Write-Host ""
        Write-Host "❌ BLOCKED: $gateFailures gate(s) failed. Fix issues before proceeding."
        Write-Host ""
        return $false
    } else {
        Write-Host ""
        Write-Host "✅ All gates passed. Proceeding..."
        Write-Host ""
        return $true
    }
}

# Run gate validation if requested
if ($CheckGates) {
    if (-not $GateContext) {
        Write-Output "ERROR: -CheckGates requires -GateContext (tasks|implement)"
        exit 1
    }

    if (-not (Test-Gates -Context $GateContext -Paths $paths)) {
        exit 1
    }
}

#==============================================================================
# Task Structure Validation
#==============================================================================

# Check for atomic task structure if required (Constitution Article IX compliance)
if ($RequireTasks) {
    # Check for tasks/ directory (Atomic Traceability Model)
    $hasAtomicTasks = (Test-Path $paths.TASKS_DIR -PathType Container) -and
                      (Get-ChildItem -Path $paths.TASKS_DIR -ErrorAction SilentlyContinue | Select-Object -First 1)
    $hasLegacyTasks = Test-Path $paths.TASKS -PathType Leaf

    if ($hasAtomicTasks) {
        # Atomic structure exists - this is the correct format
    } elseif ($hasLegacyTasks) {
        # Legacy tasks.md exists - warn about migration
        Write-Warning "Found legacy tasks.md file. Per Constitution Article IX,"
        Write-Warning "tasks should be in tasks/ directory with individual T-XXX-[name].md files."
        Write-Warning "Consider running /speckit.tasks to migrate to atomic task structure."
    } else {
        Write-Output "ERROR: No task structure found in $($paths.FEATURE_DIR)"
        Write-Output "Run /speckit.tasks first to create atomic task files."
        exit 1
    }

    # Also check for required Atomic Traceability files
    if (-not (Test-Path $paths.INDEX -PathType Leaf)) {
        Write-Warning "index.md not found. Required for Atomic Traceability Model."
    }
    if (-not (Test-Path $paths.TRACEABILITY -PathType Leaf)) {
        Write-Warning "traceability.md not found. Required for Atomic Traceability Model."
    }
}

#==============================================================================
# Build Available Documents List
#==============================================================================

$docs = @()

# Always check these optional docs
if (Test-Path $paths.RESEARCH) { $docs += 'research.md' }
if (Test-Path $paths.DATA_MODEL) { $docs += 'data-model.md' }

# Check contracts directory (only if it exists and has files)
if ((Test-Path $paths.CONTRACTS_DIR) -and (Get-ChildItem -Path $paths.CONTRACTS_DIR -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    $docs += 'contracts/'
}

if (Test-Path $paths.QUICKSTART) { $docs += 'quickstart.md' }

# Include atomic traceability files if they exist
if (Test-Path $paths.INDEX) { $docs += 'index.md' }
if (Test-Path $paths.TRACEABILITY) { $docs += 'traceability.md' }

# Include tasks/ if requested and it exists (Atomic Traceability Model)
if ($IncludeTasks) {
    if ((Test-Path $paths.TASKS_DIR -PathType Container) -and
        (Get-ChildItem -Path $paths.TASKS_DIR -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        $docs += 'tasks/'
    } elseif (Test-Path $paths.TASKS) {
        # Legacy support
        $docs += 'tasks.md'
    }
}

#==============================================================================
# Output Results
#==============================================================================

if ($Json) {
    # JSON output
    [PSCustomObject]@{
        FEATURE_DIR = $paths.FEATURE_DIR
        AVAILABLE_DOCS = $docs
    } | ConvertTo-Json -Compress
} else {
    # Text output
    Write-Output "FEATURE_DIR:$($paths.FEATURE_DIR)"
    Write-Output "AVAILABLE_DOCS:"

    # Show status of each potential document
    Test-FileExists -Path $paths.RESEARCH -Description 'research.md' | Out-Null
    Test-FileExists -Path $paths.DATA_MODEL -Description 'data-model.md' | Out-Null
    Test-DirHasFiles -Path $paths.CONTRACTS_DIR -Description 'contracts/' | Out-Null
    Test-FileExists -Path $paths.QUICKSTART -Description 'quickstart.md' | Out-Null
    Test-FileExists -Path $paths.INDEX -Description 'index.md' | Out-Null
    Test-FileExists -Path $paths.TRACEABILITY -Description 'traceability.md' | Out-Null

    if ($IncludeTasks) {
        Test-DirHasFiles -Path $paths.TASKS_DIR -Description 'tasks/' | Out-Null
        # Legacy fallback
        if (-not (Test-Path $paths.TASKS_DIR -PathType Container)) {
            Test-FileExists -Path $paths.TASKS -Description 'tasks.md (legacy)' | Out-Null
        }
    }
}
