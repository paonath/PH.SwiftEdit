# Workflow 04: Version Control Commit & Report (`release-notes`)

## Step 8: Version Control Commit

1. Stage target directory: `git add docs/releases/<version>/` or `git add docs/hotfixes/<version>/`.
2. Commit document:
   - Release: `git commit -m "docs(release): add release notes for <version>"`
   - Hotfix: `git commit -m "docs(hotfix): add hotfix notes for <version>"`
3. **STOP** immediately; do not push, merge, or tag.

## Step 9: Report and Usage Instructions

1. Report committed file path, commit hash, and summary.
2. Provide reuse guidance:
   - **GitHub Release**: Paste document body or run `gh release create <tag> --notes-file <target-path>`.
   - **Email/Word**: Copy text from rendered Markdown preview.

## Operational Requirements (EARS)

- WHEN Step 8 commits generated notes, the commit-and-report workflow SHALL stage only the target release or hotfix notes folder and commit with `docs(release):` or `docs(hotfix):`.
- The commit-and-report workflow SHALL stop immediately after the local commit without pushing, merging, or tagging.
- WHERE `$TYPE` is `hotfix`, the commit-and-report workflow SHALL advise merging the hotfix back into the development branch (`develop` or `main`) after trunk merge.
