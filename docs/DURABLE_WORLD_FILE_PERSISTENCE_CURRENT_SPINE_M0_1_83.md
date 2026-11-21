# M0.1.83 — Durable World File Persistence on the Current Backrooms Spine

## Purpose

Port the validated durable JSON file-store implementation from historical PR #348 onto the current Backrooms combined-save and entity-ownership/navigation branch stack (parent PR #402). Do not merge the historical #348 branch directly: it is based on the older #347 stack and has divergent history from the current production spine.

## Dependencies

- Parent branch: PR #402 exact HEAD 1eb70d3c96966237f627e560b45f1e00b3d8259d.
- Combined envelope: PR #388.
- Entity ownership ledger and runtime-state pairing: PRs #398–#401.
- Cell-local NavigationAgent3D: PR #402.
- Historical source only: PR #348 exact HEAD 62e319be03b0d5a7676c44cc420c419c8ffaf169.

## Files

- systems/WorldEnvelopeFileStore.gd: atomic JSON write, canonical readback, .bak rotation, corrupt-primary preservation, fail-closed restore.
- world/SurfaceWorld.gd: production save_game/load_game, default user://2126_survival_world.json, F5 save, F9 confirmation, touch Save/Load buttons.
- scripts/world.gd, systems/SurvivalStamina.gd, systems/SurvivalQuickUse.gd, systems/SurfaceTerrainPatch.gd, systems/UndergroundMineLift.gd, systems/WorldObjectStatefulProp.gd: accept finite whole-valued JSON integers while preserving range and semantic validation.
- tests/surface_world_file_persistence_test.gd: production SurfaceWorld file round-trip, atomic backup recovery, symlink/path obstruction, active Backrooms session and portal persistence, integral-float compatibility.
- tests/backrooms_entity_owner_runtime_integration_test.gd: Hound A→B ownership/runtime snapshot written to disk, corrupt primary recovered from .bak, exact owner/revision/state reconstruction, one-identity invariant, fresh NavigationAgent3D.
- tests/world_save_load_input_test.gd: touch button signal wiring, F5 save, F9 confirmation, confirmed load, and disabled controls during unsafe transitions.
- .github/workflows/godot-validation.yml and .github/workflows/world-file-persistence-validation.yml: full and focused Godot 4.3 validation.

## Usage

- Desktop: F5 saves; F9 opens a confirmation dialog before loading.
- Touch: top-right SAVE and LOAD controls; LOAD requires explicit confirmation.
- Default file: user://2126_survival_world.json; previous valid primary retained as .bak.
- Save is allowed only in stable SurfaceWorld IDLE or stable Backrooms IN_BACKROOMS state.
- Load is allowed only from an idle SurfaceWorld. Return from Backrooms before loading another world.
- No cloud sync or multi-slot UI is included.

## Validation

- Full Godot 4.3 Compatibility Gate must pass on the exact PR HEAD.
- Focused file-persistence workflow must pass.
- Hound disk recovery test must preserve immutable spawn identity, mutable owner cell, owner revision, runtime state, exactly one entity, and a freshly created NavigationAgent3D.
- Save/Load input regression must pass.
- Local Godot runtime is not claimed unless an actual local executable is available; GitHub Actions results are authoritative for this branch.

## Limitations

- No physical iPhone/iPad device test or GPU rendering validation is claimed.
- Hound disk test exercises the actual Backrooms runtime snapshot through the production atomic file store; the separate production SurfaceWorld persistence test covers the combined SurfaceWorld envelope API.
- Navigation paths are not serialized. NavigationAgent3D is recreated by the current cell factory after runtime restore; movement targets are recalculated by the central movement driver.


## Parent retarget revalidation — 2026-11-21

- Parent PR #402 exact HEAD advanced from `1eb70d3c96966237f627e560b45f1e00b3d8259d` to `a1312fdc246578105cfd2d7f461b4741b86f3966` after its documentation-only parent-retarget commit. The PR #402 branch is `integration/backrooms-cell-local-navigation-2026-11-19`; the current branch comparison confirms this exact tip.
- PR #402 exact-head validation on `a1312fdc246578105cfd2d7f461b4741b86f3966` is complete: 19/19 PR-triggered workflows succeeded; Full Gate [44833102893](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/44833102893) has 571/571 job step records successful. The full log was audited: 7,948,890 characters / 86,933 lines / 80,231 PASS assertions / 26 classified Godot warnings, with no actual Godot error/parse/failure/leak diagnostics.
- The branch comparison for this PR now uses base tip `a1312fdc246578105cfd2d7f461b4741b86f3966`; previous #404 exact-head CI on `65b190367cede5e115255f92eaa01d9d82203ca8` was run against the earlier parent tip `1eb70d3c96966237f627e560b45f1e00b3d8259d` and is not reused as exact-new-base evidence.
- This documentation-only parent record is added to trigger a fresh PR #404 exact-head validation matrix against the current #402 parent. No production code behavior is changed by this commit.
- Keep PR #404 Draft until its new exact-head Full Compatibility Gate, focused persistence workflow, software-rendered Hound workflow (if selected by branch conditions), all other associated workflows, and complete logs are checked. No main merge.
- Local authoring environment has no Godot executable. CI is the Godot 4.3 runtime source; no physical iPhone/iPad or hardware-GPU test is claimed.
