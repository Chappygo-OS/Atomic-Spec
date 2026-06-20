#!/usr/bin/env bash
#
# inject-orientation (v0.3+) — keep agent files in sync with the canonical
# Atomic Spec Orientation block.
#
# Called from check-prerequisites.sh at the top of every command run, so a
# project becomes self-healing: if CLAUDE.md / GEMINI.md / AGENTS.md / etc.
# is missing the v1 orientation block (e.g., the project was initialized
# pre-v0.3, or a new agent was added), this script idempotently injects it.
#
# Reads the canonical block from templates/agent-file-template.md (between
# the ATOMIC-SPEC-ORIENTATION sentinels) and writes it into every agent
# file that EXISTS in the repo. Files that don't exist are skipped — no
# preemptive creation. To bootstrap a new agent file (e.g., switch claude
# -> codex), see README "Multi-agent setup".
#
# Sentinel format:
#   <!-- ATOMIC-SPEC-ORIENTATION:vN:START -->
#   ... block content ...
#   <!-- ATOMIC-SPEC-ORIENTATION:vN:END -->
#
# Versioning: when the block content changes semantically (new directive,
# stamp format change), bump v1 -> v2 in templates/agent-file-template.md.
# This script will detect the version mismatch and splice the new block
# over the old. Newer versions in target files are left alone (never
# downgrade).
#
# USAGE
#   inject-orientation.sh [--check] [--quiet]
#
# OPTIONS
#   --check    Report what would be injected, but make no changes (dry run)
#   --quiet    Suppress non-error output
#
# EXIT CODES
#   0    Success (injection performed or no-op)
#   2    Usage error
#   3    Canonical block not found in templates/agent-file-template.md
#   4    Agent file write failed
#

set -euo pipefail

QUIET="${QUIET:-0}"
CHECK_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_ONLY=1; shift ;;
        --quiet) QUIET=1; shift ;;
        --help|-h)
            sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
    esac
done

log_info()  { [[ "$QUIET" == "1" ]] || printf '%s\n' "$*" >&2; }
log_error() { printf 'ERROR: %s\n' "$*" >&2; }

# Locate repo root (script may be called from anywhere).
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$REPO_ROOT/templates/agent-file-template.md"
SENTINEL_START_RE='<!-- ATOMIC-SPEC-ORIENTATION:v[0-9]+:START -->'
SENTINEL_END_RE='<!-- ATOMIC-SPEC-ORIENTATION:v[0-9]+:END -->'

if [[ ! -f "$TEMPLATE" ]]; then
    log_error "Template not found: $TEMPLATE"
    exit 3
fi

# Extract the canonical block (including its sentinels) from the template.
CANONICAL_BLOCK="$(awk -v s="$SENTINEL_START_RE" -v e="$SENTINEL_END_RE" '
    $0 ~ s { in_block = 1 }
    in_block { print }
    $0 ~ e && in_block { in_block = 0; exit }
' "$TEMPLATE")"

if [[ -z "$CANONICAL_BLOCK" ]]; then
    log_error "No ATOMIC-SPEC-ORIENTATION block found in $TEMPLATE"
    exit 3
fi

# Extract the canonical version (e.g., v1) from the sentinel.
CANONICAL_VERSION="$(printf '%s' "$CANONICAL_BLOCK" | head -1 | sed -E 's/.*ORIENTATION:(v[0-9]+):START.*/\1/')"

# Canonical agent file paths (matches the 17-agent mapping used by atomicspec CLI).
# Only files that ALREADY EXIST are touched; missing files are skipped.
AGENT_FILES=(
    "$REPO_ROOT/CLAUDE.md"
    "$REPO_ROOT/GEMINI.md"
    "$REPO_ROOT/AGENTS.md"
    "$REPO_ROOT/QWEN.md"
    "$REPO_ROOT/QODER.md"
    "$REPO_ROOT/SHAI.md"
    "$REPO_ROOT/CODEBUDDY.md"
    "$REPO_ROOT/.github/agents/copilot-instructions.md"
    "$REPO_ROOT/.github/copilot-instructions.md"
    "$REPO_ROOT/.cursor/rules/specify-rules.mdc"
    "$REPO_ROOT/.cursorrules"
    "$REPO_ROOT/.windsurf/rules/specify-rules.md"
    "$REPO_ROOT/.windsurfrules"
    "$REPO_ROOT/.kilocode/rules/specify-rules.md"
    "$REPO_ROOT/.augment/rules/specify-rules.md"
    "$REPO_ROOT/.roo/rules/specify-rules.md"
)

