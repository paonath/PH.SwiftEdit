# Workflow 03: Autonomous Post-Hoc `<spec_root>` Reconciliation (`03-reconcile`)

## Rules (100% Non-Interactive & Zero Auto-Commit)
- **Zero Prompts & Zero Commits**: NEVER call `AskUserQuestion`, NEVER create `<changes_dir>/` folders, and NEVER run automatic `git commit` (update `CHANGELOG.md` only if requested in the Disambiguated Prompt).
- **No Synthetic Waivers (`SEC-010`)**: NEVER synthesize `Security-Waiver:` metadata unless explicitly approved by the human prior to `STOP` in `Workflow 01`.

## Steps
1. **Write Brief (`<briefs_dir>/brief-<slug>.md`)**: Record the Disambiguated Prompt, `/qa` + `STOP` decision log, compact 6-category STRIDE table, `- Security Review: approved`, and implemented `P#`/`N#` summary (`CWE-798` clean).
2. **Reconcile Brief Branch, Living Specs & `index.yml` via Canonical Python Engines**:
   ```bash
   python3 -c '
   import datetime, json, sys; from pathlib import Path
   for p in ("myspec-init", "myspec-sync"): sys.path.insert(0, f".agents/skills/{p}/scripts")
   sys.path.insert(0, "scripts")
   from myspec_config import MySpecConfigManager; from myspec_index import MySpecGitBranchTracker, MySpecIndexManager
   from myspec_sync import MySpecLivingSpecMerger; from sync_agents_helpers import SCAN_PATTERNS
   r = Path(".").resolve(); cfg = MySpecConfigManager(r); idx = MySpecIndexManager(r)
   slug, cap = cfg.sanitize_relative_path("<slug>", "slug"), cfg.sanitize_relative_path("<cap>", "cap")
   bp = cfg.get_briefs_dir() / f"brief-{slug}.md"; bt = bp.read_text(encoding="utf-8")
   assert not any(k != "absolute-user-path" and p.search(bt) for k, p in SCAN_PATTERNS.items()), "CWE-798 secret in brief"
   br = MySpecGitBranchTracker(r).record_branch_in_proposal(bp, phase="implemented")
   sf = cfg.get_specs_dir() / cap / "spec.md"; lv = sf.read_text(encoding="utf-8") if sf.is_file() else None
   md, _ = MySpecLivingSpecMerger(r, strict=True).merge_capability_delta(cap, """<EARS_GHERKIN_DELTA_MD>""", lv)
   sf.parent.mkdir(parents=True, exist_ok=True); sf.write_text(md, encoding="utf-8")
   idx.upsert_spec(f"{idx.get_next_prefix()}-{slug}", "implemented", datetime.date.today().isoformat(), [cap], str(sf.relative_to(r)), "<SUMMARY_MAX_120_CHARS>")
   assert not idx.validate_index(), idx.validate_index(); print(json.dumps({"branch": br, "spec": str(sf)}))
   ' && python3 .agents/skills/myspec-init/scripts/myspec_index.py --target . --validate --json
   ```
3. **Emit Summary & Decision D10 Next-Step Guidance**:
   ```markdown
   ---
   > [!TIP]
   > **Recommended Next Step**: `/changelog-write` then a Conventional Commit, or `/myspec-status` (Claude Code: `/myspec:status`)
   > **Rationale**: Code verified and `<spec_root>` reconciled post-hoc (`brief`, living `spec.md`, `index.yml`); review uncommitted changes, update changelog if needed, and commit.
   ---
   ```

## Normative Requirements (EARS)
- WHEN Workflow 02 completes with exit code 0, the Reconcile Workflow SHALL record brief branch provenance, merge living specs, and upsert `index.yml` as implemented.
- The Reconcile Workflow SHALL leave all modified files uncommitted and reject any synthetic `Security-Waiver:` not approved in Workflow 01.
