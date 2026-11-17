# Backrooms Combined World Save Envelope M0.1.59

## Purpose

Add a versioned, transactional save envelope that captures the active SurfaceWorld location and an active Backrooms visit as one consistent snapshot. This is a selective port of historical PR #347 onto the validated production player-handoff PR #387 exact HEAD. No historical branch is merged.

## Parent and provenance

- Parent PR: #387, exact base HEAD `92882b82dad00768abb0f109c211d1cde3fb8a19`.
- Historical source: PR #347 exact HEAD `78561e5dbf0f8d14202e1c025eeb65f8fff45f4d`.
- The port is file-level and is revalidated on this hardened chain. Historical CI is not treated as evidence for this branch.

## Files

- `world/SurfaceWorld.gd`: schema-v1 envelope serialization, preflight validation, transactional restore, exact rollback verification, surface chunk identity/visibility capture and restore.
- `systems/BackroomsTransitionManager.gd`: world-load-only Session restore and rollback boundary.
- `tests/backrooms_combined_world_save_test.gd`: production entry/save/restore/return round-trip, mismatched Session seed rejection, injected maze staging failure, nested SurfaceWorld rollback failure and fail-closed assertion.
- `.github/workflows/godot-validation.yml`: dedicated Godot 4.3 test step with captured output, diagnostic rejection, success marker and hard-kill timeout.
- This document records M0.1.59.

## Envelope schema

Schema version: 1.

The envelope records:

- active location: surface, underground or Backrooms;
- SurfaceWorld save payload anchored to the correct surface/return transform;
- BackroomsLocationSession payload;
- BackroomsMazeCellRuntime stream payload;
- player position and velocity for the active location;
- exact loaded surface chunk IDs;
- original visibility state for every loaded surface chunk.

The legacy `serialize_stream_state()` and `restore_stream_state()` APIs remain surface-only and continue to fail closed while Backrooms is active. The combined envelope is the only supported save/restore boundary during a Backrooms visit.

## Transaction and rollback

- Save first synchronizes the live Backrooms player transform into the Runtime and Session, then requires exact Runtime/Session payload equality.
- Restore is accepted only into an idle SurfaceWorld with inactive Session and empty Runtime.
- Session and maze-runtime payloads are preflighted using detached candidates before live mutation.
- SurfaceWorld is restored first and its exact loaded surface chunk window is verified.
- For a Backrooms target, Session is restored, the hidden maze Runtime is rebuilt, the player is moved, and Runtime activation occurs before surface visibility is hidden and the world is marked active.
- Any later failure deactivates staged Runtime, restores the prior Session and SurfaceWorld snapshots, reapplies exact mineral/crop/world-object snapshots, and verifies payload, chunk IDs, visibility, manager state, Runtime state and player transform.
- If rollback cannot be proven complete, SurfaceWorld streaming is locked fail-closed and portal activation is disabled.

## Dependencies

- Godot 4.3.
- PR #387 production player handoff and return.
- BackroomsLocationSession, BackroomsMazeCellRuntime, BackroomsTransitionManager, BackroomsPortalDirector.
- Existing SurfaceWorld chunk controller, mineral registry, crop registry, world-object state and stamina/quick-use adapters.

No third-party packages, new autoloads, Project Settings or input mappings are introduced.

## Import and execution

No manual import is required. The GDScript files are under existing `res://systems`, `res://world` and `res://tests` paths. Open/import the root Godot 4.3 project normally.

Dedicated test command:

```bash
godot --headless --path . --script res://tests/backrooms_combined_world_save_test.gd
```

The CI wrapper uses `timeout -k 5s 120s`, captures stdout/stderr, rejects `SCRIPT ERROR`, `ERROR:` and `FAIL:`, and requires the exact success marker.

## Validation status

- Historical source compatibility review completed against PR #347.
- Current branch changes are being applied to child branch `integration/backrooms-combined-world-save-envelope-2026-11-17`.
- Exact-head Godot 4.3 test and Full Compatibility Gate: pending.
- Local Godot executable is unavailable; no local engine pass is claimed.
- No merge to main.

## Limitations

- Restore target must be a fresh/idle SurfaceWorld. Replacing an already active Backrooms world with another envelope is deliberately rejected.
- The saved surface chunk window is verified exactly. Underground mine streaming follows the existing SurfaceWorld restore contract and may be rebuilt at its canonical origin when restoring a surface-layer save.
- Headless tests verify transaction/data behavior, not graphical rendering, lighting, collision feel, navigation, AI, GPU performance, iPhone controls or target-device performance.
- The interim same-scene vertical-offset Backrooms architecture remains unchanged.

## Next steps

1. Run the new combined-envelope integration test on the exact child HEAD.
2. Run the full Godot 4.3 compatibility gate and inspect the complete job log.
3. Fix any exact-head failures without weakening fail-closed behavior.
4. Obtain independent review.
5. After review, integrate this PR into #387's feature branch and rerun #387; continue parent-first. Do not merge main before review and all required validation.
