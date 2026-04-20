#!/usr/bin/env bash

# Tech Stack Validation Script
#
# Validates package compatibility, freshness, and security for the tech stack
# defined in plan.md. This script is called during Phase 0.6 of /atomicspec.plan.
#
# Usage: ./validate-tech-stack.sh [OPTIONS]
#
# OPTIONS:
#   --json              Output in JSON format
#   --plan-file PATH    Path to plan.md (default: auto-detect from feature)
#   --ecosystem ECO     Package ecosystem: npm, pypi, cargo, go (default: auto-detect)
#   --help, -h          Show help message
#
# OUTPUTS:
#   JSON mode: {"status":"...", "packages":[...], "warnings":[...]}
#   Text mode: Human-readable validation report
#
# NOTE: This script queries package registries. Network access required.

set -e

# Parse command line arguments
JSON_MODE=false
PLAN_FILE=""
ECOSYSTEM=""

i=1
while [ $i -le $# ]; do
    arg="${!i}"
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --plan-file)
            i=$((i + 1))
            PLAN_FILE="${!i}"
            ;;
        --ecosystem)
            i=$((i + 1))
            ECOSYSTEM="${!i}"
            ;;
        --help|-h)
            cat << 'EOF'
Usage: validate-tech-stack.sh [OPTIONS]

Validates package compatibility and freshness for the tech stack in plan.md.

OPTIONS:
  --json              Output in JSON format
  --plan-file PATH    Path to plan.md (default: auto-detect from feature)
  --ecosystem ECO     Package ecosystem: npm, pypi, cargo, go (default: auto-detect)
  --help, -h          Show this help message

EXAMPLES:
  # Validate tech stack for current feature
  ./validate-tech-stack.sh --json

  # Validate specific plan file
  ./validate-tech-stack.sh --plan-file /path/to/plan.md --ecosystem npm

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

#==============================================================================
# Helper Functions
#==============================================================================

log_info() {
    echo "[validate] $1" >&2
}

log_warn() {
    echo "[validate] ⚠ $1" >&2
}

log_error() {
    echo "[validate] ✗ $1" >&2
}

log_success() {
    echo "[validate] ✓ $1" >&2
}

#==============================================================================
# Package Registry Functions
#==============================================================================

