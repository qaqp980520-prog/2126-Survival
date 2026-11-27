# M0.3.37 — Production SurfaceWorld Durable Save/Load

## Purpose

Add the first file-backed save/load path to the production `world/SurfaceWorld.tscn` scene. The Backrooms portal playground keeps its separate prototype file and is not the production save target.

## User entry points

- **F5** calls `SurfaceWorld.save_game()`.
- **F9** calls `SurfaceWorld.load_game()`.
- Default path: `user://surface_world_save.json`.
- No automatic or background save is introduced in this version. Any future autosave must call the same `save_game()` entry point; it must not serialize registries directly.

## File format

The outer JSON envelope is versioned independently from the existing stream payload and carries a SHA-256 checksum of the canonical compact JSON payload. Only `user://` paths are accepted; `res://`, traversal-like paths and malformed relative paths are rejected. This checksum detects accidental or semantic payload corruption; it is not an authenticity signature.

The outer JSON envelope is:

```json
{
  "format_id": "2126.surface_world",
  "format_version": 1,
  "saved_at_unix": 1795766400,
  "payload_sha256": "<64 lowercase hexadecimal characters>",
  "payload": {
    "schema_version": 1
  }
}
```

The payload is the complete production `SurfaceWorld.serialize_stream_state()` result, including:

- player position and world seed;
- active world location layer, mine depth and surface-return position;
- mineral, crop and world-object registries;
- inventory;
- stamina;
- quick-use slot assignments and selected slot.

Unknown envelope format IDs and versions are rejected. There is no previous production disk-save format to migrate; the separate Backrooms prototype save is not silently imported. Existing stream-payload schema 1 legacy fields remain accepted by the direct restore validator where the pre-existing restore contract provided defaults, while new disk envelopes require the complete current payload.

## File replacement and recovery

Files used:

- primary: `user://surface_world_save.json`
- last valid primary backup: `user://surface_world_save.json.bak`
- write temp: `*.tmp`
- backup temp: `*.bak.tmp`
- staged prior primary: `*.previous`
- backup-promotion temp: `*.restore.tmp`
- corrupt-primary archive: `*.corrupt.<unix-time>[.<suffix>]`

Save sequence:

1. Check all recovery barriers: Mineral Registry atomic-registration recovery, WorldObject chunk write leases, MineralChunkController load recovery, Surface streaming Director retained recovery roots, and UndergroundMineDirector Registry-pair recovery.
2. Capture the stream payload and validate every participant using detached probes.
3. Write a temporary envelope and read it back through the same envelope and payload validator.
4. If the current primary is valid, copy and validate it before replacing the backup.
5. Stage the previous primary, atomically promote the verified temp, and restore the staged primary if promotion fails.
6. Preserve invalid primary bytes in a diagnostic archive rather than silently deleting them.

Load sequence:

1. Check all recovery and write-lease barriers before touching disk.
2. Validate the current in-memory snapshot for rollback.
3. Read and validate the primary; if invalid or missing, validate the backup.
4. Complete full payload preflight before any world streaming or participant mutation.
5. Complete detached-probe validation for minerals, crops, world objects, inventory, stamina, quick-use, layer/depth and positions before any live snapshot or streaming mutation. Direct `restore_stream_state()` calls use the same preflight and retain a complete rollback snapshot.
6. Apply the payload through the existing transactional `restore_stream_state()` path.
7. Only after a successful world restore may a validated backup be promoted over a corrupt/missing primary.

An invalid primary and invalid backup are left byte-for-byte untouched. A backup is never promoted before both its envelope and complete payload have passed validation.

## In-memory recovery barrier

If world restore reports an incomplete rollback, the previous in-memory snapshot is retained and new save/load requests are blocked. `retry_save_recovery()` retries the previous snapshot only after the underground Director's own recovery barrier is clear, then checks the restored participant state and Director/Controller chunk-set agreement.

