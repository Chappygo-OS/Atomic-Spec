#!/usr/bin/env bash
#
# stamp-lifecycle (v0.3+) — write and inspect Lifecycle Markers blocks
#
# Deterministic, scripted gate for Atomic Spec's cross-provider AI handoff
# (Article IX, Directive 9 — Orientation Read Surface). AIs MUST NOT write
# stamps by hand. All authoring/implementation lifecycle events go through
# this script so that timestamps, provider names, and block format stay
# uniform across providers (Claude / Codex / Gemini / Cursor / etc.).
#
# USAGE
#   stamp-lifecycle.sh init    <artifact-path> --lifecycle <authoring|both>
#   stamp-lifecycle.sh start   <artifact-path> --lifecycle <authoring|implementation> \
#                              --provider <name> [--model <m>] [--verify-depth <light|deep>]
#   stamp-lifecycle.sh end     <artifact-path> --lifecycle <authoring|implementation> \
#                              --provider <name> [--model <m>]
#   stamp-lifecycle.sh status  <artifact-path> [--json]
#
# GLOBAL FLAGS
#   --force    Overwrite an already-populated field (humans only; never from templates)
#   --quiet    Suppress non-error output
#   --help     Show this help
#
# EXIT CODES
#   0   Success
#   2   Usage error (bad flags, unknown subcommand, missing required flag)
#   3   Artifact path does not exist or is not a file
#   4   Lifecycle Markers block missing or malformed (start/end on uninitialised artifact)
#   5   Provider not in allowlist
#   6   Field already populated and --force not set
#   7   end called without matching start for that lifecycle
#   8   implementation lifecycle requested on artifact that doesn't support it
#
# PROVIDER ALLOWLIST
#   claude, gpt, gemini, cursor, copilot, codex, windsurf, qwen, opencode,
#   kilocode, auggie, shai, q, bob, qoder, roo, amp, legacy
#
# TIMESTAMP FORMAT
#   ISO 8601 UTC, second precision: 2026-06-19T22:14:03Z
#

set -euo pipefail

readonly SCRIPT_VERSION="v0.3.0"
readonly PROVIDER_ALLOWLIST=(claude gpt gemini cursor copilot codex windsurf qwen opencode kilocode auggie shai q bob qoder roo amp legacy)
readonly BLOCK_HEADING="## Lifecycle Markers"

# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
QUIET="${QUIET:-0}"
log_info()  { [[ "$QUIET" == "1" ]] || printf '%s\n' "$*" >&2; }
log_error() { printf 'ERROR: %s\n' "$*" >&2; }

