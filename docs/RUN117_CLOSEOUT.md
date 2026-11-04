# Run 117 Closeout — KROLL Thermal Containment Lab and restore-success verification

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#264](https://github.com/qaqp980520-prog/2126-Survival/pull/264)  
Merge commit: 35ce2b478b3df5abf4c20bc918badbad828bc067  
Validated feature head: 05b3b716f160c4fc01d6568fa7017fc174fe854a

## Delivered game — KROLL Thermal Containment Lab M0.1

Path: `daily_games/KROLL_Thermal_Containment_Lab/`

- Three authored 4×4 thermal-field chambers.
- Each chamber runs four cycles. A selected row is vented, fixed reactor heat is applied, then each cell diffuses 25% toward the average of its orthogonal neighbors with integer rounding.
- A chamber succeeds only when all 16 cells finish between 19°C and 29°C inclusive after cycle four.
- Keyboard, pointer and touch controls; row selection, vent/advance, undo, restart and next-chamber navigation.
- Each chamber awards 100 points once; campaign cap 300.
- The rules test exhaustively checks all 4^4 row schedules for each chamber and confirms the authored schedule is the unique solution.
- Standalone Godot 4.3+ Compatibility renderer project; no external assets, plugins, audio, network or save dependencies.

## Existing-system change — verify successful inventory restores

- Source: `systems/SurvivalWorldBridge.gd`.
- Validate schema version, game day and inventory count payloads before invoking custom loaders.
- A custom loader returning `true` is not trusted by itself: the serialized result must equal the normalized expected snapshot.
- Lying-success and no-op-success loaders are rejected and rolled back to the prior snapshot; rollback itself is verified.
- If rollback cannot be verified, emit one defensive inventory refresh.
- Built-in `SurvivalInventory` compact payload compatibility is preserved.
- Public bridge signatures and world-save schema 1 remain unchanged.

## Regression coverage

- `tests/world_bridge_restore_success_verification_test.gd` covers invalid payload rejection, lying/no-op success, verified rollback, unverifiable rollback, built-in compact payloads and world-save adapter restoration.
- Focused workflow: `.github/workflows/run117-validation.yml`.
- Full compatibility workflow includes Run 117 game and bridge gates.

## Exact-head validation and merge

- Exact-head full Godot 4.3 Compatibility Gate [#41798421579](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41798421579): 537/537 job-step records succeeded, zero failures/skips; Run 117 game/restore gates and cleanup succeeded.
- Run 117 focused [#41798421426](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41798421426): 16/16, 67 PASS assertions, zero failures/skips.
- Fifteen exact-head workflow runs returned by GitHub concluded successfully, including the full gate and focused suites for Runs 103–117.
- PR #264 merged as `35ce2b478b3df5abf4c20bc918badbad828bc067`.
- Post-merge main-push full Godot gate [#41811878630](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41811878630) passed 537/537; fourteen focused push workflows on main also succeeded.

## Limitations and next steps

- The thermal field is a deterministic discrete puzzle model, not a computational-fluid-dynamics or full thermodynamics solver.
- Local rendered GUI/GPU and physical iPhone QA are not covered by headless CI.
- Continue inventory transaction/reentrancy hardening and production world-object persistence work.
