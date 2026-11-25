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
#   Release            -Osize + whole-module + thin LTO + dead-strip; symbols in a dSYM beside the app.
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

require_arg_value() {
    local flag="$1"
    local arg_count="$2"
    local hint="$3"
    if [[ "$arg_count" -lt 2 ]]; then
        printf 'Error: %s requires %s\n' "$flag" "$hint" >&2
        exit 1
    fi
}

validate_configuration() {
    local config="$1"
    case "$config" in
        Debug|Release) ;;
        *)
            printf 'Error: Invalid configuration "%s" (expected Debug or Release)\n' "$config" >&2
            exit 1
            ;;
    esac
}

apply_cli_option() {
    local flag="$1"
    local arg_count="$2"
    local next_val="${3:-}"
    CONSUMED_ARGS=1

    case "$flag" in
        -c|--configuration)
            require_arg_value "$flag" "$arg_count" "Debug or Release"
            validate_configuration "$next_val"
            OPT_CONFIGURATION="$next_val"
            CONSUMED_ARGS=2
            ;;
        --clean)
            OPT_DO_CLEAN="true"
            ;;
        --debuggable)
            OPT_DEBUGGABLE="true"
            ;;
        --derived-data)
            require_arg_value "--derived-data" "$arg_count" "a path"
            OPT_DERIVED_DATA="$next_val"
            CONSUMED_ARGS=2
            ;;
        --dry-run)
            OPT_DRY_RUN="true"
            ;;
        -h|--help)
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
    OPT_CONFIGURATION="Release"
    OPT_DO_CLEAN="false"
    OPT_DEBUGGABLE="false"
    OPT_DERIVED_DATA=""
    OPT_DRY_RUN="false"

    while [[ $# -gt 0 ]]; do
        apply_cli_option "$1" "$#" "${2:-}"
        shift "$CONSUMED_ARGS"
    done
}

validate_build_prerequisites() {
    local stamp_script="$1"
    local xcodeproj="$2"
    if [[ ! -x "$stamp_script" ]]; then
        printf 'Error: stamp-info-plist.sh not found or not executable at %s\n' "$stamp_script" >&2
        exit 1
    fi
    if [[ ! -d "$xcodeproj" ]]; then
        printf 'Error: Xcode project not found at %s\n' "$xcodeproj" >&2
        exit 1
    fi
    if ! command -v xcodebuild >/dev/null 2>&1; then
        printf 'Error: xcodebuild not found in PATH\n' >&2
        exit 1
    fi
}

stamp_info_plist() {
    local stamp_script="$1"
    local full_version="$2"
    local dry_run="$3"
    printf '==> Step 1/3: Stamping Info.plist (version %s)...\n' "$full_version"
    if [[ "$dry_run" == "true" ]]; then
        "$stamp_script" --dry-run
    else
        "$stamp_script"
    fi
}

prepare_xcodebuild_args() {
    local xcodeproj="$1"
    local scheme="$2"
    local destination="$3"
    local repo_root="$4"

    XCODEBUILD_BASE_ARGS=(
        -project "$xcodeproj"
        -scheme "$scheme"
        -configuration "$OPT_CONFIGURATION"
        -destination "$destination"
        -skipPackagePluginValidation
    )
    if [[ "$OPT_CONFIGURATION" == "Release" || "$OPT_DEBUGGABLE" == "false" ]]; then
        XCODEBUILD_BASE_ARGS+=(
            "SWIFT_COMPILATION_MODE=wholemodule"
            "SWIFT_OPTIMIZATION_LEVEL=-Osize"
            "GCC_OPTIMIZATION_LEVEL=s"
            "DEAD_CODE_STRIPPING=YES"
            "LLVM_LTO=YES_THIN"
        )
    fi
    if [[ -z "$OPT_DERIVED_DATA" && "$OPT_CONFIGURATION" == "Debug" && "$OPT_DEBUGGABLE" == "false" ]]; then
        # Compact Debug uses its own DerivedData so Xcode's -Onone Debug products are never rebuilt or replaced.
        OPT_DERIVED_DATA="${repo_root}/.build/xcode-compact"
    fi
    if [[ -n "$OPT_DERIVED_DATA" ]]; then
        XCODEBUILD_BASE_ARGS+=(-derivedDataPath "$OPT_DERIVED_DATA")
    fi

    XCODEBUILD_ARGS=("${XCODEBUILD_BASE_ARGS[@]}")
    if [[ "$OPT_DO_CLEAN" == "true" ]]; then
        XCODEBUILD_ARGS+=(clean)
    fi
    XCODEBUILD_ARGS+=(build)
}

stage_built_product() {
    local stage_dir="$1"
    local configuration="$2"

    local build_settings
    build_settings="$(xcodebuild "${XCODEBUILD_BASE_ARGS[@]}" -showBuildSettings 2>/dev/null || true)"
    local target_dir=""
    local product_name=""
    target_dir="$(printf '%s\n' "$build_settings" | awk -F ' = ' '/^[[:space:]]*TARGET_BUILD_DIR = / { print $2; exit }')"
    product_name="$(printf '%s\n' "$build_settings" | awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / { print $2; exit }')"

    if [[ -z "$target_dir" || -z "$product_name" || ! -d "${target_dir}/${product_name}" ]]; then
        printf 'Error: built product not found at %s/%s\n' "$target_dir" "$product_name" >&2
        exit 1
    fi

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

    parse_args "$@"
    validate_build_prerequisites "$readonly_stamp_script" "$readonly_xcodeproj"

    local full_version
    full_version="$(resolve_full_version "$readonly_version_json")"
    local stage_dir="${repo_root}/build/${full_version}"

    stamp_info_plist "$readonly_stamp_script" "$full_version" "$OPT_DRY_RUN"
    prepare_xcodebuild_args "$readonly_xcodeproj" "$readonly_scheme" "$readonly_destination" "$repo_root"

    printf '==> Step 2/3: Building %s (%s -> SwiftEdit.app)...\n' "$readonly_scheme" "$OPT_CONFIGURATION"
    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        printf '[dry-run] xcodebuild'
        printf ' %q' "${XCODEBUILD_ARGS[@]}"
        printf '\n'
        printf '[dry-run] Stage %s app into %s/SwiftEdit.app\n' "$OPT_CONFIGURATION" "$stage_dir"
        return 0
    fi

    xcodebuild "${XCODEBUILD_ARGS[@]}"
    stage_built_product "$stage_dir" "$OPT_CONFIGURATION"
}

main "$@"
