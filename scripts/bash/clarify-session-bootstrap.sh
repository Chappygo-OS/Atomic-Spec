#!/usr/bin/env bash
#
# clarify-session-bootstrap (v0.3+) — initialize or extend clarify-log.md
# for a new /atomicspec.clarify session.
#
# Clarify is an EDIT to spec.md, not a re-author, so spec.md is NOT
# re-stamped per session (Article IX, Directive 9 — one-artifact-one-
# authoring-lifecycle invariant). Instead each clarify run gets its own
# Session block in clarify-log.md, with its own H3 Lifecycle Markers stamp.
#
# This script deterministically:
#   - Creates clarify-log.md from the template if absent
#   - Otherwise PREPENDS a fresh "## Session <ISO-UTC>" block right after
#     the file header (most-recent-first ordering)
#   - Returns the absolute path to the new session's H3 Lifecycle Markers
#     section so stamp-lifecycle can be called on it
#
# Replaces freeform pseudocode in templates/commands/clarify.md so two
# different providers (Claude / Codex / Gemini) produce identical structure.
#
# USAGE
#   clarify-session-bootstrap.sh --feature-dir <path>
#
# OUTPUTS
#   Stdout: the absolute path to clarify-log.md (always single line)
#   Stderr: human-readable log
#
# EXIT CODES
#   0  Success
#   2  Usage error
#   3  Template not found
#   4  Feature dir not a directory
#

set -euo pipefail

FEATURE_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --feature-dir) FEATURE_DIR="$2"; shift 2 ;;
        --help|-h)
            sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
    esac
done

[[ -n "$FEATURE_DIR" ]] || { echo "ERROR: --feature-dir is required" >&2; exit 2; }
[[ -d "$FEATURE_DIR" ]] || { echo "ERROR: feature-dir not a directory: $FEATURE_DIR" >&2; exit 4; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE="$REPO_ROOT/templates/clarify-log-template.md"
TARGET="$FEATURE_DIR/clarify-log.md"

[[ -f "$TEMPLATE" ]] || { echo "ERROR: template not found: $TEMPLATE" >&2; exit 3; }

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [[ ! -f "$TARGET" ]]; then
    # First clarify run — copy the template, then patch the placeholder
    # timestamp with the real session time.
    cp "$TEMPLATE" "$TARGET"
    # The template has '## Session [ISO 8601 UTC TIMESTAMP]' — replace once.
    awk -v ts="$TS" '
        !replaced && /^## Session \[ISO 8601 UTC TIMESTAMP\]$/ {
            print "## Session " ts; replaced = 1; next
        }
        { print }
    ' "$TARGET" > "$TARGET.tmp-bootstrap-$$"
    mv "$TARGET.tmp-bootstrap-$$" "$TARGET"
    echo "Bootstrapped $TARGET with Session $TS" >&2
else
    # Existing file — prepend a new session block above the previous one.
    # Strategy: extract the canonical session skeleton from the template
    # (between the '---' separator and EOF). Inject it just below the file's
    # top-level '---' separator. Newest session ends up at top.
    SKELETON="$(awk '/^---$/ { found = 1; next } found { print }' "$TEMPLATE")"
    # Substitute the timestamp placeholder in the skeleton.
    SKELETON_TS="$(printf '%s' "$SKELETON" | sed "s/^## Session \[ISO 8601 UTC TIMESTAMP\]\$/## Session $TS/")"

    # Splice the new skeleton in just AFTER the first '---' separator in target.
    awk -v new_block="$SKELETON_TS" '
        !injected && /^---$/ {
            print
            print ""
            print new_block
            print ""
            print "---"
            injected = 1
            next
        }
        { print }
    ' "$TARGET" > "$TARGET.tmp-bootstrap-$$"
    mv "$TARGET.tmp-bootstrap-$$" "$TARGET"
    echo "Prepended new Session $TS to $TARGET" >&2
fi

# Emit the target path for the caller (clarify.md) to capture.
printf '%s\n' "$TARGET"
