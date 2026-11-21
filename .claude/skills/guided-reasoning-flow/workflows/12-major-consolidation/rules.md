# Rules: Workflow 12 — Major Version Consolidation & Delta Purge

1. **Mandatory Snapshot First**:
   - The Guided Reasoning Orchestrator SHALL run `scaffold_reasoning.py --new-major` and verify `superseded/<version>/` with `.md.old` renames before modifying any live root document.
2. **Strict Single-Truth Prohibition of Comparative Delta Phrasing**:
   - The Live Documents SHALL state an authoritative single-truth specification for the new Major version without historical revision comparisons.
3. **Exclusion Guardrail**:
   - WHILE executing subsequent minor rework flows, the Guided Reasoning Orchestrator SHALL exclude `superseded/` directories and `.old` files from context reads and annotation parsing.
4. **Anti-Recursion Directory Isolation**:
   - WHEN snapshotting a major version, the Guided Reasoning Orchestrator SHALL exclude preexisting `superseded/` directories from the new snapshot.
5. **Zero Direct Code Modifications**:
   - The Guided Reasoning Orchestrator SHALL confine writes to markdown documentation inside the active reasoning session folder.
