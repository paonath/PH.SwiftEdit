#!/usr/bin/env bash
# ==============================================================================
# build-app.sh
# Synchronizes Info.plist via stamp-info-plist.sh, builds a macOS Release
# (default) bundle of PH.SwiftEdit (producing SwiftEdit.app), and stages it
# inside local build/<FULL_VERSION>/SwiftEdit.app (gitignored).
#
# Usage:
#   ./Scripts/build-app.sh [--configuration <Debug|Release>] [--debuggable] [--clean] [--derived-data <path>] [--dry-run] [--help]
#
# Size policy:
#   Release            -Osize + whole-module + full LTO + LD_EXPORT_SYMBOLS=NO + no reflection metadata + dead-strip;
#                      symbols live in a dSYM beside the app.
#   Debug (default)    compact: same -Osize code generation for every module (SwiftTerm included) in a separate
#                      DerivedData (.build/xcode-compact) so Xcode's -Onone Debug cache is untouched; DEBUG flag kept.
#   Debug --debuggable -Onone code for step-by-step debugging and assert(); still dead-stripped with a dSYM.
#
# Exit Codes:
#   0 - Info.plist stamped, application built, and staged into build/<FULL_VERSION>/
#   1 - Invalid arguments, missing files/tools, or build failure
# ==============================================================================
set -euo pipefail
IFS=$'\n\t'

print_help() {
    cat <<'EOF'
Usage: build-app.sh [options]

Options:
  -c, --configuration <Debug|Release>  Xcode build configuration (default: Release)
      --debuggable                     Debug only: keep -Onone code (bigger app) instead of the compact -Osize Debug
      --clean                          Run clean before building
      --derived-data <path>            Custom DerivedData path for xcodebuild
      --dry-run                        Print commands without executing them
  -h, --help                           Display this help message and exit
EOF
}

resolve_full_version() {
    local version_json="$1"
    [[ -f "$version_json" ]] || {
        printf 'Error: version.json not found at %s\n' "$version_json" >&2
        exit 1
    }
    local full_version
    full_version="$(/usr/bin/plutil -extract version raw -o - "$version_json" | tr -d '[:space:]')"
    if [[ -z "$full_version" || "$full_version" == *".."* || "$full_version" == *"/"* ]]; then
        printf 'Error: invalid version "%s" in %s\n' "$full_version" "$version_json" >&2
        exit 1
    fi
    printf '%s' "$full_version"
}

main() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root
    repo_root="$(cd "${script_dir}/.." && pwd)"

    local readonly_stamp_script="${script_dir}/stamp-info-plist.sh"
    local readonly_version_json="${repo_root}/version.json"
    local readonly_xcodeproj="${repo_root}/XcodeApp/PH.SwiftEdit.xcodeproj"
    local readonly_scheme="PH.SwiftEdit"
    local readonly_destination="platform=macOS"

    local configuration="Release"
    local do_clean="false"
    local debuggable="false"
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
            --debuggable)
                debuggable="true"
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

    local full_version
    full_version="$(resolve_full_version "$readonly_version_json")"
    local stage_dir="${repo_root}/build/${full_version}"

    printf '==> Step 1/3: Stamping Info.plist (version %s)...\n' "$full_version"
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
        -skipPackagePluginValidation
    )
    if [[ "$configuration" == "Release" || "$debuggable" == "false" ]]; then
        xcodebuild_base_args+=(
            "SWIFT_COMPILATION_MODE=wholemodule"
            "SWIFT_OPTIMIZATION_LEVEL=-Osize"
            "SWIFT_REFLECTION_METADATA_LEVEL=none"
            "GCC_OPTIMIZATION_LEVEL=s"
            "GCC_SYMBOLS_PRIVATE_EXTERN=YES"
            "DEAD_CODE_STRIPPING=YES"
        )
        if [[ "$configuration" == "Release" ]]; then
            xcodebuild_base_args+=(
                "LLVM_LTO=YES"
            )
        else
            xcodebuild_base_args+=(
                "LLVM_LTO=YES_THIN"
            )
        fi
    fi
    if [[ -z "$derived_data" && "$configuration" == "Debug" && "$debuggable" == "false" ]]; then
        # Compact Debug uses its own DerivedData so Xcode's -Onone Debug products are never rebuilt or replaced.
        derived_data="${repo_root}/.build/xcode-compact"
    fi
    if [[ -n "$derived_data" ]]; then
        xcodebuild_base_args+=(-derivedDataPath "$derived_data")
    fi

    local xcodebuild_args=("${xcodebuild_base_args[@]}")
    if [[ "$do_clean" == "true" ]]; then
        xcodebuild_args+=(clean)
    fi
    xcodebuild_args+=(build)

    printf '==> Step 2/3: Building %s (%s -> SwiftEdit.app)...\n' "$readonly_scheme" "$configuration"
    if [[ "$dry_run" == "true" ]]; then
        printf '[dry-run] xcodebuild'
        printf ' %q' "${xcodebuild_args[@]}"
        printf '\n'
        printf '[dry-run] Stage %s app into %s/SwiftEdit.app\n' "$configuration" "$stage_dir"
        return 0
    fi

    xcodebuild "${xcodebuild_args[@]}"

    local build_settings
    build_settings="$(xcodebuild "${xcodebuild_base_args[@]}" -showBuildSettings 2>/dev/null || true)"
    local target_dir=""
    local product_name=""
    target_dir="$(printf '%s\n' "$build_settings" | awk -F ' = ' '/^[[:space:]]*TARGET_BUILD_DIR = / { print $2; exit }')"
    product_name="$(printf '%s\n' "$build_settings" | awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / { print $2; exit }')"

    [[ -n "$target_dir" && -n "$product_name" && -d "${target_dir}/${product_name}" ]] || {
        printf 'Error: built product not found at %s/%s\n' "$target_dir" "$product_name" >&2
        exit 1
    }

    printf '==> Step 3/3: Staging %s into %s/%s...\n' "$product_name" "$stage_dir" "$product_name"
    local staged_app="${stage_dir}/${product_name}"
    mkdir -p "$stage_dir"
    rm -rf -- "${staged_app:?}"
    ditto "${target_dir}/${product_name}" "$staged_app"

    # Symbols live in a dSYM beside (never inside) the app so the bundle stays compact yet debuggable.
    local source_dsym="${target_dir}/${product_name}.dSYM"
    local staged_dsym="${staged_app}.dSYM"
    rm -rf -- "${staged_dsym:?}"
    if [[ -d "$source_dsym" ]]; then
        ditto "$source_dsym" "$staged_dsym"
    fi
    printf '==> Build complete (%s): %s (%s)\n' "$configuration" "$staged_app" "$(du -sh "$staged_app" | awk '{print $1}')"
}

main "$@"
