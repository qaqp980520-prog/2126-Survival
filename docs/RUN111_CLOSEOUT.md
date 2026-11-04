# Run 111 Closeout — KROLL Tidal Lock Operator and custom inventory count validation

Date: 2026-11-04  
Engine target: Godot 4.3+  
Feature PR: [#255](https://github.com/qaqp980520-prog/2126-Survival/pull/255)  
Merge commit: `36613e589e060724d91877475c473557bde75b04`  
Validated feature head: `d660287ae3d809880a7c138b8fedfabe8e4d5c0e`

## Delivered game — KROLL Tidal Lock Operator M0.1

Path: `daily_games/KROLL_Tidal_Lock_Operator/`

- Three hydraulic lock puzzles: Service Lock, Pressure Exchange and High Reservoir.
- Water levels 0–5; pumping requires both gates closed.
- A gate opens only when chamber and adjacent basin levels match; both gates cannot be open simultaneously.
- Ship movement requires the matching gate; each accepted action consumes one action.
- Par counts 7/10/13; hard limits 10/13/16.
- One-time rewards: 100 points at/below par, otherwise 75; campaign maximum 300.
- Keyboard, pointer and touch controls; no external assets/plugins/audio/network/save integration.

Independent BFS model found exactly one shortest solution for each authored lock at 7/10/13 actions. This is model-level evidence, not a substitute for Godot validation.

## Existing-system change

Updated `systems/SurvivalWorldBridge.gd`.

- Custom `get_item_count()` results and legacy counts-dictionary fallback pass through one finite, whole-number, non-negative validator bounded by `SurvivalInventory.MAX_SAVED_COUNT`.
- Whole-valued floats are handled consistently with the built-in inventory model.
- Fractional, negative, Boolean, string and out-of-range values return zero.
- Legacy unknown-key reads remain visible; strict save validation still rejects unknown item IDs.
- No public API signature or world-save schema change; schema remains version 1.
- Regression: `tests/world_bridge_legacy_inventory_count_test.gd`.

## Validation

- Exact-head full Godot 4.3 [#41758619233](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41758619233): 505/505 job steps successful, zero failures.
- Focused Run 111 [#41758619232](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41758619232): 13/13; nine compatibility suites: 131/131.
- Post-merge main full [#41763880870](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41763880870): 505/505 successful.

## Limitations

Local rendered GUI/GPU and physical iPhone QA were not performed. Main branch protection remains tracked under issue #236.
