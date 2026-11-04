# Run 115 Closeout — KROLL Orbital Foundry and inventory serialization snapshot isolation

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#260](https://github.com/qaqp980520-prog/2126-Survival/pull/260)  
Merge commit: 8e45797f721ef0349240fa00694c9e04d4559129  
Validated feature head: 378da5f45e2e2c9d581dd92ce0bffccc5cf59501

## Delivered game — KROLL Orbital Foundry M0.1

Path: daily_games/KROLL_Orbital_Foundry/

- Standalone crafting-chain and production-budget puzzle with three contracts: Sensor Calibration, Emergency Power Cell and Pressure Transfer Pump.
- Six recipes form three authored dependency chains from raw stock through intermediate components to required output.
- Ingredient, energy and action-budget checks reject impossible recipes without mutating the state.
- Campaign controls support keyboard, pointer and touch; restart preserves previously earned contract rewards, while a new campaign clears the ledger.
- Each contract awards 100 points once; campaign maximum 300.
- Godot 4.3+ Compatibility renderer; no third-party plugins, external assets, audio, network or save dependency.

## Existing-system change — serialization snapshot isolation

Updated systems/SurvivalWorldBridge.gd.

- serialize_inventory() now returns duplicate(true) of a custom inventory's serialized Dictionary so nested data returned by a custom inventory cannot alias live state.
- serialize_world_save() calls to_save_dict() once, rejects a non-Dictionary snapshot with invalid_inventory_snapshot, deep-copies a valid Dictionary and passes the detached snapshot to SurvivalInventorySaveAdapter.
- Raw invalid Dictionary contents remain visible to strict downstream validation instead of being silently normalized.
- Public bridge signatures, REQUIRED_INVENTORY_METHODS and world-save schema 1 remain unchanged.
- Regression: tests/world_bridge_serialization_snapshot_test.gd, using a custom inventory whose to_save_dict() deliberately exposes its live counts Dictionary.

## Exact-head validation

- Full Godot 4.3 Compatibility Gate [#41790697871](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41790697871): 525/525 step records successful; zero failures and zero skipped. Run 115 gates #518–522, post-checkout cleanup, container shutdown and complete-job all succeeded.
- Focused Run 115 [#41790697767](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41790697767): 16/16, 70 PASS assertions; no actual Godot SCRIPT ERROR/ERROR/FAIL output.
- Eleven exact-head historical focused suites: 160/160 combined; all eleven jobs completed successfully with cleanup.
- PR #260 merged as 8e45797f721ef0349240fa00694c9e04d4559129.

## Infrastructure and limitations

- The connected workflow/status lookup did not return a post-merge main-push run for 8e45797; post-merge main validation is unconfirmed, not passed or failed.
- Main branch protection's last recorded readback was protected=false with required-check enforcement disabled. Issue [#236](https://github.com/qaqp980520-prog/2126-Survival/issues/236) remains open; the Run 114/115 status update was added in issue comment 6625039608.
- Local Godot executable unavailable; local rendered GUI/GPU and physical iPhone QA remain untested.
