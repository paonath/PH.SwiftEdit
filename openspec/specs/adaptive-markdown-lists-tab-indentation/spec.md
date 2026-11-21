# Capability: adaptive-markdown-lists-tab-indentation

## Purpose
Defines the pure `MarkdownSmartListEngine` that nests and outdents Markdown list items with CommonMark-valid four-space steps on `Tab` and `Shift+Tab`, resumes parent numbering, inherits valid user markers, rejects orphan code-block indentation, and applies edits atomically through the workbench without touching binary or non-Markdown buffers.

## Requirements

### Requirement: REQ-001 CommonMark-Valid Four-Space List Nesting and Outdent
WHEN the user presses `Tab` or `Shift+Tab` on a list line or multi-line selection outside fenced code in a Markdown document, the `MarkdownSmartListEngine` SHALL emit a single `TextEdit` batch that nests or outdents by four spaces with CommonMark-valid markers, resumes parent numbering on outdent, and inherits valid user markers [AR-002][BC-004][BC-011].

#### Scenario: P1 Tab Nests and Shift+Tab Outdents With Parent Numbering Resumed
- **Path**: P1
- **Trait**: positive
- **GIVEN** a Markdown snapshot `"1. Primo punto\n2. Secondo punto\n3. "` and a task list `"- [ ] task\n- [ ] "`
- **WHEN** `evaluateIndent` runs with `Tab` on line `3` of the first list, then `Shift+Tab` on the result, and `Tab` on line `2` of the task list
- **THEN** line `3` becomes `"    1. "`, `Shift+Tab` restores `"3. "`, and the task line becomes `"    - [ ] "`, each as one `TextEdit` batch

#### Scenario: P2 Multi-Line Selection Indents All List Lines and Inherits Valid Override Markers
- **Path**: P2
- **Trait**: positive
- **GIVEN** a snapshot `"- root\n* a\n* b\n+ c"` with a selection spanning lines `2` through `4`
- **WHEN** `evaluateIndent` runs with `Tab`
- **THEN** a single batch indents lines `2..4` to `"    * a"`, `"    * b"`, `"    + c"` preserving each valid marker (the parent `"- root"` satisfies the Parent-Ceiling), and `newSelection` shifts by the total inserted prefix length

#### Scenario: N1 Root First Item Non-List Line Fenced Code and Non-Markdown Are Safely Handled
- **Path**: N1
- **Trait**: negative
- **GIVEN** `"1. Primo punto"` with the caret on line `1`, a prose line, a line inside a fenced code block, and a `.swift` buffer
- **WHEN** `evaluateIndent` runs with `Tab`
- **THEN** the root item yields `.consumedNoOp`, and the prose line, fenced line, and non-Markdown buffer yield `.notApplicable`

### Requirement: REQ-002 Bounded Safe Evaluation of List Indentation
IF the snapshot is binary read-only or degraded, the line exceeds `4096` UTF-16 units, nesting would exceed `32` levels, or an ordered number would exceed `999_999_999`, THEN the `MarkdownSmartListEngine` SHALL return no edit without allocating unbounded work [BC-011][DATA-003][SEC-012].

#### Scenario: P4 Valid Deep List Within Limits Still Nests
- **Path**: P4
- **Trait**: positive
- **GIVEN** a list nested `3` levels deep with a valid preceding sibling at the same level
- **WHEN** `evaluateIndent` runs with `Tab` on the last item
- **THEN** the item gains exactly four spaces and keeps a CommonMark-valid marker

#### Scenario: N2 Binary Degraded Overlong Deep and Overflowing Inputs Return No Edit
- **Path**: N2
- **Trait**: security
- **GIVEN** a binary read-only snapshot, a degraded snapshot, a list line of `4097` UTF-16 units, an item already nested `32` levels, and the item `"999999999. x"` under `Tab` following a sibling
- **WHEN** `evaluateIndent` runs for each input
- **THEN** every call returns `.notApplicable` or `.consumedNoOp` with zero edits and no arithmetic overflow

### Requirement: REQ-003 Atomic Workbench Application of List Indentation
WHEN `SwiftEditWorkbenchModel.applyListIndentation(outdent:)` receives a list edit for an editable Markdown tab, it SHALL apply the batch in exactly one `BufferRevision` and translate the caret, and IF the tab is binary read-only or not Markdown, THEN it SHALL return without mutation [BC-006][DATA-003][UI-005][UI-007].

#### Scenario: P5 Workbench Applies Tab in One Revision and Translates Caret
- **Path**: P5
- **Trait**: positive
- **GIVEN** a workbench holding `"1. a\n2. b\n3. "` with the caret at the end of line `3`
- **WHEN** `applyListIndentation(outdent: false)` runs
- **THEN** the text becomes `"1. a\n2. b\n    1. "`, `BufferRevision` increases by exactly `1`, and the caret sits at the end of the new line

#### Scenario: N4 Binary or Non-Markdown Tab Is Not Mutated
- **Path**: N4
- **Trait**: security
- **GIVEN** an inspected binary read-only file and a plain-text `notes.swift` buffer containing `"- item"`
- **WHEN** `applyListIndentation(outdent: false)` runs for each
- **THEN** the call reports not handled, the text and `BufferRevision` stay unchanged
