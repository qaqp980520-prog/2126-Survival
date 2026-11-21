# M0.1.94 — Hound Three-Hop Two-Turn Pursuit and Durable Owner Recovery

## Purpose

Extend M0.1.93's deterministic 90-degree two-hop Hound scenario to three consecutive owner transfers with two 90-degree turns. The test verifies that the movement driver re-collects the same immutable entity identity and replans from each new owner cell before committing the next adjacent transfer.

## Deterministic fixture

- Level: `Level 2`
- World seed: `20261118`
- Cell size: `8.0 m`
- Loaded window: 3×3 cells centered at `(0,0)`
- Hound spawn / immutable identity cell A: `(1,0)`
- Intermediate owner B: `(0,0)`
- First turn cell C: `(0,-1)`
- Final owner cell D: `(-1,-1)`
- Exact route: A `(1,0)` → B `(0,0)` → C `(0,-1)` → D `(-1,-1)`
- Directions: west `(-1,0)`, north `(0,-1)`, west `(-1,0)`

The route is derived from the production deterministic maze topology and loaded-cell route planner. The fixture fails closed unless the exact four-cell path and west/north/west direction sequence are returned. It does not accept a shorter path, straight continuation, reversal, or a fallback route.

## Scope and files

- Updated: `tests/backrooms_entity_owner_runtime_integration_test.gd`
- Added: `docs/BACKROOMS_HOUND_THREE_HOP_TWO_TURN_PURSUIT_M0_1_94.md`
- No production movement code changed.
- No project settings, input actions, autoloads, third-party dependencies, or asset imports added.

## Test behavior

1. Prepare and activate the production Level 2 maze runtime with seed `20261118` and a 3×3 loaded window.
2. Select the deterministic Hound in A and validate the exact A→B→C→D route.
3. Preserve existing source-edge, perpendicular/vertical bounds, stale-route rejection, collision handoff rollback, immutable identity, and initial owner revision checks.
4. Set a pursuit target inside D.
5. Execute the first real physics callback and require exactly one A→B transfer, owner revision 0→1, and no duplicate in A.
6. Reset the movement scheduler, re-collect the same immutable identity under B, replan B→C→D, and execute a separate physics callback. Require exactly one B→C transfer and owner revision 1→2.
7. Require the second north-facing doorway to be centered within 0.25 m and its edge landing to remain inside the strict serialization boundary. Reset the scheduler again, re-collect the same identity under C, replan C→D, and execute a third independent physics callback. Require exactly one C→D transfer and owner revision 2→3.
8. Require A, B, and C to contain no copy of the Hound and D to contain exactly one instance. Require the ownership ledger to have no pending transfer.
9. Preserve stream unload/reload and retained-but-unloaded owner reconstruction for D.
10. Preserve the atomic file write, primary corruption, `.bak` recovery, semantic save comparison, and fresh NavigationAgent3D factory reconstruction. Disk recovery must retain owner D and revision 3.
11. Preserve schema-three owner==spawn migration coverage.

## Dependencies

- Parent PR #407 exact HEAD before this child: `f56285351c6ca2d50010a5edb641dc3009740267`.
- PR #406: straight two-hop Hound pursuit and durable owner recovery.
- PR #405: one-hop edge approach and perpendicular alignment.
- PR #404: durable world file persistence and Hound owner/runtime round-trip.
- PR #402: cell-local NavigationAgent3D and bounded movement scheduling.
- BackroomsCellRoutePlanner, BackroomsMazeLayout, BackroomsMazeCellRuntime, EntityOwnershipLedger, EntityRuntimeState, and BackroomsEntityMovementDriver.
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

The existing Full Compatibility Gate and SurfaceWorld File Persistence workflow run this integration test. The existing Xvfb/Mesa Hound job must also execute the same exact-head integration path; the child branch retains the established `feat/hound-two-hop-pursuit-durable-recovery` prefix so the rendered Hound test remains covered by the current allowlist.

## Static preflight

- The production maze layout's deterministic edge function was independently recalculated for seed `20261118`.
- Production BFS neighbor order is north, east, south, west.
- The expected routes were recalculated from the same topology:
  - A→D: `(1,0) → (0,0) → (0,-1) → (-1,-1)`, west/north/west.
  - B→D: `(0,0) → (0,-1) → (-1,-1)`, north/west.
  - C→D: `(0,-1) → (-1,-1)`, west.
- All four cells are inside the 3×3 loaded window centered at `(0,0)`.
- The route planner remains bounded by the existing nine loaded-cell descriptor limit; no production search-budget increase is made.

## Validation status

- Static source diff reviewed against exact parent #407 HEAD.
- Deterministic route topology and all three replanning paths independently recalculated.
- GitHub Actions exact-head Godot 4.3 Full Compatibility Gate, focused persistence, and Xvfb/Mesa tests are required; no runtime pass is claimed until those exact-head runs complete and logs are audited.
- Local Godot executable is unavailable in the authoring environment.

## Limitations and next steps

- This asset covers one deterministic three-hop/two-turn route in a fixed 3×3 loaded window.
- It does not claim arbitrary routes, more than three hops, unbounded pursuit, dynamic stream-window expansion during pursuit, or arbitrary multi-turn navigation.
- No physical iPhone/iPad, hardware-GPU, or device-performance validation is claimed.
- Preserve parent-first review and integration. Do not merge this child before PR #407 and all ancestors are independently reviewed and safely integrated.


## Parent integration and exact-head revalidation — 2026-11-21

- Validated parent PR #407 exact HEAD: `b5e39de888927af417d231ec9a7937b21eb28b89`; PR #407 is Open / Ready for Review / Mergeable / Unmerged after 2/2 exact-head workflow runs succeeded, Full Gate 574/574, focused persistence 13/13 and Xvfb/Mesa 11/11.
- This child branch includes the parent through merge commit `33ddb8310ab4f343a2e7eb369b4864a669b5c89a`; first parent prior #409 HEAD `fac66a7ae119a8023e589fc0687d29ab9a575dc4`, second parent #407 HEAD `b5e39de888927af417d231ec9a7937b21eb28b89`.
- Parent delta from merge base `f56285351c6ca2d50010a5edb641dc3009740267` was three documentation files only. Child diff remains this M0.1.94 document and `tests/backrooms_entity_owner_runtime_integration_test.gd`.
- Corrected the Schema 3 fixture comment to describe the actual formula `source_cell + direction * 2`: the stream center moves two cells west of spawn A so A is outside the 3×3 loaded window but remains within the retention halo. Migration behavior is unchanged; only the comment was corrected.
- New exact-head compare against the live parent branch: 6 ahead / 0 behind, merge base equals `b5e39de888927af417d231ec9a7937b21eb28b89`.
- Exact-head GitHub Actions workflows are pending. Previous 4/4 successful workflows on `fac66a7a` validate only the old parent and are not reused. Keep PR #409 Draft until Full Gate, focused persistence, Xvfb/Mesa and complete log audit pass.
- No main merge; no physical iPhone/iPad or hardware-GPU validation is claimed. Local Godot executable unavailable; runtime evidence must come from GitHub Actions Godot 4.3.
