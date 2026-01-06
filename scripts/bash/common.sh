#!/usr/bin/env bash
# Common functions and variables for all scripts

# Get repository root, with fallback for non-git repositories
get_repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        # Fall back to script location for non-git repos
        local script_dir="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        (cd "$script_dir/../../.." && pwd)
    fi
}

# Get current branch, with fallback for non-git repositories
get_current_branch() {
    # First check if SPECIFY_FEATURE environment variable is set
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi

    # Then check git if available
    if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
        git rev-parse --abbrev-ref HEAD
        return
    fi

    # For non-git repos, try to find the latest feature directory
    local repo_root=$(get_repo_root)
    local specs_dir="$repo_root/specs"

    if [[ -d "$specs_dir" ]]; then
        local latest_feature=""
        local highest=0

        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                if [[ "$dirname" =~ ^([0-9]{3})- ]]; then
                    local number=${BASH_REMATCH[1]}
                    number=$((10#$number))
                    if [[ "$number" -gt "$highest" ]]; then
                        highest=$number
                        latest_feature=$dirname
                    fi
                fi
            fi
        done

        if [[ -n "$latest_feature" ]]; then
            echo "$latest_feature"
            return
        fi
    fi

    echo "main"  # Final fallback
}

# Check if we have git available
has_git() {
    git rev-parse --show-toplevel >/dev/null 2>&1
}

check_feature_branch() {
    local branch="$1"
    local has_git_repo="$2"

    # For non-git repos, we can't enforce branch naming but still provide output
    if [[ "$has_git_repo" != "true" ]]; then
        echo "[specify] Warning: Git repository not detected; skipped branch validation" >&2
        return 0
    fi

    if [[ ! "$branch" =~ ^[0-9]{3}- ]]; then
        echo "ERROR: Not on a feature branch. Current branch: $branch" >&2
        echo "Feature branches should be named like: 001-feature-name" >&2
        return 1
    fi

    return 0
}

get_feature_dir() { echo "$1/specs/$2"; }

# Find feature directory by numeric prefix instead of exact branch match
# This allows multiple branches to work on the same spec (e.g., 004-fix-bug, 004-add-feature)
find_feature_dir_by_prefix() {
    local repo_root="$1"
    local branch_name="$2"
    local specs_dir="$repo_root/specs"

    # Extract numeric prefix from branch (e.g., "004" from "004-whatever")
    if [[ ! "$branch_name" =~ ^([0-9]{3})- ]]; then
        # If branch doesn't have numeric prefix, fall back to exact match
        echo "$specs_dir/$branch_name"
        return
    fi

    local prefix="${BASH_REMATCH[1]}"

    # Search for directories in specs/ that start with this prefix
    local matches=()
    if [[ -d "$specs_dir" ]]; then
        for dir in "$specs_dir"/"$prefix"-*; do
            if [[ -d "$dir" ]]; then
                matches+=("$(basename "$dir")")
            fi
        done
    fi

    # Handle results
    if [[ ${#matches[@]} -eq 0 ]]; then
        # No match found - return the branch name path (will fail later with clear error)
        echo "$specs_dir/$branch_name"
    elif [[ ${#matches[@]} -eq 1 ]]; then
        # Exactly one match - perfect!
        echo "$specs_dir/${matches[0]}"
    else
        # Multiple matches - this shouldn't happen with proper naming convention
        echo "ERROR: Multiple spec directories found with prefix '$prefix': ${matches[*]}" >&2
        echo "Please ensure only one spec directory exists per numeric prefix." >&2
        echo "$specs_dir/$branch_name"  # Return something to avoid breaking the script
    fi
}

get_feature_paths() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)
    local has_git_repo="false"

    if has_git; then
        has_git_repo="true"
    fi

    # Use prefix-based lookup to support multiple branches per spec
    local feature_dir=$(find_feature_dir_by_prefix "$repo_root" "$current_branch")

    cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_BRANCH='$current_branch'
HAS_GIT='$has_git_repo'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
TASKS_DIR='$feature_dir/tasks'
INDEX='$feature_dir/index.md'
TRACEABILITY='$feature_dir/traceability.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
EOF
}

#==============================================================================
# Template Resolution Functions
#==============================================================================

resolve_template() {
    # Resolves template path, checking primary then legacy locations.
    # Returns empty string if neither exists.
    local template_name="$1"
    local repo_root
    repo_root=$(get_repo_root)

    local primary_path="$repo_root/templates/$template_name"
    local legacy_path="$repo_root/.specify/templates/$template_name"

    if [[ -f "$primary_path" ]]; then
        echo "$primary_path"
    elif [[ -f "$legacy_path" ]]; then
        echo "$legacy_path"
    else
        echo ""
    fi
}

copy_template_with_guard() {
    # Safely copies a template to target, with fail-safe guards.
    #
    # BEHAVIOR:
    # - NEVER overwrites a file that has content with empty content
    # - If template found and target empty/missing: copies template
    # - If template found and target has content: warns, keeps existing
    # - If template missing and target has content: warns, keeps existing
    # - If template missing and target empty/missing: ERROR, returns 1
    #
    # Args:
    #   $1 - template_name (e.g., "plan-template.md")
    #   $2 - target_path (full path to target file)
    #   $3 - context (for error messages, e.g., "setup-plan")
    #
    # Returns: 0 on success (including skip), 1 on failure

    local template_name="$1"
    local target_path="$2"
    local context="$3"

    local template_path
    template_path=$(resolve_template "$template_name")

    local target_has_content=false
    if [[ -f "$target_path" && -s "$target_path" ]]; then
        target_has_content=true
    fi

    if [[ -n "$template_path" ]]; then
        if $target_has_content; then
            echo "WARNING: [$context] Target already has content at $target_path. Skipping template copy." >&2
            return 0  # Success - preserved existing
        fi
        cp "$template_path" "$target_path"
        echo "[$context] Copied template to $target_path"
        return 0
    else
        # Template not found
        if $target_has_content; then
            echo "WARNING: [$context] Template '$template_name' not found, but target has content. Keeping existing file." >&2
            return 0  # Success - preserved existing
        else
            echo "ERROR: [$context] Template '$template_name' not found at templates/ or .specify/templates/" >&2
            echo "ERROR: [$context] Cannot create $target_path without template. Aborting." >&2
            return 1  # Failure - would create empty file
        fi
    fi
}

#==============================================================================
# File/Directory Check Functions
#==============================================================================

check_file() { [[ -f "$1" ]] && echo "  ✓ $2" || echo "  ✗ $2"; }
check_dir() { [[ -d "$1" && -n $(ls -A "$1" 2>/dev/null) ]] && echo "  ✓ $2" || echo "  ✗ $2"; }

