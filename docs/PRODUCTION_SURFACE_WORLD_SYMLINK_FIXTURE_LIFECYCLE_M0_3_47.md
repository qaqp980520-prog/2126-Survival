# M0.3.47 — Owned Symlink Fixture Lifecycle and Replacement-safe Cleanup

## Purpose

M0.3.46 introduced per-process save-family ownership and non-destructive file cleanup. A follow-up audit found that symlink fixtures were still removed manually at the end of individual test branches. An early exit or interrupted test could leave a test-created link behind, and cleanup needed an explicit rule for a link path that had been replaced by a regular file after creation.

## Versioned files

- `tests/production_surface_world_test.gd` — register each symlink only after successful creation; route fixture cleanup through an ownership-aware unlink helper; clean remaining owned links from the test finish path; refuse to delete a non-link entry that replaced a tracked symlink.
- `docs/PRODUCTION_SURFACE_WORLD_SYMLINK_FIXTURE_LIFECYCLE_M0_3_47.md` — this version record.

## Dependencies

- Production save/load regression suite: PR [#452](https://github.com/qaqp980520-prog/2126-Survival/pull/452).
- Recovery and archive collision tests: PR [#459](https://github.com/qaqp980520-prog/2126-Survival/pull/459).
- Per-process save fixture ownership: [M0.3.46](https://github.com/qaqp980520-prog/2126-Survival/blob/fix/recover-verified-first-write-temp-2026-11-27-run11/docs/PRODUCTION_SURFACE_WORLD_TEST_FIXTURE_PATH_ISOLATION_M0_3_46.md).

## Behavior

- Add a per-invocation registry of symlink paths successfully created by the test.
- Centralize link creation; an occupied path is rejected before `create_link`, and ownership is recorded only after the OS reports success.
- Centralize unlinking; the helper checks that the entry is still a symlink and removes the link entry through its parent `DirAccess`, never by opening or deleting the target.
- If the tracked path has disappeared, release the stale ownership record.
- If another entry now occupies the former link path, preserve that replacement and relinquish symlink ownership without deleting it.
- The test finish path removes any remaining owned links before cleaning owned save families.
- Existing directory, direct-file, dangling-archive, and end-to-end archive-collision fixtures now use the ownership-aware lifecycle.
- Add regressions proving that cleanup removes a link while preserving its target bytes, and that cleanup refuses to delete a regular file that replaced an owned link.

## Version commits

- Initial lifecycle ownership implementation: `2d06dee83764f843b5ea9468d0c18d808948d6d6`.
- Replacement-entry refusal and regression: `76e77210a69706a2f80bef44277016a85bc7e202`.

## Import and test

No asset import, scene, Project Settings, Autoload, save-schema migration, production runtime GDScript, or external dependency is required.

Run the existing root Godot 4.3 checks:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/production_surface_world_test.gd
```

The exact-head Dedicated Production SurfaceWorld Save Validation and Full Godot 4.3 Compatibility Gate must both pass after this version is promoted to PR #459.

## Validation status

- Static diff review: one tracked `create_link` call remains inside the ownership helper; all normal fixture link removals route through the owned-link helper. The sole direct `DirAccess.remove` in the test intentionally simulates an external actor unlinking the fixture before placing a regular replacement entry.
- The two exact code commits are on staging branch `fix/save-test-symlink-fixture-lifecycle-run465`, based on PR #459 HEAD `593325b3cd42c747207996c881243a94bd83e9e5`.
- Godot CI is pending; no test pass is claimed for this candidate yet.
- No local Godot run is claimed; the current authoring container does not provide a Godot executable.

## Limitations

- This is test-harness lifecycle hardening. It does not change the production save algorithm or provide OS-level power-loss durability or filesystem `fsync` guarantees.
- Windows may skip symlink-specific assertions when Developer Mode or elevated privileges are unavailable.
- GPU/rendering, Xvfb/Mesa, mobile, and target-device QA remain outside headless CI.

## Next step

Review the final staging diff, fast-forward the tested staging head into PR #459 using an expected-SHA guard, and run exact-head Dedicated Save Validation plus the full Godot 4.3 Compatibility Gate. Keep PR #459 Draft and do not merge to main pending parent-first independent review and release governance.
