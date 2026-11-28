# M0.3.49 — Owned Symlink Target Identity Guard

## Purpose

Prevent the production save regression harness from deleting a replacement symbolic link at a path that was originally owned by the test. The previous cleanup helper checked only whether the path was still a link; it did not compare the link's current target with the target recorded when the test created it.

A concurrent or injected replacement link could therefore be removed even though the current link no longer matched the fixture registered in the ownership map.

## Versioned files

- `tests/production_surface_world_test.gd` — compare `DirAccess.read_link()` with the registered target before unlinking; fail closed and relinquish the stale ownership record when the target differs.
- `docs/PRODUCTION_SURFACE_WORLD_OWNED_SYMLINK_TARGET_IDENTITY_M0_3_49.md` — this version record.

No production runtime GDScript, save schema, scene, Project Settings, Autoload, or external dependency changes.

## Dependencies

- Parent production SurfaceWorld persistence feature: [PR #452](https://github.com/qaqp980520-prog/2126-Survival/pull/452).
- First-write recovery and test fixture lifecycle: [PR #459](https://github.com/qaqp980520-prog/2126-Survival/pull/459).
- Exact child base at staging creation: `959b2f85328510d8c4ab36e763c3f9c363f4c995`.

## Behavior

- Record the exact target passed to `DirAccess.create_link()` in the per-run ownership registry.
- Before removing a path that is still a symlink, read its current target with `DirAccess.read_link()`.
- Normalize path components before comparison; compare case-insensitively on Windows and case-sensitively on other platforms.
- If the link target is empty or differs from the registered target, do not unlink it. Clean only a verified placeholder belonging to the original fixture, relinquish the stale ownership record, and report the refusal.
- Continue to preserve regular-file replacements and the existing target-byte protections.

## Regression coverage

The replacement-race test now covers both replacement types:

1. A regular file replacing the original owned link must remain byte-for-byte unchanged.
2. A different symlink replacing the original owned link must remain a symlink, continue pointing to its replacement target, and preserve that target's bytes. Cleanup must relinquish the original fixture's ownership without removing the replacement.

The test removes its own simulated replacement link only after the refusal assertions pass.

## Import and test

No asset import or project setting change is required. The test runs through the existing root Godot 4.3 validation workflows:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

The exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate are required before promotion into PR #459.

## Validation status

Pending exact-head GitHub Actions. No local Godot run is claimed because the authoring container has no Godot executable.

## Limitations

- `DirAccess.read_link()` exposes the target path, not a portable inode/file-identity token. A replacement symlink to the exact same target is therefore semantically indistinguishable through this API; this guard specifically rejects a changed target and fails closed on unreadable/empty targets.
- Windows may skip symlink-specific fixtures when Developer Mode or elevated privileges are unavailable.
- This is test-harness ownership hardening; it does not alter production save/load behavior or claim OS-level power-loss durability.
- GPU/rendering, Xvfb/Mesa, mobile, and target-device QA remain outside headless CI.

## Next step

Wait for both exact-head workflows. If they pass, fast-forward this staging branch into PR #459 using the expected old HEAD `959b2f85328510d8c4ab36e763c3f9c363f4c995` with `force=false`, then rerun the exact-head Dedicated and Full Gate workflows. Keep PR #459 Draft pending parent-first independent review; do not merge to main.

## Validation correction — expected refusal diagnostic

The first exact-head Dedicated Save Validation run [46090801233](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46090801233) failed even though the production regression script completed and all assertions passed. The fail-closed replacement-symlink branch emitted an expected `push_error()`; the workflow's diagnostic guard correctly treats every `ERROR:` line as a failure. This was a test-harness diagnostic classification issue, not a failed preservation assertion.

Correction commit: `029a9c2d2265dd4db4d3cc3156d5e8d8d3a46361`. The expected refusal is now logged as a `SAFEGUARD:` message rather than an engine error. The exact corrected HEAD must pass both workflows before promotion. The initial failed run remains in history and is not reported as successful.
