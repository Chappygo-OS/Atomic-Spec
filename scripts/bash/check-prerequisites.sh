#!/usr/bin/env bash

# Consolidated prerequisite checking script
#
# This script provides unified prerequisite checking for Spec-Driven Development workflow.
# It replaces the functionality previously spread across multiple scripts.
#
# Usage: ./check-prerequisites.sh [OPTIONS]
#
# OPTIONS:
#   --json              Output in JSON format
#   --require-tasks     Require tasks/ directory to exist (for implementation phase)
#   --include-tasks     Include tasks/ in AVAILABLE_DOCS list
#   --paths-only        Only output path variables (no validation)
#   --check-gates       Validate Knowledge Station gate criteria (blocks on failure)
#   --gate-context CTX  Gate context: 'tasks' or 'implement' (determines which gates to check)
#   --help, -h          Show help message
#
# OUTPUTS:
#   JSON mode: {"FEATURE_DIR":"...", "AVAILABLE_DOCS":["..."]}
#   Text mode: FEATURE_DIR:... \n AVAILABLE_DOCS: \n ✓/✗ file.md
#   Paths only: REPO_ROOT: ... \n BRANCH: ... \n FEATURE_DIR: ... etc.
#
# NOTE: Per Constitution Article IX (Atomic Injunction), tasks are now stored in
#       a tasks/ directory with individual T-XXX-[name].md files, not tasks.md

set -e

# Parse command line arguments
JSON_MODE=false
REQUIRE_TASKS=false
INCLUDE_TASKS=false
PATHS_ONLY=false
CHECK_GATES=false
GATE_CONTEXT=""

i=1
while [ $i -le $# ]; do
    arg="${!i}"
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --require-tasks)
            REQUIRE_TASKS=true
            ;;
        --include-tasks)
            INCLUDE_TASKS=true
            ;;
        --paths-only)
            PATHS_ONLY=true
            ;;
        --check-gates)
            CHECK_GATES=true
            ;;
        --gate-context)
            i=$((i + 1))
            GATE_CONTEXT="${!i}"
            ;;
        --help|-h)
            cat << 'EOF'
Usage: check-prerequisites.sh [OPTIONS]

Consolidated prerequisite checking for Spec-Driven Development workflow.

OPTIONS:
  --json              Output in JSON format
  --require-tasks     Require tasks/ directory to exist (for implementation phase)
  --include-tasks     Include tasks/ in AVAILABLE_DOCS list
  --paths-only        Only output path variables (no prerequisite validation)
  --check-gates       Validate Knowledge Station gate criteria (blocks on failure)
  --gate-context CTX  Gate context: 'tasks' or 'implement' (which gates to check)
  --help, -h          Show this help message

EXAMPLES:
  # Check task prerequisites (plan.md required)
  ./check-prerequisites.sh --json

  # Check with gate validation (Plan → Tasks transition)
  ./check-prerequisites.sh --json --check-gates --gate-context tasks

  # Check implementation prerequisites (plan.md + tasks/ required)
  ./check-prerequisites.sh --json --require-tasks --include-tasks

  # Get feature paths only (no validation)
  ./check-prerequisites.sh --paths-only
  
EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$arg'. Use --help for usage information." >&2
            exit 1
            ;;
    esac
    i=$((i + 1))
done

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get feature paths and validate branch
eval $(get_feature_paths)
check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1

# If paths-only mode, output paths and exit (support JSON + paths-only combined)
if $PATHS_ONLY; then
    if $JSON_MODE; then
        # Minimal JSON paths payload (no validation performed)
        printf '{"REPO_ROOT":"%s","BRANCH":"%s","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s"}\n' \
            "$REPO_ROOT" "$CURRENT_BRANCH" "$FEATURE_DIR" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS"
    else
        echo "REPO_ROOT: $REPO_ROOT"
        echo "BRANCH: $CURRENT_BRANCH"
        echo "FEATURE_DIR: $FEATURE_DIR"
        echo "FEATURE_SPEC: $FEATURE_SPEC"
        echo "IMPL_PLAN: $IMPL_PLAN"
        echo "TASKS: $TASKS"
    fi
    exit 0
fi

# Validate required directories and files
if [[ ! -d "$FEATURE_DIR" ]]; then
    echo "ERROR: Feature directory not found: $FEATURE_DIR" >&2
    echo "Run /atomicspec.specify first to create the feature structure." >&2
    exit 1
fi

