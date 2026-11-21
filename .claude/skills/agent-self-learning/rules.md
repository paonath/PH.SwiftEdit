# Shared Governance Rules (`agent-self-learning`)

## Governance Rules

Apply **before** creating, updating, or reusing any artifact (`Status` values: `active` | `deprecated` | `blocked`):

### Versioned Patterns and Deduplication
1. The agent-self-learning skill SHALL include `PatternId`, `PatternVersion`, `Status`, and `Supersedes` in every lesson or memory artifact.
2. The agent-self-learning skill SHALL search existing artifacts following the `tokensave-first` rule for matching root cause, decision, and scope before creating a new file.
3. IF new evidence contradicts an `active` pattern, THEN the agent-self-learning skill SHALL mark the older artifact `deprecated` (or `blocked` if unsafe), author a replacement citing `Supersedes`, and notify the user.

### Safety Gate and Reuse Priority
4. IF an artifact carries `Status: blocked`, THEN the agent-self-learning skill SHALL forbid applying or recommending it without validation evidence and explicit user confirmation.
5. The agent-self-learning skill SHALL prefer the newest validated `active` pattern and ask the user before applying when confidence is low.

## File Naming

- Lessons: `YYYY-MM-DD-<short-kebab-title>.md` in `.agents/Lessons/`
- Memories: `<short-kebab-title>.md` in `.agents/Memories/`
- `PatternId`: `LESSON-NNN` or `MEMORY-NNN` (sequential, zero-padded to 3 digits)
