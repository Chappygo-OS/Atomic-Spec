#Requires -Version 5.1
<#
.SYNOPSIS
    inject-orientation (v0.3+) -- keep agent files in sync with the canonical
    Atomic Spec Orientation block.

.DESCRIPTION
    Called from check-prerequisites.ps1 at the top of every command run so a
    project becomes self-healing: if CLAUDE.md / GEMINI.md / AGENTS.md / etc.
    is missing the v1 orientation block, this script idempotently injects it.

    Reads the canonical block from templates/agent-file-template.md (between
    the ATOMIC-SPEC-ORIENTATION sentinels) and writes it into every agent
    file that EXISTS in the repo. Files that don't exist are skipped.

.PARAMETER Check
    Report what would be injected, but make no changes (dry run).

.PARAMETER Quiet
    Suppress non-error output.

.NOTES
    Sentinel format:
      <!-- ATOMIC-SPEC-ORIENTATION:vN:START -->
      ... block content ...
      <!-- ATOMIC-SPEC-ORIENTATION:vN:END -->

    Exit codes:
      0 - Success
      2 - Usage error
      3 - Canonical block not found in template
      4 - Agent file write failed
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Write-Info  { param([string]$m) if (-not $Quiet) { [Console]::Error.WriteLine($m) } }
function Write-Err   { param([string]$m) [Console]::Error.WriteLine("ERROR: $m") }

# Locate repo root.
$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir '..\..') | Select-Object -ExpandProperty Path
$Template  = Join-Path $RepoRoot 'templates\agent-file-template.md'

$SentinelStartRe = '<!-- ATOMIC-SPEC-ORIENTATION:v\d+:START -->'
$SentinelEndRe   = '<!-- ATOMIC-SPEC-ORIENTATION:v\d+:END -->'

if (-not (Test-Path $Template -PathType Leaf)) {
    Write-Err "Template not found: $Template"
    exit 3
}

# Extract canonical block (including sentinels) from the template.
$TemplateText = [System.IO.File]::ReadAllText($Template, [System.Text.UTF8Encoding]::new($false))
$BlockMatch = [regex]::Match(
    $TemplateText,
    "(?ms)$SentinelStartRe.*?$SentinelEndRe"
)
if (-not $BlockMatch.Success) {
    Write-Err "No ATOMIC-SPEC-ORIENTATION block found in $Template"
    exit 3
}
$CanonicalBlock = $BlockMatch.Value
$CanonicalVersion = ([regex]::Match($CanonicalBlock, 'ORIENTATION:(v\d+):START').Groups[1].Value)

# Canonical agent file paths (matches the 17-agent mapping).
$AgentFiles = @(
    'CLAUDE.md',
    'GEMINI.md',
    'AGENTS.md',
    'QWEN.md',
    'QODER.md',
    'SHAI.md',
    'CODEBUDDY.md',
    '.github\agents\copilot-instructions.md',
    '.github\copilot-instructions.md',
    '.cursor\rules\specify-rules.mdc',
    '.cursorrules',
    '.windsurf\rules\specify-rules.md',
    '.windsurfrules',
    '.kilocode\rules\specify-rules.md',
    '.augment\rules\specify-rules.md',
    '.roo\rules\specify-rules.md'
) | ForEach-Object { Join-Path $RepoRoot $_ }

function Write-FileText {
    param([string]$Path, [string]$Content)
    $tmp = "$Path.tmp-inject-$PID"
    try {
        [System.IO.File]::WriteAllText($tmp, $Content, [System.Text.UTF8Encoding]::new($false))
        Move-Item -Path $tmp -Destination $Path -Force
    } catch {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        Write-Err "Failed to write $Path : $_"
        exit 4
    }
}

function Inject-Into {
    param([string]$File)
    if (-not (Test-Path $File -PathType Leaf)) { return }

    $content = [System.IO.File]::ReadAllText($File, [System.Text.UTF8Encoding]::new($false))
    $existing = [regex]::Match($content, 'ATOMIC-SPEC-ORIENTATION:(v\d+):START')

    if ($existing.Success) {
        $existingVer = $existing.Groups[1].Value
        $existingN = [int]($existingVer.Substring(1))
        $canonicalN = [int]($CanonicalVersion.Substring(1))

        if ($existingN -eq $canonicalN) {
            Write-Info "  [skip]    $File (already at $CanonicalVersion)"
            return
        }
        if ($existingN -gt $canonicalN) {
            Write-Info "  [skip]    $File (has $existingVer, newer than canonical $CanonicalVersion)"
            return
        }

        # Replace old block with canonical.
        if ($Check) {
            Write-Info "  [upgrade] $File ($existingVer -> $CanonicalVersion)"
            return
        }
        $newContent = [regex]::Replace(
            $content,
            "(?ms)$SentinelStartRe.*?$SentinelEndRe",
            { param($m) $CanonicalBlock }
        )
        Write-FileText -Path $File -Content $newContent
        Write-Info "  [upgrade] $File ($existingVer -> $CanonicalVersion)"
        return
    }

    # No sentinel: insert. Try before MANUAL ADDITIONS, else append.
    if ($Check) {
        Write-Info "  [inject]  $File (no orientation block found)"
        return
    }
    if ($content -match '<!-- MANUAL ADDITIONS START -->') {
        $newContent = $content -replace '(?ms)(<!-- MANUAL ADDITIONS START -->)', "$CanonicalBlock`n`n`$1"
    } else {
        $newContent = $content.TrimEnd("`r","`n") + "`n`n" + $CanonicalBlock + "`n"
    }
    Write-FileText -Path $File -Content $newContent
    Write-Info "  [inject]  $File"
}

Write-Info "atomicspec: orientation injection (canonical version: $CanonicalVersion)"
foreach ($f in $AgentFiles) {
    if (Test-Path $f -PathType Leaf) {
        Inject-Into -File $f
    }
}
Write-Info "atomicspec: orientation injection complete"
exit 0
