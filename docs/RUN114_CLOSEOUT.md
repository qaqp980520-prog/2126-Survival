# Run 114 Closeout — KROLL Zero-G Cargo Bay and inventory restore atomicity

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#259](https://github.com/qaqp980520-prog/2126-Survival/pull/259)  
Merge commit: a2b52aa43c5ad57fe218e56b131213632ffec4da  
Validated feature head: beb107f3dcad62cfc9e234ec1359833fcd6460d2

## Delivered game — KROLL Zero-G Cargo Bay M0.1

Path: daily_games/KROLL_Zero_G_Cargo_Bay/

- Three authored 5×5 cargo-bay work orders with six distinct cargo shapes and mass values.
- Place and rotate cargo; prevent overlap and out-of-bounds placement.
- Compute the mass-weighted centre of mass and require both axes to remain inside the support region 1.25–3.75.
- Undo the last placement, restart the bay, and advance the three-stage campaign.
- Each bay awards once; maximum campaign score 300.
- Keyboard and pointer/touch controls; standalone Godot 4.3+ Compatibility renderer project with no third-party plugins, external assets, audio, network or save dependency.

## Existing-system change — inventory restore atomicity

Updated systems/SurvivalWorldBridge.gd.

- Capture a deep serialized snapshot before applying a custom inventory restore.
- If load_save_dict() reports failure after a partial mutation, attempt to restore the snapshot.
- Verify the rollback by serializing the custom inventory again and comparing it with the captured snapshot.
- If rollback cannot be verified, emit a defensive inventory_changed refresh rather than promising arbitrary third-party atomicity.
- Public bridge signatures, REQUIRED_INVENTORY_METHODS and world-save schema 1 remain unchanged.
- Regression: tests/world_bridge_restore_atomicity_test.gd.

## Exact-head validation

- Full Godot 4.3 gate [#41783539122](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41783539122): 520/520 step records successful; zero failures and zero skipped. Run 114 gates #513–517, post-checkout cleanup, container shutdown and complete-job all succeeded.
- Focused Run 114 [#41783539212](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41783539212): 16/16, 90 PASS assertions.
- Eleven exact-head historical focused suites: 160/160 combined.
- PR #259 merged as a2b52aa43c5ad57fe218e56b131213632ffec4da.

## Infrastructure and limitations

- The connected workflow/status lookup did not return a post-merge main-push run for a2b52aa; post-merge main validation is unconfirmed, not passed or failed.
- Main branch protection's last recorded readback was protected=false with required-check enforcement disabled. Issue [#236](https://github.com/qaqp980520-prog/2126-Survival/issues/236) remains open.
- Local Godot executable unavailable; local rendered GUI/GPU and physical iPhone QA remain untested.
