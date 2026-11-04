# Run 119 Closeout — KROLL Abyssal Sonar and restore read isolation

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#269](https://github.com/qaqp980520-prog/2126-Survival/pull/269)  
Merge commit: `deebd5effe5cc53e28287cced2b939edcbea160f`  
Validated feature head: `62b2b211510153f0003462f841741a2c7819048a`  
Base main before merge: `c98359d2263be8cf8715abbe63aa3d9501ebf802`  
Branch: `feature/run119-abyssal-sonar-restore-read-isolation-rebased-2026-11-04`

## Delivered game — KROLL Abyssal Sonar M0.1

Path: `daily_games/KROLL_Abyssal_Sonar/`

- Standalone Godot 4.3+ Compatibility-renderer project with three 9×9 turn-based deep-trench missions.
- The beacon remains hidden. Each sonar ping reports an eight-way bearing and a coarse Manhattan-distance band; visible rock walls constrain navigation.
- Each authored route uses two planned ping positions. The intersection of both echo clues leaves exactly one passable beacon candidate.
- Player navigates from the SUB tile, collects the beacon, then returns to SUB for extraction.
- Movement costs 1 battery; sonar costs 2; each mission has a finite battery budget and at most three pings.
- Each mission awards once: 100 points when extracted with at least its par battery reserve, otherwise 75; campaign cap 300.
- Keyboard and on-screen pointer/touch controls are included.
- No external assets, plugins, audio, network or save dependencies.

## Existing-system change — SurvivalWorldBridge restore read isolation M0.1

Source: `systems/SurvivalWorldBridge.gd`

- While `_inventory_restore_in_progress` is true, `serialize_inventory()` and `serialize_world_save()` return an explicit `inventory_restore_in_progress` error instead of exposing a partially restored snapshot.
- `get_item_count()` fails closed to 0; summary, weight, movement and jump reads return safe defaults during the transaction.
- The public `inventory` getter returns null while the custom loader callback is active; the internal backing field remains available to the restore verifier.
- The transaction lock is released before `inventory_changed` is emitted, so listeners can serialize the completed snapshot.
- Public bridge signatures, `REQUIRED_INVENTORY_METHODS` and world-save schema 1 remain unchanged.
- Limitation: arbitrary direct references held by third-party code can still read or mutate their custom inventory object outside Bridge-mediated APIs.

## Regression coverage

- `tests/world_bridge_restore_read_isolation_test.gd` mutates a custom inventory partially inside `load_save_dict()`, then attempts reentrant inventory/world-save serialization, count/summary reads and public getter access.
- The test verifies no extra custom serializer call occurs during the transaction, no intermediate snapshot escapes, the public getter is hidden, and normal reads resume after lock release.
- Existing `tests/world_bridge_restore_reentrancy_test.gd` and `tests/world_bridge_restore_success_verification_test.gd` were updated for getter isolation.

## Exact-head validation and merge

- Run 119 focused [#41817145460](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41817145460): 17/17 successful step records, 248 PASS assertions, zero failures; cleanup, post-checkout, container shutdown and complete-job succeeded.
- Sixteen historical focused workflows for Runs 103–118 passed on the same exact candidate. Aggregate focused evidence including Run 119: 258/258 step records, zero failures.
- Exact-head full Godot 4.3 Compatibility Gate [#41817145400](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41817145400): 549/549 job-step records succeeded, zero failures/skips. Run 119 gates #539–544 passed; import metadata cleanup #545, clean-workspace check #546, post-checkout #1091, container stop #1092 and complete-job #1093 succeeded.
- PR #269 was squash-merged after exact-head focused, historical and full gates passed. Merge commit: `deebd5effe5cc53e28287cced2b939edcbea160f`.
- Main was re-read at the exact merge SHA. Main-push validation was triggered for the merge SHA: full Godot gate [#41818569223](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41818569223) and fifteen focused push workflows were in progress at the closeout readback. Do not infer post-merge success until these finish.

## Follow-up findings and limitations

- GitHub issue [#266](https://github.com/qaqp980520-prog/2126-Survival/issues/266) tracks the reentrant read-isolation finding. The feature is merged and exact-head tests pass; close the issue after post-merge main validation is confirmed.
- Main branch protection remains unresolved under [issue #236](https://github.com/qaqp980520-prog/2126-Survival/issues/236). The main branch endpoint reports `protected=false`; the branch-protection detail endpoint returned HTTP 403 for this integration, and no write action is exposed.
- Local Godot executable is unavailable. Cloud Godot 4.3 headless CI is the engine validation path; local rendered GUI/GPU and physical iPhone QA are not claimed.