if [[ ! -f "$IMPL_PLAN" ]]; then
    echo "ERROR: plan.md not found in $FEATURE_DIR" >&2
    echo "Run /atomicspec.plan first to create the implementation plan." >&2
    exit 1
fi

#==============================================================================
# Gate Validation (Knowledge Station Prerequisites)
#==============================================================================

check_gate_file() {
    local station_file="$1"
    local gate_name="$2"
    local required_pattern="$3"

    if [[ ! -f "$station_file" ]]; then
        echo "⚠ GATE SKIP: $gate_name - Station file not found" >&2
        return 0  # Don't fail if station doesn't exist (might be optional)
    fi

    # Check if the file has been customized (not just template content)
    if grep -q "$required_pattern" "$station_file" 2>/dev/null; then
        echo "✓ GATE PASS: $gate_name" >&2
        return 0
    else
        echo "✗ GATE FAIL: $gate_name" >&2
        echo "  → Review: $station_file" >&2
        return 1
    fi
}

validate_gates() {
    local context="$1"
    local gate_failures=0
    local stations_dir="$REPO_ROOT/.specify/knowledge/stations"

    echo "" >&2
    echo "════════════════════════════════════════════════════════════" >&2
    echo "🛑 GATE VALIDATION - $context" >&2
    echo "════════════════════════════════════════════════════════════" >&2

    case "$context" in
        tasks)
            # Plan → Tasks gate criteria
            # These are the gates that should be satisfied before generating tasks

            # Check if spec.md exists and has requirements
            if [[ -f "$FEATURE_SPEC" ]] && grep -qE "^## (Functional Requirements|User Stories)" "$FEATURE_SPEC" 2>/dev/null; then
                echo "✓ GATE PASS: spec.md has requirements defined" >&2
            else
                echo "✗ GATE FAIL: spec.md missing or lacks requirements section" >&2
                ((gate_failures++))
            fi

            # Check if plan.md has tech stack defined
            if [[ -f "$IMPL_PLAN" ]] && grep -qE "^\*\*Language/Version\*\*:" "$IMPL_PLAN" 2>/dev/null; then
                echo "✓ GATE PASS: plan.md has tech stack defined" >&2
            else
                echo "✗ GATE FAIL: plan.md missing tech stack (Language/Version)" >&2
                ((gate_failures++))
            fi

            # Check Tech Stack Approval (HITL checkpoint)
            if [[ -f "$IMPL_PLAN" ]] && grep -qE "^\*\*Approval Status\*\*: Approved" "$IMPL_PLAN" 2>/dev/null; then
                echo "✓ GATE PASS: Tech Stack approved by user" >&2
            else
                echo "✗ GATE FAIL: Tech Stack not approved (HITL checkpoint)" >&2
                echo "  → Run /atomicspec.plan and complete Phase 0.5 approval" >&2
                ((gate_failures++))
            fi

            # Check Tech Stack Validation (Phase 0.6/0.7)
            if [[ -f "$IMPL_PLAN" ]] && grep -qE "^\*\*Validation Status\*\*: (PASS|PASS_WITH_WARNINGS|PASS_WITH_OVERRIDES)" "$IMPL_PLAN" 2>/dev/null; then
                echo "✓ GATE PASS: Tech Stack validation completed" >&2
            else
                echo "✗ GATE FAIL: Tech Stack validation not completed" >&2
                echo "  → Run /atomicspec.plan and complete Phase 0.6/0.7 validation" >&2
                ((gate_failures++))
            fi
            ;;

        implement)
            # Tasks → Implementation gate criteria

            # Check for atomic task structure
            if [[ -d "$TASKS_DIR" ]] && [[ -n "$(ls -A "$TASKS_DIR" 2>/dev/null)" ]]; then
                echo "✓ GATE PASS: tasks/ directory exists with task files" >&2
            else
                echo "✗ GATE FAIL: tasks/ directory missing or empty" >&2
                ((gate_failures++))
            fi

            # Check for index.md
            if [[ -f "$INDEX" ]]; then
                echo "✓ GATE PASS: index.md exists" >&2
            else
                echo "✗ GATE FAIL: index.md missing (required for navigation)" >&2
                ((gate_failures++))
            fi

            # Check for traceability.md
            if [[ -f "$TRACEABILITY" ]]; then
                echo "✓ GATE PASS: traceability.md exists" >&2
            else
                echo "✗ GATE FAIL: traceability.md missing (required for coverage)" >&2
                ((gate_failures++))
            fi
            ;;

        *)
            echo "WARNING: Unknown gate context '$context'. Skipping validation." >&2
            return 0
            ;;
    esac

    echo "════════════════════════════════════════════════════════════" >&2

    if [[ $gate_failures -gt 0 ]]; then
        echo "" >&2
        echo "❌ BLOCKED: $gate_failures gate(s) failed. Fix issues before proceeding." >&2
        echo "" >&2
        return 1
    else
        echo "" >&2
        echo "✅ All gates passed. Proceeding..." >&2
        echo "" >&2
        return 0
    fi
}

