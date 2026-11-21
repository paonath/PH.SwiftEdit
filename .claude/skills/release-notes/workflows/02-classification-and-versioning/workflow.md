# Workflow 02: Changelog Alignment, Classification & Version Detection (`release-notes`)

## Step 3: Changelog Alignment

1. Check for `CHANGELOG.md`, `docs/CHANGELOG.md`, or `changelog.md`.
2. Mirror existing category vocabulary (e.g., Keep a Changelog) if present.
3. Reuse `[Unreleased]` draft descriptions where validated against the git diff; proceed normally if no changelog exists.

## Step 4: Change Classification

1. Classify every non-merge commit into one category:
   - **New Features**: User-facing or API-facing additions.
   - **Bug Fixes**: Behavioral corrections.
   - **Improvements**: Performance, UX, or beneficial refactoring.
   - **Breaking Changes & Migration Notes**: Breaking API changes, migrations, or removals.
   - **Documentation**: Documentation-only modifications.
   - **Internal / Technical**: Chores, dependencies, CI, tests, and internal refactors.
2. Infer category from Conventional Commits (`feat:`, `fix:`, `refactor:`) or raw diff changes; exclude merge commits and formatting noise.

## Step 5: Version Strategy Detection

Detect repository versioning strategy using the first matching rule:
1. `version.json` -> Nerdbank.GitVersioning (NBGV); run `nbgv get-version -f json` if available, else mark tool-managed.
2. `GitVersion.yml` or `GitVersion.json` -> GitVersion (tool-managed).
3. `*.csproj` with `<Version>`, `<VersionPrefix>`, or `<AssemblyVersion>` -> Project-file SemVer.
4. `package.json` with `"version"` -> npm SemVer.
5. Recent git tags (`git tag --sort=-creatordate`) -> Tag-based SemVer (`vX.Y.Z`), short SemVer (`vX.Y`), or CalVer.
6. `CHANGELOG.md` headings -> Changelog SemVer convention.
7. None -> Prompt user for version scheme.

Propose a candidate version: tool-managed uses computed tool version; manual SemVer release bumps major for breaking changes, minor for new features, else patch; manual SemVer hotfix proposes patch bump from latest version.

## Operational Requirements (EARS)

- The classification-and-versioning workflow SHALL classify every non-merge commit into one of the six canonical categories and omit undocumented changes absent from the diff.
- IF a commit classification is uncertain, THEN the classification-and-versioning workflow SHALL default the entry to **Breaking Changes & Migration Notes**.
- WHERE **New Features** appear on a `hotfix/*` branch, the classification-and-versioning workflow SHALL flag a process anomaly for explicit user confirmation in Step 6.
- WHEN detecting version strategy, the classification-and-versioning workflow SHALL evaluate rules 1 through 7 in order and prompt the user if no versioning source exists.
