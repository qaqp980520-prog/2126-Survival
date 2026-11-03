# Run 103 Closeout — KROLL Casefile and queued-root lifecycle guard

**Feature PR:** [#243](https://github.com/qaqp980520-prog/2126-Survival/pull/243)  
**Merge commit:** `5f19d52879b9eac9bd38e8621f1a091e2bcb98e4`  
**Current main after Run 102 documentation merge:** `8b4c86dce4cf59305e08b7f3f9dff352bd3cc987`

## New game: KROLL Casefile: Station Zero M0.1

A standalone Godot 4.3+ deduction puzzle with three fictional station incidents:
- Airlock 03
- Relay 04
- Archive 09

For each case, select one suspect and exactly two linked evidence records. Each authored case has one unique valid solution. Three incorrect submissions fail the case; retry resets only that case's strikes and selection. Each solved case awards 100 points once; campaign cap is 300.

**Project:** `daily_games/KROLL_Casefile_Station_Zero/`  
**Entry scene:** `main.tscn` (standalone project)  
**Root Test Hub scene:** `main_root.tscn` (uses repository-root script path)  
**Dependencies:** Godot 4.3+, no external assets, plugins, network or save integration.

Controls:
- Mouse/touch: select suspect, select two evidence records, Submit.
- 1–3: suspect; Q/W/E: evidence.
- Enter: submit; Backspace: clear; N: next case; R: retry after failure; C: reset campaign.

The root Survival Test Hub now contains 48 launch entries.

## Existing system: queued-for-deletion chunk roots

A Node3D can remain instance-valid and unparented after `queue_free()` but before end-of-frame deletion. Accepting it into chunk ownership could leave stale references.

The Run 103 fix:
- Rejects queued roots in synchronous factory loading, async staging and stale-chunk restoration in `MineralGridStreamingDirector.gd`.
- Adds `factory_root_queued_for_deletion` to sync/async diagnostic details.
- Skips double-free in `_free_unowned_root()` when a root is already queued.
- Adds the same lifecycle rejection at `MineralChunkController.load_chunk()`.

Regression file: `tests/mineral_grid_streaming_queued_root_rejection_test.gd`. It passed 25 assertions across direct controller, sync, async and rollback restore paths.

World-save schema remains version 1.

## Validation evidence

- Full exact-head Godot 4.3 Run [#1195](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41641795635): **463/463** job step records; zero failures/skips; Run 103 gates #456–460, checkout cleanup, container shutdown and complete-job all succeeded.
- Focused Run 103 #4: [13/13](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41641795684).
- Focused compatibility: Run 101 #9 [13/13](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41641795634), Run 102 #7 [13/13](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41641795701), Run 92 #93 [13/13](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41641795704), Run 93 #88 [13/13](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41641796095), Run 94–100 #83 [39/39](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41641795649). Total focused checks: 91/91.
- An initial candidate failed root-scene smoke due to a standalone-relative script path; corrected and retested on the final candidate. The failure is preserved in workflow history.
- Post-merge main push CI has not surfaced through the connected workflow/status lookup; this remains unconfirmed.

## Remaining limitations
- Local Godot executable unavailable; local rendered GUI/GPU and physical iPhone QA remain untested.
- Main branch protection remains unresolved under issue #236.
