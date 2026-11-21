# Workflow 03: Create Scripts & Validate Skill (`skill-creator`)

## Step 5: Create Scripts (if needed)

Scripts are executed by the AI agent for deterministic operations (adhering to the `python-coding-standards` rule):

```python
#!/usr/bin/env python3
"""Script description for the AI Agent."""

import argparse
import json
import sys


def main():
    parser = argparse.ArgumentParser(description="Script description for the AI Agent.")
    parser.add_argument("input_file", help="Path of the input file")
    args = parser.parse_args()  # --help and invalid options exit before any logic

    try:
        result = process(args.input_file)
        print(json.dumps(result, indent=2))
        sys.exit(0)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


def process(input_file):
    return {"status": "success", "data": {}}


if __name__ == "__main__":
    main()
```

**Requirements**:
- Deterministic: Same input -> same output
- Error handling: All exceptions caught
- JSON output: For AI agent parsing
- CLI contract: use `argparse` so `--help` works and invalid options exit 2
- Timeout: Complete within 30 seconds
- Test locally: `python scripts/name.py test_input`

## Step 6: Validate Your Skill

Run validation before packaging (see [validation-rules.md](../../references/validation-rules.md)):

```bash
python3 ./scripts/validate_skill.py "<skill-dir>"
```

Expected output:
```json
{
  "status": "pass",
  "errors": [],
  "warnings": []
}
```

**Validation checks**:
- `SKILL.md` exists
- Frontmatter: valid YAML with `name` + `description` only
- Name: lowercase, hyphens, max 64 chars
- Description: max 1024 chars, includes triggers
- Body: uses imperative form, under 500 lines
- Files: all referenced files exist
- Scripts: tested and working
- No credentials: no API keys/secrets embedded

## Common Issues & Solutions

- **Q: My `SKILL.md` exceeds 500 lines** -> Split detailed content into `references/` or `workflows/`.
- **Q: Link validation fails** -> Use relative paths `./references/file.md`, ensure files exist, no leading slashes.
- **Q: Script times out or fails** -> Test locally: `python scripts/script.py test_input`. Add error handling.
- **Q: Frontmatter validation fails** -> Check YAML syntax, ensure only `name` and `description` fields.
- **Q: Description doesn't help the agent discover my skill?** -> Add explicit "Use when:" with 3+ specific triggers.

## Phase Requirements (EARS)

- The script authoring workflow SHALL enforce deterministic JSON stdout output, argparse CLI parsing with exit code 2 on invalid options, and a 30-second timeout budget.
- IF validation detects embedded credentials or missing referenced files, THEN the skill validator SHALL return a failing status before packaging.
