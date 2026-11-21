# Workflow 04: Opt-In Project Constitution Proposal & Bootstrap (`myspec-init` — `SDD-008`)

- **MANDATORY**: When `<spec_root>/Constitution.md` does NOT exist in the target repository, `myspec-init` MUST propose creating it to the user via `AskUserQuestion` (`the qa skill`):
  - **If the user declines**: Do NOT write empty or placeholder Constitution files to `<spec_root>/` (leaving `<spec_root>/Constitution.md` absent so zero trivial boilerplate exists on disk and any subsequent `/myspec-init` run re-proposes creation).
  - **If the user accepts**:
    1. Execute `python3 ./scripts/myspec_init.py --target <dir> --spec-root <chosen_root> --scaffold-constitution [--set KEY=VALUE]` to scaffold the 30-file Bare-Bones skeleton (`<spec_root>/Constitution.md <= 45` lines + `<spec_root>/constitution/01..08/`) and pin `<spec_root>/Constitution.md` in `always_read:` of `<spec_root>/index.yml`.
    2. Immediately invoke `the guided-reasoning-flow skill` in **`Constitution-Bootstrap Mode`** (`scaffold_reasoning.py --slug "project-constitution" --constitution-bootstrap`) to analyze project code, data, and existing specs; standard reasoning deliverables (`README.md`/`README.ai.md`) MAY be skipped, while `<spec_root>/Constitution.md` and `<spec_root>/constitution/**` MUST be directly created/edited in Bare-Bones syntax (zero preambles, zero blockquotes, 1 line per rule) and validated via `myspec_validate.py --validate-constitution`.

## Normative Requirements (EARS)
- WHERE `<spec_root>/Constitution.md` is absent and the user accepts creation, the Constitution Bootstrapper SHALL run `--scaffold-constitution` followed by `--constitution-bootstrap` and `--validate-constitution`.
- IF the user declines Constitution creation, THEN the Constitution Bootstrapper SHALL leave `<spec_root>/Constitution.md` absent with zero boilerplate files created.

## Behavioral Contract (BDD)
```gherkin
Feature: MySpec Init Opt-In Constitution Bootstrap

  @REQ-INIT-004
  Scenario: Declining constitution creation leaves workspace free of boilerplate
    Given a workspace without a Constitution file
    When the user declines the opt-in Constitution bootstrap prompt
    Then the bootstrapper writes no Constitution placeholder files to the workspace
```