If a file promotion cannot restore the staged previous primary, the file recovery barrier remains active. `retry_save_recovery()` calls the store's interrupted-write recovery path; it only clears the barrier after a valid primary is read back.

This is an in-process recovery barrier, not a persistent transaction journal. A process crash discards the in-memory barrier; the next process can only use the verified primary/backup/temp artifacts. A future disk journal is a separate design task.

## Files and dependencies

- `systems/SurfaceWorldSaveStore.gd` — versioned envelope, bounded reads, verified temp writes, backup promotion, corrupt-file archival and interrupted-write recovery.
- `world/SurfaceWorld.gd` — production save/load entry points, F5/F9 controls, complete detached preflight, recovery barriers and retry path.
- `systems/WorldObjectStateRegistry.gd` — read-only query for active chunk write leases and pending-lock status.
- `tests/production_surface_world_test.gd` — restart roundtrip, checksum tampering, unsupported envelope version, user-data path restriction, backup fallback, corrupt-primary and corrupt-backup archival, invalid-envelope isolation across every participant, stale-temp replacement, failed promotion, interrupted-promotion recovery, invalid direct-restore preflight, target-stream rollback, and Director/Controller/Mineral/WorldObject write barriers.
- `docs/PRODUCTION_SURFACE_WORLD_DURABLE_SAVE_M0_3_37.md` — this record.

No third-party dependency, new Autoload, scene, or save-schema migration is introduced. The new store script is loaded by a direct `preload` from `SurfaceWorld.gd`.

## Parent and PR dependency

- Parent PR: #449 / M0.3.34.
- Exact parent HEAD: `c8ea73916be1eff208594301cc614fe58804d5de`.
- This is a stacked child PR of #449, not a merge to main.
- PR #450 is a separate sibling child of #449 and is not included as a dependency.
- Keep this PR Draft until the parent-first review/integration sequence is completed.

## Validation status

- Implementation and regression tests are committed to the feature branch.
- Exact-head Godot 4.3 Full Compatibility Gate: pending at the time of this document update; the final run ID and conclusion must be written after the final branch HEAD completes CI.
- Local Godot executable is unavailable in the current authoring environment; no local engine pass is claimed.
- GPU, rendered FPS, Xvfb/Mesa, mobile and target-device tests are not covered by headless CI.

## Limitations and next steps

- The first production save format is version 1; unknown future versions fail closed until an explicit migration is implemented.
- No autosave is added. Future autosave must route through `save_game()`.
- The in-memory recovery barrier is not a disk-backed crash-recovery journal.
- `save_game()` and `load_game()` are manual F5/F9 entry points; no autosave is enabled. Future autosave must route through the same barrier-aware entry points.
- Verify the exact final CI HEAD, inspect all workflow logs, and update this asset with the final evidence before requesting review.


## Run 451 — exact-head JSON round-trip and Controller barrier correction (candidate)

The first exact-head Full Compatibility Gate on the initial PR #452 candidate reached the production SurfaceWorld integration test and failed at temporary-file verification. The decoded JSON payload was rejected by the stream validator because schema_version and mine_depth accepted only int, while Godot 4.3 JSON parsing represents integral JSON numbers as numeric Variants that may be float. This caused the first save to fail with phase=temp_verify, reason=payload_validation_failed; backup, promotion, and restart assertions then failed downstream. The failure was a production preflight compatibility defect, not a file-write failure.

The correction candidate:

- Accepts only finite whole-valued numeric Variants for the stream schema, world seed, and mine depth; fractional values remain rejected.
- Treats a non-empty retained _pending_chunk_load_recovery payload as a pending Controller recovery barrier, even if the companion boolean is temporarily inconsistent.
- Adds a file-reader regression that serializes whole-valued JSON numeric fields, parses the envelope back from disk, and validates the decoded payload.
- Adds positive and negative fractional schema/depth assertions and checks that Controller recovery blocks snapshots and direct restore with the expected barrier phase.

