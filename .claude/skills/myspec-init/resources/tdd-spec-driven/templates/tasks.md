# Tasks: [Feature Name]

## 1. Unit: [UnitName]
<!-- When <spec_root>/Constitution.md exists (SDD-002), tag tasks with [Const: <PREFIX>-### (<NN-area>/<file>.md)]. -->

- [ ] 1.1 [PHASE: RED] Write failing tests covering P1 and N1
- [ ] 1.2 [PHASE: GREEN] Implement minimum production logic satisfying P1 and N1
- [ ] 1.3 [PHASE: REFACTOR] Clean up code and test structure while all tests remain green
- [ ] 1.4 [PHASE: DOC] Write concise, development-oriented in-code documentation in English
- [ ] 1.5 [PHASE: RED] [SECURITY] Write failing security abuse and traversal tests
- [ ] 1.6 [PHASE: GREEN] [SECURITY] Implement boundary containment and security guards
- [ ] 1.7 [PHASE: REFACTOR] [SECURITY] Audit security defenses and verify full suite green
- [ ] 1.8 [PHASE: DOC] [SECURITY] Document security invariants and boundary protections in English

<!-- Optional: Unit for manual human operations runbook (manual-steps.md) when required:
## 2. Unit: ManualOperations
- [ ] 2.1 [MANUAL] TASK-NNN-MANUAL: Execute manual operations listed in manual-steps.md and confirm completion via qa
-->

## 2. Unit: LivingSpecificationReconciliation
<!-- Required when the change includes MODIFIED, REMOVED, or RENAMED requirements -->
- [ ] 3.1 [SYNC] TASK-NNN-SYNC: Execute `/myspec-sync <change-id>` to reconcile delta changes into `<specs_dir>/<capability>/spec.md` (automatically marked `[x]` by `myspec_sync.py`)
