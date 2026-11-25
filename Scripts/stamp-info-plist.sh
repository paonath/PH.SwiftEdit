#!/usr/bin/env bash
# ==============================================================================
# stamp-info-plist.sh
# Synchronizes CFBundleShortVersionString and CFBundleVersion in XcodeApp/Info.plist
# (and built bundle Info.plist when invoked from Xcode) from root version.json.
#
# Usage:
#   ./Scripts/stamp-info-plist.sh [--version-json <path>] [--info-plist <path>] [--dry-run] [--help]
#
# Exit Codes:
#   0 - Info.plist is already synchronized or was updated successfully
#   1 - Invalid arguments, missing files, or malformed version.json / Info.plist
# ==============================================================================
set -euo pipefail
IFS=$'\n\t'

print_help() {
    cat <<'EOF'
Usage: stamp-info-plist.sh [--version-json <path>] [--info-plist <path>] [--dry-run] [--help]

Options:
  --version-json <path>  Path to Nerdbank.GitVersioning version.json (default: <repo>/version.json)
  --info-plist <path>    Path to Info.plist (default: <repo>/XcodeApp/Info.plist)
  --dry-run              Print planned version updates without modifying Info.plist
  --help                 Display this help message and exit
EOF
}

stamp_single_plist() {
    local plist_path="$1"
    local short_ver="$2"
    local full_ver="$3"
    local dry_run="$4"

    [[ -f "$plist_path" ]] || {
        printf 'Error: Info.plist not found at %s\n' "$plist_path" >&2
        return 1
    }

    local current_short=""
    local current_full=""
    current_short="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist_path" 2>/dev/null || true)"
    current_full="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist_path" 2>/dev/null || true)"

    if [[ "$current_short" == "$short_ver" && "$current_full" == "$full_ver" ]]; then
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        printf '[dry-run] Would update %s: CFBundleShortVersionString=%s CFBundleVersion=%s\n' \
            "$plist_path" "$short_ver" "$full_ver"
        return 0
    fi

    if [[ -n "$current_short" ]]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $short_ver" "$plist_path"
    else
        /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $short_ver" "$plist_path"
    fi

    if [[ -n "$current_full" ]]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $full_ver" "$plist_path"
    else
        /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $full_ver" "$plist_path"
    fi
}

OPT_VERSION_JSON=""
OPT_INFO_PLIST=""
OPT_DRY_RUN="false"
CONSUMED_ARGS=1
RESOLVED_FULL_VERSION=""
RESOLVED_SHORT_VERSION=""

require_arg_value() {
    local flag="$1"
    local arg_count="$2"
    local hint="$3"
    if [[ "$arg_count" -lt 2 ]]; then
        printf 'Error: %s requires %s\n' "$flag" "$hint" >&2
        exit 1
    fi
}

apply_cli_option() {
    local flag="$1"
    local arg_count="$2"
    local next_val="${3:-}"
    CONSUMED_ARGS=1

    case "$flag" in
        --version-json)
            require_arg_value "--version-json" "$arg_count" "a path"
            OPT_VERSION_JSON="$next_val"
            CONSUMED_ARGS=2
            ;;
        --info-plist)
            require_arg_value "--info-plist" "$arg_count" "a path"
            OPT_INFO_PLIST="$next_val"
            CONSUMED_ARGS=2
            ;;
        --dry-run)
            OPT_DRY_RUN="true"
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            printf 'Error: Unknown argument: %s\n' "$flag" >&2
            exit 1
            ;;
    esac
}

parse_args() {
    local repo_root="$1"
    shift

    OPT_VERSION_JSON="${repo_root}/version.json"
    OPT_INFO_PLIST="${repo_root}/XcodeApp/Info.plist"
    OPT_DRY_RUN="false"

    while [[ $# -gt 0 ]]; do
        apply_cli_option "$1" "$#" "${2:-}"
        shift "$CONSUMED_ARGS"
    done
}

resolve_versions_from_json() {
    local version_json="$1"
    [[ -f "$version_json" ]] || {
        printf 'Error: version.json not found at %s\n' "$version_json" >&2
        exit 1
    }

    RESOLVED_FULL_VERSION="$(/usr/bin/plutil -extract version raw -o - "$version_json" | tr -d '[:space:]')"
    [[ -n "$RESOLVED_FULL_VERSION" ]] || {
        printf 'Error: empty version in %s\n' "$version_json" >&2
        exit 1
    }

    local short_version="${RESOLVED_FULL_VERSION%%-*}"
    RESOLVED_SHORT_VERSION="${short_version%%+*}"
    [[ -n "$RESOLVED_SHORT_VERSION" ]] || {
        printf 'Error: invalid SemVer prefix in %s\n' "$RESOLVED_FULL_VERSION" >&2
        exit 1
    }
}

stamp_built_plist_if_present() {
    local short_ver="$1"
    local full_ver="$2"
    local dry_run="$3"

    [[ -n "${TARGET_BUILD_DIR:-}" && -n "${INFOPLIST_PATH:-}" ]] || return 0
    local built_plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
    if [[ -f "$built_plist" ]]; then
        stamp_single_plist "$built_plist" "$short_ver" "$full_ver" "$dry_run"
    fi
}

main() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root
    repo_root="$(cd "$script_dir/.." && pwd)"

    parse_args "$repo_root" "$@"
    resolve_versions_from_json "$OPT_VERSION_JSON"
    stamp_single_plist "$OPT_INFO_PLIST" "$RESOLVED_SHORT_VERSION" "$RESOLVED_FULL_VERSION" "$OPT_DRY_RUN"
    stamp_built_plist_if_present "$RESOLVED_SHORT_VERSION" "$RESOLVED_FULL_VERSION" "$OPT_DRY_RUN"
}

main "$@"
