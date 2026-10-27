# Run 26 — KROLL Orbit Warden + Mineral Restore Contract M0.1

## Baseline reconciliation

- Start-of-run GitHub main was verified from the repository's latest commit search and PROJECT_INDEX.md: a48ec761f2b36cee44e6eb5022cda2b3c39aeca4 (Run 25 closeout).
- GitHub search returned zero open PRs at start. Historical feature/run10 through feature/run25 branches remain visible; no active PR was associated with them.
- The Notion asset index still had Run 23 pending snapshots at its top while GitHub main already contained Run 25 closeout. This is a stale Notion snapshot; append a correction and the final Run 26 state to the asset index and create a dedicated daily record.

## New playable game

Path: daily_games/KROLL_Orbit_Warden/

- Standalone Godot 4.3+ project, no external assets or add-ons.
- Top-down asteroid survival: rotate, thrust, fire, wrap-around movement, 12 destroys to win, 3 lives and 75-second time limit.
- Files: project.godot, main.tscn, main.gd, rules.gd, tests/rules_test.gd, tests/game_smoke_test.gd, README.md.
- Import: open daily_games/KROLL_Orbit_Warden/project.godot in Godot Project Manager.
- Validation: latest PR-head Godot 4.3 CI must pass import, rule and runtime smoke steps before merge. Local GUI/GPU/iPhone playtest is not available in this run.

## Existing-system change

- systems/MineralMiningNode.gd: restore_vein(units, now_unix=-1) -> int now returns the actual accepted amount, clamps to remaining capacity, accepts an injectable timestamp for deterministic tests, and resets the regeneration clock only when stock is actually added.
- tests/mineral_mining_regeneration_test.gd: covers exact restored amount, capacity cap, full-stock/zero/negative no-ops, and the fresh regeneration interval after a manual restore.
- Compatibility: existing callers that ignore the former void return remain source-compatible; calls with one argument still use current Unix time. No save schema change.

## CI integration

- .github/workflows/godot-validation.yml adds Orbit Warden project import, rules test and runtime smoke test.
- The existing mineral regeneration test step now exercises the restore return contract.
- Test evidence is recorded only after the exact PR HEAD completes successfully; pending or cancelled runs are not passes.

## Remaining limits / next step

- The formal production M1.3 world controller remains absent; underground mining is still a fixed-cave prototype.
- The inventory and mineral weight definitions are still duplicated; Run 25's compatibility test detects drift but does not yet centralize the source.
- No local Godot executable or GUI/GPU/iPhone hardware validation is available in this environment.
- Next: after CI/merge, connect inventory, mining and save/restore to the production world controller when it exists, then add full scene-level pickup/drop/weight/save/reload/failure-recovery tests.