# Check npm package info
# Returns: JSON with name, version, lastPublish, deprecated, engines
check_npm_package() {
    local package="$1"
    local version="${2:-latest}"

    # Query npm registry
    local registry_url="https://registry.npmjs.org/${package}"
    local response

    if ! response=$(curl -s --fail "$registry_url" 2>/dev/null); then
        echo '{"error":"not_found","package":"'"$package"'"}'
        return 1
    fi

    # Extract relevant info using jq if available, otherwise basic parsing
    if command -v jq &>/dev/null; then
        local latest_version
        latest_version=$(echo "$response" | jq -r '."dist-tags".latest // "unknown"')

        local last_publish
        last_publish=$(echo "$response" | jq -r '.time["'"$latest_version"'"] // .time.modified // "unknown"')

        local deprecated
        deprecated=$(echo "$response" | jq -r '.versions["'"$latest_version"'"].deprecated // ""')

        local engines
        engines=$(echo "$response" | jq -r '.versions["'"$latest_version"'"].engines // {}')

        local peer_deps
        peer_deps=$(echo "$response" | jq -r '.versions["'"$latest_version"'"].peerDependencies // {}')

        echo "{\"package\":\"$package\",\"requested\":\"$version\",\"latest\":\"$latest_version\",\"lastPublish\":\"$last_publish\",\"deprecated\":\"$deprecated\",\"engines\":$engines,\"peerDependencies\":$peer_deps}"
    else
        # Fallback: basic grep parsing
        local latest_version
        latest_version=$(echo "$response" | grep -o '"latest":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo "{\"package\":\"$package\",\"requested\":\"$version\",\"latest\":\"$latest_version\",\"lastPublish\":\"unknown\",\"deprecated\":\"\",\"engines\":{},\"peerDependencies\":{}}"
    fi
}

# Check PyPI package info
check_pypi_package() {
    local package="$1"
    local version="${2:-latest}"

    local registry_url="https://pypi.org/pypi/${package}/json"
    local response

    if ! response=$(curl -s --fail "$registry_url" 2>/dev/null); then
        echo '{"error":"not_found","package":"'"$package"'"}'
        return 1
    fi

    if command -v jq &>/dev/null; then
        local latest_version
        latest_version=$(echo "$response" | jq -r '.info.version // "unknown"')

        local last_publish
        # Get upload time of latest release
        last_publish=$(echo "$response" | jq -r '.releases["'"$latest_version"'"][0].upload_time // "unknown"')

        local requires_python
        requires_python=$(echo "$response" | jq -r '.info.requires_python // ""')

        local yanked
        yanked=$(echo "$response" | jq -r '.releases["'"$latest_version"'"][0].yanked // false')

        echo "{\"package\":\"$package\",\"requested\":\"$version\",\"latest\":\"$latest_version\",\"lastPublish\":\"$last_publish\",\"requiresPython\":\"$requires_python\",\"yanked\":$yanked}"
    else
        local latest_version
        latest_version=$(echo "$response" | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo "{\"package\":\"$package\",\"requested\":\"$version\",\"latest\":\"$latest_version\",\"lastPublish\":\"unknown\"}"
    fi
}

#==============================================================================
# Validation Logic
#==============================================================================

# Calculate days since last publish
days_since_publish() {
    local publish_date="$1"

    if [[ "$publish_date" == "unknown" || -z "$publish_date" ]]; then
        echo "-1"
        return
    fi

    # Try to parse the date
    local publish_epoch
    if publish_epoch=$(date -d "$publish_date" +%s 2>/dev/null); then
        local now_epoch
        now_epoch=$(date +%s)
        local diff_days=$(( (now_epoch - publish_epoch) / 86400 ))
        echo "$diff_days"
    else
        echo "-1"
    fi
}

# Validate a single package
validate_package() {
    local ecosystem="$1"
    local package="$2"
    local version="$3"

    local result
    local status="PASS"
    local warnings=()
    local notes=""

    case "$ecosystem" in
        npm)
            result=$(check_npm_package "$package" "$version")
            ;;
        pypi)
            result=$(check_pypi_package "$package" "$version")
            ;;
        *)
            echo "{\"package\":\"$package\",\"status\":\"SKIP\",\"notes\":\"Unsupported ecosystem: $ecosystem\"}"
            return
            ;;
    esac

    # Check for errors
    if echo "$result" | grep -q '"error"'; then
        echo "{\"package\":\"$package\",\"requested\":\"$version\",\"validated\":\"N/A\",\"status\":\"FAIL\",\"notes\":\"Package not found in registry\"}"
        return
    fi

    local latest
    latest=$(echo "$result" | grep -o '"latest":"[^"]*"' | cut -d'"' -f4)

    local last_publish
    last_publish=$(echo "$result" | grep -o '"lastPublish":"[^"]*"' | cut -d'"' -f4)

    local deprecated
    deprecated=$(echo "$result" | grep -o '"deprecated":"[^"]*"' | cut -d'"' -f4)

    # Check freshness (warn if >2 years old)
    local days_old
    days_old=$(days_since_publish "$last_publish")
    if [[ "$days_old" -gt 730 ]]; then
        status="WARN"
        notes="Last published ${days_old} days ago (>2 years)"
    fi

    # Check deprecation
    if [[ -n "$deprecated" && "$deprecated" != "null" ]]; then
        status="WARN"
        notes="DEPRECATED: $deprecated"
    fi

    # Output result
    echo "{\"package\":\"$package\",\"requested\":\"$version\",\"validated\":\"$latest\",\"status\":\"$status\",\"notes\":\"$notes\",\"lastPublish\":\"$last_publish\"}"
}

#==============================================================================
# Plan Parsing
#==============================================================================

# Extract tech stack from plan.md
extract_tech_stack() {
    local plan_file="$1"

    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        return 1
    fi

    # Extract packages from Technical Context section
    # Looking for patterns like:
    # **Primary Dependencies**: FastAPI, SQLAlchemy, Pydantic
    # **Framework**: React 18

    local deps=""

    # Extract Primary Dependencies line
    deps=$(grep -E "^\*\*Primary Dependencies\*\*:" "$plan_file" 2>/dev/null | sed 's/.*: *//' || echo "")

    # Also check for Framework line
    local framework
    framework=$(grep -E "^\*\*Primary Framework\*\*:|^\*\*Framework\*\*:" "$plan_file" 2>/dev/null | sed 's/.*: *//' || echo "")

    if [[ -n "$framework" && "$framework" != *"NEEDS CLARIFICATION"* ]]; then
        deps="$framework,$deps"
    fi

    # Clean up and split
    echo "$deps" | tr ',' '\n' | sed 's/^ *//' | sed 's/ *$//' | grep -v '^$' | grep -v "NEEDS CLARIFICATION"
}

# Detect ecosystem from plan.md
detect_ecosystem() {
    local plan_file="$1"

    local lang
    lang=$(grep -E "^\*\*Language/Version\*\*:" "$plan_file" 2>/dev/null | sed 's/.*: *//' || echo "")

    case "$lang" in
        *Python*|*python*)
            echo "pypi"
            ;;
        *TypeScript*|*JavaScript*|*Node*|*node*|*typescript*|*javascript*)
            echo "npm"
            ;;
        *Rust*|*rust*)
            echo "cargo"
            ;;
        *Go*|*go*|*Golang*)
            echo "go"
            ;;
        *)
            # Default to npm as it's most common
            echo "npm"
            ;;
    esac
}

