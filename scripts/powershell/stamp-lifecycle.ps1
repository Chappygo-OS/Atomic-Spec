#Requires -Version 5.1
<#
.SYNOPSIS
    stamp-lifecycle (v0.3+) -- write and inspect Lifecycle Markers blocks.

.DESCRIPTION
    Deterministic, scripted gate for Atomic Spec's cross-provider AI handoff
    (Article IX, Directive 9 -- Orientation Read Surface). AIs MUST NOT write
    stamps by hand. All authoring/implementation lifecycle events go through
    this script so that timestamps, provider names, and block format stay
    uniform across providers (Claude / Codex / Gemini / Cursor / etc.).

.PARAMETER Command
    init | start | end | status

.PARAMETER Artifact
    Path to the artifact file.

.PARAMETER Lifecycle
    For init: authoring | both
    For start/end: authoring | implementation

.PARAMETER Provider
    Provider key from allowlist (claude/gpt/gemini/cursor/codex/etc.).

.PARAMETER Model
    Optional model qualifier (e.g., opus-4-7). Sanitized.

.PARAMETER VerifyDepth
    Optional, on start authoring of both-lifecycle artifacts: light | deep.

.PARAMETER Force
    Overwrite an already-populated field (humans only).

.PARAMETER Quiet
    Suppress non-error output.

.PARAMETER Json
    Emit JSON output for status.

.EXAMPLE
    stamp-lifecycle.ps1 -Command init -Artifact spec.md -Lifecycle authoring
    stamp-lifecycle.ps1 -Command start -Artifact spec.md -Lifecycle authoring -Provider claude -Model opus-4-7
    stamp-lifecycle.ps1 -Command end -Artifact spec.md -Lifecycle authoring -Provider claude -Model opus-4-7
    stamp-lifecycle.ps1 -Command status -Artifact spec.md -Json

.NOTES
    Exit codes match scripts/bash/stamp-lifecycle.sh: 0/2/3/4/5/6/7/8.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('init', 'start', 'end', 'status', 'help', '--help', '-h')]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Artifact,

    [string]$Lifecycle,
    [string]$Provider,
    [string]$Model,
    [ValidateSet('light', 'deep', '')]
    [string]$VerifyDepth,
    [switch]$Force,
    [switch]$Quiet,
    [switch]$Json,
    [switch]$Closed
)

$ErrorActionPreference = 'Stop'
$script:SCRIPT_VERSION = 'v0.3.0'
$script:PROVIDER_ALLOWLIST = @(
    'claude', 'gpt', 'gemini', 'cursor', 'copilot', 'codex', 'windsurf',
    'qwen', 'opencode', 'kilocode', 'auggie', 'shai', 'q', 'bob',
    'qoder', 'roo', 'amp', 'legacy'
)
$script:BLOCK_HEADING_REGEX = '^#{2,6}\s+Lifecycle Markers\s*$'

function Write-Info {
    param([string]$Message)
    if (-not $Quiet) {
        [Console]::Error.WriteLine($Message)
    }
}

function Write-Err {
    param([string]$Message)
    [Console]::Error.WriteLine("ERROR: $Message")
}

