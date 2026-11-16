# M0.1.45 — Root Godot Test Timeout Coverage

## Purpose

Close the remaining per-test timeout gaps in the root-project Godot 4.3 validation workflow. The prior M0.1.43/M0.1.44 work already guaranteed combined stdout/stderr capture, Godot diagnostic rejection, and an exact success marker for every root-project test. This follow-up makes sure none of those tests can hang indefinitely inside the overall job.

## GitHub delivery

- Repository: `qaqp980520-prog/2126-Survival`
- PR: [#378 — Core Godot test output guards](https://github.com/qaqp980520-prog/2126-Survival/pull/378)
- Parent PR: #377 feature branch.
- Branch: `ci/backrooms-core-test-output-guards-2026-11-16`
- Workflow commit: `66e080bb591a8f1cbd07f5e75474d13772c16f31`
- Changed workflow: `.github/workflows/godot-validation.yml`
- 13 existing root-project test steps received an explicit `timeout -k 5s 60s` wrapper.
- No new PR was created; this is a scoped continuation of the existing CI-hardening PR #378.

## Updated test steps

The following root-project tests now have a 60-second execution budget and a 5-second forced-termination grace period:

1. `backrooms_portal_scene_test.gd`
2. `backrooms_portal_playground_test.gd`
3. `inventory_weight_boundaries.gd`
4. `mineral_catalog_test.gd`
5. `mineral_vein_chunk_stream_test.gd`
6. `mineral_chunk_lifecycle_adapter_test.gd`
7. `mineral_chunk_controller_test.gd`
8. `backrooms_player_input_test.gd`
9. `backrooms_settings_profile_test.gd`
10. `backrooms_settings_integration_test.gd`
11. `mineral_grid_streaming_director_test.gd`
12. `surface_chunk_streaming_playground_test.gd`
13. `inventory_mineral_catalog_compatibility_test.gd`

## Static audit

- Root-project Godot test steps: 117.
- Steps with explicit timeout after this change: 117/117.
- Steps capturing stdout and stderr: 117/117.
- Steps rejecting `SCRIPT ERROR`, `ERROR:`, and `FAIL:`: 117/117.
- Steps requiring their exact success marker: 117/117.
- Root import retains its separate import/diagnostic guard.
- The informational Godot version probe is not counted as a test.
- Legacy standalone KROLL project invocations under `daily_games/` are outside this root-project audit and were not changed.

## Timeout budget rationale

The previous successful exact-head Full Gate #43876541098 was used as a runtime baseline for the 13 previously unbounded tests. Their observed durations ranged from approximately 0.196 seconds to 2.352 seconds; the slowest was `surface_chunk_streaming_playground_test.gd`. A 60-second budget is more than 25 times that observed maximum while still bounding a hung process. This baseline is historical evidence only; the new exact HEAD must pass its own CI.

## Dependencies and import

- Godot 4.3 CI environment.
- Bash shell, GNU coreutils `timeout`, and `grep`.
- No third-party packages or new project dependencies.
- Import remains `godot --headless --path . --editor --quit`.
- Focused execution is provided by the existing `.github/workflows/godot-validation.yml`.

## Validation status

- Static post-edit audit passed locally in the workflow text: all 117 root-project test blocks have timeout, combined output capture, diagnostic rejection, and exact success-marker checks.
- Previous exact-head Full Gate #43876541098 passed on the parent workflow before this 13-timeout follow-up; it does not validate this new commit.
- Current commit `66e080bb591a8f1cbd07f5e75474d13772c16f31` requires a fresh exact-head Godot 4.3 Full Compatibility Gate and complete job-log diagnostic scan.
- Local Godot executable is unavailable; engine validation must run in GitHub Actions.

## Limitations

- This change affects CI execution bounds only. No gameplay code, save schema, scenes, assets, input mappings, Project Settings, or runtime behavior changed.
- Legacy standalone KROLL projects are not part of this root-project timeout audit.
- The 60-second limit is based on the latest observed successful durations; if a future legitimate test exceeds it, adjust that specific test's budget with measured evidence rather than removing timeout protection.

## Next steps

1. Verify the new exact-head Full Gate and all associated focused workflows.
2. Confirm no test timed out and all 554 validation steps pass.
3. Download and scan the complete Full Gate job log for actual Godot diagnostics.
4. Keep PR #378 unmerged until independent review is obtained.
5. Merge #378 only into PR #377's feature branch, then rerun PR #377's exact-head Full Gate.
6. Never merge this child directly to main.
