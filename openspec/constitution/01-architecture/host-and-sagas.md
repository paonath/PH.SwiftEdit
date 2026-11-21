---
area: "01-architecture"
file: "host-and-sagas.md"
rules: ["AR-011", "AR-012", "AR-013", "AR-014"]
---

# 01-architecture/host-and-sagas (AR-011..AR-014)

## Context
- markdown_and_edit_engine: `Offline swift-markdown AST Lint/Format, Cmd+D Smart Duplication, (){}[] Bracket Balancing, Myers Diff`
- version_stamping: `Nerdbank.GitVersioning (nbgv) from version.json into Info.plist`

## Rules
- **AR-011**: The `SwiftEditCore` Markdown engine SHALL execute CommonMark and GitHub Flavored Markdown parsing, AST linting, `Format Section`, and `Format Document` transformations 100% offline via `swiftlang/swift-markdown` without network access.
- **AR-012**: The `SwiftEditCore` editing engine SHALL implement `Cmd+D` duplication (duplicating the current line when unselected or inserting selected text on a new line immediately after the cursor), live `(){}[]` bracket balancing, and Myers file diffing as pure deterministic functions.
- **AR-013**: WHEN syntax tokenization, regex search, `(){}[]` bracket matching, Markdown lint/format, or Myers diffing executes off `@MainActor`, the worker SHALL enforce cooperative `Task` cancellation deadlines against an injected Swift `Clock`.
- **AR-014**: The Xcode build pipeline SHALL stamp `CFBundleShortVersionString` and `CFBundleVersion` into `Info.plist` deterministically from `version.json` using Nerdbank.GitVersioning (`nbgv`) without dirtying tracked source files.