function Get-TimestampUtc {
    return [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
}

function Get-SanitizedModel {
    param([string]$Raw)
    if ([string]::IsNullOrEmpty($Raw)) { return '' }
    # SECURITY: strip newlines and carriage returns FIRST so a multi-line
    # -Model value cannot forge additional stamp lines via Set-FieldValue.
    $clean = $Raw -replace '[\r\n]+', ''
    $s = $clean.ToLowerInvariant().Trim()
    $s = [regex]::Replace($s, '[^a-z0-9.\-]+', '-')
    $s = [regex]::Replace($s, '^-+', '')
    $s = [regex]::Replace($s, '-+$', '')
    if ($s.Length -gt 40) {
        $s = $s.Substring(0, 40).TrimEnd('-')
    }
    return $s
}

function Test-Provider {
    param([ref]$P)
    # AGENT_NAME placeholder safety net (Directive 9: never silently default).
    if ($P.Value -eq '{{AGENT_NAME}}') {
        if ($env:ATOMICSPEC_PROVIDER) {
            Write-Info "[warn] {{AGENT_NAME}} placeholder leaked; using ATOMICSPEC_PROVIDER=$($env:ATOMICSPEC_PROVIDER)"
            $P.Value = $env:ATOMICSPEC_PROVIDER
        } else {
            Write-Err "Provider is unresolved {{AGENT_NAME}} placeholder and ATOMICSPEC_PROVIDER env var is not set. Run init-project.{sh,ps1} to substitute the placeholder, OR set `$env:ATOMICSPEC_PROVIDER = '<your-agent>'."
            exit 5
        }
    }
    if ($script:PROVIDER_ALLOWLIST -notcontains $P.Value) {
        Write-Err "Provider '$($P.Value)' not in allowlist. Allowed: $($script:PROVIDER_ALLOWLIST -join ' ')"
        exit 5
    }
}

function Get-Actor {
    param([string]$P, [string]$M)
    $clean = Get-SanitizedModel $M
    if ([string]::IsNullOrEmpty($clean)) { return $P }
    return "${P}:${clean}"
}

function Read-FileText {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

function Write-FileText {
    param([string]$Path, [string]$Content)
    # Atomic write: tempfile + rename. UTF-8 without BOM.
    $tmp = "$Path.tmp-stamp-$PID"
    [System.IO.File]::WriteAllText($tmp, $Content, [System.Text.UTF8Encoding]::new($false))
    Move-Item -Path $tmp -Destination $Path -Force
}

function Find-BlockLines {
    param([string]$Path)
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.UTF8Encoding]::new($false))
    $start = -1
    $end = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match $script:BLOCK_HEADING_REGEX) {
            $start = $i
            break
        }
    }
    if ($start -lt 0) { return $null }
    for ($i = $start + 1; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^#{1,6}\s+') {
            $end = $i - 1
            break
        }
    }
    if ($end -lt 0) { $end = $lines.Length - 1 }
    return @{ Start = $start; End = $end; Lines = $lines }
}

function Get-FieldValue {
    param([hashtable]$Block, [string]$Field)
    if (-not $Block) { return $null }
    $escaped = [regex]::Escape($Field)
    $pat = "^-\s+${escaped}:\s+(.+)$"
    for ($i = $Block.Start; $i -le $Block.End; $i++) {
        if ($Block.Lines[$i] -match $pat) {
            return $Matches[1].Trim()
        }
    }
    return $null
}

function Test-FieldSet {
    param([string]$Value)
    return ($null -ne $Value -and $Value -ne '' -and $Value -ne '<empty>')
}

function Set-FieldValue {
    param([string]$Path, [hashtable]$Block, [string]$Field, [string]$NewValue)
    $escaped = [regex]::Escape($Field)
    $pat = "^(-\s+${escaped}:\s+)(.+)$"
    $found = $false
    for ($i = $Block.Start; $i -le $Block.End; $i++) {
        if ($Block.Lines[$i] -match $pat) {
            $Block.Lines[$i] = "$($Matches[1])$NewValue"
            $found = $true
            break
        }
    }
    if (-not $found) {
        Write-Err "Field '$Field' not found in block at $Path."
        exit 4
    }
    $content = ($Block.Lines -join "`n") + "`n"
    Write-FileText -Path $Path -Content $content
}

