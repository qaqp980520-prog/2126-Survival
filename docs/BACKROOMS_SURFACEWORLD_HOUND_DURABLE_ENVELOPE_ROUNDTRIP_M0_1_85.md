# M0.1.85 — Production SurfaceWorld + Hound Durable Envelope Round-Trip

## Purpose

Close the remaining integration gap between the production SurfaceWorld combined world envelope and the Hound ownership-ledger disk-persistence test. The existing tests separately covered (1) production SurfaceWorld/Backrooms envelope file save and restore and (2) Hound owner-ledger/runtime snapshot persistence through WorldEnvelopeFileStore. This version exercises both through the production SurfaceWorld.save_game()/load_game() API in one fresh-world recovery scenario.

## Scope

- Enter a real Level 2 Backrooms destination through the production portal visual and transition manager.
- Select a deterministic Hound with a loaded adjacent ownership hop.
- Commit one A-to-B cell ownership transfer through BackroomsMazeCellRuntime.transfer_entity_to_next_cell().
- Save the active Backrooms world through production SurfaceWorld.save_game() to a real user:// file.
- Verify the combined envelope contains the Backrooms Session, entity runtime state, immutable spawn identity, mutable owner cell and owner revision.
- Perform a second production save so the first known-good combined envelope rotates to .bak.
- Corrupt only the primary file and load into a fresh production SurfaceWorld through load_game().
- Require backup recovery, primary repair and preservation of the corrupt primary as .corrupt.
- Verify exactly one Hound is reconstructed under the committed owner cell, with the original spawn cell, owner revision, and a newly created NavigationAgent3D.

## Files

- tests/surface_world_hound_file_roundtrip_test.gd
  - End-to-end production portal entry, Hound A-to-B ownership transfer, combined file save, backup rotation, corrupt-primary recovery and fresh-world reconstruction.
- .github/workflows/godot-validation.yml
  - Adds the new test to the exact-head Godot 4.3 Full Compatibility Gate.
- .github/workflows/world-file-persistence-validation.yml
  - Adds the new test to the focused persistence gate and its path filters.
- docs/BACKROOMS_SURFACEWORLD_HOUND_DURABLE_ENVELOPE_ROUNDTRIP_M0_1_85.md
  - This version record.

## Dependencies

- PR #402 — cell-local NavigationAgent3D and production Backrooms cell runtime.
- PR #404 — current-spine WorldEnvelopeFileStore, SurfaceWorld.save_game()/load_game(), combined world envelope, Hound owner-ledger/runtime persistence and keyboard/touch Save/Load.
- Existing BackroomsPortalDirector, BackroomsTransitionManager, BackroomsLocationSession, BackroomsMazeCellRuntime, BackroomsEntityOwnershipLedger, BackroomsEntityRuntimeState and BackroomsCellNavigationFactory.
- Godot 4.3; no new third-party dependencies, autoloads, project settings or input mappings.

## Deterministic fixture

- SurfaceWorld world seed: 20261118.
- The test pins only the portal director RNG state to a canonical state whose next target-level draw selects Level 2. The world/maze seed remains unchanged.
- The Hound is selected from the actual production Level 2 cell roots and must have an adjacent loaded route.
- The transfer uses the production edge-boundary precondition and ownership transaction; no ledger records are fabricated by the test.

## Validation commands

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/surface_world_hound_file_roundtrip_test.gd
```

The focused GitHub Actions workflow runs the same script after root-project import. The Full Compatibility Gate runs it on the exact PR HEAD as well.

## Acceptance criteria

- Real portal entry resolves to Level 2.
- A live Hound transfers from its immutable spawn cell A to adjacent owner cell B; owner revision advances from 0 to 1.
- Production save file contains the active Backrooms envelope and matching ownership/runtime records.
- The second save rotates the first valid envelope to .bak.
- A malformed primary is rejected; a fresh SurfaceWorld restores from .bak and repairs the primary while preserving .corrupt.
- Restored Session remains Level 2.
- Restored Hound count for the immutable spawn identity is exactly one.
- The Hound remains under owner cell B while retaining spawn cell A and owner revision 1.
- A fresh NavigationAgent3D is created by the current cell factory; navigation scene objects are not serialized.
- Both focused persistence and exact-head Full Compatibility Gate pass, with complete logs checked for actual Godot diagnostics.

## Current validation status

- GitHub code and workflow commits are pushed to the existing PR #404 head branch.
- Exact-head CI is pending after these changes; no Godot runtime pass is claimed in this version record until the new workflow runs complete.
- Local Godot executable is not available in the authoring environment.
- Physical iPhone/iPad, hardware GPU and on-device performance validation remain outside this headless integration test.

## Next step

Run the focused persistence workflow and full Godot 4.3 Compatibility Gate on the updated exact PR #404 HEAD. If either fails, diagnose and correct the test or production integration before marking the PR Ready for Review again.
