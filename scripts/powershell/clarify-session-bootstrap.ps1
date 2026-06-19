#Requires -Version 5.1
<#
.SYNOPSIS
    clarify-session-bootstrap (v0.3+) -- initialize or extend clarify-log.md
    for a new /atomicspec.clarify session.

.DESCRIPTION
    Clarify is an EDIT to spec.md, not a re-author, so spec.md is NOT
    re-stamped per session (Article IX, Directive 9). Instead each clarify
    run gets its own Session block in clarify-log.md.

    This script deterministically:
      - Creates clarify-log.md from the template if absent
      - Otherwise PREPENDS a fresh "## Session <ISO-UTC>" block right after
        the file header (most-recent-first ordering)
      - Returns the absolute path to clarify-log.md on stdout

.PARAMETER FeatureDir
    Path to the feature folder (e.g., specs/014-ai-credit-system).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$FeatureDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $FeatureDir -PathType Container)) {
    [Console]::Error.WriteLine("ERROR: feature-dir not a directory: $FeatureDir")
    exit 4
}

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir '..\..') | Select-Object -ExpandProperty Path
$Template  = Join-Path $RepoRoot 'templates\clarify-log-template.md'
$Target    = Join-Path $FeatureDir 'clarify-log.md'

if (-not (Test-Path $Template -PathType Leaf)) {
    [Console]::Error.WriteLine("ERROR: template not found: $Template")
    exit 3
}

$Ts = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)

function Write-FileText {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Test-Path $Target -PathType Leaf)) {
    # First clarify run.
    $content = [System.IO.File]::ReadAllText($Template, [System.Text.UTF8Encoding]::new($false))
    $content = $content -replace '^## Session \[ISO 8601 UTC TIMESTAMP\]', "## Session $Ts"
    Write-FileText -Path $Target -Content $content
    [Console]::Error.WriteLine("Bootstrapped $Target with Session $Ts")
} else {
    # Extract session skeleton (everything after the first '---' separator in template).
    $tmplLines = [System.IO.File]::ReadAllLines($Template, [System.Text.UTF8Encoding]::new($false))
    $skeletonStart = -1
    for ($i = 0; $i -lt $tmplLines.Length; $i++) {
        if ($tmplLines[$i] -eq '---') { $skeletonStart = $i + 1; break }
    }
    $skeleton = if ($skeletonStart -ge 0) {
        ($tmplLines[$skeletonStart..($tmplLines.Length - 1)] -join "`n")
    } else { '' }
    $skeleton = $skeleton -replace '^## Session \[ISO 8601 UTC TIMESTAMP\]', "## Session $Ts"

    # Splice the new skeleton in just AFTER the first '---' separator in target.
    $targetLines = [System.IO.File]::ReadAllLines($Target, [System.Text.UTF8Encoding]::new($false))
    $output = New-Object System.Collections.Generic.List[string]
    $injected = $false
    foreach ($line in $targetLines) {
        $output.Add($line)
        if (-not $injected -and $line -eq '---') {
            $output.Add('')
            $output.Add($skeleton)
            $output.Add('')
            $output.Add('---')
            $injected = $true
        }
    }
    Write-FileText -Path $Target -Content (($output -join "`n") + "`n")
    [Console]::Error.WriteLine("Prepended new Session $Ts to $Target")
}

# Emit the target path for the caller to capture.
Write-Output $Target
exit 0
