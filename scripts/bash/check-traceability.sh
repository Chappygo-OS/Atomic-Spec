#!/usr/bin/env bash
#
# Reverse-traceability check (v0.2+) — closes the "silent scope creep" loop.
#
# Walks every file touched by the current feature branch and verifies that it
# appears in `<FEATURE_DIR>/traceability.md`. Files that don't (the "Docker
# without asking" class — config or scaffolding the AI created that no FR
# demanded) are reported as ORPHANS.
#
# Per the v0.2 proposal, this gate is WARN-ONLY by default on v0.2.0. Pass
# `--enforce` to make orphans a hard failure (non-zero exit). Promote to
# default-enforce in v0.2.1 once consumer projects have had a release cycle
# to clean up legacy orphans.
#
# Exempt patterns: feature artifacts (the spec/plan/tasks themselves),
# framework files, CI, and registry files — these don't need to map to a
# task because they ARE the framework or the feature artifacts.
#
# USAGE
#   check-traceability.sh [--enforce] [--json]
#
# OUTPUTS
#   Text mode: human-readable report with orphan list and remediation hint.
#   JSON mode: { "total": N, "mapped": M, "orphans": [...], "exempt": K }
#
# EXIT CODES
#   0 — no orphans, or --enforce not set and orphans were only warnings
#   1 — orphans found AND --enforce was passed
#   2 — usage / setup error (no git, no traceability.md, etc.)

set -e

ENFORCE=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --enforce) ENFORCE=true; shift ;;
        --json)    JSON_MODE=true; shift ;;
        --help|-h)
            cat << 'EOF'
Usage: check-traceability.sh [--enforce] [--json]

Verifies every file in the current feature branch is referenced in
traceability.md. Default is warn-only; pass --enforce to fail on orphans.
EOF
            exit 0 ;;
        *) echo "ERROR: unknown flag '$1'. See --help." >&2; exit 2 ;;
    esac
done

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

load_feature_paths
check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 2

if [[ ! -f "$TRACEABILITY" ]]; then
    if $JSON_MODE; then
        printf '{"error":"traceability.md not found","feature_dir":"%s"}\n' "$FEATURE_DIR"
    else
        echo "ERROR: $TRACEABILITY not found" >&2
        echo "Run /atomicspec.tasks first — traceability.md is generated there." >&2
    fi
    exit 2
fi

# Find the merge base with the main branch. If we can't find one, fall back
# to comparing against the previous commit (less ideal, but works for spike
# branches without a clear parent). In rare criss-cross-merge cases
# git merge-base returns multiple lines — take the first.
MERGE_BASE=""
for base_branch in main master; do
    if git rev-parse --verify "$base_branch" >/dev/null 2>&1; then
        MERGE_BASE=$(git merge-base HEAD "$base_branch" 2>/dev/null | head -1 || true)
        [[ -n "$MERGE_BASE" ]] && break
    fi
done

if [[ -z "$MERGE_BASE" ]]; then
    MERGE_BASE=$(git rev-parse HEAD~1 2>/dev/null || true)
fi

# Parse `git status --porcelain` correctly — rename rows ("R  old -> new")
# need the destination path, not the source.
porcelain_paths() {
    git status --porcelain 2>/dev/null | awk '
        $1 ~ /^R/ {
            # Rename: "R  src/old.ts -> src/new.ts"
            split($0, parts, " -> ")
            print parts[2]
            next
        }
        { print $2 }
    '
}

if [[ -z "$MERGE_BASE" ]]; then
    $JSON_MODE || echo "WARNING: cannot determine merge base; comparing against working tree only" >&2
    CHANGED_FILES=$(porcelain_paths)
else
    CHANGED_FILES=$(printf '%s\n%s\n' "$(git diff --name-only "$MERGE_BASE" HEAD 2>/dev/null)" "$(porcelain_paths)")
fi

# Dedupe + filter empty lines (|| true suppresses grep's exit 1 on no matches under set -e)
CHANGED_FILES=$(printf '%s\n' "$CHANGED_FILES" | sort -u | grep -v '^$' || true)

