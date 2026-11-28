# M0.3.50 — Verified Temp Recovery After Invalid Staged Previous

## Purpose

Close a recovery gap when an interrupted save leaves a `.previous` file that exists but fails validation. If the current primary, staged previous, and committed backup are all invalid, the recovery path previously returned before checking a fully validated `.tmp`. This could strand the only recoverable world snapshot behind an invalid staged file.

## Versioned files

- `systems/SurfaceWorldSaveStore.gd` — when primary, previous, and backup validation all fail, validate the temp before changing any file; archive the invalid previous; reuse the verified-temp promotion path; retain the temp and recovery evidence if promotion fails.
- `tests/production_surface_world_test.gd` — exercise the real `SurfaceWorld.load_game()` entry point with corrupt primary, corrupt `.previous`, corrupt `.bak`, and a fully valid `.tmp`.
- `docs/PRODUCTION_SURFACE_WORLD_INVALID_PREVIOUS_TEMP_RECOVERY_M0_3_50.md` — this version record.

## Dependencies and staging

- Production durable save/load parent: PR #452.
- First-write recovery and save-store recovery chain: PR #459.
- Exact staging base at branch creation: PR #459 HEAD `959b2f85328510d8c4ab36e763c3f9c363f4c995`.
- Staging branch: `fix/save-recover-temp-after-invalid-previous-2026-11-28-run12`.
- This is a staging child of PR #459. It is not a standalone release and must not be merged before parent-first independent review.

## Recovery precedence

1. A valid committed primary remains authoritative.
2. A valid staged previous remains the rollback source.
3. A valid committed backup remains preferred over an uncommitted temp.
4. Only when primary, previous, and backup are invalid may a fully validated temp be considered.
5. The invalid staged previous is archived using the collision-safe corrupt-archive allocator.
6. The existing verified-temp promotion routine separately archives an invalid primary, copies and verifies the temp, promotes it, verifies the primary, and consumes the source temp only after success.
7. If archival or promotion fails, return a recovery-required report and preserve the remaining source/evidence for retry.

An invalid or missing temp preserves the existing fail-closed error path; no invalid file is promoted.

## Regression coverage

The production test writes:
- a corrupt primary;
- a corrupt staged `.previous`;
- a corrupt committed `.bak`;
- a valid, checksum- and payload-validated `.tmp`.

It then calls the real `SurfaceWorld.load_game()` entry point and requires:
- the valid temp becomes the exact primary bytes;
- the source temp is consumed only after successful promotion;
- the corrupt primary and previous bytes survive in two distinct collision-safe archives;
- the corrupt backup remains byte-for-byte intact for diagnosis;
- the load report returns through the normal `loaded_from_primary` path.

## Import and test

No asset import, project setting, scene, Autoload, or external dependency change.

From the repository root:

~~~bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
~~~

The exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate must both pass before promotion.

## Validation status

Implementation and regression are staged; exact-head Godot CI is pending. The authoring container has no local Godot executable, so no local engine pass is claimed.

## Limitations

- This is a recovery fallback for the specific state where no committed candidate validates. It does not claim power-loss durability beyond the existing filesystem flush/rename protocol.
- Windows filesystem behavior and symlink permissions remain subject to the existing platform-specific test skips.
- No GPU, rendered-frame, iPhone, iPad, or target-device QA is implied by headless CI.

## Next step

Run exact-head Dedicated Save Validation and Full Godot 4.3 Compatibility Gate. Preserve any failed candidate evidence. If both pass, keep this PR Draft pending independent review and integrate parent-first into PR #459 only after approval. Do not merge main.
