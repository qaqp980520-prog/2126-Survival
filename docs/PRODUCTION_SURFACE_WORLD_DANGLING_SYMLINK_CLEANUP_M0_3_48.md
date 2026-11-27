## Validation correction — first M0.3.48 candidate failed

The first placeholder/marker candidate `572fc559f38caa023159f475321861d789b4a801` failed Dedicated Save Validation [46083295698](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/46083295698). The log showed two related symptoms:
- Existing-target directory links were incorrectly treated as if a placeholder marker existed.
- Dangling-link cleanup skipped placeholder creation and `DirAccess.remove()` still returned Error 1.

Root cause: the per-link placeholder dictionary was initialized with boolean `false`, then converted to a String. `str(false)` is the non-empty string `"false"`, so the helper incorrectly treated the marker as already present. The correction initializes the marker path to an empty string. The regression suite exercises both existing-target and dangling-target paths, so this state error is covered by the exact-head test.

Correction commit: `0a5a11e7b833bcbe0dfa90af23ab6d12f62e96ca`. The failed candidate is retained in Git history and is not reported as passed.

# M0.3.48 — Dangling Symlink Cleanup with Verified Owned Placeholder

## Purpose

M0.3.47 introduced ownership-tracked symlink fixtures, but its first exact-head Dedicated CI exposed that Godot 4.3 `DirAccess.remove()` returns Error 1 for a dangling symlink. The helper could remove links whose targets existed, but could not reliably remove the intentionally dangling archive and end-to-end fixtures.

Godot 4.3 Unix source calls `stat()` before `unlink()`, and `stat()` follows a dangling link and fails. The Windows implementation checks file attributes before unlinking. See:
- [Godot 4.3 Unix DirAccess implementation](https://github.com/godotengine/godot/blob/4.3/drivers/unix/dir_access_unix.cpp#L410-L441)
- [Godot 4.3 Windows DirAccess implementation](https://github.com/godotengine/godot/blob/4.3/drivers/windows/dir_access_windows.cpp#L311-L329)

## Versioned files

- `tests/production_surface_world_test.gd` — record each symlink's exact target, create a temporary owned target directory only when the target is genuinely missing, add an ownership marker, remove the symlink, then remove the marker and empty directory only after verifying the directory contains exactly the marker.
- `docs/PRODUCTION_SURFACE_WORLD_DANGLING_SYMLINK_CLEANUP_M0_3_48.md` — this version record.
- `docs/PRODUCTION_SURFACE_WORLD_SYMLINK_FIXTURE_LIFECYCLE_M0_3_47.md` — corrected to mark the initial candidate failure and this superseding version.

## Dependencies

- Parent production save/load feature: [PR #452](https://github.com/qaqp980520-prog/2126-Survival/pull/452).
- Recovery/archive collision and test fixture ownership: [PR #459](https://github.com/qaqp980520-prog/2126-Survival/pull/459).
- M0.3.46 per-process save-family ownership and M0.3.47 owned symlink lifecycle.

## Behavior

- Keep the symlink path and exact absolute target in a per-process ownership registry.
- Reject link paths and target paths outside the current run's unique `user://` namespace.
- For a dangling target only, create an empty directory at the target path using `DirAccess.make_dir_absolute`. This makes the link resolvable for Godot 4.3's removal implementation.
- Write a unique marker file inside that directory and record its exact path.
- Remove the symlink entry through `DirAccess.remove`.
- Remove the marker and directory only if the target directory contains exactly the expected marker with the expected owner token and no child directories.
- If the target path has been replaced by a file, symlink, or unexpected directory contents, preserve the replacement and release or retain ownership safely for retry.
- If cleanup stops after marker removal but before directory removal, the next cleanup pass may remove only the now-empty owned directory.
- Keep cleanup in the test finish path so remaining owned links are retried.

## Regression coverage

- A dangling archive collision link is removed by the ownership helper.
- The temporary target placeholder is absent after cleanup.
- Each of the end-to-end dangling archive-collision links is removed and leaves no target placeholder.
- Cleanup of a link to an existing file preserves the target bytes.
- A regular file that replaces an owned link is preserved.
- Windows continues to skip symlink-only fixtures when Developer Mode or elevated privileges are unavailable.

## Version commits

- Initial M0.3.47 symlink lifecycle work: `2d06dee83764f843b5ea9468d0c18d808948d6d6`, `76e77210a69706a2f80bef44277016a85bc7e202`, `1feb3bce787c8148dee2de3e1ced567eb7aa80af`.
- First dangling-cleanup attempt and path normalization: `e985f71c21bf0cf4eaaeae63929931fa53a84f0f`, `73ec12e7af2ad6605e3bb6fa9dfe361365700ac1`.
- Verified placeholder/marker correction: `57590fb997976fe0664427d110399b795466fdcf`.
- M0.3.47 documentation correction and this M0.3.48 record are committed on the isolated staging branch; exact final HEAD will be recorded after the staging diff is complete.

## Import and test

No asset import, scene, Project Settings, Autoload, save-schema migration, production runtime GDScript, or external dependency is required.

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

The exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate must both pass after the corrected staging head is promoted to PR #459.

## Validation status

- The first M0.3.47 exact-head Dedicated workflow failed at the production save/load regression step because dangling symlink removal returned Error 1. This failure is recorded, not hidden.
- The current M0.3.48 correction is on isolated branch `fix/save-test-symlink-cleanup-diraccess-run465`, based on PR #459 HEAD `4e672c9cfa3e92257c3f666d2b8129e075ef2a70`.
- Static review is complete for the placeholder ownership algorithm; exact-head Godot CI is pending.
- No local Godot run is claimed; the current authoring container has no Godot executable.

## Limitations

- This is test-harness lifecycle hardening; it does not change the production save algorithm or schema.
- Placeholder creation is restricted to a unique per-process test namespace. The marker and empty-directory checks fail closed if unexpected content appears.
- Windows may skip symlink-specific assertions without Developer Mode or elevated privileges.
- No OS-level power-loss durability or filesystem `fsync` guarantee is claimed.
- GPU/rendering, Xvfb/Mesa, mobile, and target-device QA remain outside headless CI.

## Next step

Review the exact M0.3.48 staging diff, fast-forward it into PR #459 using an expected-SHA guard, then run exact-head Dedicated Save Validation and the full Godot 4.3 Compatibility Gate. Keep PR #459 Draft and do not merge main pending parent-first independent review and release governance.