function Invoke-Init {
    param(
        [string]$Path,
        [string]$Lc,
        [string]$ClosedProvider = '',
        [string]$ClosedModel = '',
        [string]$ClosedVerifyDepth = ''
    )
    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Err "Artifact not found: $Path"; exit 3
    }
    $block = Find-BlockLines $Path
    if (-not $block) {
        Write-Err "Lifecycle Markers heading not found in $Path. Templates should pre-include the heading."
        exit 4
    }
    # Already initialized?
    $existing = Get-FieldValue -Block $block -Field 'Authored start'
    if ($null -ne $existing) {
        Write-Info "Lifecycle Markers already initialized in $Path."
        return
    }

    # Closed-init mode: synchronous authoring (start + end written together).
    $closedValue = '<empty>'
    if (-not [string]::IsNullOrEmpty($ClosedProvider)) {
        Test-Provider ([ref]$ClosedProvider)
        $actor = Get-Actor -P $ClosedProvider -M $ClosedModel
        $ts = Get-TimestampUtc
        $closedValue = "$ts by $actor"
    }

    # Build the stamp lines.
    $newLines = @(
        "- Authored start:        $closedValue",
        "- Authored end:          $closedValue"
    )
    if ($Lc -eq 'both') {
        $vdLine = if (-not [string]::IsNullOrEmpty($ClosedVerifyDepth)) {
            "- verify-depth:          $ClosedVerifyDepth"
        } else {
            '- verify-depth:          <empty>'
        }
        $newLines += @(
            '- Implementation start:  <empty>',
            '- Implementation end:    <empty>',
            $vdLine
        )
    }

    # Insert at the end of the block (right after Block.End), with a blank separator.
    $lines = $block.Lines
    $before = if ($block.End -ge 0) { $lines[0..$block.End] } else { @() }
    $after = if ($block.End -lt $lines.Length - 1) { $lines[($block.End + 1)..($lines.Length - 1)] } else { @() }

    $combined = @()
    $combined += $before
    $combined += ''  # blank line separator
    $combined += $newLines
    if ($after.Count -gt 0) {
        $combined += $after
    }

    $content = ($combined -join "`n") + "`n"
    Write-FileText -Path $Path -Content $content
    Write-Info "Initialized Lifecycle Markers in $Path (lifecycle=$Lc)."
}

function Invoke-Stamp {
    param([string]$Action, [string]$Path, [string]$Lc, [string]$Prov, [string]$Mdl, [string]$Vd, [bool]$ForceFlag)

    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Err "Artifact not found: $Path"; exit 3
    }
    Test-Provider ([ref]$Prov)

    # Implementation lifecycle scope guard.
    if ($Lc -eq 'implementation') {
        $bn = [System.IO.Path]::GetFileName($Path)
        if (-not ($bn -match '^T-\d+') -and $bn -ne 'traceability.md') {
            Write-Err "Implementation lifecycle is not valid for $bn (only T-*.md and traceability.md)"
            exit 8
        }
    }

    $block = Find-BlockLines $Path
    if (-not $block) {
        Write-Err "Lifecycle Markers block missing in $Path. Run 'stamp-lifecycle init' first."
        exit 4
    }

    # Determine the field.
    $field = switch ("$Lc/$Action") {
        'authoring/start'      { 'Authored start' }
        'authoring/end'        { 'Authored end' }
        'implementation/start' { 'Implementation start' }
        'implementation/end'   { 'Implementation end' }
        default {
            Write-Err "Invalid action/lifecycle combination: $Action/$Lc"; exit 2
        }
    }

    # Pre-check: field already set?
    $current = Get-FieldValue -Block $block -Field $field
    if ((Test-FieldSet $current) -and (-not $ForceFlag)) {
        Write-Err "Field '$field' already populated in ${Path}: $current. Use -Force to overwrite."
        exit 6
    }

    # Sequencing: end requires matching start.
    if ($Action -eq 'end') {
        $matchingStartField = switch ($field) {
            'Authored end'       { 'Authored start' }
            'Implementation end' { 'Implementation start' }
        }
        $ms = Get-FieldValue -Block $block -Field $matchingStartField
        if (-not (Test-FieldSet $ms)) {
            Write-Err "Cannot write '$field' -- matching start stamp is missing in $Path."
            exit 7
        }
    }
    # Sequencing: implementation start requires authoring end.
    if ($Lc -eq 'implementation' -and $Action -eq 'start') {
        $authEnd = Get-FieldValue -Block $block -Field 'Authored end'
        if (-not (Test-FieldSet $authEnd)) {
            Write-Err "Cannot start implementation on $Path -- authoring is not complete (Authored end is missing)."
            exit 7
        }
    }

    # Compose value and write.
    $actor = Get-Actor -P $Prov -M $Mdl
    $ts = Get-TimestampUtc
    $newValue = "$ts by $actor"
    Set-FieldValue -Path $Path -Block $block -Field $field -NewValue $newValue

    Write-Info "Stamped $field on ${Path}: $newValue"

    # Optionally set verify-depth on start authoring.
    if ($Action -eq 'start' -and $Lc -eq 'authoring' -and -not [string]::IsNullOrEmpty($Vd)) {
        if ($Vd -ne 'light' -and $Vd -ne 'deep') {
            Write-Err "Invalid -VerifyDepth value: $Vd (must be light or deep)"
            exit 2
        }
        # Re-read the block since we just wrote to it.
        $block = Find-BlockLines $Path
        $vdCurrent = Get-FieldValue -Block $block -Field 'verify-depth'
        if ($null -ne $vdCurrent) {
            Set-FieldValue -Path $Path -Block $block -Field 'verify-depth' -NewValue $Vd
        }
    }
}