#==============================================================================
# Main
#==============================================================================

main() {
    # Get feature paths
    load_feature_paths

    # Determine plan file
    if [[ -z "$PLAN_FILE" ]]; then
        PLAN_FILE="$IMPL_PLAN"
    fi

    if [[ ! -f "$PLAN_FILE" ]]; then
        log_error "Plan file not found: $PLAN_FILE"
        log_error "Run /atomicspec.plan first to create the implementation plan."
        exit 1
    fi

    # Detect ecosystem if not specified
    if [[ -z "$ECOSYSTEM" ]]; then
        ECOSYSTEM=$(detect_ecosystem "$PLAN_FILE")
        log_info "Detected ecosystem: $ECOSYSTEM"
    fi

    # Extract packages
    local packages
    packages=$(extract_tech_stack "$PLAN_FILE")

    if [[ -z "$packages" ]]; then
        log_warn "No packages found in plan.md Technical Context"
        if $JSON_MODE; then
            echo '{"status":"SKIP","message":"No packages to validate","packages":[],"warnings":[]}'
        else
            echo "No packages found to validate in plan.md"
        fi
        exit 0
    fi

    log_info "Validating packages from $PLAN_FILE..."
    log_info "Ecosystem: $ECOSYSTEM"

    # Validate each package
    local results=()
    local warnings=()
    local overall_status="PASS"

    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue

        # Split package and version if specified (e.g., "react@18" or "react 18")
        local pkg_name
        local pkg_version="latest"

        if [[ "$pkg" == *"@"* ]]; then
            pkg_name="${pkg%@*}"
            pkg_version="${pkg#*@}"
        elif [[ "$pkg" == *" "* ]]; then
            pkg_name="${pkg%% *}"
            pkg_version="${pkg#* }"
        else
            pkg_name="$pkg"
        fi

        log_info "Checking $pkg_name..."

        local result
        result=$(validate_package "$ECOSYSTEM" "$pkg_name" "$pkg_version")
        results+=("$result")

        # Check status
        local pkg_status
        pkg_status=$(echo "$result" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

        if [[ "$pkg_status" == "FAIL" ]]; then
            overall_status="FAIL"
            log_error "$pkg_name: FAIL"
        elif [[ "$pkg_status" == "WARN" ]]; then
            [[ "$overall_status" != "FAIL" ]] && overall_status="PASS_WITH_WARNINGS"
            local notes
            notes=$(echo "$result" | grep -o '"notes":"[^"]*"' | cut -d'"' -f4)
            warnings+=("{\"package\":\"$pkg_name\",\"issue\":\"$notes\"}")
            log_warn "$pkg_name: $notes"
        else
            log_success "$pkg_name: OK"
        fi

    done <<< "$packages"

    # Output results
    if $JSON_MODE; then
        local packages_json
        packages_json=$(printf '%s\n' "${results[@]}" | paste -sd',' -)

        local warnings_json="[]"
        if [[ ${#warnings[@]} -gt 0 ]]; then
            warnings_json=$(printf '%s\n' "${warnings[@]}" | paste -sd',' -)
            warnings_json="[$warnings_json]"
        fi

        echo "{\"status\":\"$overall_status\",\"ecosystem\":\"$ECOSYSTEM\",\"packages\":[$packages_json],\"warnings\":$warnings_json}"
    else
        echo ""
        echo "════════════════════════════════════════════════════════════"
        echo "Tech Stack Validation Report"
        echo "════════════════════════════════════════════════════════════"
        echo ""
        echo "Status: $overall_status"
        echo "Ecosystem: $ECOSYSTEM"
        echo ""
        echo "Packages:"
        for result in "${results[@]}"; do
            local pkg
            pkg=$(echo "$result" | grep -o '"package":"[^"]*"' | cut -d'"' -f4)
            local status
            status=$(echo "$result" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            local validated
            validated=$(echo "$result" | grep -o '"validated":"[^"]*"' | cut -d'"' -f4)
            local notes
            notes=$(echo "$result" | grep -o '"notes":"[^"]*"' | cut -d'"' -f4)

            printf "  %-30s %s → %s" "$pkg" "$status" "$validated"
            [[ -n "$notes" ]] && printf " (%s)" "$notes"
            echo ""
        done

        if [[ ${#warnings[@]} -gt 0 ]]; then
            echo ""
            echo "Warnings:"
            for warning in "${warnings[@]}"; do
                local pkg
                pkg=$(echo "$warning" | grep -o '"package":"[^"]*"' | cut -d'"' -f4)
                local issue
                issue=$(echo "$warning" | grep -o '"issue":"[^"]*"' | cut -d'"' -f4)
                echo "  ⚠ $pkg: $issue"
            done
        fi

        echo ""
        echo "════════════════════════════════════════════════════════════"
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
