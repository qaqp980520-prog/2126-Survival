# Backrooms Entity Runtime-State / Ownership Pairing — M0.1.74

## Purpose

Close the remaining persistence consistency gap in the bounded live-owner-transfer system. A retained migrated entity must never be saved or restored with a runtime-state record that points at a different owner cell, nor may a migrated ownership-ledger record exist without its required runtime-state snapshot.

This work is a persistence-integrity layer. It does not add autonomous roaming, multi-hop movement, NavigationAgent3D, or a save-schema version change.

## Files

- `systems/BackroomsMazeCellRuntime.gd`
  - Validates runtime-state and ownership-ledger snapshots as a pair before producing a save snapshot.
  - Builds the serialized result on a detached StreamState clone so a rejected save cannot partially mutate the live archive.
  - Validates the pair after candidate ledger reconstruction and before staging/committing restored cell roots, and on every subsequent stream-window shift.
  - Backfills only pre-ledger schema-three deterministic spawn records whose archived owner still equals the immutable spawn cell.
- `systems/BackroomsEntityOwnershipLedger.gd`
  - Adds `register_deterministic_spawn_identity()` for bounded legacy spawn-state migration. It validates the immutable spawn descriptor and creates only an owner==spawn, revision-zero record.
- `tests/backrooms_entity_owner_runtime_integration_test.gd`
  - Adds valid unloaded-owner restore and subsequent reconstruction.
  - Adds mismatched owner-key and missing migrated-state restore rejection.
  - Adds fail-closed save tests for both mismatch and missing-state cases, including proof that the committed StreamState snapshot remains unchanged.
  - Adds pre-ledger schema-three owner==spawn backfill coverage while the spawn cell is retained but unloaded.
- `.github/workflows/godot-validation.yml`
  - Requires this versioned design/implementation record in the root project validation guard.

## Pairing invariant

Identity key is the immutable pair `spawn_cell_key|entity_id`.

For every runtime-state record:

1. Exactly one ownership-ledger record must exist for the same immutable identity.
2. Runtime-state `cell_key` must equal ownership-ledger `owner_cell_key`.
3. Duplicate, malformed, or orphan state/ledger identities fail closed.

For every ownership-ledger record:

- If `owner_cell_key != spawn_cell_key`, a runtime-state record is mandatory, regardless of whether the owner cell is currently loaded.
- If owner equals spawn, deterministic reconstruction remains sufficient; a state snapshot is optional only when no mutable runtime state has been archived.

## Save behavior

- Capture the loaded entities and merge the bounded retained archive.
- Produce the ownership-ledger snapshot using the same retained-owner window.
- Validate the two record sets before writing either into a save candidate.
- Clone StreamState and set both snapshots on the clone.
- Return the candidate payload only after both setters and serialization succeed.

A mismatch, orphan, or missing migrated state returns an empty save payload. The live StreamState archive is not partially rewritten by a failed save attempt.

## Restore behavior

- Parse and validate the StreamState payload into a detached candidate.
- Rebuild the ownership ledger and apply the retention filter.
- Validate all runtime-state and ownership records as a pair before staging cell roots.
- Only then stage, restore, commit the candidate window, and replace live roots.

A valid migrated owner may remain outside the loaded window but inside the one-cell retention halo. Its ledger assignment and runtime-state archive are preserved; the entity is reconstructed exactly once when that owner cell is loaded again.

## Legacy compatibility

Schema-three saves predate the ownership ledger. During restore, a retained archived record whose owner cell equals its immutable spawn cell may be backfilled as a deterministic owner==spawn, revision-zero ledger record when the ownership payload is absent or empty. No migrated owner is inferred: any state whose owner differs from spawn still requires an explicit matching ledger record and fails closed when it is missing. A non-empty current ownership payload is never auto-repaired.

## Dependencies and import

- Godot 4.3.
- Existing Backrooms maze stream state schema 4.
- Entity runtime-state codec v2.
- Entity ownership ledger schema 1.
- Existing deterministic entity director and loaded-cell runtime.
- No third-party plugins, binaries, autoloads, input maps, or manual import steps.
- Root project import remains `godot --headless --path . --import`.

Focused test entry:

```sh
godot --headless --path . --script res://tests/backrooms_entity_owner_runtime_integration_test.gd
```

## Test status at branch creation

- Code and regression tests are pushed to a dedicated branch based on PR #400 exact HEAD `ee95a31e324a36a58d266387d7865233f7d0ba7c`.
- Exact-head Godot 4.3 CI for this new branch has not yet completed at the time this document is created.
- No test is claimed as passed until the branch's own Full Compatibility Gate, focused workflows, post-job cleanup, and complete log review finish.

## Limitations and next steps

- The transfer primitive remains one-hop and requires both source and destination cells to be loaded.
- NavigationAgent3D, autonomous multi-hop pursuit, and hardware/mobile performance validation remain out of scope.
- Keep the follow-up PR Draft until exact-head CI passes and the parent PR #400 persistence contract is reviewed.
