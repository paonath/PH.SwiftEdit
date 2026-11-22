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

main() {
    local version="latest"
    local install_dir="/Applications"
    local remove_quarantine="false"
    local relaunch="true"
    local dry_run="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                [[ $# -ge 2 ]] || { printf 'Error: --version requires a tag or "latest"\n' >&2; exit 1; }
                version="$2"
                shift 2
                ;;
            --install-dir)
                [[ $# -ge 2 ]] || { printf 'Error: --install-dir requires a path\n' >&2; exit 1; }
                install_dir="$2"
                shift 2
                ;;
            --remove-quarantine)
                remove_quarantine="true"
                shift
                ;;
            --no-relaunch)
                relaunch="false"
                shift
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

    for cmd in curl shasum ditto python3 xattr open; do
        command -v "$cmd" >/dev/null 2>&1 || {
            printf 'Error: required tool "%s" not found in PATH\n' "$cmd" >&2
            exit 1
        }
    done

    local tag="$version"
    if [[ "$tag" == "latest" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            tag="latest"
            printf '[dry-run] Would query https://api.github.com/repos/%s/releases/latest\n' "$REPO"
        else
            tag="$(resolve_latest_tag)"
        fi
    fi
    validate_tag "$tag"

    local safe_tag="${tag//\//-}"
    local archive_name="PH.SwiftEdit-${safe_tag}-macOS-arm64.zip"
    local sha_name="${archive_name}.sha256"
    local base_url="https://github.com/${REPO}/releases/download/${tag}"
    local archive_url="${base_url}/${archive_name}"
    local sha_url="${base_url}/${sha_name}"
    local dest_app="${install_dir}/${APP_NAME}"

    # Detect whether an existing installation is already quarantine-free so updating never re-introduces quarantine.
    local had_existing_app="false"
    local existing_had_quarantine="false"
    if [[ -d "$dest_app" ]]; then
        had_existing_app="true"
        if app_has_quarantine "$dest_app"; then
            existing_had_quarantine="true"
        fi
    fi

    local should_strip_quarantine="false"
    if [[ "$remove_quarantine" == "true" ]]; then
        should_strip_quarantine="true"
    elif [[ "$had_existing_app" == "true" && "$existing_had_quarantine" == "false" ]]; then
        should_strip_quarantine="true"
    fi

    if [[ "$dry_run" == "true" ]]; then
        printf '[dry-run] Archive URL:  %s\n' "$archive_url"
        printf '[dry-run] Checksum URL: %s\n' "$sha_url"
        printf '[dry-run] Verify:       shasum -a 256 -c %s\n' "$sha_name"
        printf '[dry-run] Install to:   %s\n' "$dest_app"
        printf '[dry-run] Quarantine:   strip=%s (explicit=%s, existing_app=%s, existing_had_quarantine=%s)\n' \
            "$should_strip_quarantine" "$remove_quarantine" "$had_existing_app" "$existing_had_quarantine"
        printf '[dry-run] Relaunch:     %s\n' "$relaunch"
        return 0
    fi

    local workdir
    workdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftedit-install.XXXXXX")"
    trap 'rm -rf "$workdir"' EXIT

    printf '==> Downloading %s (%s)...\n' "$archive_name" "$tag"
    curl -fsSL -o "${workdir}/${archive_name}" "$archive_url"
    curl -fsSL -o "${workdir}/${sha_name}" "$sha_url"

    printf '==> Verifying SHA-256 checksum...\n'
    (cd "$workdir" && shasum -a 256 -c "$sha_name")

    printf '==> Extracting %s...\n' "$archive_name"
    mkdir -p "${workdir}/extracted"
    ditto -x -k "${workdir}/${archive_name}" "${workdir}/extracted"

    local extracted_app="${workdir}/extracted/${APP_NAME}"
    if [[ ! -d "$extracted_app" && -d "${workdir}/extracted/${LEGACY_APP_NAME}" ]]; then
        extracted_app="${workdir}/extracted/${LEGACY_APP_NAME}"
    fi
    [[ -d "$extracted_app" ]] || {
        printf 'Error: %s not found inside archive %s\n' "$APP_NAME" "$archive_name" >&2
        exit 1
    }

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

    if [[ "$should_strip_quarantine" == "true" ]]; then
        printf '==> Removing com.apple.quarantine attribute...\n'
        xattr -dr com.apple.quarantine "$dest_app" || true
    fi

    printf '==> Installed %s (%s) to %s\n' "$APP_NAME" "$tag" "$dest_app"

    if [[ "$relaunch" == "true" ]]; then
        printf '==> Launching %s...\n' "$dest_app"
        open "$dest_app"
    fi
}

main "$@"
