# M0.1.92 — Hound Two-Hop Pursuit and Durable Owner Recovery

## Purpose

Extend the production Hound pursuit integration from one adjacent ownership transfer to a real two-hop route (A → B → C), with a separate physics-driven movement tick for each hop and a durable file/backup recovery of the final owner revision.

## Scope and files

- Updated: `tests/backrooms_entity_owner_runtime_integration_test.gd`
- Added: `docs/BACKROOMS_HOUND_TWO_HOP_PURSUIT_DURABLE_RECOVERY_M0_1_92.md`
- No production movement code is changed in this version; the objective is to prove that the existing route replanning and ownership transaction compose across consecutive hops.

## Dependencies

- Parent PR #405: one-hop Hound cross-cell pursuit and perpendicular edge alignment.
- PR #404: WorldEnvelopeFileStore and Hound ownership/runtime persistence.
- PR #402: cell-local NavigationAgent3D and movement scheduling.
- Existing BackroomsCellRoutePlanner, BackroomsMazeCellRuntime, EntityOwnershipLedger, EntityRuntimeState and SurfaceWorld integration contracts.
- Godot 4.3; no new third-party dependency, autoload, project setting, input action, or asset import requirement.

## Test behavior

The deterministic Level 2 fixture searches the loaded maze for a Hound with a validated two-hop route whose first hop is the existing adjacent-cell fixture.

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

The existing Full Compatibility Gate, SurfaceWorld File Persistence workflow and Xvfb/Mesa Backrooms render job already execute this integration test; no workflow change is needed.

## Validation status

- Branch was created from exact parent PR #405 HEAD `4588131608ee31769ae9d90fab67a4a3af2a1c04`.
- The test file update is committed on a new stacked branch.
- Static review only at authoring time; no local Godot executable is available.
- Exact-head GitHub Actions validation is required before this PR can leave Draft.
- No main merge; parent-first review and integration remain required.

## Limitations and next steps

- This version verifies two hops in one loaded-window route; it does not yet claim unbounded pursuit across arbitrarily long streamed routes.
- No physical iPhone/iPad or hardware-GPU validation is claimed.
- If the deterministic fixture cannot find a two-hop path, the test must fail explicitly rather than silently fall back to a one-hop scenario.
- Next: run exact-head Full Compatibility Gate, focused file persistence and Xvfb/Mesa jobs; audit complete logs; only then mark the PR Ready for Review.