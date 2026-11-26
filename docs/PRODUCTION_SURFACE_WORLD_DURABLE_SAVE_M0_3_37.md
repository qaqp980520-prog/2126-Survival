# M0.3.37 — Production SurfaceWorld Durable Save/Load

## Purpose

Add the first file-backed save/load path to the production `world/SurfaceWorld.tscn` scene. The Backrooms portal playground keeps its separate prototype file and is not the production save target.

## User entry points

- **F5** calls `SurfaceWorld.save_game()`.
- **F9** calls `SurfaceWorld.load_game()`.
- Default path: `user://surface_world_save.json`.
- No automatic or background save is introduced in this version. Any future autosave must call the same `save_game()` entry point; it must not serialize registries directly.

## File format

The outer JSON envelope is versioned independently from the existing stream payload:

```json
{
  "format_id": "2126.surface_world",
  "format_version": 1,
  "saved_at_unix": 1795766400,
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

1. Check the underground Director, Mineral Registry and WorldObject chunk-write lease barriers.
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
5. Apply the payload through the existing transactional `restore_stream_state()` path.
6. Only after a successful world restore may a validated backup be promoted over a corrupt/missing primary.

An invalid primary and invalid backup are left byte-for-byte untouched. A backup is never promoted before both its envelope and complete payload have passed validation.

## In-memory recovery barrier

If world restore reports an incomplete rollback, the previous in-memory snapshot is retained and new save/load requests are blocked. `retry_save_recovery()` retries the previous snapshot only after the underground Director's own recovery barrier is clear, then checks the restored participant state and Director/Controller chunk-set agreement.

If a file promotion cannot restore the staged previous primary, the file recovery barrier remains active. `retry_save_recovery()` calls the store's interrupted-write recovery path; it only clears the barrier after a valid primary is read back.

This is an in-process recovery barrier, not a persistent transaction journal. A process crash discards the in-memory barrier; the next process can only use the verified primary/backup/temp artifacts. A future disk journal is a separate design task.

## Files and dependencies

- `systems/SurfaceWorldSaveStore.gd` — versioned envelope, bounded reads, verified temp writes, backup promotion, corrupt-file archival and interrupted-write recovery.
- `world/SurfaceWorld.gd` — production save/load entry points, F5/F9 controls, complete detached preflight, recovery barriers and retry path.
- `systems/WorldObjectStateRegistry.gd` — read-only query for active chunk write leases.
- `tests/production_surface_world_test.gd` — restart roundtrip, backup fallback, corrupt-file preservation, invalid-envelope isolation, stale-temp replacement, failed promotion, interrupted-promotion recovery, target-stream rollback, and Director/Mineral/WorldObject write barriers.
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
- Exact-head Godot 4.3 Full Compatibility Gate: pending.
- Local Godot executable is unavailable in the current authoring environment; no local engine pass is claimed.
- GPU, rendered FPS, Xvfb/Mesa, mobile and target-device tests are not covered by headless CI.

## Limitations and next steps

- The first production save format is version 1; unknown future versions fail closed until an explicit migration is implemented.
- No autosave is added. Future autosave must route through `save_game()`.
- The in-memory recovery barrier is not a disk-backed crash-recovery journal.
- Verify the exact final CI HEAD, inspect all workflow logs, and update this asset with the final evidence before requesting review.
