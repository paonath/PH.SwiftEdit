#!/usr/bin/env bash
# ==============================================================================
# build-app.sh
# Synchronizes Info.plist via stamp-info-plist.sh and performs a full macOS
# application build of PH.SwiftEdit via xcodebuild.
#
# Usage:
#   ./Scripts/build-app.sh [--configuration <Debug|Release>] [--clean] [--derived-data <path>] [--dry-run] [--help]
#
# Exit Codes:
#   0 - Info.plist stamped and application build succeeded
#   1 - Invalid arguments, missing files/tools, or build failure
# ==============================================================================
set -euo pipefail
IFS=$'\n\t'

print_help() {
    cat <<'EOF'
Usage: build-app.sh [options]

Options:
  -c, --configuration <Debug|Release>  Xcode build configuration (default: Release)
      --clean                          Run clean before building
      --derived-data <path>            Custom DerivedData path for xcodebuild
      --dry-run                        Print commands without executing them
  -h, --help                           Display this help message and exit
EOF
}

main() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root
    repo_root="$(cd "${script_dir}/.." && pwd)"

    local readonly_stamp_script="${script_dir}/stamp-info-plist.sh"
    local readonly_xcodeproj="${repo_root}/XcodeApp/PH.SwiftEdit.xcodeproj"
    local readonly_scheme="PH.SwiftEdit"
    local readonly_destination="platform=macOS"

    local configuration="Release"
    local do_clean="false"
    local derived_data=""
    local dry_run="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--configuration)
                [[ $# -ge 2 ]] || { printf 'Error: %s requires Debug or Release\n' "$1" >&2; exit 1; }
                case "$2" in
                    Debug|Release) configuration="$2" ;;
                    *) printf 'Error: Invalid configuration "%s" (expected Debug or Release)\n' "$2" >&2; exit 1 ;;
                esac
                shift 2
                ;;
            --clean)
                do_clean="true"
                shift
                ;;
            --derived-data)
                [[ $# -ge 2 ]] || { printf 'Error: --derived-data requires a path\n' >&2; exit 1; }
                derived_data="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                printf 'Error: Unknown argument: %s\n' "$1" >&2
                exit 1
                ;;
        esac
    done

    [[ -x "$readonly_stamp_script" ]] || {
        printf 'Error: stamp-info-plist.sh not found or not executable at %s\n' "$readonly_stamp_script" >&2
        exit 1
    }
    [[ -d "$readonly_xcodeproj" ]] || {
        printf 'Error: Xcode project not found at %s\n' "$readonly_xcodeproj" >&2
        exit 1
    }
    command -v xcodebuild >/dev/null 2>&1 || {
        printf 'Error: xcodebuild not found in PATH\n' >&2
        exit 1
    }

    printf '==> Step 1/2: Stamping Info.plist...\n'
    if [[ "$dry_run" == "true" ]]; then
        "$readonly_stamp_script" --dry-run
    else
        "$readonly_stamp_script"
    fi

    local xcodebuild_base_args=(
        -project "$readonly_xcodeproj"
        -scheme "$readonly_scheme"
        -configuration "$configuration"
        -destination "$readonly_destination"
    )
    if [[ -n "$derived_data" ]]; then
        xcodebuild_base_args+=(-derivedDataPath "$derived_data")
    fi

    local xcodebuild_args=("${xcodebuild_base_args[@]}")
    if [[ "$do_clean" == "true" ]]; then
        xcodebuild_args+=(clean)
    fi
    xcodebuild_args+=(build)

    printf '==> Step 2/2: Building %s (%s)...\n' "$readonly_scheme" "$configuration"
    if [[ "$dry_run" == "true" ]]; then
        printf '[dry-run] xcodebuild'
        printf ' %q' "${xcodebuild_args[@]}"
        printf '\n'
        return 0
    fi

    xcodebuild "${xcodebuild_args[@]}"

    local build_settings
    build_settings="$(xcodebuild "${xcodebuild_base_args[@]}" -showBuildSettings 2>/dev/null || true)"
    local target_dir=""
    local product_name=""
    target_dir="$(printf '%s\n' "$build_settings" | awk -F ' = ' '/^[[:space:]]*TARGET_BUILD_DIR = / { print $2; exit }')"
    product_name="$(printf '%s\n' "$build_settings" | awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / { print $2; exit }')"
    if [[ -n "$target_dir" && -n "$product_name" ]]; then
        printf '==> Build complete: %s/%s\n' "$target_dir" "$product_name"
    fi
}

main "$@"
