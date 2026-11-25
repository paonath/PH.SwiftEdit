#!/usr/bin/env bash
# ==============================================================================
# install-from-github.sh
# Downloads, SHA-256 verifies, and installs/updates SwiftEdit.app from a
# GitHub Release of paonath/PH.SwiftEdit.
#
# Automatically quits a running SwiftEdit before replacing it, preserves the
# quarantine-free state if the installed app had no com.apple.quarantine before
# updating, and relaunches the updated app (unless --no-relaunch is passed).
#
# Usage:
#   ./Scripts/install-from-github.sh [--version <tag|latest>] [--install-dir <path>] [--remove-quarantine] [--no-relaunch] [--dry-run] [--help]
# ==============================================================================
set -euo pipefail
IFS=$'\n\t'

readonly REPO="paonath/PH.SwiftEdit"
readonly APP_NAME="SwiftEdit.app"
readonly LEGACY_APP_NAME="PH.SwiftEdit.app"
readonly PROCESS_NAME="SwiftEdit"

print_help() {
    cat <<'EOF'
Usage: install-from-github.sh [options]

Downloads a release archive from GitHub (paonath/PH.SwiftEdit), verifies its
SHA-256 checksum, and installs or updates SwiftEdit.app.

Options:
  --version <tag|latest>  Release tag to install (default: latest)
  --install-dir <path>    Destination directory (default: /Applications)
  --remove-quarantine     Always run xattr -dr com.apple.quarantine after verification
                          (also automatic when updating an existing app without quarantine)
  --no-relaunch           Do not run `open <dest_app>` after installation/update
  --dry-run               Print resolved URLs and actions without downloading
  -h, --help              Display this help message and exit
EOF
}

validate_tag() {
    local tag="$1"
    if [[ -z "$tag" || "$tag" == *".."* || "$tag" == *"/"* || "$tag" =~ [[:space:]] ]]; then
        printf 'Error: invalid release tag "%s"\n' "$tag" >&2
        exit 1
    fi
}

resolve_latest_tag() {
    local api_url="https://api.github.com/repos/${REPO}/releases/latest"
    local json
    json="$(curl -fsSL -H "Accept: application/vnd.github+json" "$api_url")"
    local tag
    tag="$(printf '%s' "$json" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("tag_name", ""))')"
    if [[ -z "$tag" ]]; then
        printf 'Error: could not resolve latest release tag from %s\n' "$api_url" >&2
        exit 1
    fi
    printf '%s' "$tag"
}

app_has_quarantine() {
    local app_path="$1"
    xattr -p com.apple.quarantine "$app_path" >/dev/null 2>&1
}

quit_running_app() {
    if ! pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
        return 0
    fi
    printf '==> Quitting running %s before updating...\n' "$PROCESS_NAME"
    osascript -e "tell application \"${PROCESS_NAME}\" to quit" >/dev/null 2>&1 || true
    local waited=0
    while pgrep -x "$PROCESS_NAME" >/dev/null 2>&1 && [[ "$waited" -lt 25 ]]; do
        sleep 0.2
        waited=$((waited + 1))
    done
    if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
        pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true
        sleep 0.3
    fi
}

INSTALL_WORKDIR=""

