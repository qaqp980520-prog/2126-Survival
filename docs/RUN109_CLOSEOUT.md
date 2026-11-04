# Run 109 Closeout — KROLL Debris Skimmer and raw inventory snapshot preservation

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#253](https://github.com/qaqp980520-prog/2126-Survival/pull/253)  
Merge commit: `0f51c274cf74d41687bc1290f00c307fcaffad0b`  
Validated feature head: `83684fcc0ad52f4fd4c6f823c50e57f82e7eff8f`

## Delivered game — KROLL Debris Skimmer M0.1

Path: `daily_games/KROLL_Debris_Skimmer/`

- Standalone Godot 4.3+ top-down inertia arcade game with three debris sectors.
- Steer and thrust, collect cargo with a tractor pulse, avoid moving asteroids and dock to meet delivery quotas.
- Sector quotas: Ring Fragments 3, Ice Drift 4, Station Graveyard 5; hull starts at 3.
- Each sector awards 100 points once; campaign maximum 300.
- Keyboard and touch controls include steering, thrust, reverse, tractor, dock, retry, next and campaign reset.
- No external assets/plugins/network/save integration.

## Existing-system change

Updated `systems/SurvivalInventory.gd` and `systems/SurvivalWorldBridge.gd`.

- Added validated `get_item_count()`; malformed directly injected counts are ignored by model count/weight reads.
- add/remove reject malformed existing counts instead of silently coercing them.
- `to_save_dict()` preserves a deep copy of raw runtime counts; strict save validation rejects malformed values and unknown IDs atomically rather than silently rewriting or dropping evidence.
- Valid unknown legacy counts retain the one-kilogram fallback for weight calculation while remaining visible to strict save validation.
- Regression: inventory weight boundaries, raw snapshot preservation, strict save validation and save-adapter compatibility.
- World-save schema remains version 1.

## Validation

- Exact-head full Godot 4.3 [#41753390703](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41753390703): 493/493 job steps successful, zero failures.
- Focused Run 109 [#41753390500](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41753390500): 15/15; same-head compatibility matrix: 103/103.
- Post-merge main full [#41754763069](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41754763069): 493/493 successful.

## Limitations

Local rendered GUI/GPU and physical iPhone QA were not performed. Main branch protection remains tracked under issue #236.