# Files exempt from traceability — these are feature artifacts, framework
# files, or operational concerns that aren't expected to map to a task.
is_exempt() {
    local f="$1"
    case "$f" in
        specs/*)                return 0 ;;  # spec/plan/tasks/traceability for this OR sibling features
        .specify/*)             return 0 ;;  # framework knowledge + subagents + scripts
        .claude/*|.github/*|.cursor/*|.gemini/*|.windsurf/*) return 0 ;;
        .gitignore|.gitattributes) return 0 ;;
        memory/*)               return 0 ;;  # framework constitution
        CHANGELOG.md|README.md) return 0 ;;  # release-time documentation updates
        package-lock.json|yarn.lock|pnpm-lock.yaml|Cargo.lock|go.sum|uv.lock|poetry.lock) return 0 ;;
    esac
    return 1
}

# Load the file paths mentioned in traceability.md. Look for any line that
# contains a file path under src/, lib/, app/, server/, or similar common
# code directories — or absolute task-id references that the implementer
# put in the doc.
TRACEABILITY_TEXT=$(cat "$TRACEABILITY")

# Determine whether a file path is referenced in traceability.md.
#
# Two-tier match, both restricted to MARKDOWN TABLE ROWS (lines starting
# with `|`) so prose / comments / inline mentions can't spoof a mapping:
#   1. Full path appears in any table row — solid match.
#   2. Basename appears with a preceding "/" in any table row — softer match,
#      but the leading slash blocks "auth.ts" matching when only
#      "src/auth/middleware.ts" is mapped (a different file in another dir).
#
# Returns 0 if mapped, 1 if not. `|| true` on every grep prevents `set -e`
# from silently killing the script on legitimate no-matches.
is_mapped() {
    local f="$1"
    local base
    base=$(basename "$f")

    # Capture only structured-table-row lines once per call.
    local table_rows
    table_rows=$(printf '%s' "$TRACEABILITY_TEXT" | grep '^|' || true)

    # Tier 1: full path verbatim in a table row.
    if printf '%s' "$table_rows" | grep -qF -- "$f" 2>/dev/null; then
        return 0
    fi

    # Tier 2: "/basename" in a table row (path-separator anchor avoids the
    # "any file with the same basename anywhere" false positive).
    if printf '%s' "$table_rows" | grep -qF -- "/$base" 2>/dev/null; then
        return 0
    fi

    return 1
}

TOTAL=0
MAPPED=0
EXEMPT_COUNT=0
declare -a ORPHANS=()

while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    TOTAL=$((TOTAL + 1))
    if is_exempt "$f"; then
        EXEMPT_COUNT=$((EXEMPT_COUNT + 1))
        continue
    fi
    if is_mapped "$f"; then
        MAPPED=$((MAPPED + 1))
    else
        ORPHANS+=("$f")
    fi
done <<< "$CHANGED_FILES"

ORPHAN_COUNT=${#ORPHANS[@]}

# JSON-escape a single path: backslash and double-quote must be escaped.
# Tab/newline are also handled defensively in case a pathological filename
# slips through (rare on POSIX; possible on NTFS).
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"      # backslash first
    s="${s//\"/\\\"}"      # then double-quote
    s="${s//$'\t'/\\t}"
    s="${s//$'\n'/\\n}"
    printf '%s' "$s"
}

# Output
if $JSON_MODE; then
    printf '{"total":%d,"mapped":%d,"exempt":%d,"orphans":[' "$TOTAL" "$MAPPED" "$EXEMPT_COUNT"
    for i in "${!ORPHANS[@]}"; do
        [[ $i -gt 0 ]] && printf ','
        printf '"%s"' "$(json_escape "${ORPHANS[$i]}")"
    done
    printf '],"enforced":%s}\n' "$ENFORCE"
else
    echo "" >&2
    echo "════════════════════════════════════════════════════════════" >&2
    echo "🔍 REVERSE-TRACEABILITY CHECK" >&2
    echo "════════════════════════════════════════════════════════════" >&2
    echo "  Total files changed:        $TOTAL" >&2
    echo "  Mapped to traceability.md:  $MAPPED" >&2
    echo "  Exempt (framework/spec):    $EXEMPT_COUNT" >&2
    echo "  Orphans:                    $ORPHAN_COUNT" >&2

    if [[ $ORPHAN_COUNT -gt 0 ]]; then
        echo "" >&2
        echo "Orphan files (modified but not referenced in traceability.md):" >&2
        for f in "${ORPHANS[@]}"; do
            echo "  ✗ $f" >&2
        done
        echo "" >&2
        echo "Per Constitution Directive 7 (v0.2 amendment), structural files" >&2
        echo "should have been gated by AskUserQuestion during /atomicspec.implement." >&2
        echo "" >&2
        echo "Fix options:" >&2
        echo "  1. Amend $TRACEABILITY to map each orphan to a task ID + FR" >&2
        echo "  2. Delete the orphan file (it shouldn't have been created)" >&2
        echo "  3. Add the file's pattern to the exempt list (rare; document why)" >&2
        echo "" >&2
        if $ENFORCE; then
            echo "❌ BLOCKED: $ORPHAN_COUNT orphan file(s) found and --enforce is set." >&2
            echo "════════════════════════════════════════════════════════════" >&2
            exit 1
        else
            echo "⚠  WARN-ONLY: orphans reported but not blocking (v0.2.0 default)." >&2
            echo "   Pass --enforce to make this a hard failure in v0.2.1+." >&2
        fi
    else
        echo "" >&2
        echo "✅ All non-exempt files map to traceability.md." >&2
    fi
    echo "════════════════════════════════════════════════════════════" >&2
    echo "" >&2
fi

exit 0