Exact-head Godot 4.3 validation for this correction candidate is pending. Do not treat the failed initial PR #452 Full Gate as a pass. Local Godot is unavailable; no local engine run is claimed.


## Run 451 — restore-application JSON numeric correction (candidate)

The first correction candidate HEAD `d308450c...` passed the new detached validator and file-readback regression, and its temp save verification succeeded. The Full Gate then exposed a second int-only check in `_restore_stream_state_impl()`: after JSON parsing, `mine_depth` was still required to be an int. The first simulated-restart load therefore failed during world restore; backup fallback and subsequent assertions were downstream failures. The file store and envelope readback were working.

The follow-up correction applies the same finite whole-number predicate to the restore-application path for `world_seed` and `mine_depth`, and adds a direct stream-restore regression using the integral JSON-number payload. Fractional schema/depth values remain rejected.

The exact-head Full Gate on `d308450c...` failed at the production SurfaceWorld integration test; do not count it as a pass. The updated correction HEAD must rerun all focused workflows and the full Godot 4.3 gate.


## Run 451 — full mineral recovery readback comparison

A static review found that `_world_recovery_matches_snapshot()` compared only the sorted stable-ID set of mineral veins. That could miss a changed record with the same IDs (for example, different `remaining_units` or `last_regen_unix`) and incorrectly clear the in-memory recovery barrier. The implementation now compares the complete validated `minerals` payload. The production integration test includes an unchanged-snapshot positive case and a valid same-ID/different-`remaining_units` negative case. Follow-up tracked in [Issue #455](https://github.com/qaqp980520-prog/2126-Survival/issues/455).

Exact-head Godot 4.3 validation for this final readback correction is pending. Do not merge until dedicated save validation, focused workflows and the full compatibility gate pass.


## Run 452 — exact-time mineral recovery readback (candidate)

A source audit found that `retry_save_recovery()` reused the captured recovery timestamp but still called the normal `WorldSessionController.restore_stream_state()` path. The normal MineralVeinRegistry restore intentionally applies elapsed offline regeneration. That is correct for loading a disk save, but not for restoring an in-memory rollback snapshot whose mineral values must be compared before the recovery barrier is cleared.

The correction adds an explicit `exact_mineral_restore` option to the base and SurfaceWorld stream-restore entry points. Normal user-facing restore keeps the existing offline-regeneration behavior. The world-recovery retry path passes the exact option and uses `MineralChunkController.restore_snapshot_exact()`. Because target streaming can unload the old window and register new chunks, the post-stream phase also reapplies the authoritative CropRegistry and WorldObjectStateRegistry snapshots; exact mineral recovery is reapplied after streaming as well. This removes records reintroduced by old-window unload and prevents newly loaded minerals from applying offline catch-up before the full readback comparison.

The regression fixture:
- captures the original production world snapshot;
- selects a currently registered surface mineral and prepares a valid depleted record with its last-regeneration timestamp two intervals before a fixed recovery time;
- moves the player far enough to unload that mineral's surface chunk, then injects a pending in-memory world-recovery barrier and invokes `retry_save_recovery()`;
- streams the captured surface window back in, exercising detached mineral registration and its normal offline catch-up before exact mineral, crop and world-object snapshots are reapplied;
- verifies the full mineral payload, remaining units and timestamp are unchanged before readback comparison;
- verifies the barrier clears only after the exact full snapshot matches; and
- restores the original test-world snapshot using the exact recovery mode.

Files updated:
- `scripts/world.gd`
- `world/SurfaceWorld.gd`
- `tests/production_surface_world_test.gd`
- this technical asset record

Exact-head Godot 4.3 dedicated validation and Full Compatibility Gate are pending for this candidate. No pass is claimed until the new exact HEAD completes all required workflows. Local Godot remains unavailable; no local engine run is claimed.