cleanup_workdir() {
    if [[ -n "${INSTALL_WORKDIR:-}" ]]; then
        rm -rf "$INSTALL_WORKDIR"
    fi
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

apply_cli_option() {
    local flag="$1"
    local arg_count="$2"
    local next_val="${3:-}"
    CONSUMED_ARGS=1

    case "$flag" in
        --version)
            require_arg_value "--version" "$arg_count" 'a tag or "latest"'
            OPT_VERSION="$next_val"
            CONSUMED_ARGS=2
            ;;
        --install-dir)
            require_arg_value "--install-dir" "$arg_count" "a path"
            OPT_INSTALL_DIR="$next_val"
            CONSUMED_ARGS=2
            ;;
        --remove-quarantine)
            OPT_REMOVE_QUARANTINE="true"
            ;;
        --no-relaunch)
            OPT_RELAUNCH="false"
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
    OPT_VERSION="latest"
    OPT_INSTALL_DIR="/Applications"
    OPT_REMOVE_QUARANTINE="false"
    OPT_RELAUNCH="true"
    OPT_DRY_RUN="false"

    while [[ $# -gt 0 ]]; do
        apply_cli_option "$1" "$#" "${2:-}"
        shift "$CONSUMED_ARGS"
    done
}

require_tools() {
    local cmd
    for cmd in curl shasum ditto python3 xattr open; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            printf 'Error: required tool "%s" not found in PATH\n' "$cmd" >&2
            exit 1
        fi
    done
}

resolve_release_tag() {
    local version="$1"
    local dry_run="$2"
    RESOLVED_TAG="$version"
    if [[ "$RESOLVED_TAG" == "latest" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            RESOLVED_TAG="latest"
            printf '[dry-run] Would query https://api.github.com/repos/%s/releases/latest\n' "$REPO"
        else
            RESOLVED_TAG="$(resolve_latest_tag)"
        fi
    fi
    validate_tag "$RESOLVED_TAG"
}

determine_quarantine_plan() {
    local dest_app="$1"
    local remove_quarantine="$2"
    # Detect whether an existing installation is already quarantine-free so updating never re-introduces quarantine.
    HAD_EXISTING_APP="false"
    EXISTING_HAD_QUARANTINE="false"
    SHOULD_STRIP_QUARANTINE="false"

    if [[ -d "$dest_app" ]]; then
        HAD_EXISTING_APP="true"
        if app_has_quarantine "$dest_app"; then
            EXISTING_HAD_QUARANTINE="true"
        fi
    fi

    if [[ "$remove_quarantine" == "true" ]]; then
        SHOULD_STRIP_QUARANTINE="true"
    elif [[ "$HAD_EXISTING_APP" == "true" && "$EXISTING_HAD_QUARANTINE" == "false" ]]; then
        SHOULD_STRIP_QUARANTINE="true"
    fi
}

print_dry_run_plan() {
    local archive_url="$1"
    local sha_url="$2"
    local sha_name="$3"
    local dest_app="$4"
    printf '[dry-run] Archive URL:  %s\n' "$archive_url"
    printf '[dry-run] Checksum URL: %s\n' "$sha_url"
    printf '[dry-run] Verify:       shasum -a 256 -c %s\n' "$sha_name"
    printf '[dry-run] Install to:   %s\n' "$dest_app"
    printf '[dry-run] Quarantine:   strip=%s (explicit=%s, existing_app=%s, existing_had_quarantine=%s)\n' \
        "$SHOULD_STRIP_QUARANTINE" "$OPT_REMOVE_QUARANTINE" "$HAD_EXISTING_APP" "$EXISTING_HAD_QUARANTINE"
    printf '[dry-run] Relaunch:     %s\n' "$OPT_RELAUNCH"
}

download_and_verify_archive() {
    local workdir="$1"
    local tag="$2"
    local archive_name="$3"
    local sha_name="$4"
    local archive_url="$5"
    local sha_url="$6"

    printf '==> Downloading %s (%s)...\n' "$archive_name" "$tag"
    curl -fsSL -o "${workdir}/${archive_name}" "$archive_url"
    curl -fsSL -o "${workdir}/${sha_name}" "$sha_url"

    printf '==> Verifying SHA-256 checksum...\n'
    (cd "$workdir" && shasum -a 256 -c "$sha_name")

    printf '==> Extracting %s...\n' "$archive_name"
    mkdir -p "${workdir}/extracted"
    ditto -x -k "${workdir}/${archive_name}" "${workdir}/extracted"

    EXTRACTED_APP="${workdir}/extracted/${APP_NAME}"
    if [[ ! -d "$EXTRACTED_APP" && -d "${workdir}/extracted/${LEGACY_APP_NAME}" ]]; then
        EXTRACTED_APP="${workdir}/extracted/${LEGACY_APP_NAME}"
    fi
    if [[ ! -d "$EXTRACTED_APP" ]]; then
        printf 'Error: %s not found inside archive %s\n' "$APP_NAME" "$archive_name" >&2
        exit 1
    fi
}

install_verified_app() {
    local workdir="$1"
    local extracted_app="$2"
    local dest_app="$3"
    local install_dir="$4"
    local tag="$5"
    local relaunch="$6"

    quit_running_app

    mkdir -p "$install_dir"
    local backup_app=""
    if [[ -e "$dest_app" ]]; then
        backup_app="${workdir}/${APP_NAME}.backup"
        mv "$dest_app" "$backup_app"
    fi

    if ! ditto "$extracted_app" "$dest_app"; then
        if [[ -n "$backup_app" && -e "$backup_app" ]]; then
            mv "$backup_app" "$dest_app"
        fi
        printf 'Error: failed to copy %s into %s\n' "$APP_NAME" "$install_dir" >&2
        exit 1
    fi

    if [[ "$SHOULD_STRIP_QUARANTINE" == "true" ]]; then
        printf '==> Removing com.apple.quarantine attribute...\n'
        xattr -dr com.apple.quarantine "$dest_app" || true
    fi

    printf '==> Installed %s (%s) to %s\n' "$APP_NAME" "$tag" "$dest_app"

    if [[ "$relaunch" == "true" ]]; then
        printf '==> Launching %s...\n' "$dest_app"
        open "$dest_app"
    fi
}

main() {
    parse_args "$@"
    require_tools

    resolve_release_tag "$OPT_VERSION" "$OPT_DRY_RUN"
    local tag="$RESOLVED_TAG"
    local safe_tag="${tag//\//-}"
    local archive_name="PH.SwiftEdit-${safe_tag}-macOS-arm64.zip"
    local sha_name="${archive_name}.sha256"
    local base_url="https://github.com/${REPO}/releases/download/${tag}"
    local archive_url="${base_url}/${archive_name}"
    local sha_url="${base_url}/${sha_name}"
    local dest_app="${OPT_INSTALL_DIR}/${APP_NAME}"

    determine_quarantine_plan "$dest_app" "$OPT_REMOVE_QUARANTINE"

    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        print_dry_run_plan "$archive_url" "$sha_url" "$sha_name" "$dest_app"
        return 0
    fi

    INSTALL_WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/swiftedit-install.XXXXXX")"
    trap cleanup_workdir EXIT

    download_and_verify_archive "$INSTALL_WORKDIR" "$tag" "$archive_name" "$sha_name" "$archive_url" "$sha_url"
    install_verified_app "$INSTALL_WORKDIR" "$EXTRACTED_APP" "$dest_app" "$OPT_INSTALL_DIR" "$tag" "$OPT_RELAUNCH"
}

main "$@"
