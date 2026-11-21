# M0.1.92 — Hound Two-Hop Pursuit and Durable Owner Recovery

## Purpose

Extend the production Hound pursuit integration from one adjacent ownership transfer to a real two-hop route (A → B → C), with a separate physics-driven movement tick for each hop and a durable file/backup recovery of the final owner revision.

## Scope and files

- Updated: `tests/backrooms_entity_owner_runtime_integration_test.gd`
- Updated: `.github/workflows/godot-validation.yml` to include this branch in the software-rendered Backrooms entity smoke job
- Added: `docs/BACKROOMS_HOUND_TWO_HOP_PURSUIT_DURABLE_RECOVERY_M0_1_92.md`
- No production movement code is changed in this version; the objective is to prove that the existing route replanning and ownership transaction compose across consecutive hops.

## Dependencies

- Parent PR #405: one-hop Hound cross-cell pursuit and perpendicular edge alignment.
- PR #404: WorldEnvelopeFileStore and Hound ownership/runtime persistence.
- PR #402: cell-local NavigationAgent3D and movement scheduling.
- Existing BackroomsCellRoutePlanner, BackroomsMazeCellRuntime, EntityOwnershipLedger, EntityRuntimeState and SurfaceWorld integration contracts.
- Godot 4.3; no new third-party dependency, autoload, project setting, input action, or asset import requirement.

## Test behavior

The deterministic Level 2 fixture searches the loaded maze for a Hound with a validated straight two-hop corridor (A → B → C) whose two edge directions are identical and whose first hop is the existing adjacent-cell fixture. This keeps the off-center doorway projection invariant across both hops.

1. Keep the existing source-edge rejection, invalid perpendicular/vertical bounds, stale-route rejection and physical rollback checks.
2. Give the Hound a pursuit target in a loaded cell exactly two route edges away.
3. Run the movement driver from an actual `_physics_process` callback and require exactly one committed hop A → B.
4. Start a separate physics-driven movement tick. The driver must re-collect the same immutable spawn identity under B, replan from B to C, and commit exactly one hop B → C.
5. Assert owner revision increments from 0 to 1 to 2; source and intermediate cells contain no duplicate; final cell contains exactly one Hound.
6. Save the final owner/runtime snapshot, stream the owner cell out and back, restore into a fresh runtime, and verify owner cell C plus revision 2.
7. Persist through WorldEnvelopeFileStore, corrupt the primary after rotating a valid backup, and recover the same Hound under C with revision 2 and a fresh NavigationAgent3D.
8. Retain schema-three deterministic owner==spawn migration and malformed ownership-pair rejection tests.

## Import and test commands

Root import:

```bash
godot --headless --path . --editor --import --quit
```

Focused production integration:

```bash
godot --headless --path . --script res://tests/backrooms_entity_owner_runtime_integration_test.gd
```

The Full Compatibility Gate and SurfaceWorld File Persistence workflow already execute this integration test. The Xvfb/Mesa job originally skipped this branch because its explicit head-ref allowlist did not include `feat/hound-two-hop-pursuit-durable-recovery`; `.github/workflows/godot-validation.yml` now includes this branch prefix so the rendered Hound round-trip is actually exercised.

## Validation status

- Branch was created from exact parent PR #405 HEAD `4588131608ee31769ae9d90fab67a4a3af2a1c04`.
- The test file update is committed on a new stacked branch.
- Static review only at authoring time; no local Godot executable is available.
- Exact-head Full Compatibility Gate and focused persistence validation are required before this PR can leave Draft.
- The prior Xvfb/Mesa job was skipped by the branch filter; the workflow allowlist fix is committed, and the new exact-head Xvfb/Mesa run is pending.
- No main merge; parent-first review and integration remain required.

## Limitations and next steps

- This version verifies two consecutive hops along one straight loaded-window corridor; it does not yet claim turning multi-hop or unbounded pursuit across arbitrarily long streamed routes.
- No physical iPhone/iPad or hardware-GPU validation is claimed.
- If the deterministic fixture cannot find a two-hop path, the test must fail explicitly rather than silently fall back to a one-hop scenario.
- Next: run exact-head Full Compatibility Gate, focused file persistence and Xvfb/Mesa jobs; audit complete logs; only then mark the PR Ready for Review.

## Parent integration and exact-head validation refresh — 2026-11-21

### Current Git ancestry

- Parent PR #405 exact validated HEAD: `1aacd7e2ef05ebc325e0f4dd2b2e363e9e667d40` on `feat/hound-cross-cell-pursuit-edge-approach-2026-11-20`.
- This child branch now contains that parent through merge commit `2e6bf23fdf28ce3e6358b3770b125240f3e493b4`.
- Merge parents: first prior child HEAD `9da4693389ff8e7022d3beb4b38e20ad176d4e95`; second validated parent #405 HEAD `1aacd7e2ef05ebc325e0f4dd2b2e363e9e667d40`.
- Compare against parent: 9 ahead / 0 behind; merge base equals parent HEAD.
- Current PR base branch: `feat/hound-cross-cell-pursuit-edge-approach-2026-11-20`; current child head branch: `feat/hound-two-hop-pursuit-durable-recovery-2026-11-20`.

### Exact-head evidence on merge commit 2e6bf23f

- Exact-head workflow matrix: 20/20 completed successfully.
- Full Compatibility Gate [44858698895](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/44858698895), job `136706825151`: 574/574 listed job steps succeeded.
- Full log: 7,975,149 characters / 87,185 lines / 80,420 timestamped PASS assertions / 26 unsuppressed warnings; timestamp-anchored audit found 0 actual Godot SCRIPT ERROR, ERROR, Parse Error, FAIL, ObjectDB leak, or Orphan StringName diagnostics.
- Focused File Persistence [44858698889](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/44858698889): 13/13 / 190 PASS / 0 actual Godot diagnostics.
- Xvfb/Mesa Hound smoke in [44858698895](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/44858698895), job `136706825328`: 11/11 / 526 PASS / 0 actual Godot diagnostics.
- Two-hop Hound diagnostic: spawn owner `1,0` → `0,0` at revision 1 → `-1,0` at revision 2; the second hop completed in 16 physics attempts. Disk backup recovery preserved owner revision 2 and reconstructed one Hound under the committed owner cell.
- Backup-recovered Hound receives a fresh NavigationAgent3D from the current cell factory; avoidance remains disabled and waypoint tolerance is 0.2.
- Schema 3 compatibility fixture removes ownership-ledger fields and moves the stream center so the spawn cell is unloaded. It verifies deterministic owner==spawn backfill only, archive retention while unloaded, and exactly-one reconstruction when the spawn cell streams back. It does not guess a migrated owner for a legacy entity that had already moved.

### Documentation-only follow-up commit

This section is committed separately after the merge commit. The documentation commit changes no production runtime code or tests. The exact-head CI above validates merge commit `2e6bf23f`, not the subsequent documentation commit. The new documentation HEAD must run a fresh exact-head workflow matrix and full-log audit before PR #406 can become Ready for Review.

### Limits and next gate

- PR #406 remains Draft until the post-documentation exact-head Full Gate, focused persistence, Xvfb/Mesa and all workflow runs pass.
- Local Godot executable unavailable; exact runtime validation uses GitHub Actions Godot 4.3.
- Xvfb/Mesa is software rendering, not physical iPhone/iPad or hardware-GPU validation.
- No main merge. Independent review remains 0 submissions / 0 inline threads on the current PR stack.