# Inject canonical block into one file. Idempotent.
inject_into() {
    local file="$1"
    [[ -f "$file" ]] || return 0  # skip non-existent files

    # Check existing version (if any).
    local existing_version
    existing_version="$(grep -m1 -oE 'ATOMIC-SPEC-ORIENTATION:v[0-9]+:START' "$file" 2>/dev/null \
        | sed -E 's/ATOMIC-SPEC-ORIENTATION:(v[0-9]+):START/\1/' || true)"

    if [[ -n "$existing_version" ]]; then
        # Compare versions numerically (strip leading 'v').
        local existing_n="${existing_version#v}"
        local canonical_n="${CANONICAL_VERSION#v}"

        if [[ "$existing_n" -eq "$canonical_n" ]]; then
            log_info "  [skip]    $file (already at $CANONICAL_VERSION)"
            return 0
        elif [[ "$existing_n" -gt "$canonical_n" ]]; then
            log_info "  [skip]    $file (has $existing_version, newer than canonical $CANONICAL_VERSION)"
            return 0
        else
            # Existing is older: splice out old block, insert new.
            if [[ "$CHECK_ONLY" == "1" ]]; then
                log_info "  [upgrade] $file ($existing_version -> $CANONICAL_VERSION)"
                return 0
            fi
            replace_block "$file"
            log_info "  [upgrade] $file ($existing_version -> $CANONICAL_VERSION)"
            return 0
        fi
    fi

    # No sentinel: insert block. Try to place before MANUAL ADDITIONS markers
    # if they exist; otherwise append at end.
    if [[ "$CHECK_ONLY" == "1" ]]; then
        log_info "  [inject]  $file (no orientation block found)"
        return 0
    fi
    insert_block "$file"
    log_info "  [inject]  $file"
}

# Replace existing (older) block in file. Atomic via tempfile + mv.
replace_block() {
    local file="$1"
    local tmp="${file}.tmp-inject-$$"
    awk -v block="$CANONICAL_BLOCK" -v sre="$SENTINEL_START_RE" -v ere="$SENTINEL_END_RE" '
        # When we see the start sentinel, emit the canonical block and skip until end sentinel.
        $0 ~ sre {
            print block
            skipping = 1
            next
        }
        skipping {
            if ($0 ~ ere) { skipping = 0 }
            next
        }
        { print }
    ' "$file" > "$tmp" || { rm -f "$tmp"; log_error "Failed to splice $file"; exit 4; }
    mv "$tmp" "$file"
}

# Insert canonical block into a file with no existing sentinels.
insert_block() {
    local file="$1"
    local tmp="${file}.tmp-inject-$$"
    if grep -q '<!-- MANUAL ADDITIONS START -->' "$file"; then
        # Insert before MANUAL ADDITIONS, with blank-line separator.
        awk -v block="$CANONICAL_BLOCK" '
            /<!-- MANUAL ADDITIONS START -->/ {
                print block
                print ""
            }
            { print }
        ' "$file" > "$tmp" || { rm -f "$tmp"; log_error "Failed to insert into $file"; exit 4; }
    else
        # Append at end (preceded by blank line for cleanliness).
        cp "$file" "$tmp"
        printf '\n%s\n' "$CANONICAL_BLOCK" >> "$tmp"
    fi
    mv "$tmp" "$file"
}

# Main loop.
log_info "atomicspec: orientation injection (canonical version: $CANONICAL_VERSION)"
for agent_file in "${AGENT_FILES[@]}"; do
    if [[ -f "$agent_file" ]]; then
        inject_into "$agent_file"
    fi
done
log_info "atomicspec: orientation injection complete"
exit 0
