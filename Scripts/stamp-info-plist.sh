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

main() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root
    repo_root="$(cd "$script_dir/.." && pwd)"

    local version_json="${repo_root}/version.json"
    local info_plist="${repo_root}/XcodeApp/Info.plist"
    local dry_run="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version-json)
                [[ $# -ge 2 ]] || { printf 'Error: --version-json requires a path\n' >&2; exit 1; }
                version_json="$2"
                shift 2
                ;;
            --info-plist)
                [[ $# -ge 2 ]] || { printf 'Error: --info-plist requires a path\n' >&2; exit 1; }
                info_plist="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --help|-h)
                print_help
                exit 0
                ;;
            *)
                printf 'Error: Unknown argument: %s\n' "$1" >&2
                exit 1
                ;;
        esac
    done

    [[ -f "$version_json" ]] || {
        printf 'Error: version.json not found at %s\n' "$version_json" >&2
        exit 1
    }

    local full_version
    full_version="$(/usr/bin/plutil -extract version raw -o - "$version_json" | tr -d '[:space:]')"
    [[ -n "$full_version" ]] || {
        printf 'Error: empty version in %s\n' "$version_json" >&2
        exit 1
    }

    local short_version="${full_version%%-*}"
    short_version="${short_version%%+*}"
    [[ -n "$short_version" ]] || {
        printf 'Error: invalid SemVer prefix in %s\n' "$full_version" >&2
        exit 1
    }

    stamp_single_plist "$info_plist" "$short_version" "$full_version" "$dry_run"

    if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${INFOPLIST_PATH:-}" ]]; then
        local built_plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
        if [[ -f "$built_plist" ]]; then
            stamp_single_plist "$built_plist" "$short_version" "$full_version" "$dry_run"
        fi
    fi
}

main "$@"
