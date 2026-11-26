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
