# M0.1.93 — Hound Turning Two-Hop Pursuit and Durable Owner Recovery

## Purpose

Extend M0.1.92's straight two-hop A→B→C persistence test to a deterministic 90-degree turn. The goal is to prove that after the first owner transfer, the movement driver replans from the intermediate owner and computes a new edge projection for a different cardinal direction before the second transfer.

## Deterministic fixture

- Level: `Level 2`
- World seed: `20261118`
- Loaded window: 3×3 cells centered at `(0,0)`
- Deterministic Hound spawn cell: `(1,0)`
- Selected route: `(1,0) → (0,0) → (0,-1)`
- First direction: west `(-1,0)`
- Second direction: north `(0,-1)`

The deterministic Level 2 fixture places the Hound in `(1,0)` for this seed. The route planner uses the loaded-cell topology only. The fixture must reject a route if the first hop does not match the selected adjacent owner, if the route is not exactly two edges, or if the second direction is straight or reversing rather than a 90-degree turn.

## Scope and files

- Updated: `tests/backrooms_entity_owner_runtime_integration_test.gd`
- Added: `docs/BACKROOMS_HOUND_TURNING_TWO_HOP_PURSUIT_M0_1_93.md`
- No production movement code changes.
- No new project setting, input action, autoload, third-party dependency, or asset import.

## Test behavior

1. Retain all existing direct-transfer preconditions: source edge, perpendicular serialized bounds, vertical bounds, stale route rejection, and physical rollback.
2. Select the deterministic Hound at `(1,0)` and validate a two-edge route whose first direction is west and second direction is north.
3. Set the pursuit target inside the final loaded cell and run the movement driver through an actual `_physics_process` callback.
4. Require exactly one transactional A→B transfer and owner revision 0→1.
5. Start a separate physics-driven tick. The driver must re-collect the same immutable spawn identity under B, replan the route, compute a north-facing edge target, and commit exactly one B→C transfer.
6. Require owner revision 1→2, no duplicate in A or B, and exactly one Hound in C.
7. Preserve the existing post-transfer stream unload/reload and durable file/backup round-trip. The fresh runtime must restore owner C, revision 2, immutable spawn identity and a newly constructed NavigationAgent3D.
8. Keep the test fail-closed: if the deterministic turning route is unavailable, fail the fixture rather than silently falling back to a straight route.

## Dependencies

- Parent PR #406: straight two-hop Hound pursuit and durable owner recovery.
- PR #405: one-hop edge approach and perpendicular alignment.
- PR #404: WorldEnvelopeFileStore and durable Hound ownership/runtime persistence.
- PR #402: cell-local NavigationAgent3D.
- Existing BackroomsCellRoutePlanner, BackroomsMazeCellRuntime, EntityOwnershipLedger, EntityRuntimeState and movement-driver contracts.
- Godot 4.3.

## Import and test commands

Root import:

```bash
godot --headless --path . --editor --import --quit
```

Focused integration:

```bash
godot --headless --path . --script res://tests/backrooms_entity_owner_runtime_integration_test.gd
```

The existing Full Compatibility Gate and SurfaceWorld File Persistence workflow run this integration test. The Xvfb/Mesa software-rendered job uses the existing `feat/hound-two-hop-pursuit-durable-recovery` prefix allowlist; this child branch intentionally retains that prefix so the rendered test is not skipped.

## Validation status

- The branch is created from exact parent PR #406 HEAD `9da4693389ff8e7022d3beb4b38e20ad176d4e95`.
- The integration test now requires a two-hop turning route, explicitly validates both directions, and rejects straight/reversing routes.
- Static source review and deterministic topology calculation identify the expected route `(1,0) → (0,0) → (0,-1)`.
- Exact-head Godot 4.3 Full Compatibility Gate, focused persistence and Xvfb/Mesa validation are required. No runtime pass is claimed until these runs complete and their logs are audited.
- Local Godot executable is unavailable in the authoring environment.

## Limitations and next steps

- This version covers one deterministic 90-degree two-hop route only.
- It does not claim arbitrary multi-turn routes, more than two hops, indefinite pursuit outside the loaded-cell window, or stream-window expansion while pursuing.
- No physical iPhone/iPad, hardware-GPU or device-performance validation is claimed.
- Keep this PR Draft until every exact-head workflow passes and the complete Full Gate log is audited. Preserve parent-first review and integration; do not merge main.
