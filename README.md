# PH.SwiftEdit

Minimal & Light Text Editor written in Swift 6 for macOS 26+ (with iOS 26+ shared core readiness).

<p align="center">
  <img src="docs/design/assets/logo-e2-refined-512.png" alt="PH.SwiftEdit Concept E2 Logo" width="128" height="128" />
</p>

## Install or Update from a GitHub Release

Release builds are published on GitHub (`paonath/PH.SwiftEdit`) as `PH.SwiftEdit-<version>-macOS-arm64.zip` with a matching `.sha256` checksum.

### One-Command Install / Update

```bash
./Scripts/install-from-github.sh --remove-quarantine
# Or pin a specific release tag:
./Scripts/install-from-github.sh --version v0.0.1-alpha5 --remove-quarantine
```

The installer verifies the `.sha256` digest fail-closed before replacing `/Applications/PH.SwiftEdit.app`, quits any running `PH.SwiftEdit` instance, and only removes `com.apple.quarantine` when `--remove-quarantine` is passed.

### Manual Install

If a release is not notarized by Apple, macOS blocks the first launch:

1. Download `PH.SwiftEdit-<version>-macOS-arm64.zip` and `PH.SwiftEdit-<version>-macOS-arm64.zip.sha256` from the GitHub release, verify the checksum (`shasum -a 256 -c PH.SwiftEdit-<version>-macOS-arm64.zip.sha256`), unzip, and move `PH.SwiftEdit.app` to `/Applications`.
2. Try to open the app normally, click **OK**, then go to **Apple menu > System Settings > Privacy & Security** and click **Open Anyway**.
3. Alternatively, after verifying the SHA-256 checksum, remove the quarantine attribute from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/PH.SwiftEdit.app
open /Applications/PH.SwiftEdit.app
```

## Build and Test

```bash
swift test --parallel
./Scripts/build-app.sh --configuration Release --clean --derived-data .tmp/DerivedData
open .tmp/DerivedData/Build/Products/Release/PH.SwiftEdit.app
```

Pushing a Git tag builds `PH.SwiftEdit-<tag>-macOS-arm64.zip` and publishes it with its `.sha256` checksum via `.github/workflows/release.yml`.

## Design & Architecture Documentation

| Document | Scope |
| :--- | :--- |
| [Color Schemes, Brand Logo E2 & Zed-Minimal Layout](docs/design/color-schemes-and-zed-layout.md) | Semantic Purple (`Viola`: `#0B0614`, `#7C3AED`, `#A78BFA`, `#C4B5FD`) chrome tokens, `#FFFFFF`/`#000000` inverted TextKit 2 canvas, `50%..300%` Zoom Mode, and UI mockups |
| [Concept E2 App Icons Summary (macOS + iPhone)](docs/design/assets/app-icons-riepilogo.md) | Master vector ([logo-e2-refined.svg](docs/design/assets/logo-e2-refined.svg)) and `AppIcon.appiconset` specifications for macOS (`16..1024 px`) and iOS (`40..1024 px`) |
| [Project Constitution](openspec/Constitution.md) | Bare-Bones governance routing matrix (`AR`, `BC`, `UI`, `DATA`, `API`, `TEST`, `SEC`, `SDD`) |
