# Run 118 Closeout — KROLL Moonbase Courier and inventory restore reentrancy guard

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#265](https://github.com/qaqp980520-prog/2126-Survival/pull/265)  
Merge commit: b79ec83472d709c5f4e3ac804e299e29f839da66  
Validated feature head: 74082e1ab03f2494e3097712eb01cbc144b2f5f5  
Branch: `feature/run118-moonbase-courier-restore-reentrancy-guard-2026-11-04`

## Delivered game — KROLL Moonbase Courier M0.1

Path: `daily_games/KROLL_Moonbase_Courier/`

- Side-view parcel-delivery platformer with three authored routes: Dustline Depot, Crater Relay and Polar Antenna Run.
- Walk and jump across one-way platforms, avoid heated vents, collect a parcel and deliver it to the marked airlock.
- Three suit charges per route; vent contact consumes one charge, respawns at the route start and returns the parcel to its pickup pad.
- Each route has a finite oxygen/time budget.
- Keyboard: A/D or arrows move; Space jumps; E picks up/delivers; R restarts; N advances; C restarts the campaign.
- On-screen LEFT/RIGHT/JUMP/INTERACT/RESTART/NEXT controls support pointer and touch.
- Each route awards once: 100 points before par time, otherwise 75; campaign cap 300.
- Level 3 vent spacing was corrected after deterministic movement simulation found the previous final vent could be reached before the courier grounded for the next jump.
- Added `tests/game_route_simulation_test.gd`, which drives all three routes through actual movement, jumps, vent collision, parcel pickup and delivery without teleporting. All three routes finish with all suit charges and 100 points.

## Existing-system change — inventory restore reentrancy guard M0.1

Source: `systems/SurvivalWorldBridge.gd`

- Add `_inventory_restore_in_progress` transaction lock.
- Public `inventory` property uses a backing field and rejects direct replacement during an active restore.
- `bind_inventory()` refuses reentrant inventory replacement.
- Bridge-mediated collect/drop/consume operations and nested restore calls are rejected during custom `load_save_dict()` callbacks.
- Restore verification and rollback operate on the captured inventory object.
- Transaction lock is released before `inventory_changed` is emitted.
- Public bridge method signatures, `REQUIRED_INVENTORY_METHODS` and world-save schema 1 remain unchanged.

## Regression coverage

- `tests/world_bridge_restore_reentrancy_test.gd` injects nested restore, collect, bind replacement and direct property assignment attempts from inside `load_save_dict()`.
- Existing `tests/world_bridge_restore_success_verification_test.gd` is extended with the same callback edge case.
- Focused workflow: `.github/workflows/run118-validation.yml`.
- Full compatibility workflow includes Run 118 input checks, project import, rules, runtime smoke, route simulation and restore reentrancy regression.

## Exact-head validation and merge

- Run 118 focused [#41813454882](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41813454882): 17/17 successful step records, 80 PASS assertions, zero failures/skips.
- Fifteen historical focused workflows for Runs 103–117 also completed successfully on the same candidate.
- Exact-head full Godot 4.3 Compatibility Gate [#41813454893](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41813454893): 543/543 job-step records succeeded, zero failures. Run 118 gates #533–538, cleanup #539–540, post-checkout #1079, container stop #1080 and complete-job #1081 all succeeded.
- PR #265 merged as `b79ec83472d709c5f4e3ac804e299e29f839da66`; main was re-read at the exact merge commit.
- The connected commit-workflow lookup and combined-status endpoint did not surface a post-merge main-push run/status. Post-merge validation is unconfirmed, not claimed as passed or failed.

## Follow-up findings and limitations

- Post-merge code review found that `serialize_inventory()` and `serialize_world_save()` do not currently block reentrant serialization reads during an active restore. A custom loader may therefore expose an intermediate snapshot. This is tracked in [issue #266](https://github.com/qaqp980520-prog/2126-Survival/issues/266); it is a follow-up, not a failure of the Run 118 regression.
- The guard protects bridge-mediated operations and the public inventory property; arbitrary direct mutation of custom inventory fields cannot be prevented.
- Local Godot executable was unavailable. Local rendered GUI/GPU and physical iPhone QA are not claimed.
- Main branch protection remains unresolved under [issue #236](https://github.com/qaqp980520-prog/2126-Survival/issues/236).