function Invoke-Status {
    param([string]$Path, [bool]$JsonFlag)
    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Err "Artifact not found: $Path"; exit 3
    }
    $block = Find-BlockLines $Path
    if (-not $block) {
        if ($JsonFlag) {
            Write-Output "{`"artifact`":`"$Path`",`"has_block`":false,`"legacy`":true,`"state`":`"legacy_closed`"}"
        } else {
            Write-Info "${Path}: legacy_closed (no Lifecycle Markers block -- pre-v0.3 artifact)"
        }
        return
    }

    $authStart  = Get-FieldValue -Block $block -Field 'Authored start'
    $authEnd    = Get-FieldValue -Block $block -Field 'Authored end'
    $implStart  = Get-FieldValue -Block $block -Field 'Implementation start'
    $implEnd    = Get-FieldValue -Block $block -Field 'Implementation end'
    $vd         = Get-FieldValue -Block $block -Field 'verify-depth'

    # State derivation.
    $state = if (-not (Test-FieldSet $authStart)) { 'empty' }
        elseif (-not (Test-FieldSet $authEnd))      { 'authoring_in_progress' }
        elseif ($null -eq $implStart)                { 'authored' }
        elseif (-not (Test-FieldSet $implStart))     { 'authored' }
        elseif (-not (Test-FieldSet $implEnd))       { 'implementing' }
        else                                          { 'done' }

    if ($JsonFlag) {
        function Get-LifecycleObj {
            param([string]$S, [string]$E)
            $sTs = $null; $sBy = $null; $eTs = $null; $eBy = $null
            if (Test-FieldSet $S) {
                $parts = $S -split ' by ', 2
                $sTs = $parts[0]; $sBy = $parts[1]
            }
            if (Test-FieldSet $E) {
                $parts = $E -split ' by ', 2
                $eTs = $parts[0]; $eBy = $parts[1]
            }
            $sTsJ = if ($sTs) { "`"$sTs`"" } else { 'null' }
            $sByJ = if ($sBy) { "`"$sBy`"" } else { 'null' }
            $eTsJ = if ($eTs) { "`"$eTs`"" } else { 'null' }
            $eByJ = if ($eBy) { "`"$eBy`"" } else { 'null' }
            return "{`"start`":$sTsJ,`"start_by`":$sByJ,`"end`":$eTsJ,`"end_by`":$eByJ}"
        }
        $authJson = Get-LifecycleObj -S $authStart -E $authEnd
        $implJson = if ($null -ne $implStart -or $null -ne $implEnd) {
            Get-LifecycleObj -S $implStart -E $implEnd
        } else { 'null' }
        $vdJson = if (Test-FieldSet $vd) { "`"$vd`"" } else { 'null' }
        Write-Output "{`"artifact`":`"$Path`",`"has_block`":true,`"legacy`":false,`"state`":`"$state`",`"authoring`":$authJson,`"implementation`":$implJson,`"verify_depth`":$vdJson}"
    } else {
        Write-Info "${Path}: state=$state"
        Write-Info "  Authored start:        $(if ($authStart) { $authStart } else { '<unset>' })"
        Write-Info "  Authored end:          $(if ($authEnd) { $authEnd } else { '<unset>' })"
        if ($null -ne $implStart -or $null -ne $implEnd) {
            Write-Info "  Implementation start:  $(if ($implStart) { $implStart } else { '<unset>' })"
            Write-Info "  Implementation end:    $(if ($implEnd) { $implEnd } else { '<unset>' })"
        }
        if (Test-FieldSet $vd) {
            Write-Info "  verify-depth:          $vd"
        }
    }
}

# Dispatch
switch ($Command) {
    'help' { Get-Help $PSCommandPath -Detailed; exit 0 }
    '-h'   { Get-Help $PSCommandPath -Detailed; exit 0 }
    '--help' { Get-Help $PSCommandPath -Detailed; exit 0 }
    'init' {
        if ([string]::IsNullOrEmpty($Artifact)) { Write-Err "Artifact path required"; exit 2 }
        if ([string]::IsNullOrEmpty($Lifecycle)) { $Lifecycle = 'authoring' }
        if ($Lifecycle -notin @('authoring', 'both')) {
            Write-Err "-Lifecycle for init must be 'authoring' or 'both' (got: $Lifecycle)"; exit 2
        }
        if ($Closed.IsPresent) {
            if ([string]::IsNullOrEmpty($Provider)) { Write-Err "-Closed requires -Provider"; exit 2 }
            Invoke-Init -Path $Artifact -Lc $Lifecycle -ClosedProvider $Provider -ClosedModel $Model -ClosedVerifyDepth $VerifyDepth
        } else {
            Invoke-Init -Path $Artifact -Lc $Lifecycle
        }
    }
    'start' {
        if ([string]::IsNullOrEmpty($Artifact)) { Write-Err "Artifact path required"; exit 2 }
        if ([string]::IsNullOrEmpty($Lifecycle)) { Write-Err "-Lifecycle is required for start"; exit 2 }
        if ([string]::IsNullOrEmpty($Provider)) { Write-Err "-Provider is required for start"; exit 2 }
        if ($Lifecycle -notin @('authoring', 'implementation')) {
            Write-Err "-Lifecycle for start must be 'authoring' or 'implementation' (got: $Lifecycle)"; exit 2
        }
        Invoke-Stamp -Action 'start' -Path $Artifact -Lc $Lifecycle -Prov $Provider -Mdl $Model -Vd $VerifyDepth -ForceFlag $Force.IsPresent
    }
    'end' {
        if ([string]::IsNullOrEmpty($Artifact)) { Write-Err "Artifact path required"; exit 2 }
        if ([string]::IsNullOrEmpty($Lifecycle)) { Write-Err "-Lifecycle is required for end"; exit 2 }
        if ([string]::IsNullOrEmpty($Provider)) { Write-Err "-Provider is required for end"; exit 2 }
        if ($Lifecycle -notin @('authoring', 'implementation')) {
            Write-Err "-Lifecycle for end must be 'authoring' or 'implementation' (got: $Lifecycle)"; exit 2
        }
        Invoke-Stamp -Action 'end' -Path $Artifact -Lc $Lifecycle -Prov $Provider -Mdl $Model -Vd '' -ForceFlag $Force.IsPresent
    }
    'status' {
        if ([string]::IsNullOrEmpty($Artifact)) { Write-Err "Artifact path required"; exit 2 }
        Invoke-Status -Path $Artifact -JsonFlag $Json.IsPresent
    }
    default {
        Write-Err "Unknown command: $Command"; exit 2
    }
}
exit 0
