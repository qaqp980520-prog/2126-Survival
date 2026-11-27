# M0.3.44 — Corrupt Archive Symlink Collision Guard

## Purpose

Prevent the save store from selecting a pre-existing symbolic-link path as a dynamically generated corrupt-archive destination. This includes dangling symlinks, which ordinary file and directory existence checks may not report.

## Versioned files

- `systems/SurfaceWorldSaveStore.gd` — `_unique_corrupt_archive_path()` now skips candidate paths that are files, directories, or symbolic links in the candidate's path ancestry.
- `tests/production_surface_world_test.gd` — deterministic dangling-symlink collision regression.
- `docs/PRODUCTION_SURFACE_WORLD_CORRUPT_ARCHIVE_SYMLINK_COLLISION_M0_3_44.md` — this version record.

## Dependencies

- Parent production persistence feature: [PR #452](https://github.com/qaqp980520-prog/2126-Survival/pull/452).
- First-write temp recovery and precedence coverage: [PR #459](https://github.com/qaqp980520-prog/2126-Survival/pull/459).
- Existing path-family symlink checks in `SurfaceWorldSaveStore.gd`.

## Behavior

The archive-name allocator now checks the full candidate path with the existing symlink-ancestor guard. If the nominal timestamped archive name is occupied by a dangling symlink, it selects the next numeric suffix instead of attempting to reuse that path.

The regression uses a fixed timestamp and a dangling link to a nonexistent target. It asserts that ordinary file/directory checks do not see the dangling link, the allocator chooses the `.1` suffix, and the original link remains intact.

## Import and test

No asset import, scene, project setting, Autoload, save-schema, or external dependency changes are required.

The test runs through the existing Production SurfaceWorld Save Validation workflow and the root Godot 4.3 Full Compatibility Gate. Required CI commands remain:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

## Validation status

Exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate are required. Results are recorded on PR #459 and in the Run 461 Notion record; no local Godot run is claimed.

## Limitations

- The guard protects generated corrupt-archive destinations against symlink collisions; it does not claim OS-level power-loss durability or filesystem `fsync` guarantees.
- Windows may skip symlink-specific fixture creation when Developer Mode or elevated privileges are unavailable; the test reports that skip explicitly.
- GPU/rendering, Xvfb/Mesa, mobile, and target-device QA remain outside headless CI.

## Next step

Verify both exact-head workflows, review the full logs, then retain PR #459 as Draft pending parent-first independent review. Integrate into PR #452 only with an expected-SHA fast-forward after review, rerun exact-head parent CI, and do not merge to main.
