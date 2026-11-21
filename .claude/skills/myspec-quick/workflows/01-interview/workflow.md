# Workflow 01: Silent Pre-Flight & Deep-Grill `/qa` Interview (`01-interview`)

## Rules (Sole Interactive Phase)
- **Read-Only Pre-Flight**: Zero code edits or mutations during `Workflow 01`.
- **Strict 1-Question/Turn (`the qa skill`)**: Ask at most 1 non-obvious design/edge-case question per turn via `AskUserQuestion`. Never ask facts evident from `<spec_root>/index.yml`, `Constitution.md`, living specs, or `tokensave`.
- **Front-Loaded Priority & Fail-Closed `Rule G3` Default**: Order checklist items by criticality: (1) `spec_root` setup or `Rule G3` security impact (`[SEC-###]` / `- **Trait**: security`), (2) core architecture/behavior, (3) edge cases. Pre-assign a concrete `(Recommended)` default to EVERY item before Turn 1. For any `Rule G3` security-impact question, the `(Recommended)` option MUST be **`(Recommended) Preserve existing security control (No Security-Waiver)`** (`SEC-010`, `SEC-012`).

## Steps
1. **Silent Pre-Flight**:
   - Resolve config and `<spec_root>/index.yml` (`always_read:`, `<spec_root>/Constitution.md` under `Single-Reference Lock`, matching `specs:`) via `MySpecConfigManager` and `MySpecIndexManager` (`myspec_index.py --target . --json`, auto-initializing via `--init` if absent).
   - Read impacted `<specs_dir>/<cap>/spec.md` files and inspect target symbols via `tokensave` (`tokensave_context`, `tokensave_search`).
2. **Checklist & Deep-Grill Interview Loop**:
   - Print the numbered `[ ]` / `[X]` checklist (marking pre-verified codebase facts `[X]`).
   - While any `[ ]` item remains AND the user has not issued `STOP`, call `AskUserQuestion` (1 question/turn) with:
     - `(Recommended) <concrete codebase-grounded default>`
     - Alternative concrete options + free-text support
     - `STOP — Stop interview and execute immediately (apply Recommended to remaining items)`
3. **Instant `STOP` / `[X]` Exit & Handoff to `Workflow 02`**:
   - Immediately stop asking questions as soon as all items reach `[X]` OR the user selects/types `STOP` (case-insensitive) — **never** ask an extra confirmation question.
   - If `STOP` was triggered, resolve every remaining `[ ]` item to its `(Recommended)` default (preserving existing security controls fail-closed on any unapproved `Rule G3` item).
   - Validate target capability and brief slugs via `MySpecConfigManager.sanitize_relative_path` (`CWE-22`).
   - Output the concise bulleted **Disambiguated Prompt** (listing finalized tasks + active `Constitution.md` prefixes), unload this file, and immediately load `workflows/02-execute/workflow.md`.

## Normative Requirements (EARS)
- The Interview Workflow SHALL ask at most one non-obvious question per turn using `AskUserQuestion`.
- WHEN all checklist items reach `[X]` or the user selects `STOP`, the Interview Workflow SHALL emit the Disambiguated Prompt and load Workflow 02 without extra prompts.