# Run gate validation if requested
if $CHECK_GATES; then
    if [[ -z "$GATE_CONTEXT" ]]; then
        echo "ERROR: --check-gates requires --gate-context (tasks|implement)" >&2
        exit 1
    fi

    if ! validate_gates "$GATE_CONTEXT"; then
        exit 1
    fi
fi

#==============================================================================
# Task Structure Validation
#==============================================================================

# Check for atomic task structure if required (Constitution Article IX compliance)
if $REQUIRE_TASKS; then
    # Check for tasks/ directory (Atomic Traceability Model)
    if [[ -d "$TASKS_DIR" ]] && [[ -n "$(ls -A "$TASKS_DIR" 2>/dev/null)" ]]; then
        # Atomic structure exists - this is the correct format
        :
    elif [[ -f "$TASKS" ]]; then
        # Legacy tasks.md exists - warn about migration
        echo "WARNING: Found legacy tasks.md file. Per Constitution Article IX," >&2
        echo "tasks should be in tasks/ directory with individual T-XXX-[name].md files." >&2
        echo "Consider running /atomicspec.tasks to migrate to atomic task structure." >&2
    else
        echo "ERROR: No task structure found in $FEATURE_DIR" >&2
        echo "Run /atomicspec.tasks first to create atomic task files." >&2
        exit 1
    fi

    # Also check for required Atomic Traceability files
    if [[ ! -f "$INDEX" ]]; then
        echo "WARNING: index.md not found. Required for Atomic Traceability Model." >&2
    fi
    if [[ ! -f "$TRACEABILITY" ]]; then
        echo "WARNING: traceability.md not found. Required for Atomic Traceability Model." >&2
    fi
fi

# Build list of available documents
docs=()

# Always check these optional docs
[[ -f "$RESEARCH" ]] && docs+=("research.md")
[[ -f "$DATA_MODEL" ]] && docs+=("data-model.md")

# Check contracts directory (only if it exists and has files)
if [[ -d "$CONTRACTS_DIR" ]] && [[ -n "$(ls -A "$CONTRACTS_DIR" 2>/dev/null)" ]]; then
    docs+=("contracts/")
fi

[[ -f "$QUICKSTART" ]] && docs+=("quickstart.md")

# Include atomic traceability files if they exist
[[ -f "$INDEX" ]] && docs+=("index.md")
[[ -f "$TRACEABILITY" ]] && docs+=("traceability.md")

# Include tasks/ directory if requested and it exists (Atomic Traceability Model)
if $INCLUDE_TASKS; then
    if [[ -d "$TASKS_DIR" ]] && [[ -n "$(ls -A "$TASKS_DIR" 2>/dev/null)" ]]; then
        docs+=("tasks/")
    elif [[ -f "$TASKS" ]]; then
        # Legacy support
        docs+=("tasks.md")
    fi
fi

# Output results
if $JSON_MODE; then
    # Build JSON array of documents
    if [[ ${#docs[@]} -eq 0 ]]; then
        json_docs="[]"
    else
        json_docs=$(printf '"%s",' "${docs[@]}")
        json_docs="[${json_docs%,}]"
    fi
    
    printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s}\n' "$FEATURE_DIR" "$json_docs"
else
    # Text output
    echo "FEATURE_DIR:$FEATURE_DIR"
    echo "AVAILABLE_DOCS:"
    
    # Show status of each potential document
    check_file "$RESEARCH" "research.md"
    check_file "$DATA_MODEL" "data-model.md"
    check_dir "$CONTRACTS_DIR" "contracts/"
    check_file "$QUICKSTART" "quickstart.md"
    
    # Check atomic traceability files
    check_file "$INDEX" "index.md"
    check_file "$TRACEABILITY" "traceability.md"

    if $INCLUDE_TASKS; then
        check_dir "$TASKS_DIR" "tasks/"
        # Legacy fallback
        if [[ ! -d "$TASKS_DIR" ]]; then
            check_file "$TASKS" "tasks.md (legacy)"
        fi
    fi
fi