# ----------------------------------------------------------------------------
# Portable ISO 8601 UTC timestamp (works on BSD and GNU date)
# ----------------------------------------------------------------------------
timestamp_utc() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ----------------------------------------------------------------------------
# Provider/model normalization
# ----------------------------------------------------------------------------
sanitize_model() {
    local raw="$1"
    # SECURITY: strip newlines and carriage returns FIRST so a multi-line
    # --model value cannot forge additional stamp lines via the awk write.
    # Then lowercase, replace non-[a-z0-9.-] runs with single hyphen, trim,
    # cap at 40 chars.
    local s
    s="$(printf '%s' "$raw" | tr -d '\n\r' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9.-]+/-/g; s/^-+//; s/-+$//')"
    if [[ ${#s} -gt 40 ]]; then
        s="${s:0:40}"
        # Re-trim trailing hyphens after cut.
        s="${s%-}"
    fi
    printf '%s' "$s"
}

validate_provider() {
    # Echoes the resolved provider (possibly substituted from
    # ATOMICSPEC_PROVIDER if --provider was the unresolved {{AGENT_NAME}}
    # placeholder). Callers MUST capture: provider="$(validate_provider "$provider")"
    # Bash passes by value, so without echo-capture the caller's variable
    # stays unresolved even after substitution here.
    local provider="$1"
    if [[ "$provider" == "{{AGENT_NAME}}" ]]; then
        if [[ -n "${ATOMICSPEC_PROVIDER:-}" ]]; then
            log_info "[warn] {{AGENT_NAME}} placeholder leaked; using ATOMICSPEC_PROVIDER=${ATOMICSPEC_PROVIDER}"
            provider="$ATOMICSPEC_PROVIDER"
        else
            log_error "Provider is unresolved {{AGENT_NAME}} placeholder and ATOMICSPEC_PROVIDER env var is not set. Run init-project.{sh,ps1} to substitute the placeholder, OR export ATOMICSPEC_PROVIDER=<your-agent>."
            exit 5
        fi
    fi
    local p
    for p in "${PROVIDER_ALLOWLIST[@]}"; do
        if [[ "$provider" == "$p" ]]; then
            printf '%s' "$provider"
            return 0
        fi
    done
    log_error "Provider '$provider' not in allowlist. Allowed: ${PROVIDER_ALLOWLIST[*]}"
    exit 5
}

compose_actor() {
    local provider="$1"
    local model="${2:-}"
    if [[ -z "$model" ]]; then
        printf '%s' "$provider"
    else
        printf '%s:%s' "$provider" "$model"
    fi
}

# ----------------------------------------------------------------------------
# Block detection and parsing
# ----------------------------------------------------------------------------

# Find the byte range (line numbers) of the Lifecycle Markers block.
# Echoes "START_LINE END_LINE" or empty string if block not present.
# Block matches heading at any depth (H2-H6) to support clarify-log session blocks.
find_block_lines() {
    local file="$1"
    awk '
        BEGIN { start = 0; end = 0; in_block = 0 }
        /^#{2,6}[[:space:]]+Lifecycle Markers[[:space:]]*$/ {
            if (in_block) { end = NR - 1; printf "%d %d\n", start, end; exit }
            start = NR; in_block = 1; next
        }
        in_block && /^#{1,6}[[:space:]]/ {
            end = NR - 1; printf "%d %d\n", start, end; exit
        }
        END { if (in_block && end == 0) printf "%d %d\n", start, NR }
    ' "$file"
}

# Extract one stamp field value from the file.
# Echoes the raw value (everything after `key: `) or empty if field absent.
get_field() {
    local file="$1"
    local field="$2"
    local range
    range="$(find_block_lines "$file")"
    [[ -z "$range" ]] && return 1
    local start_line=${range%% *}
    local end_line=${range##* }
    sed -n "${start_line},${end_line}p" "$file" \
        | sed -nE "s/^-[[:space:]]+${field}:[[:space:]]+(.+)$/\1/p" \
        | head -n1
}

# Is the field's value treated as "set" (i.e., not <empty>)?
field_is_set() {
    local value="$1"
    [[ -n "$value" && "$value" != "<empty>" ]]
}

# ----------------------------------------------------------------------------
# Atomic write helpers
# ----------------------------------------------------------------------------
atomic_write() {
    local file="$1"
    local content="$2"
    local tmp="${file}.tmp-stamp-$$"
    printf '%s' "$content" > "$tmp"
    mv "$tmp" "$file"
}

# ----------------------------------------------------------------------------
# Subcommand: init
# ----------------------------------------------------------------------------
cmd_init() {
    local file="$1"
    local lifecycle="${2:-authoring}"  # authoring | both
    local closed_provider="${3:-}"     # if non-empty, init in CLOSED state
    local closed_model="${4:-}"
    local closed_verify_depth="${5:-}"

    [[ -f "$file" ]] || { log_error "Artifact not found: $file"; exit 3; }

    local range
    range="$(find_block_lines "$file")"

    if [[ -z "$range" ]]; then
        log_error "Lifecycle Markers heading not found in $file. Templates should pre-include the heading; check templates/."
        exit 4
    fi

    local end_line=${range##* }

    # Check if stamp lines already exist within the block.
    local existing
    existing="$(get_field "$file" 'Authored start' || true)"
    if [[ -n "$existing" ]]; then
        log_info "Lifecycle Markers already initialized in $file (Authored start present)."
        return 0
    fi

    # Closed-init mode: synchronous authoring (start + end in one atomic write).
    # Used when authoring completes within a single command run (no resume risk
    # to detect). E.g., /atomicspec.tasks stamps 100 task files at once.
    local closed_value="<empty>"
    if [[ -n "$closed_provider" ]]; then
        closed_provider="$(validate_provider "$closed_provider")"
        local closed_actor closed_ts
        closed_actor="$(compose_actor "$closed_provider" "$(sanitize_model "$closed_model")")"
        closed_ts="$(timestamp_utc)"
        closed_value="$closed_ts by $closed_actor"
    fi

    # Build the stamp lines based on lifecycle scope.
    local lines=""
    lines+="- Authored start:        ${closed_value}"$'\n'
    lines+="- Authored end:          ${closed_value}"$'\n'
    if [[ "$lifecycle" == "both" ]]; then
        lines+="- Implementation start:  <empty>"$'\n'
        lines+="- Implementation end:    <empty>"$'\n'
        if [[ -n "$closed_verify_depth" ]]; then
            lines+="- verify-depth:          ${closed_verify_depth}"$'\n'
        else
            lines+="- verify-depth:          <empty>"$'\n'
        fi
    fi

    # Insert lines at the end of the block (just before the next heading or EOF).
    local before after
    before="$(head -n "$end_line" "$file")"
    after="$(tail -n +"$((end_line + 1))" "$file")"

    local new_content
    if [[ -n "$after" ]]; then
        new_content="${before}"$'\n'"${lines}"$'\n'"${after}"
    else
        new_content="${before}"$'\n'"${lines}"
    fi

    atomic_write "$file" "$new_content"
    log_info "Initialized Lifecycle Markers in $file (lifecycle=$lifecycle)."
}

# ----------------------------------------------------------------------------
# Subcommand: start | end (shared logic)
# ----------------------------------------------------------------------------
cmd_stamp() {
    local action="$1"        # start | end
    local file="$2"
    local lifecycle="$3"     # authoring | implementation
    local provider="$4"
    local model="${5:-}"
    local verify_depth="${6:-}"
    local force="${7:-0}"

    [[ -f "$file" ]] || { log_error "Artifact not found: $file"; exit 3; }
    provider="$(validate_provider "$provider")"

    # Reject implementation lifecycle on artifacts that don't support it.
    if [[ "$lifecycle" == "implementation" ]]; then
        local basename
        basename="$(basename "$file")"
        # Only task files and traceability.md support implementation lifecycle.
        if [[ ! "$basename" =~ ^T-[0-9]+ ]] && [[ "$basename" != "traceability.md" ]]; then
            log_error "Implementation lifecycle is not valid for $basename (only T-*.md and traceability.md)"
            exit 8
        fi
    fi

    local range
    range="$(find_block_lines "$file")"
    if [[ -z "$range" ]]; then
        log_error "Lifecycle Markers block missing in $file. Run 'stamp-lifecycle init' first."
        exit 4
    fi

    # Determine field name.
    local field
    if [[ "$lifecycle" == "authoring" && "$action" == "start" ]]; then field="Authored start"
    elif [[ "$lifecycle" == "authoring" && "$action" == "end" ]]; then field="Authored end"
    elif [[ "$lifecycle" == "implementation" && "$action" == "start" ]]; then field="Implementation start"
    elif [[ "$lifecycle" == "implementation" && "$action" == "end" ]]; then field="Implementation end"
    else
        log_error "Invalid action/lifecycle combination: $action/$lifecycle"
        exit 2
    fi

    # Pre-check: field already set?
    local current
    current="$(get_field "$file" "$field" || true)"
    if field_is_set "$current" && [[ "$force" != "1" ]]; then
        log_error "Field '$field' already populated in $file: $current. Use --force to overwrite."
        exit 6
    fi

    # Sequencing checks:
    # - end requires matching start
    # - implementation requires authoring end (artifact must be authored before impl starts)
    if [[ "$action" == "end" ]]; then
        local matching_start
        matching_start="$(get_field "$file" "${field% *} start" || true)"
        # field is "Authored end" or "Implementation end"; matching start is "Authored start" / "Implementation start"
        case "$field" in
            "Authored end") matching_start="$(get_field "$file" 'Authored start' || true)" ;;
            "Implementation end") matching_start="$(get_field "$file" 'Implementation start' || true)" ;;
        esac
        if ! field_is_set "$matching_start"; then
            log_error "Cannot write '$field' — matching start stamp is missing in $file."
            exit 7
        fi
    fi
    if [[ "$lifecycle" == "implementation" && "$action" == "start" ]]; then
        local auth_end
        auth_end="$(get_field "$file" 'Authored end' || true)"
        if ! field_is_set "$auth_end"; then
            log_error "Cannot start implementation on $file — authoring is not complete (Authored end is missing)."
            exit 7
        fi
    fi

    # Compose the value.
    local actor ts new_value
    actor="$(compose_actor "$provider" "$(sanitize_model "$model")")"
    ts="$(timestamp_utc)"
    new_value="$ts by $actor"

    # Rewrite the matching line via awk. CORRECTNESS: track whether the field
    # row was actually matched; exit non-zero if not, to avoid silently logging
    # "Stamped <field>" while leaving the file unchanged. Brings bash to parity
    # with PowerShell's Set-FieldValue which errors on missing field row.
    local start_line=${range%% *}
    local end_line=${range##* }
    local tmp="${file}.tmp-stamp-$$"

    if ! awk -v sl="$start_line" -v el="$end_line" -v fld="$field" -v val="$new_value" '
        BEGIN { found = 0 }
        NR >= sl && NR <= el {
            if (match($0, "^- " fld ":[[:space:]]+")) {
                # Preserve column alignment (use the matched prefix length to indent value).
                prefix_len = RLENGTH
                prefix = substr($0, 1, prefix_len)
                print prefix val
                found = 1
                next
            }
        }
        { print }
        END { exit (found ? 0 : 1) }
    ' "$file" > "$tmp"; then
        rm -f "$tmp"
        log_error "Field '$field' row not present in Lifecycle Markers block in $file. Run 'stamp-lifecycle init' with --lifecycle both if you need implementation lifecycle."
        exit 4
    fi
    mv "$tmp" "$file"

    # Optionally set verify-depth on a start stamp (authoring side, when --verify-depth was provided).
    if [[ "$action" == "start" && "$lifecycle" == "authoring" && -n "$verify_depth" ]]; then
        if [[ "$verify_depth" != "light" && "$verify_depth" != "deep" ]]; then
            log_error "Invalid --verify-depth value: $verify_depth (must be light or deep)"
            exit 2
        fi
        # Only set if the field exists in the block (both-lifecycle artifacts only).
        local vd_current
        vd_current="$(get_field "$file" 'verify-depth' || true)"
        if [[ -n "$vd_current" ]]; then
            local tmp2="${file}.tmp-stamp-$$"
            awk -v sl="$start_line" -v el="$end_line" -v val="$verify_depth" '
                NR >= sl && NR <= el {
                    if (match($0, "^- verify-depth:[[:space:]]+")) {
                        prefix_len = RLENGTH
                        prefix = substr($0, 1, prefix_len)
                        print prefix val
                        next
                    }
                }
                { print }
            ' "$file" > "$tmp2"
            mv "$tmp2" "$file"
        fi
    fi

    log_info "Stamped $field on $file: $new_value"
}

# ----------------------------------------------------------------------------
# Subcommand: status
# ----------------------------------------------------------------------------
cmd_status() {
    local file="$1"
    local json="${2:-0}"

    [[ -f "$file" ]] || { log_error "Artifact not found: $file"; exit 3; }

    local range
    range="$(find_block_lines "$file")"

    if [[ -z "$range" ]]; then
        # Legacy artifact (no block at all).
        if [[ "$json" == "1" ]]; then
            printf '{"artifact":"%s","has_block":false,"legacy":true,"state":"legacy_closed"}\n' "$file"
        else
            log_info "$file: legacy_closed (no Lifecycle Markers block — pre-v0.3 artifact)"
        fi
        return 0
    fi

    local auth_start auth_end impl_start impl_end vd
    auth_start="$(get_field "$file" 'Authored start' || true)"
    auth_end="$(get_field "$file" 'Authored end' || true)"
    impl_start="$(get_field "$file" 'Implementation start' || true)"
    impl_end="$(get_field "$file" 'Implementation end' || true)"
    vd="$(get_field "$file" 'verify-depth' || true)"

    # Determine state.
    local state
    if ! field_is_set "$auth_start"; then
        state="empty"
    elif ! field_is_set "$auth_end"; then
        state="authoring_in_progress"
    elif [[ -z "$impl_start" ]]; then
        # No implementation lifecycle on this artifact at all.
        state="authored"
    elif ! field_is_set "$impl_start"; then
        state="authored"
    elif ! field_is_set "$impl_end"; then
        state="implementing"
    else
        state="done"
    fi

    if [[ "$json" == "1" ]]; then
        # Emit single-line JSON.
        emit_json_field() {
            local v="$1"
            if field_is_set "$v"; then
                # Split "<ts> by <provider>" into ts + by.
                local ts="${v% by *}"
                local by="${v##* by }"
                printf '"start":"%s","start_by":"%s"' "$ts" "$by"
            else
                printf '"start":null,"start_by":null'
            fi
        }
        # Build authoring object.
        local auth_json impl_json vd_json
        auth_json="{"
        if field_is_set "$auth_start"; then
            auth_json+="\"start\":\"${auth_start% by *}\",\"start_by\":\"${auth_start##* by }\""
        else
            auth_json+="\"start\":null,\"start_by\":null"
        fi
        auth_json+=","
        if field_is_set "$auth_end"; then
            auth_json+="\"end\":\"${auth_end% by *}\",\"end_by\":\"${auth_end##* by }\""
        else
            auth_json+="\"end\":null,\"end_by\":null"
        fi
        auth_json+="}"

        if [[ -n "$impl_start" || -n "$impl_end" ]]; then
            impl_json="{"
            if field_is_set "$impl_start"; then
                impl_json+="\"start\":\"${impl_start% by *}\",\"start_by\":\"${impl_start##* by }\""
            else
                impl_json+="\"start\":null,\"start_by\":null"
            fi
            impl_json+=","
            if field_is_set "$impl_end"; then
                impl_json+="\"end\":\"${impl_end% by *}\",\"end_by\":\"${impl_end##* by }\""
            else
                impl_json+="\"end\":null,\"end_by\":null"
            fi
            impl_json+="}"
        else
            impl_json="null"
        fi

        if field_is_set "$vd"; then
            vd_json="\"$vd\""
        else
            vd_json="null"
        fi

        printf '{"artifact":"%s","has_block":true,"legacy":false,"state":"%s","authoring":%s,"implementation":%s,"verify_depth":%s}\n' \
            "$file" "$state" "$auth_json" "$impl_json" "$vd_json"
    else
        log_info "$file: state=$state"
        log_info "  Authored start:        ${auth_start:-<unset>}"
        log_info "  Authored end:          ${auth_end:-<unset>}"
        if [[ -n "$impl_start" || -n "$impl_end" ]]; then
            log_info "  Implementation start:  ${impl_start:-<unset>}"
            log_info "  Implementation end:    ${impl_end:-<unset>}"
        fi
        if field_is_set "$vd"; then
            log_info "  verify-depth:          $vd"
        fi
    fi
    return 0
}

# ----------------------------------------------------------------------------
# Help
# ----------------------------------------------------------------------------
show_help() {
    sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \?//'
}

# ----------------------------------------------------------------------------
# Main argument dispatch
# ----------------------------------------------------------------------------
main() {
    [[ $# -lt 1 ]] && { show_help; exit 2; }

    local subcommand="$1"
    shift

    case "$subcommand" in
        -h|--help|help) show_help; exit 0 ;;
        --version) printf '%s\n' "$SCRIPT_VERSION"; exit 0 ;;
    esac

    [[ $# -lt 1 ]] && { log_error "Missing artifact path"; show_help; exit 2; }
    local artifact="$1"
    shift

    local lifecycle="" provider="" model="" verify_depth="" force="0" json="0" closed="0"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lifecycle)     lifecycle="$2"; shift 2 ;;
            --provider)      provider="$2"; shift 2 ;;
            --model)         model="$2"; shift 2 ;;
            --verify-depth)  verify_depth="$2"; shift 2 ;;
            --closed)        closed="1"; shift ;;
            --force)         force="1"; shift ;;
            --quiet)         QUIET="1"; shift ;;
            --json)          json="1"; shift ;;
            *) log_error "Unknown flag: $1"; exit 2 ;;
        esac
    done

    case "$subcommand" in
        init)
            [[ -z "$lifecycle" ]] && lifecycle="authoring"
            [[ "$lifecycle" == "authoring" || "$lifecycle" == "both" ]] || {
                log_error "--lifecycle for 'init' must be 'authoring' or 'both' (got: $lifecycle)"; exit 2
            }
            if [[ "$closed" == "1" ]]; then
                [[ -z "$provider" ]] && { log_error "--closed requires --provider"; exit 2; }
                cmd_init "$artifact" "$lifecycle" "$provider" "$model" "$verify_depth"
            else
                cmd_init "$artifact" "$lifecycle"
            fi
            ;;
        start|end)
            [[ -z "$lifecycle" ]] && { log_error "--lifecycle is required for $subcommand"; exit 2; }
            [[ -z "$provider" ]] && { log_error "--provider is required for $subcommand"; exit 2; }
            [[ "$lifecycle" == "authoring" || "$lifecycle" == "implementation" ]] || {
                log_error "--lifecycle for '$subcommand' must be 'authoring' or 'implementation' (got: $lifecycle)"; exit 2
            }
            cmd_stamp "$subcommand" "$artifact" "$lifecycle" "$provider" "$model" "$verify_depth" "$force"
            ;;
        status)
            cmd_status "$artifact" "$json"
            ;;
        *)
            log_error "Unknown subcommand: $subcommand"; show_help; exit 2
            ;;
    esac
}

main "$@"
