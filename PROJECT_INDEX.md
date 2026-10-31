# 2126 Survival — 開發資產索引

這個儲存庫用於保存《2126 Survival》的程式碼與原型版本。

## 專案原則
- 引擎：Godot 4
- 類型：跨平台 3D 生存遊戲（PC／iPhone 目標）
- 世界觀：西元 2126 年；KROLL、軍閥與野區並存；後室傳送門可能出現在主世界。
- 每次更新應記錄版本、變更、檔案、測試狀態與已知限制。

## 重要驗證規則
本索引不代表所有原型都已上傳或測試。每個版本必須以實際提交紀錄與引擎測試結果為準。未在 Godot 4 執行的版本會明確標示「尚未在 Godot 4 實測」。

## 2026-10-31 Run 65 — KROLL Core Drill + stale camera-ray target lifecycle guard (feature merged / exact-head CI passed)

### New Godot 4 game
- Project: `daily_games/KROLL_Core_Drill/`, a lane-planning mining arcade game with three authored eight-row/five-lane sites.
- Controls: A/D or arrows shift one lane; Space drills one row; V vents heat once per row; R restarts; N advances after meeting the ore quota. Touch users can tap a lane and use on-screen LEFT/RIGHT/VENT/DRILL/RESTART/NEXT controls.
- Tile systems: rock, copper, iron, titanium, gas, coolant ice, lava and hard rock. Energy, thermal load and drill-hull integrity constrain the route. No external assets, audio, plugins or network dependencies; Godot 4.3+.
- Registered in `prototypes/SurvivalTestHub.gd`. The hub launch list now uses a bounded vertical ScrollContainer so all 10 launch buttons remain reachable on smaller screens; the root hub smoke test checks scrolling and Core Drill scene/rules initialization.
- Independent route-model check: Copper Spine reaches 8 ore with 8 energy, 84 heat and 5 hull; Ion Vein reaches 6 ore with 8 energy, 42 heat and 5 hull; Mantle Edge reaches 6 ore with 12 energy, 40 heat and 5 hull. This supplements but does not replace Godot tests.

### Existing-system change
- `world/SurfaceWorld.gd` caches the exact Area3D interaction proxy with each camera-ray target.
- Before returning a cached target, validate the target/proxy instance, tree membership, queued-for-deletion state, interaction collision layer, target/proxy ancestry, active loaded-object membership and mineral-vein visibility/remaining stock.
- A queued proxy, removed proxy, queued streamed-chunk ancestor or no-longer-loaded object invalidates the cache immediately. HUD prompts and E/F/G/V actions cannot invoke a stale node.
- Added `tests/production_surface_world_interaction_lifecycle_test.gd` for proxy removal and streamed-chunk subtree teardown. No world-save schema change; interaction cache remains transient.

### Exact GitHub evidence
- Feature PR [#166](https://github.com/qaqp980520-prog/2126-Survival/pull/166) merged as `3e74a20cc312da04d6197e6747bced715734af83`.
- Exact candidate HEAD `45f15c93c91991602807f642c4bc8b0bfccac153` passed Godot 4.3 [Run #742](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41167697452): 278/278 step records successful, zero failures and zero skipped.
- Run #742 includes root project import, Survival Test Hub scroll/launch smoke, Core Drill standalone import/rules/runtime, existing game/world regressions and production interaction lifecycle test.
- Main was re-read at feature merge SHA `3e74a20cc312da04d6197e6747bced715734af83`; PR #166 is closed/merged.

### Known limits and next steps
- The lifecycle test injects proxy removal and a queued chunk ancestor; a controller-driven unload/reload cycle with same stable ID and proxy re-registration remains next.
- Star Chart M0.1 still lacks touch-only RESTART/NEXT navigation, although Core Drill has complete on-screen touch controls.
- Cache lid animation, inventory-full modal, procedural mine generation, terrain/object persistence and asynchronous chunk streaming remain incomplete.
- No local Godot executable was available; manual GUI, GPU performance and iPhone device QA are not claimed.

## 2026-10-31 Run 64 — KROLL Star Chart + camera-ray world interactions (feature merged / exact-head CI passed)

- Start-of-run reconciliation: main before this work was `5a797a19e0694a56f95db82bfa1f4316c3efc929`; PR #164 was the only open PR. Full branch pagination returned 170 branches. PR #164 feature HEAD `5fc815dfbabf0b993c824fba12b0e012b4140907` was 45 commits ahead / 0 behind main, 19 changed files.
- New game: `daily_games/KROLL_Star_Chart/`, a telescope-alignment puzzle with three authored sectors and four ordered stars per sector. Zoom tightens lock tolerance; missed locks cost time; score reflects zoom and remaining time. Keyboard, mouse and partial touch aiming/locking are supported. Godot 4.3+, no external assets/add-ons; import through `daily_games/KROLL_Star_Chart/project.godot` or launch from SurvivalTestHub.
- Game controls: WASD/arrows adjust aim, Q/E zoom, Space/right mouse lock, R restart and N advance after completing a sector. Touch supports tap-to-aim, drag fine-adjustment and the on-screen lock control; touch-only restart/next-sector navigation is not yet implemented.
- Existing-system change: `world/SurfaceWorld.gd` now selects interaction targets with a camera-forward physics ray and reuses the same selected target for the prompt and E/F/G/V actions. Registered non-blocking Area3D proxies are on physics layer 2; a separate body-only layer-1 ray preserves solid world occlusion while ignoring unrelated trigger areas. Depleted mineral veins disable their interaction proxy. No world-save schema change; stable IDs and existing inventory transaction APIs are unchanged.
- Regression coverage: `tests/production_surface_world_interaction_prompt_test.gd` covers aim-based surface/underground prompts, unrelated trigger-area filtering and solid-body occlusion. `tests/production_surface_world_mining_test.gd` verifies the exact aimed vein/cache target before inventory actions, including clear approaches around the mine lift proxy. Existing production SurfaceWorld and underground mining tests remain in the workflow.
- Feature PR [#164](https://github.com/qaqp980520-prog/2126-Survival/pull/164) merged as `4ab93b8aaeac2392b5d464afdfdb77b1cec477dd`; exact candidate HEAD `5fc815dfbabf0b993c824fba12b0e012b4140907`.
- Exact-head Godot 4.3 CI [Run #736](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41166102103) completed successfully: 273/273 step records, zero failures and zero skips. Run 64 steps 265–270 (production prompt test, input verification, Star Chart import/rules/runtime and camera-ray production integration) all passed. Supplementary Runs #33 (12/12) and #35 (13/13) also passed.
- Historical candidates #731/#734/#735 had test failures and were superseded; only exact-head Run #736 is accepted as final feature evidence. The runtime smoke-test helper and prompt-test physics-node setup were corrected before final CI.
- No local Godot executable was available. Manual GUI, GPU performance and iPhone device testing are not claimed.

### Known limits and next steps
- Touch-only users cannot yet restart or advance sectors; add on-screen RESTART/NEXT controls and test a complete touch-only campaign.
- Add manual GUI/GPU/iPhone acceptance when a suitable device/runtime is available.
- Continue improving camera-ray feedback and interaction-target lifecycle validation, then proceed with stable-ID world-object factory integration, terrain/object persistence and vertical mine streaming.

## 2026-10-31 Run 62 — Shadow Courier + persisted underground world seed (feature merged / exact-head CI passed)

- Start-of-run reconciliation: Run 61 PRs #158/#159 were merged; final main was `01d1b30120f568b7e99e8d2045212dbd55a3249e`. Post-merge main workflow Run #688 completed successfully with 258/258 step records, zero failures and zero skips. Before Run 62 there were no open PRs and 165 branches.
- New game: `daily_games/KROLL_Shadow_Courier/`, a deterministic 8×8 turn-based stealth game with three authored missions, rotating patrol sight lines, walls that block sight, three data shards per mission, two decoys, extraction objective, keyboard and touch controls. All three authored missions have verified winning action sequences. Godot 4.3+, no external assets/add-ons; import through `daily_games/KROLL_Shadow_Courier/project.godot`.
- Existing-system change: `world/SurfaceWorld.gd` now persists an optional bounded `world_seed` field in the existing schema-1 stream-save envelope. `systems/UndergroundMineFactory.gd` uses the seed for deterministic underground salvage-cache spawn, item identity and position. Seed 0 preserves the prior coordinate/layer formulas and fixed layer-zero service caches; schema-1 legacy saves without the field fall back to seed 0.
- Seed restore safety: when a save uses a different seed, the active underground window is unloaded/rebuilt even if chunk IDs are unchanged. Failed target-seed streaming or base restore resets the prior seed, rebuilds the prior mine window and reapplies exact mineral and world-object registry snapshots.
- Regression coverage: `tests/production_surface_world_seed_test.gd` covers same-seed determinism, cross-seed variation, invalid values, same-window rebuild, unload/reload, legacy fallback, and injected factory failure with exact registry rollback. Shadow Courier rules tests verify all three mission solutions; scene smoke tests exercise touch buttons and keyboard input.
- Feature PR [#160](https://github.com/qaqp980520-prog/2126-Survival/pull/160) merged as `cd76c87f888e8cc4606ffed3fffc1fb22a81552d`; exact candidate HEAD `ae887177633842a5d8a4ed3da3acb7b8fdc59906`.
- Exact-head Godot 4.3 CI [Run #699](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41156096505) completed successfully: 263/263 total step records succeeded, zero failures, zero skips. Shadow Courier steps 256–259 and production world-seed integration step 260 all passed.
- Main was re-read at merge SHA `cd76c87f888e8cc4606ffed3fffc1fb22a81552d`; PR #160 is closed/merged. Post-merge main workflow [Run #700](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41156636725) completed successfully on that exact SHA with 263/263 step records successful, zero failures and zero skips. The exact documentation candidate `09063ca83ef9f634ef47c32dc80fde34b60d5740` passed Godot 4.3 [Run #701](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41156688464): 263/263 step records successful, zero failures and zero skips.
- No local Godot executable was available; manual GUI, GPU performance and iPhone device testing are not claimed.

### Known limits and next steps
- The seed currently affects underground salvage caches only; mineral vein identities and terrain generation remain coordinate/layer deterministic.
- There is no in-game new-world seed picker; the value is configurable on SurfaceWorld and persisted in saves.
- Continue integrating stable-ID state restoration into all production world-object factories; then complete terrain/object persistence and vertical underground streaming.
- Add stamina/food balancing and complete device QA. Do not treat cloud headless CI as GUI/GPU/iPhone evidence.

## 2026-10-27 Run 26 — Orbit Warden + mineral restore contract (merged / exact-head CI passed)

- Start-of-run reconciliation: actual main was a48ec761f2b36cee44e6eb5022cda2b3c39aeca4. Run 25 PRs #84/#85 were merged; exact-head Godot 4.3 Runs #395 and #397 succeeded with 102 workflow validation steps each. Open PR search was empty. The Notion asset index still showed stale Run 23 pending snapshots; a correction was appended to the fixed Notion index and the Run 26 records.
- New game: daily_games/KROLL_Orbit_Warden/ is a non-combat top-down space-navigation arcade game: steer/thrust to recover six energy cells, avoid drifting asteroids, and use a brief deflection shield. Three lives, 75-second limit, keyboard/touch controls. Godot 4.3+, no external assets/add-ons; import through daily_games/KROLL_Orbit_Warden/project.godot.
- Existing-system change: systems/MineralMiningNode.gd restore_vein(units, now_unix=-1) now returns the actual accepted units, caps at remaining capacity, supports deterministic timestamps, and resets regeneration timing only when stock actually increases. Existing one-argument calls remain compatible; no save schema change.
- Regression coverage: tests/mineral_mining_regeneration_test.gd now tests exact accepted count, partial interval, capacity cap, full-stock/zero/negative no-ops, and no-op timestamp preservation.
- Feature PR #86 merged as adaf93ab255bff720d3bc70af1221ea4cc58f727; exact candidate HEAD 453358cfae88a4f62511dd33bb40a807d04a2f6d. PR: https://github.com/qaqp980520-prog/2126-Survival/pull/86.
- Exact-head Godot 4.3 CI Run #406 (40527501347) completed successfully: all 108 job steps succeeded. The final Orbit Warden import, rules test and runtime smoke test all succeeded. Focused Run 24 workflow Run #11 (40527501336) also succeeded, all 13 steps, including mineral regeneration and underground-mining compatibility.
- Static review caught and fixed a missing HUD parenthesis and changed energy-cell initialization to explicit typed-array appends before the successful candidate CI. No local Godot executable is available; GUI/GPU/iPhone device playtesting is not claimed.
- Limits: production M1.3 world controller remains absent; underground mining remains a fixed-cave prototype; inventory and mineral weight catalogs are still duplicated; crop persistence is not integrated.
- Next: integrate the tested inventory/mining/save lifecycle into the actual production world controller when it exists, then add end-to-end pickup/drop/weight/save/reload/failure-recovery acceptance tests and device QA.

## 2026-10-27 Run 25 — Vent Runner + inventory/mineral weight compatibility (merged / exact-head CI passed)

- Start-of-run reconciliation: GitHub main was `789ba5fedd90c12afdf4b710c62a322682733bd2`; Run 24 PRs #80–#83 were all merged, with exact-head Godot 4.3 Runs #387, #389, #391 and #393 each passing 98/98 numbered validation steps. No open PRs existed before Run 25.
- New game: `daily_games/KROLL_Vent_Runner/`, a side-view platform escape with five power cells, moving hazards, vent boosts, three lives and a 90-second limit. Godot 4.3+, no external assets/add-ons. Import through `daily_games/KROLL_Vent_Runner/project.godot`.
- Existing-system regression: `tests/inventory_mineral_catalog_compatibility_test.gd` checks every MineralCatalog ID is registered in `SurvivalInventory.ITEM_WEIGHTS`, all mineral weights match, registered weights are finite/non-negative, and externally injected unknown counts receive the non-zero safety weight and are rejected by save validation without mutation.
- Feature PR [#84](https://github.com/qaqp980520-prog/2126-Survival/pull/84) merged as `4d465dab1b966617c4bf08ab57d344bffb5eb5a9`; validated candidate HEAD `f2b0d5aa6cdad0be26ae3063ccabd8a82332e334`.
- Canonical Godot 4.3 CI Run #395 (40509153168) succeeded: 102 numbered validation steps passed, zero failed steps. New game import/rules/runtime steps 99–101 and inventory/mineral compatibility step 102 all passed. Full job completed successfully after cleanup steps.
- No local Godot executable is available; no local GUI/GPU/iPhone test is claimed. The compatibility test detects drift but does not yet centralize the two catalogs.
- Remaining work: production M1.3 world controller is still absent; underground mining remains a fixed-cave prototype; asynchronous streaming and device QA remain open. Next priority is production world-session integration and end-to-end mining/drop/weight/save/reload/failure-recovery acceptance tests.

## 2026-10-27 Run 24 — Frequency Lock + mineral regeneration clock guard (merged / exact-head CI passed)

- Start-of-run reconciliation: Run 23's PR #79 was initially recorded as pending, but the actual exact-head Godot 4.3 Run #384 (40489504444) subsequently completed successfully. PR #79 merged as `6cd7a8bf2372972a7f64064f5c6653145141657e`; this was the Run 24 base.
- New game: `daily_games/KROLL_Frequency_Lock/`; four unique symbols selected from a six-symbol bank, exact/misplaced feedback, eight attempts, deterministic secret generation, keyboard/mouse/touch input and restart. Godot 4.3+, no external assets/add-ons.
- Existing-system fix: `systems/MineralMiningNode.gd` now resets `last_regen_unix` when `restore_vein(units)` actually increases stock. This prevents a depleted interval from being banked and converted immediately into extra stock after manual restoration.
- Tests: `daily_games/KROLL_Frequency_Lock/tests/rules_test.gd`, `tests/game_smoke_test.gd`, and `tests/mineral_mining_regeneration_test.gd`. Coverage includes feedback scoring, invalid/duplicate symbols, win/lockout, interval boundaries, clock rollback, full-stock timer reset, invalid-save non-mutation, legacy schema-v1 loading, manual restore timing, and existing underground mining compatibility.
- Feature branch `feature/run24-kroll-frequency-lock-mineral-clock-regression-2026-10-27`; PR [#80](https://github.com/qaqp980520-prog/2126-Survival/pull/80) merged as `29915be423318a4c3be4a2fbceeb2ec78f1e59b9`. Exact candidate HEAD: `b6316a60561eb0590021cd086426ca95d8fa80fa`.
- Exact-head canonical Godot 4.3 CI Run #387 (40493037193) succeeded: 98 numbered validation steps, zero failed steps. Steps 95–97 validated Frequency Lock import/rules/runtime; step 98 validated mineral regeneration. Focused Run 24 workflow Run #2 (40493037265) also succeeded, including root import, game import/rules/runtime, mineral regeneration and underground mining compatibility.
- At feature PR #80 closeout, GitHub compare confirmed `main` equalled `29915be423318a4c3be4a2fbceeb2ec78f1e59b9`. Documentation PR #81 then merged as `487c9740a9248315fd7f2f3489ef9135b9bc74a6`, and follow-up SHA-correction PR #82 merged as `ae2a6e443926bc716c582ec0031f2176e83330f2`. These are chronological merge points for Run 24, not a claim that either remains HEAD after subsequent documentation commits. Exact-head documentation CI passed Run #389 (40493657236) and Run #391 (40494066682), 98/98 numbered steps each. The connector did not expose separate main-push workflow records for the documentation merges, so no post-merge push CI is claimed.
- Limits: no local Godot executable, GUI/GPU playtest or iPhone hardware test. Frequency Lock is a compact puzzle prototype, not an account-security tool. The production M1.3 world controller remains absent; mining remains a fixed-cave prototype and world streaming remains synchronous/factory-driven.
- Next: connect the tested inventory/mining lifecycle to the production world controller when that controller exists; add production-scene load/unload/save/restore tests and device QA.

## 2026-10-27 Run 23 — Network Stabilizer + underground mining capacity guard (merged / exact-head CI passed)

- Base main: `629f8c79518d46717326ab833d70fc3a2953a843`. Run 23's pending snapshot was later superseded by successful full CI.
- New game: `daily_games/KROLL_Network_Stabilizer/`; a 10×8 relay-routing/packet-cleaning arcade prototype with three waves, scanning relays, credits and network integrity. Godot 4.3+, no external assets/add-ons.
- Mining regression: `tests/underground_mining_playground_test.gd` injects maximum valid inventory count, confirms the bridge rejects the next unit and verifies the vein's stock does not decrease.
- PR [#79](https://github.com/qaqp980520-prog/2126-Survival/pull/79), exact HEAD `8cae8af531ca65140de34404b1b655fbd434258d`, passed full Godot 4.3 CI Run #384 (40489504444), 94 numbered validation steps, zero failures. Steps 91–94 covered underground mining and Network Stabilizer import/rules/runtime. PR #79 merged as `6cd7a8bf2372972a7f64064f5c6653145141657e`.
- The earlier focused Run #4 (40488678824) validated a pre-rename equivalent candidate; it is historical evidence, not a substitute for Run #384.
- Limits: local GUI/GPU/iPhone tests not performed; the underground mine is a fixed-cave prototype, not the missing production M1.3 world controller.
- Next: continue toward production world-controller integration rather than treating the cave prototype as production.

## 2026-10-27 Run 22 — Command Grid + underground mining entry (merged; exact-head CI passed)

- Start-of-run reconciliation: GitHub main had advanced from Run 21 closeout SHA `d2a9d8a9fef010af49eedbb5b8e231a7bec96209` to `7ee84c5e61a61bd5d30a9d7ebf391e1a6fe887d7` (21 commits ahead, 0 behind). The intervening history adds the Survival Test Hub, surface inventory bridge integration, and a correction that mineral veins remain underground and are not mineable from the surface. Run 21's Notion/index snapshot had not recorded this later history; preserve it and use the actual main SHA as the baseline.
- New game: `daily_games/KROLL_Command_Grid/`; deterministic 8×8 turn-based tactics, four data cores, shortest-path security bots, three EMP charges, 32-action budget, keyboard and mouse/touch grid input. Godot 4.3+, no external assets/add-ons.
- New underground integration: `prototypes/UndergroundMiningPlayground.tscn` and `prototypes/UndergroundMiningPlayground.gd`. Registers three cave veins under stable chunk ID `underground/cave_0_0`, uses `MineralChunkController`, `MineralVeinRegistry`, `MineralMiningNode`, and `SurvivalWorldBridge`; F mines, G drops one unit, HUD shows immediate weight/encumbrance state.
- Regression: `tests/underground_mining_playground_test.gd` checks below-surface placement, stable chunk registration, mine-to-inventory transfer, vein snapshot restore, drop weight recalculation, and no surface mining path. Existing surface test remains in place.
- Hub/CI changes: `prototypes/SurvivalTestHub.gd`, `tests/survival_test_hub_smoke_test.gd`, `.github/workflows/godot-validation.yml`; the hub now exposes a third underground-mine entry and CI imports/tests Command Grid plus the cave integration.
- Feature branch: `feature/run22-underground-mine-cargo-crane-2026-10-27`, based on start SHA `7ee84c5e61a61bd5d30a9d7ebf391e1a6fe887d7`. PR [#76](https://github.com/qaqp980520-prog/2126-Survival/pull/76) was merged only after exact-head Godot 4.3 CI Run #360 (`40486271348`) succeeded. Candidate HEAD: `67f2818e6269ce87f6b36054bae59d38c54abfcd`; functional PR #76 merge commit: `0c232c540d2d479ab71a22e065384e55aea5ca54`. Documentation PR #77 merged as `a975e111853b94ae5684911812796bdd9d63d04e`; this is the final main SHA. Run #360 passed all 91 numbered validation steps (steps 1–91), zero failed steps. The new Command Grid import/rules/runtime steps 88–90 and underground mining integration step 91 all passed. Run #354's implicit Label-name failure was fixed with explicit `StatusLabel`; Run #357's stale surface-mining success-marker mismatch was fixed by aligning the workflow with the actual underground-only regression marker. GitHub compare first confirmed main equalled the PR #76 functional merge, then after PR #77 the final main equalled `a975e111853b94ae5684911812796bdd9d63d04e`. PR #77 exact-head Run #362 (`40486889706`) passed all 91 numbered steps; final open PR search is empty. No separate main-push workflow run was exposed for the final docs merge SHA.
- Limits: this remains a fixed single-cave prototype, not the missing production M1.3 controller; no local GUI/GPU/iPhone test is claimed.

## 2026-10-27 Run 21 — Neon Breaker + recoverable active-world save (merged / exact-head verified)

- Base main after Run 20 documentation merge: `31b8038824caf0f368262d243c2052abc4848e8b`; PR #73 exact-head Godot 4.3 CI Run #325 succeeded with all 82 numbered validation steps.
- New game candidate: `daily_games/KROLL_Neon_Breaker/`; 8×5 neon brick field, paddle steering, three lives, 60-second timer, keyboard/mouse/touch controls. Godot 4.3+, no external assets or addons.
- Rules and runtime tests cover paddle bounds, reflection, hit-angle steering, life/timer boundaries, launch, brick collision/scoring, life loss and restart.
- Existing-system change candidate: `prototypes/BackroomsPortalPlayground.gd` writes a temporary save, flushes and parses it before promotion, retains a backup during replacement, and recovers a backup if the primary save is missing.
- Integration tests inject a temporary-path obstruction to ensure failed writes preserve the previous save bytes, verify a complete replacement payload, and simulate recovery from a backup. Existing active-world save roundtrip and invalid-payload non-mutation tests remain enabled.
- PR #74 merged as `2625b3a0460305ab0759a1e01f9040ed74db36a0`; exact feature HEAD `55b2bd8248af756f3bcbaafa19fa396c37455aec` passed Godot 4.3 CI Run #327 (`40471674229`) with all 85 numbered validation steps successful and zero failures. This includes Neon Breaker import/rules/runtime (steps #82–#84) and active world save roundtrip with atomic-write failure injection (step #85).
- Main compare confirms `main` is identical to merge commit `2625b3a0460305ab0759a1e01f9040ed74db36a0`. The GitHub connector did not expose a separate main-push workflow run for this commit; exact-head PR CI is the verified test evidence. Local GUI/GPU/iPhone tests are not claimed.
- Boundary: `scripts/world.gd` remains absent; this work improves the active Backrooms Portal Playground controller and does not claim M1.3 production-world integration.

## 2026-10-27 Run 20 — Magnetic Salvage + active world save roundtrip (merged / exact-head verified)

- PR #72 merged to main as `fa4f680434fe7e961b1d6266a8a7357b9ef0e77a`. Feature head `5d01baf62594834d7d492fffd7a42090e13fa3d1` was validated against base `3b20fc9cb5f5ec2532c407e31a3212510e4c7062`.
- Exact-head Godot 4.3 CI Run #321 (40465124945) succeeded; all 82 numbered validation steps passed, including root project import and existing regressions. Steps #79–#81 verified Magnetic Salvage import/rules/runtime; step #82 verified the active world save roundtrip integration test.
- New game: `daily_games/KROLL_Magnetic_Salvage/`; continuous top-down drone movement, magnetic pull pulses, charge regeneration, debris hazards, collect six metal parts and extract at dock before 75 seconds. Godot 4.3+, no external assets/addons. Import via `daily_games/KROLL_Magnetic_Salvage/project.godot`.
- Existing-system integration: `tests/world_session_save_roundtrip_test.gd` instantiates `prototypes/BackroomsPortalPlayground.tscn`, writes and reloads the real `user://backrooms_playground_save.json`, and verifies inventory/player-position roundtrip. Unknown item IDs and non-finite player positions are rejected without partial live-state mutation.
- The main game script avoids banking charge regeneration while full; the smoke test uses the scene's existing typed scrap array.
- Post-merge main-push CI Run #322 (40465398061) completed successfully for exact main SHA `fa4f680434fe7e961b1d6266a8a7357b9ef0e77a`; all 82 numbered validation steps passed, with no failed steps. This is the authoritative post-merge main validation.
- Boundary: `scripts/world.gd` remains absent. This adds an end-to-end test for the active playground controller; it does not claim the separate M1.3 production world controller or crop persistence patches are integrated.
- Limits: no local Godot executable, GUI/GPU playtest or iPhone hardware test was available.
- Documentation-only PR #73 merged as `31b8038824caf0f368262d243c2052abc4848e8b` after exact-head Run #325 succeeded (82/82 numbered validation steps). Run #322 remains the verified post-merge code CI for the prior main SHA `fa4f680434fe7e961b1d6266a8a7357b9ef0e77a`.
- Next: continue with the actual production world controller integration rather than treating the prototype as production.

## 2026-10-27 Run 19 — Echo Diver + WorldBridge save regression hardening (merged / verified)

- PR #70 merged to main as 66e18a1350bc81c42ffac86eb440c4eba739e4da. Feature head cb07165259502bbc390bbe31c501e95f9cf29011 was validated against base 5f961148f8ee25b67309ec88020b5e08bc3e4cad.
- Exact-head Godot 4.3 CI Run #317 (40454156074) succeeded: all 78 validation steps passed, zero failed steps. It includes root project import, existing survival regression suite, Echo Diver import/rules/runtime tests, and WorldBridge save-adapter integration.
- Run #316 (40453841062) failed only because the Echo Diver runtime smoke test omitted the workflow-required success marker; all seven runtime assertions had passed. Commit cb071652... adds the marker only when the final exit code is zero; Run #317 verifies the corrected head.
- New game: daily_games/KROLL_Echo_Diver/; 8×7 sonar navigation, three data beacons, hidden hazards, 32 fuel, 75-second limit; four sonar pulses reveal nearby hazards for 2.4 seconds. Godot 4.3+, no external assets/add-ons.
- WorldBridge test hardening: tests/world_bridge_save_adapter_integration.gd owns/stops/frees its watchdog Timer, tests malformed inventory containers, unknown IDs, fractional/negative/out-of-range counts, invalid game day and unsupported version, and asserts rejected restore does not mutate live inventory. CI uses a 35-second timeout and requires an explicit success marker.
- PR #70 changed 12 files; the merged workflow contains one guarded WorldBridge integration step (no duplicate test execution).
- M1.3 boundary: scripts/world.gd is absent from the current repository (GitHub contents API returned 404). M1.3 save-validation patches remain unapplied patch files; do not claim the production world save/controller is integrated.
- Limits: no local Godot executable, GUI/GPU playtest, or iPhone hardware test was available. Production world-controller integration and device QA remain outstanding.
- Next: locate/add the actual production world controller, then apply M1.3 validation and connect SurvivalWorldBridge to the real pickup/mining/save lifecycle with end-to-end tests.

## 2026-10-27 Run 17 — Vertical Relay + atomic surface restore（已合併／已驗證）

- PR #64 功能合併 commit：e9d853fe0114e3432b7269f902fd579bbcbe9dcc；PR #65 文件／索引同步合併 commit：4bc657cad8133e21a44b5a473283fe9023d9da62。此處記錄 Run 17 的兩個歷史合併點，不將較早的功能合併 SHA 誤標為最新 main。
- PR #64：Run 17: Vertical Relay and atomic surface restore；功能分支 HEAD c00be54a008978f2406ea35612d6d02609f1bcf8，已合併。
- 精確驗證：PR-head Godot 4.3 CI Run #297（40442929654）成功，72/72 個必要驗證步驟通過；main-push CI Run #298（40443291605）亦成功，72/72 個必要驗證步驟通過。
- KROLL Vertical Relay：daily_games/KROLL_Vertical_Relay/；單關垂直平台跳躍，收集五個資料晶片、避開兩個移動危險區並在 75 秒內抵達出口；鍵盤與觸控按鈕；無外部素材。CI 已通過匯入、規則與 runtime smoke tests。
- Surface stream restore transaction M0.2：prototypes/SurfaceChunkStreamingPlayground.gd 的 restore_stream_state() 先保存礦脈快照；目標串流失敗時回復舊位置、依 Controller 實際區塊 ID 執行 recovery，再還原舊礦脈狀態。get_last_restore_report() 提供 phase、rollback_complete 與原始目標同步／恢復細節。
- 故障注入回歸：tests/surface_chunk_streaming_playground_test.gd 使目標窗口在至少一個新區塊載入後失敗，驗證玩家位置、Controller／Director ID、保存礦脈 ID 與 live ore count 復原；保留原始 load_factory 失敗報告。
- 測試清理：Vertical Relay 與 surface streaming smoke tests 已改用由測試擁有並在結束前停止／釋放的 Timer watchdog。Run #297／#298 的這兩項測試不再輸出 ObjectDB leak warning。其他既有診斷、Cipher Recall、Cargo Tugs、Vector Rally 測試仍有非致命 ObjectDB warning；CI 成功，但這些舊警告尚未全部清理。
- 限制：本機沒有 Godot 執行檔，GUI／iPhone 實測未完成。SurfaceChunkStreamingPlayground 仍是整合原型，不是正式世界生成器；Director 仍同步、factory-driven，非同步區塊串流未完成。

## 開發追蹤
- [M1.3.4 世界狀態欄位驗證補強](patches/M1_3_4_WorldStateValidation.patch)：要求作物記錄具有有效三維座標，驗證文字與成熟狀態型別；尚未經 Godot 4 測試。
- [M1.3.3 存檔欄位驗證修補](patches/M1_3_3_SaveValidation.patch)：讀檔前驗證版本、背包數量、快捷欄、座標與作物狀態欄位；尚未經 Godot 4 測試。
- [M1.3.2 合併後靜態複核](docs/M1_3_2_STATIC_REVIEW_2026-10-25.md)：核對 M1.3.1 作物存檔與 M1.3.2 重複讀檔修補的整合關係，列出尚未測試的風險。
- [M1.3 跨系統整合檢查清單](docs/INTEGRATION_CHECKLIST_M1_3.md)：追蹤存檔修補、共用背包、世界互動與回歸測試之間的依賴。
- [M1.3.2 重複讀檔整合修補檔](patches/M1_3_2_IdempotentWorldRestore.patch)：避免重複載入時複製動態作物／玩家種植作物，並將標籤設為作物子節點；尚未在 Godot 4 實測。
- [M1.3.1 世界作物存檔修補檔](patches/M1_3_1_WorldCropPersistence.patch)：補上種植作物、野生作物重生倒數與已採集固定作物的存檔資料；僅為 patch，尚未在 Godot 4 測試。
- [程式碼稽核與強制驗證流程](docs/CODE_AUDIT_2026-10-25.md)：第一輪靜態檢查、已知問題與後續測試順序。
- [開發問題與待辦清單](docs/DEVELOPMENT_ISSUES.md)：整合、測試、跨平台與資產保存待辦。

## 共用系統
- [SurvivalWorldBridge.gd](systems/SurvivalWorldBridge.gd)：世界拾取、採礦產出、丟棄、負重查詢與存檔接口橋接（M0.2；尚未接入既有遊戲場景，尚未在 Godot 4 實測）。[整合說明](systems/INTEGRATION_M0_2.md)
- [SurvivalInventory.gd](systems/SurvivalInventory.gd)：背包數量、重量、負重倍率與存檔字典服務（M0.1；尚未在 Godot 4 實測，也尚未替換既有原型實作）。

## 專案分類
- [歷史原型與資產目錄](docs/HISTORICAL_ASSET_CATALOG.md)：依世界／後室、背包與收藏室、KROLL、採礦、每日小遊戲分類，並註明整理原則。

## 上傳狀態
- 已提交：專案索引與歷史資產目錄。
- 已上傳原始 ZIP（提交已核對）：
  - [KROLL Circuit Relay（2026-10-21）](releases/mini-games/KROLL_Circuit_Relay_Godot4_2026-10-21.zip)
- 已上傳原始程式檔（非 ZIP）：
  - [KROLL Drone Rescue 原始專案檔](prototypes/KROLL_Drone_Rescue/README.md)（project.godot、main.tscn、main.gd、README 已分別提交；原始 ZIP 不在此資料夾）
  - [KROLL Signal Runner 原始專案檔](prototypes/KROLL_Signal_Runner/README.md)（project.godot、main.tscn、scripts/game.gd、README 已分別提交；原始 ZIP 不在此資料夾）
  - [Ore Shift 採礦小遊戲原始專案檔](prototypes/Ore_Shift/README.md)（project.godot、main.tscn、scripts/main.gd、README 已分別提交；原始 ZIP 不在此資料夾）
- [Portal Courier 原始專案檔](prototypes/Portal_Courier/README.md)（project.godot、main.tscn、scripts/game.gd、README 已分別提交；原始 ZIP 不在此資料夾）。
- 尚未完成：工作區中其餘原始 ZIP 與模型的二進位檔上傳。歷史目錄中的其他檔名不代表已進入 GitHub。
- 測試狀態：現有原型不能一概視為已在 Godot 4 實測。

## 版本索引
- KROLL Circuit Relay：提交 `6b46c1e5e6549e0ae5f827f3b1580281c55fb12a`；ZIP 已上傳，尚未在 Godot 4 實測。
- KROLL Drone Rescue：原始專案文字檔已分別提交；README、project.godot、main.tscn、main.gd；尚未在 Godot 4 實測。
- KROLL Signal Runner：原始專案文字檔已分別提交；README、project.godot、main.tscn、scripts/game.gd；尚未在 Godot 4 實測。
- Ore Shift：原始專案文字檔已分別提交；README、project.godot、main.tscn、scripts/main.gd；尚未在 Godot 4 實測。
- Portal Courier：原始專案文字檔已分別提交；README、project.godot、main.tscn、scripts/game.gd；尚未在 Godot 4 實測。
- SurvivalInventory 共用背包服務 M0.1：`18777282039f1f5fab8427bee71b2163ddb22549`；程式與說明文件已提交，尚未在 Godot 4 實測，尚未整合進 M1.3 原型。
- SurvivalWorldBridge 橋接接口 M0.2：`732f32ed09db88b66d5304e4b61f8204b8b91b7d`；橋接腳本與整合說明已提交，尚未接入既有場景或在 Godot 4 實測。
- 新版本完成並實際提交後，繼續新增對應路徑與提交資訊。


## 2026-10-26 Run 4 — 新增原型
- KROLL Gravity Lander：daily_games/KROLL_Gravity_Lander/；獨立 Godot 4.3+ 專案，含規則測試與場景 smoke test。PR #16 的 Godot 4.3 CI run #32 已通過；iPhone 實機尚未測試。
- Backrooms Portal Playground：根目錄 project.godot + prototypes/BackroomsPortalPlayground.tscn；將 portal director、3D portal visual、共用 SurvivalWorldBridge、save adapter 串成可啟動的整合測試場景。這是測試場，不代表正式 M1.3 world.gd 已接線。
- 後室入口視覺修正：保留原場景 90° X 軸旋轉以維持垂直 ring，入口中心提高至地面上方 1m；新增 scene test 覆蓋姿態與位置映射。

## 2026-10-26 Run 5 — Core Defense + shared inventory binding
- KROLL Core Defense：`daily_games/KROLL_Core_Defense/`；獨立 Godot 4.3+ 塔防小遊戲，含規則測試與場景 smoke test。玩法為點擊格子部署砲塔、三波無人機路線防守；無外部素材。
- SurvivalWorldBridge binding fix：新增 `bind_inventory()`，保留進入 SceneTree 前注入的共用背包，並拒絕缺少必要方法的物件；新增 `tests/world_bridge_binding_test.gd` 覆蓋 ready 前／後綁定與無效替換回歸。
- CI：`.github/workflows/godot-validation.yml` 新增 Core Defense 匯入、規則測試、場景 smoke test 與 bridge binding lifecycle 測試。
- 分支：`feature/kroll-core-defense-bridge-binding-2026-10-26`；PR #18 已合併至 main，merge commit `7ab6a6f14aaff0bd3b65cb72f782442394f7c05b`；Godot 4.3 CI run #34 全部驗證步驟成功。
- 本機沒有 Godot 執行檔；Run 5 程式碼已合併 main，Godot 4.3 引擎驗證證據為 PR #18 的 CI run #34。


## 2026-10-26 Run 6 — KROLL Freight Sorter M0.1（已驗證／已合併）
- 小遊戲路徑：daily_games/KROLL_Freight_Sorter/；60 秒貨物分流反應遊戲，原礦／醫療／資料核心分流至對應倉口，危險貨箱必須隔離；無外部素材。
- 包含 project.godot、main.tscn、main.gd、rules.gd、規則測試、場景 smoke test、README。
- PR #25 已合併，commit `8baf8a7653ec8a255c159e6fd1c4b3a24c1afe21`；Godot 4.3 CI Run #44 success，29 個主要步驟全部成功。
- 本機沒有 Godot 執行檔；尚未進行人工視覺或 iPhone 測試。


## 2026-10-26｜離線礦脈再生 M0.1（已驗證／已合併）
- 修改：systems/MineralMiningNode.gd；schema 升至 v2，新增 max_units、regen_interval_seconds、last_regen_unix，支援依 Unix 時間進行線上／離線再生、保留部分間隔、容量上限與時鐘倒退防護。
- 相容：仍接受舊 schema-v1 存檔；缺少再生欄位時從載入時間開始計時。無效 schema、容量、間隔、時間戳或存量會在改動狀態前拒絕。
- 測試：tests/mineral_catalog_test.gd 新增離線回補、部分間隔、容量上限、時鐘倒退、schema-v2 往返、舊 schema-v1 相容與無效資料拒絕。
- 文件：docs/MINERAL_VEIN_OFFLINE_REGENERATION_M0_1_2026-10-26.md。
- PR #28 已合併 main，commit `4990b15700654bbadeac29784662c2e7b9a58bf8`；Godot 4.3 CI Run #55 success，31 個 workflow steps 全部成功。
- 舊候選 PR #26、#27 已關閉且未合併；Run #45／#50 為舊候選紀錄，Run #53／#54 cancelled，不作為成功證據。


## 2026-10-26｜未知物品負重防禦 M0.1（已驗證／已合併）
- 修改：systems/SurvivalInventory.gd 新增 UNKNOWN_ITEM_WEIGHT_KG=1.0；total_weight_kg() 對直接注入 public counts 的未知 key 不再預設為 0kg。
- 相容：已登錄物品重量不變；constructor、add_item()、load_save_dict() 仍拒絕未登錄 ID，存檔驗證失敗不會部分改動狀態。
- 測試：tests/inventory_weight_boundaries.gd 新增未知 key 防禦性計重、未知 ID API 拒絕與無效存檔狀態保留測試。
- PR #30 已合併 main，commit `9e05c47dc91a361aee4e49af7304ca812a802b06`；Godot 4.3 CI Run #57 success，31 個 workflow steps 全部成功。
- PR #3 已關閉為 superseded；其嚴格存檔驗證已在 main，剩餘未知重量 fallback 由 PR #30 完成。
- 限制：1.0kg 只作防禦性 fallback；正式物品仍需登錄 ITEM_WEIGHTS。counts 仍是公開字典，長期可考慮封裝存取。


## 2026-10-26 Run 7 — Mineral registry streamed-chunk persistence M0.2 (verified and merged)
- PR #34 is merged to main as 14869cffd543d8d33dec427fb84ddb493e206fc6.
- Exact merged head e6a55bcec7a160a1ae8fd27a295deae661f9d58e passed Godot 4.3 shared CI Run 40276109216 on base 6c6f2779541175b3cc372d3cb73319ceac98f354. All 33 workflow steps succeeded; guarded logs contained no actual SCRIPT ERROR, ERROR:, or FAIL output.
- Mineral registry behavior: systems/MineralVeinRegistry.gd retains records for unloaded chunk IDs; unregister captures final state; register restores by stable ID; saved IDs are deterministic; invalid restore payloads are rejected before mutation; same-node registration is idempotent; disabling offline catch-up resets the clock so the next _process() cannot apply skipped time.
- Regression files: tests/mineral_catalog_test.gd and tests/mineral_vein_chunk_stream_test.gd. The dedicated step printed “Mineral vein chunk-stream persistence tests passed.” and the catalog step printed “Mineral catalog regression tests passed.”
- Workflow guard: .github/workflows/godot-validation.yml rejects SCRIPT ERROR, ERROR:, and FAIL output and requires explicit success markers.
- Design note: docs/MINERAL_VEIN_CHUNK_STREAM_PERSISTENCE_M0_2_2026-10-26.md.
- Related verified changes: PR #35 strict Variant typing fix merged as 6c6f2779541175b3cc372d3cb73319ceac98f354 (Run 40275478307 success); PR #36 KROLL Magnetic Pinball M0.1 merged as abe695c08adc26b699033d9d500dadd98fcb8b64 (dedicated Run 40275642300 and shared Run 40275642253 success). PR #33 was closed without merge as superseded.
- Limit: the formal world/chunk streaming controller is not yet present; its lifecycle still needs to call registry register/unregister with deterministic IDs. No local Godot binary, graphical manual playtest, or iPhone device test is claimed.
- Next step: integrate the registry into the actual world/chunk load-unload lifecycle, then add a scene-level integration test covering chunk unload, save/load, and world travel.
- Old documentation PRs #1, #2, #6, and #8 remain open and are not claimed as merged.


## Run 8 update — 2026-10-26 — Mineral Chunk Controller + KROLL Pulse Rhythm

- Working branch: `feature/kroll-pulse-rhythm-mineral-chunk-controller-m0-1-2026-10-26`; base `main` at `9d2554c8e02ff5b4fa2528697d98b1a5a30700d2`.
- New survival controller: `systems/MineralChunkController.gd` owns instantiated chunk-root lifetime, discovers nested `MineralMiningNode` nodes using stable scene-name paths, connects them through `MineralChunkLifecycleAdapter`, and delegates mineral save/restore to `MineralVeinRegistry`.
- New regression test: `tests/mineral_chunk_controller_test.gd` covers save -> unload -> registry restore -> reload with elapsed regeneration, empty chunks, and duplicate chunk ID rejection.
- New mini-game: `daily_games/KROLL_Pulse_Rhythm/` (Godot 4.3, no external assets): four-lane rhythm timing, 32 authored notes, PERFECT/GOOD/MISS scoring, five reactor cores, keyboard and lower-screen touch input.
- New validation: `.github/workflows/godot-validation.yml` now checks the new project files, imports Pulse Rhythm, runs its rules and scene smoke tests, and runs the mineral chunk controller integration test with explicit success markers and runtime-error guards.
- Documentation: `docs/MINERAL_CHUNK_CONTROLLER_M0_1_2026-10-26.md`.
- Validation status at branch creation: no local Godot binary is available. Static source review only so far; remote Godot 4.3 CI must pass before merge. No GUI playtest or iPhone device test is claimed.
- At the time of this original feature-branch index commit, PR #39 had not yet been opened; it was subsequently opened, fully validated by Run #115, and merged into main as `1b48e11f1638e56d63263fa3ed6cb37fd9106624`.
- Integration limit: this controller owns instantiated chunk roots provided by a world generator, but does not yet perform distance-based spatial selection, asynchronous scene loading, or procedural world generation. It is the first lifecycle owner, not a complete streaming engine.
- Next: inspect the complete diff, run the new CI, fix any actual failures on this branch, and only merge after the full regression suite passes. Then reconcile the Notion asset index with the resulting PR/commit/test IDs.

## Run 8 validation update — 2026-10-26

- PR #39 was merged into `main`: https://github.com/qaqp980520-prog/2126-Survival/pull/39. Merge commit: `1b48e11f1638e56d63263fa3ed6cb37fd9106624`.
- Initial full CI Run #113 (40284210713) failed at controller compilation because the new script referenced its own global class name in the ID check. Fixed in commit 052ff685d27cd0e7007d36c41ee23c59756f3b09 by calling the preloaded adapter's static ID builder.
- Full Godot 4.3 CI Run #114 (40284396621) then succeeded. Required steps 1–35 all passed; explicit success markers were present for Pulse Rhythm rules tests, Pulse Rhythm runtime smoke test, and mineral chunk controller integration test. Job logs showed no actual Godot script/runtime error output.
- The feature-branch index update was validated by final-head Godot 4.3 CI Run #115 (`40284605381`) before PR #39 merged. Run #115 passed; required steps 1–35 succeeded, including the new rhythm and chunk-controller tests.
- Current limitations remain: no local Godot binary, no GUI/iPhone playtest, and no distance-based or asynchronous chunk selection. Controller owns chunk roots supplied by the world generator; integration into the production world generator remains a separate step.

## Run 8 final mainline reconciliation — 2026-10-26

- PR #39 is merged; mainline merge commit is `1b48e11f1638e56d63263fa3ed6cb37fd9106624`.
- Validating run on the exact PR head before merge: Godot 4.3 CI Run #115 (`40284605381`) success; all required steps 1–35 passed. The merge commit has the same tree as the validated PR head.
- This reconciliation was PR #40, merged as `349ff77f2fcd2e2ac136d2dc8432793408c883a7` after Godot 4.3 CI Run #116 (`40284833278`) passed with 38 steps and zero failures.
- Remaining: connect `MineralChunkController` to the actual production world generator; no distance-based chunk selection, async streaming, GUI playtest, or iPhone test is claimed.


## 2026-10-26 Run 9 — merged and validated
- KROLL Hydroponics Shift M0.1: standalone Godot 4.3+ crop-care arcade game in daily_games/KROLL_Hydroponics_Shift/; three beds, moisture/growth simulation, ten-harvest target, keyboard and touch controls; no external assets.
- MineralChunkController M0.1.1: failed registration detaches but preserves the caller-owned root. Integration tests cover duplicate stable-ID load preservation and rollback when a later vein unregister fails.
- Code head `92568e240abe1bd25149bba5a8da47d41ab451ce` passed Godot 4.3 CI Run #123 (`40290454611`); all 38 required validation steps succeeded, zero failures.
- Final pre-merge head `9c519e47b4e77fcf53392647716fcd4db03c04ab` passed Run #126 (`40291085414`); all 38 required validation steps succeeded, zero failures, including Hydroponics import/rules/runtime smoke and MineralChunkController integration tests.
- PR #42 merged to main as `e0545d7a5bcd7a2bb44e810ca6d56d8fef4b93c0`. Current index reconciliation is a docs-only follow-up PR; do not confuse it with the already merged feature PR.
- Limits: formal world generator integration, distance/asynchronous streaming, manual GUI play and iPhone testing remain incomplete.


## 2026-10-26 Run 9 — Backrooms integration audit
- Audit report: [docs/BACKROOMS_INTEGRATION_AUDIT_2026-10-26.md](docs/BACKROOMS_INTEGRATION_AUDIT_2026-10-26.md).
- Fixed maze streaming cell indexing to align with the actual half-cell wall boundaries; added coordinate-boundary regression cases.
- Natural portal director now ticks only on the Surface; added a regression test to prevent portal spawning inside Backrooms.
- World-save restore rejects a state that combines a Backrooms location with an active surface portal, before mutating live inventory/world state.
- Bound the playground player's movement and jump permissions to SurvivalWorldBridge weight calculations; regression tests cover super-heavy movement slowdown and immediate recovery after dropping items.
- Removed duplicate shared-edge wall collision bodies, added deterministic corridor baffles and ceiling OmniLight3D nodes; topology tests cover edge symmetry and 7×7 connectivity.
- Enabled Godot headless validation on pushes to `main` so direct commits receive automated checks.
- Current status: changes committed to main; latest Godot headless CI result must be checked before claiming engine validation passed. Graphical manual playtest and iPhone test remain outstanding.

- Camera/avatar follow-up: root prototype now has a visible primitive humanoid in third-person mode and `V` toggles first-person mode; first-person hides the avatar to prevent camera clipping. Headless camera-toggle regression coverage is included in `tests/backrooms_portal_playground_test.gd`.


## 2026-10-26 Run 11 — Sentinel Escape + persistent shadow settings + mineral streaming reconciliation
- Current implementation branch merged: PR #49; merge commit `2cca29d30481a3943e07600cf4b73a757f7ea976`. Parent/main base before merge: `2d7f346f1d7d199278f4e5896c1fdb506d850a55`.
- Exact implementation head `d4dc2fa58274e30d82d48cf647aa9124fc014aae` passed Godot 4.3 CI Run #181 (`40316093821`) before merge. Verified success markers include settings profile/integration, MineralGridStreamingDirector, Signal Siphon rules/runtime, and Sentinel Escape rules/runtime tests.
- KROLL Sentinel Escape: `daily_games/KROLL_Sentinel_Protocol/`; collect 8 energy cells, avoid security drones, short nonviolent dash; keyboard/touch paths; no external assets. The README-listed Space dash was found missing from the keyboard input path and fixed in PR #51, merge commit `fb08be72eb0f68be75b352bb73e4ec715030f4c8`; exact-head CI Run #185 passed with explicit dash timer/cooldown assertions.
- KROLL Signal Siphon remains included at `daily_games/KROLL_Signal_Siphon/`.
- Backrooms settings persistence now saves camera mode, mouse sensitivity, and shadow/graphics quality. Fluorescent flicker is automatic (no user toggle); legacy `flicker_enabled` config keys are ignored. The shadow-quality toggle controls deterministic local shadows and procedural detail.
- MineralGridStreamingDirector and its explicit CI test are included; still synchronous/factory-driven and not wired to the production world generator.
- Superseded PR #46, #47, #48 are closed without merge. PR #49 is merged.
- Main push CI Run #182 (`40316354828`) completed successfully; exact-head PR CI Run #181 also succeeded before PR #49 merge.
- Local GUI/manual play, GPU shader compilation check, and iPhone device test remain unverified.


## 2026-10-26 Run 11 — Consolidated integration/audit references
- [Branch-first integration workflow](docs/BRANCH_AND_INTEGRATION_WORKFLOW.md)：分支、差異審查、測試、合併與 Notion 同步規則。
- [Cross-version integration regression matrix](docs/INTEGRATION_REGRESSION_MATRIX.md)：更新至目前 main 狀態，區分已通過 CI 的原型與尚未接入的正式 M1.3 世界。
- [Inventory/save schema compatibility review](docs/INVENTORY_SAVE_SCHEMA_COMPAT_REVIEW_2026-10-25.md)：把舊靜態發現標記為已修正或仍待正式世界整合，附 Run #181 證據。
- [M1.3 inventory integration boundary](docs/M1_3_INVENTORY_INTEGRATION_BOUNDARY_2026-10-25.md)：保留正式世界控制器缺席與單一資料來源接線的阻斷條件。
- These four documents were consolidated from stale draft PRs #1/#2/#6/#8 after reviewing and updating their content against current main. They are reference/audit documents, not evidence that the full M1.3 world is integrated.
- PR #50 merged as `f6732519736697725a612e4c3a1a8836591c7aaa`; PRs #1/#2/#6/#8 were closed without merge after their documentation was consolidated and updated here.

- PR #51 keyboard dash fix merged as `fb08be72eb0f68be75b352bb73e4ec715030f4c8`; exact-head Godot 4.3 CI Run #185 (`40316901157`) succeeded with explicit dash timer/cooldown assertions.
- Current main after the documentation consolidation is `f6732519736697725a612e4c3a1a8836591c7aaa`. Main push CI Run #188 (`40317515975`) is pending at the time of this index update; the PR-level exact-head CI Run #187 succeeded before the docs merge.
- GitHub open PR list was empty after closing superseded drafts #1/#2/#6/#8 and old feature branches #46/#47/#48.


## 2026-10-26 Run 12 — Backrooms display/settings follow-up
- Wall texture source replaced with a fine, low-contrast yellow repeating wallpaper pattern in `assets/textures/backrooms_wallpaper.svg`; engine-rendered appearance remains pending a graphical playtest.
- Settings profile now persists `resolution_index` and `shadows_enabled`, validates their types/ranges, and keeps procedural geometry quality separate from dynamic shadow toggling.
- Resolution presets update the window size and viewport base resolution; settings UI scales with the selected preset.
- Regression coverage expanded in `tests/backrooms_settings_profile_test.gd` and `tests/backrooms_settings_integration_test.gd` for resolution range, save/load round-trip, dropdown restoration, and independent shadows.
- Key commits: wallpaper `333ed896`; profile `06bd68f3`; display settings `f4452b90`; profile tests `46ef882f`; integration tests `625629ef`; geometry/shadow separation `0daf395b` and `973e25d5`.
- Exact-head Godot 4.3 CI result must be checked before declaring tests passed. Manual graphical testing and iPhone device testing are still outstanding.

## 2026-10-26 Run 12 — Reactor Balance + transactional mineral streaming rollback (clean-main closeout)

- KROLL Reactor Balance M0.1: `daily_games/KROLL_Reactor_Balance/` (Godot 4.3+, no external assets/addons). A three-reactor output/heat management game with vent/boost actions, 60-second round, 135–165 grid band and 18-second stability goal.
- M0.1.1 regression fix: a meltdown and the 18-second stability threshold could happen on the same tick; meltdown now takes priority over victory. `tests/game_smoke_test.gd` covers the simultaneous condition; README documents precedence.
- MineralGridStreamingDirector transactional rollback: `systems/MineralGridStreamingDirector.gd`; new `tests/helpers/FakeMineralChunkController.gd` and `tests/mineral_grid_streaming_transaction_test.gd` inject failure on the second stale-chunk unload and assert restoration of the original active IDs.
- CI reliability: root project import/parse now runs before root-level tests preload SVG resources. `tests/backrooms_settings_integration_test.gd` now checks SVG-backed `StandardMaterial3D` texture/UV properties and preserves the current separate `high_graphics` / `shadows_enabled` settings.
- PR #54 merged as `4756cee9aef6ccacd95a7752287ab4e65afa7d2b`. Exact PR-head Godot 4.3 CI Run #257 (`40349176376`) passed on `03ae4dfb9d98aad2bede36a6824b9037a5c411f1`: 55/55 steps succeeded, 0 failed.
- Post-merge main push CI Run #259 (`40349541937`) passed on main HEAD `a1e10a620cb13cb8fd12c3b06511d372c24839d3`: 55/55 steps succeeded, 0 failed. This includes the latest Backrooms wallpaper/material follow-up commit.
- Reconciliation: PR #53 was closed without merge because its branch diverged 33 ahead / 22 behind; its Run #225 success is historical only. Main Runs #246/#252/#256 failed on the stale SVG import order or were superseded/cancelled; Run #259 is the final successful main-head evidence.
- Limitations remain: local GUI/GPU/iPhone playtests were not run (no local Godot executable); MineralGridStreamingDirector remains synchronous/factory-driven and is not yet wired into the production world generator.
- Next: connect the director to the real world generator and add scene-level chunk load/unload/save/restore coverage; schedule graphical and iPhone validation separately.

## 2026-10-26 Run 13 — Cipher Recall + playable surface chunk streaming integration (merged)
- Final main HEAD at feature merge: `caf825eca2d2c38b72852209a5edf6d8d4996558`.
- PR #56 merged: feature head `51261d57e6162d469b3ac8be0e765c39bc3d8ab6`; exact-head Godot 4.3 CI Run #268 (`40353202696`) succeeded with 60/60 steps and zero failures.
- Post-merge main push CI Run #269 (`40353782834`) also succeeded on the exact merge commit `caf825eca2d2c38b72852209a5edf6d8d4996558`.
- Mini-game: `daily_games/KROLL_Cipher_Recall/` — 3×3 memory sequence, five rounds (length 3–7), three lives, score, keyboard 1–9 and mouse/touch. Files include `project.godot`, `main.tscn`, `scripts/main.gd`, `scripts/rules.gd`, `tests/rules_test.gd`, `tests/game_smoke_test.gd`, and `README.md`. Godot 4.3+, no external assets/addons.
- Survival integration: `prototypes/SurfaceChunkStreamingPlayground.tscn`, `prototypes/SurfaceChunkStreamingPlayground.gd`, `tests/surface_chunk_streaming_playground_test.gd`, and `docs/SURFACE_CHUNK_STREAMING_PLAYGROUND_M0_1_2026-10-26.md`. Uses the real MineralVeinRegistry, MineralChunkController and MineralGridStreamingDirector with a movable CharacterBody3D and synchronous primitive chunk factory.
- Regression coverage: initial 3×3 load; negative/exact-positive chunk boundaries; shift/unload; 15 retained stable-ID records; save/restore of player position and mineral stock; invalid schema must leave position, active IDs, registry IDs and live stock unchanged.
- CI reliability fix: Run #265 failed after assertions passed because the headless dummy renderer emitted null-mesh errors during teardown. The playground now skips renderer-backed mesh creation in headless mode, and new tests wait a frame after queue_free. Exact-head Run #268 and post-merge main Run #269 both pass.
- Limits: integration playground, not the production M1.3 world generator; chunk creation is synchronous and primitive. No biome generation, async streaming, networking or iPhone touch movement. Local GUI playtest and iPhone device test remain unperformed because no local Godot executable is available.
- Next: wire the validated factory/controller contract to the real production world generator; add production-scene streaming acceptance tests, then do GUI/iPhone validation.


## 2026-10-27 Run 14 — KROLL Cargo Tugs + mineral streaming diagnostics (merged and validated)
- Feature PR #58 merged as `d2eef1c4a30c67116f8bc8a1cb9c3df94bacc561`; exact validated feature head `656d3727c41551ef9ef38ecbc8c34213a4afa23f`.
- Exact-head Godot 4.3 CI Run #272 (`40356509039`) succeeded. Cargo Tugs import/rules/runtime smoke steps #58–#60, mineral streaming failure diagnostics step #44, and surface chunk streaming integration step #61 all succeeded.
- Main push CI Run #273 (`40356977715`) succeeded on merge commit `d2eef1c4a30c67116f8bc8a1cb9c3df94bacc561`.
- Mini-game: `daily_games/KROLL_Cargo_Tugs/` — three-stage warehouse-pushing puzzle with keyboard/touch movement, crates, docking pads, undo and restart; no external assets/addons.
- Survival diagnostics: `systems/MineralGridStreamingDirector.gd` exposes `sync_failed(report)` and `get_last_sync_report()`, including failure phase, rollback completeness, failed chunk IDs and snapshots of controller/director active IDs. `tests/mineral_grid_streaming_diagnostics_test.gd` injects stale-unload failure followed by failed restoration and verifies the incomplete rollback report.
- CI workflow now runs Cargo Tugs import/rules/runtime tests and the explicit mineral streaming diagnostics regression.
- Limits: local Godot executable unavailable; GUI/iPhone tests are not claimed. The streaming director remains synchronous and factory-driven, not connected to the production world generator.
- Next: connect the diagnostics contract to the production world host, define retry/recovery behavior after incomplete rollback, and add production-scene chunk save/restore acceptance tests.

## 2026-10-27 Run 15 candidate — Vector Rally + mineral stream recovery

- Candidate branch: feature/run15-vector-rally-mineral-recovery-2026-10-27; based on main 3aedd4676403258ab5a7bfafd604b7c4c899c3de.
- New game: daily_games/KROLL_Vector_Rally/ — top-down time-trial racer, ordered four checkpoints, three laps, 90-second limit, off-track speed loss, two cooldown-gated boost pads; keyboard and touch controls; no external assets/add-ons.
- Game tests: tests/rules_test.gd covers checkpoint/lap progression, off-track bounds, boost eligibility and speed clamp; tests/game_smoke_test.gd covers win/time-up/restart, off-track drag and boost activation.
- Survival change: systems/MineralGridStreamingDirector.gd adds recover_to_world_position(), which validates and reconciles the controller's actual loaded IDs using the surface/chunk_X_Z format, then retries the requested window.
- Recovery regression is isolated in tests/mineral_grid_streaming_recovery_test.gd: seed eight actual controller grid IDs, recover the missing ninth chunk, then reject unknown IDs without changing the managed map. The existing diagnostics test is restored to the known-good base version and continues to verify incomplete-rollback reporting.
- Workflow adds Vector Rally import/rules/runtime steps and verifies the new files exist. Design note: docs/MINERAL_GRID_STREAMING_RECOVERY_M0_2_2026-10-27.md.
- Candidate validation pending; do not merge until exact-head Godot 4.3 CI succeeds. Local Godot/GUI/iPhone tests are not claimed.
- Limits: recovery remains synchronous and factory-driven; production world generator and asynchronous streaming are not wired. If the factory/controller continues failing, recovery may still return false and callers must inspect get_last_sync_report().
- Next: validate the exact PR head, merge only after success, run post-merge main CI, then record the final merge SHA and CI evidence.

## Run 15 final reconciliation｜2026-10-27
- PR #60 merged as `7f4cae3eb74a7258a6f45364c07e1765956bd1f2`; exact feature head `2aa86c6e74993a1bd4a9a20ec591bef386c791ac` passed Godot 4.3 CI Run #285 (`40418593413`), 68/68 steps successful, including mineral recovery and Vector Rally import/rules/runtime tests. The earlier 65-step count was a documentation error; the final job record reports 68 successful steps and zero failures.
- Earlier Run 15 candidate notes above are historical; this entry is the final state. Production world generator integration and async streaming remain outstanding. Local GUI/iPhone testing is not claimed.

## Run 16 final reconciliation｜2026-10-27
- PR #61 merged as `a9c4aec4387818616e1855d4d3775c5d9e243748`; validated feature head `789de09cb9851b39265554bcff84e5a43f37070d`.
- Exact-head Godot 4.3 CI Run #287 (`40430587483`) succeeded with 72/72 steps successful and zero failed steps. New mineral finite-position test step #46 and Star Chart import/rules/runtime steps #66–#68 all succeeded; the existing streaming director and surface integration tests also passed.
- New game: `daily_games/KROLL_Star_Chart_Expedition/` — 7×7 turn-based route puzzle, three survey beacons, extraction gate, 34 fuel and 90-second time limit; keyboard and touch, no external assets.
- Survival fix: `systems/MineralGridStreamingDirector.gd` rejects NaN/infinite coordinates before grid selection and before recovery reconciliation. `tests/mineral_grid_streaming_position_validation_test.gd` verifies rejection leaves controller and director chunk-ID sets unchanged.
- GitHub compare confirms current `main` is identical to merge commit `a9c4aec4387818616e1855d4d3775c5d9e243748`. The connector did not expose a separate main-push run record, so this index does not claim post-merge push CI beyond the exact-head Run #287.
- Limits: local Godot/GUI/iPhone tests not performed; streaming remains synchronous and factory-driven, not connected to the production world generator.
- Next: connect the director to the production world host, then add production-scene load/unload/save/restore acceptance tests and graphical/iPhone validation.

## Run 18 final reconciliation｜2026-10-27

- PR #67 merged by squash as `408f263648ac88a6097399331cc8fd9398489601` (feature merge commit). PR #68 documentation closeout merged as `1b7a12fe92696f3087ed6d9bb794d5cc97611ab0`, the current `main` SHA at final reconciliation.
- Exact-head Godot 4.3 CI Run ID `40445410307` for PR #67 succeeded: all 78 job steps completed successfully, with zero failed steps. The root project import, mineral streaming diagnostics/recovery/position-validation/director tests, and all existing mini-game tests passed.
- Exact-head documentation PR #68 CI Run ID `40445774345` also succeeded: 78/78 job steps, zero failures, including Mini Golf and streaming regression steps.
- New game: `daily_games/KROLL_Orbital_Mini_Golf/` — three top-down mini-golf courses; pull-back mouse/touch aiming, keyboard direction shots, cup capture speed limit, obstacle/wall bounce, five strokes per course, and 90-second total timer. No external assets or add-ons.
- Survival hardening: `systems/MineralGridStreamingDirector.gd` rejects non-finite or extreme world coordinates before grid conversion, invalid chunk dimensions, non-canonical IDs such as `surface/chunk_01_1`, and canonical-looking IDs outside the supported grid bound. Recovery tests prove rejected IDs/coordinates do not mutate the managed map or controller ID set.
- Test cleanup: streaming diagnostics, Cipher Recall, Cargo Tugs, and Vector Rally smoke tests now own and release their watchdog Timer nodes. The exact-head CI log contains no actual Godot `SCRIPT ERROR:`, `ERROR:`, or `FAIL:` lines and no `ObjectDB instances leaked at exit` warning.
- PR #67 added the Mini Golf import/rules/runtime steps to `.github/workflows/godot-validation.yml`; the final exact-head workflow included 78 steps, all successful.
- Limits: no local Godot executable was available; graphical playtesting, GPU validation, and iPhone device testing are not claimed. Mini Golf uses a small custom 2D simulation rather than a rigid-body physics engine. Mineral streaming remains synchronous/factory-driven and is not yet connected to the production world generator.
- Next: connect the streaming director to the production world host, add end-to-end production-scene load/unload/save/restore acceptance tests, and perform GUI/iPhone validation when a suitable device/environment is available.


## Run 27 final reconciliation — 2026-10-28

- Start-of-run external reconciliation: GitHub main before the feature merge was `fa3d4edca2227c8a225a413ba050fa662bb3f1a4`. Notion's Run 27 snapshot and PR #88 history showed multiple superseded candidates; the latest branch head was `c4e624c2ce838fdf44f140ff10cd90842fe1a12d`. Use the exact-head CI and merge record below as final evidence.
- New game: `daily_games/KROLL_Pressure_Circuit/`, Godot 4.3+, no external assets/add-ons. A deterministic 6×6 pipe-rotation puzzle with a 30-move limit, keyboard/mouse/touch input, rules tests, and runtime smoke test.
- Survival change: `prototypes/BackroomsPortalPlayground.gd` now uses `JSON.new().parse()` to inspect malformed save data without emitting an engine ERROR log. If the primary save is corrupt or fails world-envelope validation, a valid `.bak` is loaded; corrupt primary bytes are preserved under `.corrupt` when the path is available, and a validated writer attempts to rebuild the primary while preserving the known-good backup if repair fails.
- Regression coverage: `tests/world_session_save_roundtrip_test.gd` includes corrupt JSON, invalid envelope, diagnostic preservation, primary repair, and missing-primary recovery. Pressure Circuit rules now build reciprocal previous-cell connector masks correctly; tests assert reciprocal adjacency, solvability within the move budget, terminal-state lockout, invalid target rejection, and malformed mask rejection.
- PR #88 merged after exact-head Godot 4.3 Run #418 (run ID 40612225426) succeeded. Candidate HEAD: `c4e624c2ce838fdf44f140ff10cd90842fe1a12d`; merge commit: `103399080afc19a1a0b7e3141a8252c862d78cee`. The run's validate job completed with conclusion success; Pressure Circuit import/rules/runtime steps 106–108 succeeded, active-world save roundtrip step 87 succeeded, and all existing validation steps succeeded.
- Earlier exact-head Runs #415 and #416 are historical failed candidates, not final status: #415 exposed expected corrupt-JSON ERROR logging; #416 confirmed save fallback passed but exposed reversed puzzle connector direction. Both causes were fixed and the later exact-head Run #418 passed.
- At feature closeout, main was verified at merge commit `103399080afc19a1a0b7e3141a8252c862d78cee`; the documentation closeout is handled in a separate PR. No local Godot executable is available, so local GUI/GPU/iPhone playtesting is not claimed.
- Remaining: production M1.3 world controller is still absent; underground mining remains a fixed-cave prototype; async chunk streaming and crop persistence remain outstanding. Next priority is to integrate the tested inventory/mining/save lifecycle into the production world controller and add production-scene load/unload/save/restore acceptance tests.


## Run 28 final verified state — 2026-10-28

- Start-of-run source-of-truth check: main was 6fb774988d2f950648745b70924f2ac79db8d43e; PR #88 and #89 from Run 27 were merged, and open-PR search was empty. The new feature branch was created from that exact main.
- New game: daily_games/KROLL_Microgrid_Operator/, Godot 4.3+, no external assets/add-ons. An eight-cycle resource-management game that balances stored power, fuel, heat, and grid stability. Controls: 1 Generate, 2 Cool, 3 Optimize, R Reset; mouse/touch action cards.
- Existing-system integration: tests/world_inventory_mining_lifecycle_test.gd instantiates the actual BackroomsPortalPlayground.tscn and a real MineralMiningNode, then verifies ore transfer through SurvivalWorldBridge, immediate weight increase/decrease, real save_game()/load_game() roundtrip, inventory restoration, and player-position restoration. It does not claim to persist vein remaining stock in the world save.
- Feature PR #90 merged by squash as 1bcc210d0ceb16fc6cbd04ebbd95a506c9325761; validated candidate HEAD d8b8f1fb2e2cdadeb6ed6bef6df1aab0e9b76da2. Exact-head Godot 4.3 Run #40636164856 completed successfully: 115/115 job steps successful, zero failed. New game import/rules/runtime steps 109–111 and mining-to-save integration step 112 passed; the log contains the explicit success markers.
- Latest main after feature merge was verified at 1bcc210d0ceb16fc6cbd04ebbd95a506c9325761. The documentation closeout is handled separately and must pass its own exact-head CI before merge.
- Limitations: no local Godot executable, GUI/GPU/iPhone hardware test is claimed; production M1.3 world controller remains absent; crop persistence and vein-stock persistence are not integrated into the active world save.
- Next engineering priority: connect the shared inventory/mining/save lifecycle to a production world-session controller and extend the end-to-end test to cover vein/chunk state persistence and restoration.


## Run 29 — Memory Matrix and active-world mineral vein persistence (2026-10-28)

- **Current verified main:** `23b531319a5bed8c215c4292ad2dc30e9e98fcfa` (PR #92 merge commit). PR #92 is merged; open PR search was empty at closeout.
- **New game:** `daily_games/KROLL_Memory_Matrix/` — deterministic nine-tile sequence-memory game, six rounds with sequence lengths 3–8, mouse/touch and keys 1–9, three mistakes allowed, R to restart. Import via `daily_games/KROLL_Memory_Matrix/project.godot` in Godot 4.3+. No external assets/add-ons.
- **Game tests:** `tests/rules_test.gd` covers deterministic seeds, legal tile range, input lock, invalid input non-mutation, replay, round progression, win/loss lock. `tests/game_smoke_test.gd` checks nine controls, sequence playback and first correct input.
- **Existing-system integration:** `MineralVeinRegistry` is now owned by the active `BackroomsPortalPlayground`; `serialize_world_state()` stores it under `mineral_veins`, and world-load validates the registry payload before changing inventory/player state. Stable-ID records for unloaded chunks survive save/load and apply when a matching node registers.
- **Backward compatibility:** old schema-v2 world saves without `mineral_veins` remain accepted and retain the current registry snapshot. Invalid mineral IDs are rejected before partial world mutation. Registry outer schema accepts finite integral JSON numeric value 1, including JSON-decoded floats.
- **End-to-end test:** `tests/world_inventory_mining_lifecycle_test.gd` now covers actual mining through `SurvivalWorldBridge`, immediate weight, real save/load, live vein stock restore, unload, fresh-world reload, stable-ID re-registration, legacy saves and atomic rejection.
- **PR #92:** https://github.com/qaqp980520-prog/2126-Survival/pull/92. Feature merge commit `23b531319a5bed8c215c4292ad2dc30e9e98fcfa`.
- **Exact-head CI:** Run #433, https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40649646947 — 118/118 job steps succeeded, zero failed. Steps 29 (registry JSON round-trip), 87 (active-world save roundtrip), 112 (world mining/vein integration), 113–115 (Memory Matrix import/rules/runtime) all passed.
- **Audit note:** commit `55a0efcd278f63d2b4d6768e01e09bed5109cb34` added the JSON round-trip regression on main before the feature PR merged; this was recorded in Run 29 Notion notes. The PR's exact merge-candidate CI ran the test together with the schema fix before merge. Run #426's typed-path parse failure and Run #432's stale success-marker mismatch were corrected before Run #433 passed.
- **Limitations:** no local Godot executable, local GUI/GPU or iPhone device test is claimed. Formal M1.3 world controller is still absent; crop persistence and complete generated chunk scene state are not yet integrated. Vein records persist, not the entire chunk scene.
- **Next:** build the production world-session controller, wire the registry to actual chunk load/unload events, and add crop plus chunk-state persistence tests.


## 2026-10-28 Run 30 — Signal Sleuth + mineral registry transactionality (merged / exact-head CI passed)

- Start-of-run reconciliation: main was `d24db974269ce457942d51061723911ae8802120`; Run 29 PRs #92/#93 were merged. Run 30 feature PR #94 was the only open PR before closeout.
- New game: `daily_games/KROLL_Signal_Sleuth/`, a deterministic 5×5 nonogram-style deduction game with three patterns, generated row/column clues, mouse/touch/keyboard controls, 60 valid cell changes, restart and next-grid actions. Godot 4.3+, no external assets/add-ons.
- Existing-system regression: `tests/mineral_vein_registry_atomicity_test.gd` verifies valid-then-invalid multi-record restore rejects atomically, validation is side-effect-free, valid payloads restore, unknown mineral IDs in unloaded stable-ID snapshots are rejected without mutation, and fractional schema versions are rejected.
- Exact candidate HEAD `b717e7bd2b1d392d9823b3e584fb93ac68fa8736` passed Godot 4.3 workflow Run #441 (ID 40651700256). The validate job conclusion is success; all 119 primary validation steps completed successfully, including Signal Sleuth import/rules/runtime steps 116–118 and mineral registry transactionality step 119. Three post-job cleanup steps also succeeded. No failed steps were reported.
- PR #94 was marked ready after CI success and merged by squash as `cf102401dd1bb7536a286f09f5f34e89613bd662`. The merge request used expected head SHA `b717e7bd2b1d392d9823b3e584fb93ac68fa8736`, preventing a stale-head merge.
- Documentation closeout branch: `docs/run30-signal-sleuth-registry-atomicity-closeout-2026-10-28`, created from the feature merge commit. This PR updates this index and `docs/DEVELOPMENT_ISSUES.md`; its own exact-head CI must pass before merge.
- Limits remain: no local Godot executable or local GUI/GPU/iPhone test is claimed. Production M1.3 world controller is absent; crop persistence and complete generated chunk scene state are not integrated. Registry transactionality tests harden the existing registry but do not add the production world controller.
- Next: finish the documentation PR, verify its exact-head CI and final main SHA, then prioritize production world-session controller integration and chunk/crop state persistence.

## 2026-10-28 Run 31 — Shadow Trace + crop registry persistence (feature merged; docs closeout candidate)

- Start-of-run reconciliation: GitHub main was `588ee02b6c936d0b84f761ac5e6b23c2e46632b4`; Run 30 PRs #94/#95 were merged and open-PR search was empty.
- Feature PR #96 merged by squash as `9e134d317f98d81a2b5061f81abf80ba6e92dd86`. Validated candidate HEAD: `59338ab48cc1a1b860200df029d6bbec81fbc470`.
- Exact-head Godot 4.3 CI Run #445 (ID `40668945834`) succeeded: 127/127 workflow steps completed, zero failed. Root project import step 7 succeeded; Signal Sleuth regression step 118 and mineral registry transactionality step 120 succeeded; Shadow Trace import/rules/runtime steps 121–123 and crop registry persistence integration step 124 all succeeded. Log review found no actual `SCRIPT ERROR:`, `ERROR: ` or `FAIL: ` output lines.
- New game `daily_games/KROLL_Shadow_Trace/`: deterministic 8×8 turn-based stealth; collect three intel caches, avoid two patrols, reach exit within 40 turns; alert threshold 3; keyboard, mouse and touch input; no external assets/add-ons.
- Existing-system change: `systems/CropRegistry.gd` stores stable-ID crop records (crop ID, stage, progress, moisture, timestamp, harvest count) with whole-payload validation and atomic restore. `prototypes/BackroomsPortalPlayground.gd` writes `crop_registry_state` into active world saves and validates it before inventory/player/mineral state mutation. Legacy saves without the field preserve the current crop-registry snapshot.
- Integration test `tests/crop_registry_persistence_test.gd` verifies real `save_game()/load_game()`, fresh-world restore, duplicate/unknown crop rejection, invalid update non-mutation, detached snapshots, fractional schema rejection, invalid-later-record atomic rejection and legacy compatibility.
- PR #96: https://github.com/qaqp980520-prog/2126-Survival/pull/96. No open PRs remained immediately after the feature merge; documentation closeout is in a separate branch `docs/run31-shadow-trace-crop-registry-closeout-2026-10-28` and must pass its own exact-head CI before merge.
- Limits: CropRegistry is data-only; it does not implement planting, crop visuals, growth simulation, watering or harvesting. Formal `scripts/world.gd` production controller is still absent; complete generated chunk-scene persistence, local GUI/GPU/iPhone testing remain outstanding.
- Next: validate and merge the documentation-only PR, then integrate crop lifecycle and chunk state with the production world-session controller and add production-scene save/restore tests.

## 2026-10-28 Run 32 — Greenhouse Keeper + CropRegistry lifecycle (feature merged; docs closeout)

- Start-of-run reconciliation: GitHub main at the start was 5c2cc14e203b38438fdf76f9d70c936a7c783e74; Run 31 PRs #96/#97 were merged and the open-PR search was empty. Notion Run 31 and the fixed asset index confirmed CropRegistry had persisted stable-ID records but did not yet implement watering/growth/harvest.
- New game: daily_games/KROLL_Greenhouse_Keeper/. Three deterministic crop plots (wheat, tomato, carrot), three water charges, moisture drain per day, stage progression, harvest yield target 5 before day 8, keyboard/mouse/touch, restart and next layout. Godot 4.3+, no external assets/add-ons; import via daily_games/KROLL_Greenhouse_Keeper/project.godot.
- Existing-system change: systems/CropRegistry.gd adds water_crop(stable_id, amount, now_unix), advance_growth(stable_id, elapsed_seconds, now_unix) and harvest_crop(stable_id, now_unix). These are caller-driven deterministic operations; candidate records are validated before replacement, timestamp rollback is rejected, moisture is bounded 0–100, dry soil pauses growth, and mature stage/progress are clamped at 4/1. Schema 1 and the existing save payload are unchanged.
- Tests: daily_games/KROLL_Greenhouse_Keeper/tests/rules_test.gd and tests/game_smoke_test.gd exercise deterministic layouts, input state immutability, watering limits, dry soil, mature harvest, win/loss, and a live-scene victory path. tests/crop_registry_lifecycle_test.gd tests watering bounds, elapsed-time bounds, multi-stage growth, dry pause, maturity, harvest reset/count, timestamp injection/rollback and schema-1 round-trip. Existing tests/crop_registry_persistence_test.gd remains in CI.
- PR #98 merged by squash as f58ccdadc521aed46dc6c5b6c03dc3fdd5528070; validated candidate HEAD e56efc36819cdc29ca42339060ff11409fd4601d. Exact-head Godot 4.3 Run #454 (40678627167) succeeded: 128 numbered validation steps plus 3 setup/cleanup steps, 131/131 total success, zero failed or skipped steps. New game import/rules/runtime steps 125–127 and crop lifecycle step 128 passed. The active-world crop persistence test at step 124 and all prior regression tests also passed.
- Failure reconciliation: Run #452 (40678191590) failed at root import because CropRegistry.gd could not be preloaded. The added lifecycle block was using spaces in a tab-indented file; commit e56efc3 normalized it to tabs. Run #453 was cancelled at step 32 after steps 1–31 passed, including root import; it is partial evidence only. Run #454 is the full passing evidence. Logs contain no actual SCRIPT ERROR, ERROR or FAIL output lines.
- No local Godot executable was available; GUI/GPU/iPhone hardware tests are not claimed.
- Limits: CropRegistry lifecycle is not yet connected to a production world-session controller or scene-based planting/watering/harvesting. Formal scripts/world.gd, crop visuals, full generated chunk scene persistence and asynchronous streaming remain outstanding.
- Next: wire lifecycle calls into the production world-session controller and actual crop interactions, then add crop/chunk unload-reload/save-failure acceptance tests.


## 2026-10-28 Run 33 — Deep Current Angler + CropPlotController (feature merged; docs closeout)

- Start-of-run reconciliation: main was `05d9e8aeacea8068b784a3d44b1cc88f6f930b5f`; Run 32 PRs #98/#99 were merged and open-PR search was empty. Notion Run 32 and its game/CropRegistry version pages were inspected before work.
- New game: `daily_games/KROLL_Deep_Current_Angler/`, a deterministic turn-based fishing game. Cast, wait for bite, hook, then alternate reel/ease to keep tension below 100; catch three fish within 30 valid actions. Godot 4.3+, no external assets/add-ons; import through `daily_games/KROLL_Deep_Current_Angler/project.godot`.
- Existing-system integration: added `systems/CropPlotController.gd` and bound it to the active `prototypes/BackroomsPortalPlayground.gd`. It exposes plant/water/advance/harvest/query/remove operations over the existing CropRegistry and adds atomic `advance_crops`: the complete schema-1 registry snapshot is restored if any crop tick fails. No CropRegistry schema change.
- Integration test: `tests/crop_plot_controller_integration_test.gd` uses the real active-world scene and save/load path; covers stable-ID planting, rollback after a later crop timestamp failure, successful batch growth, save/reload, watering, maturity and harvest receipt.
- Feature PR [#100](https://github.com/qaqp980520-prog/2126-Survival/pull/100) merged as `3b010096c6ee0c73fe0039a9a0ba87398aaf2bfc`; exact candidate HEAD `8f7af262b6d4c4e7da64661859088bc8d7f67a32`.
- Exact-head Godot 4.3 CI Run #459 ([40693583329](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40693583329)) passed all 132 validation steps, with zero failures or skipped validation steps. Angler import/rules/runtime steps 129–131 and CropPlotController active-world integration step 132 passed. Existing regression steps 1–128 also passed. Run #458 (40693478408) targeted the prior candidate and was cancelled; it is not final evidence.
- Test correction: static review found the line-snap test's default fish energy would catch before reaching the tension limit. Commit `8f7af26` injects a higher test-only fish energy; Run #459 validates that exact HEAD.
- No local Godot executable was available; GUI/GPU/iPhone device QA is not claimed.
- Limits: CropPlotController is now bound to the active playground, but crop meshes/proximity interaction are not implemented. Formal `scripts/world.gd`, full generated chunk-scene persistence and asynchronous streaming remain outstanding.
- Next: build visible plot placement/interactions and then integrate crop/mineral registry state with chunk unload/reload in the formal world-session controller.


## 2026-10-28 Run 34 — Salvage Exchange + scene-backed crop plots (feature merged)

- Start-of-run reconciliation: main was `56a3ba086a802c601f30c2add4bc140aadc26ff2`; PR #100/#101 were merged and open-PR search was empty. Run 34 candidate details and its historical pending status were recorded in Notion, then reconciled against GitHub after the exact run completed.
- New game: `daily_games/KROLL_Salvage_Exchange/`, a deterministic four-commodity trading game with 5% rounded-up fees, cargo capacity 10, eight-day contract and net-worth target 150. Godot 4.3+, no external assets/add-ons.
- Existing-system change: added `systems/CropPlotVisual.tscn` and `systems/CropPlotVisual.gd`; four stable-ID surface crop plots are bound to the active `BackroomsPortalPlayground`. Press E within 3.25 m to plant, water, advance one bounded growth interval or harvest. The Backrooms boundary blocks crop mutation. CropRegistry remains authoritative; schema 1 and the save envelope are unchanged. Save/load refreshes plot visuals.
- Failure correction: Runs #467/#469/#474 exposed null-mesh errors during headless teardown. Moving meshes into serialized `CropPlotVisual.tscn` fixed the issue. Run #478 was cancelled and is not final evidence.
- PR #102 merged as `b6fcdc039ea78cff478ef7f2415a3a2d6d410198`. Exact-head Run #479 (40715313513) passed: 139/139 total steps (6 setup, 130 validation, 3 cleanup), zero failures/skips. Active-world playground step 23, crop visual interaction step 133, and Salvage Exchange steps 134–136 passed. No local GUI/GPU/iPhone hardware pass is claimed.
- Independent Notion records: [Run 34 daily record](https://app.notion.com/p/407bc6a809d7815993d0e43e6886da18), [Salvage Exchange](https://app.notion.com/p/407bc6a809d7810f843cc10e64d29357), [CropPlotVisual](https://app.notion.com/p/407bc6a809d781fe8424fbde26512805).

## 2026-10-28 Run 35 — Cargo Crane + touch-safe crop interaction (feature merged)

- New game: `daily_games/KROLL_Cargo_Crane/`, deterministic stacking arcade game. Move the crane hook and drop six containers; overlap and center-drift checks determine success. Keyboard and on-screen mouse/touch controls, restart and next manifest; Godot 4.3+, no external assets/add-ons.
- Existing-system change: added `HUD/CropInteractButton` to `BackroomsPortalPlayground`, preserving keyboard E while enabling tap interaction for nearby plots. The button is disabled inside Backrooms and re-enabled on the surface. Plot status text advertises both input paths.
- Integration coverage: `tests/crop_plot_visual_integration_test.gd` now checks touch button creation, touch-triggered nearest-plot planting, Backrooms safety and re-enabling on the surface.
- PR #103 merged as `8d74ef8b3ae96be94fa930d48ee69402070e73d1`; candidate HEAD `02858cff9d6dacd2dd92184ca544cbcaefdda073`. Exact-head Godot 4.3 Run #481 (40717496360) passed: 142/142 total steps (6 setup, 133 validation, 3 cleanup), zero failures/skips. Crop visual integration step 133 and Cargo Crane import/rules/runtime steps 137–139 passed. No local GUI/GPU/iPhone hardware pass is claimed.
- Independent Notion records: [Run 35 daily record](https://app.notion.com/p/407bc6a809d7819fb6e8d39523270468), [Cargo Crane](https://app.notion.com/p/407bc6a809d78119b627e0a0525545df), [CropPlot Touch Interaction](https://app.notion.com/p/407bc6a809d78198808ff79cfd661dd0).

## Current remaining production work

- Formal `scripts/world.gd` world-session controller is still absent; the crop visuals and interaction are integrated into the Backrooms Portal Playground prototype, not a production world controller.
- Full generated chunk-scene state persistence across chunk unload/reload remains incomplete.
- Asynchronous chunk streaming remains incomplete.
- Local interactive GUI, GPU performance and iPhone hardware QA are not claimed.

## Run 35 documentation closeout verification — 2026-10-28

- Documentation PR #104 merged as `df3ba169aeab8440102386706bcc8e0117bc26b8` after exact-head Godot 4.3 Run #483 (40718477267) passed all 142/142 total steps (6 setup, 133 validation, 3 cleanup), zero failures/skips.
- PR #103 feature merge remains `8d74ef8b3ae96be94fa930d48ee69402070e73d1`; PR #104 records Run 34/35 feature validation and production gaps.
- Final main was compared against the PR #104 merge SHA and returned identical, ahead 0 / behind 0. The final open-PR search returned empty.
- This repository section now records the closeout CI result; no separate post-merge main-push workflow is claimed.

## 2026-10-29 Run 36 — Prism Relay + streamed crop persistence (feature merged)

- New game: `daily_games/KROLL_Prism_Relay/`, a deterministic 7×7 mirror-routing puzzle with three relay layouts, visible beam tracing, an 18-rotation budget, terminal lock, reset/next controls and mouse/touch mirror rotation. Godot 4.3+, no external assets/add-ons.
- Existing-system integration: `MineralChunkController` now binds stable-ID `CropPlotVisual` nodes inside streamed chunks. The Surface Chunk Streaming Playground creates two crop plots per chunk and supports E interaction with the nearest plot within 3.25 world units.
- Stream-save schema remains 1 with an optional `crops` payload. Restore validates crop data before mutation, restores crop and mineral registries together, refreshes active visuals and rolls crop state back if target streaming fails. Legacy stream saves without the crops key remain loadable and preserve the current CropRegistry.
- Expanded `tests/surface_chunk_streaming_playground_test.gd` covers crop planting/growth, crop payload capture, chunk unload/reload with stable-ID visual reconstruction, E reach rejection, invalid crop payload atomicity, injected stream failure rollback and legacy save compatibility.
- PR #106 merged as `915ae79a1f24ad67572d06854cf7248de8a6db20`. Exact candidate HEAD `4628afcb82e7d6979fdefa65d04310332088b35d`; Godot 4.3 CI Run #491 ([40785631457](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40785631457)) passed 142/142 total steps (6 setup, 133 validation, 3 cleanup), zero failures/skips. Streamed crop integration step 75 and Prism Relay import/rules/runtime steps 140–142 passed.
- Independent Notion records: [Run 36 daily log](https://app.notion.com/p/407bc6a809d781ce9e57f535ae7850e4), [Prism Relay M0.1](https://app.notion.com/p/407bc6a809d781e38be3ca31979a8e12), [Streamed Crop Plot Persistence M0.1](https://app.notion.com/p/407bc6a809d78146829fde4463817c25).
- No local Godot executable; local GUI/GPU/iPhone hardware QA is not claimed. No separate post-merge main-push workflow is claimed.
- Remaining: formal `scripts/world.gd` world-session controller; complete generated chunk scene state persistence beyond crop/mineral registry records; asynchronous chunk streaming and device QA.

## Run 37 — Skyline Courier and streamed crop offline growth (2026-10-29)

- Feature PR [#109](https://github.com/qaqp980520-prog/2126-Survival/pull/109) merged as `7b9c589985a9af87a9ba3a3f7b98dc1cc60e8041`; feature candidate HEAD was `cefa1b0b4255752755c2ff4c289fe67ed38973bb`. Final main compared identical to the merge SHA; no open PR remained before this documentation closeout.
- New playable game: [KROLL Skyline Courier](daily_games/KROLL_Skyline_Courier/README.md), a deterministic three-lane runner with keyboard/touch lane selection, three lives, a 45-second delivery window and a six-packet objective. No external assets/add-ons.
- Crop persistence: `CropRegistry.advance_to_time()` performs bounded wall-clock catch-up; `CropPlotController.advance_crops_to_time()` advances a chunk's crop IDs as an atomic batch. `MineralChunkController.load_chunk()` catches up crops before rebuilding visuals and restores the crop snapshot if subsequent mineral registration fails, including refreshing the detached plot visuals after rollback.
- Compatibility: crop save schema remains version 1. Catch-up simulates at most one day because moisture drains to dry steady state within 400 seconds; time rollback is an atomic no-op.
- New regression: `tests/crop_chunk_offline_growth_test.gd`; expanded `tests/crop_registry_lifecycle_test.gd` and `tests/crop_plot_controller_integration_test.gd`.
- Exact-head Godot 4.3 CI [Run #502](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40798810304) passed 149/149 total job steps, including 146 named validation steps, with no failures or skips. New Skyline import/rules/runtime steps 143–145 and crop offline growth integration step 146 passed. Earlier Run #498's Node.get argument error was fixed before the final candidate.
- Notion records: [Run 37 daily log](https://app.notion.com/p/408bc6a809d7813d97e6c07b1dfdd79d), [Skyline Courier M0.1](https://app.notion.com/p/408bc6a809d7819e8747dfebcea4326e), [Crop Offline Growth M0.1](https://app.notion.com/p/408bc6a809d781b1b7aef71202004e1d).
- Limits: no local Godot executable; manual GUI/GPU/iPhone testing is not claimed. Production `scripts/world.gd` remains absent; complete generated terrain/object persistence and async chunk streaming remain open.


## Run 38 — Echo Survey and WorldSessionController (2026-10-29)

- New game: `daily_games/KROLL_Echo_Survey/`, a deterministic 8×8 sonar exploration and salvage game with three layouts, battery/oxygen management, rock collision and extraction. Godot 4.3+; no external assets.
- World architecture: add `scripts/world.gd` as the first reusable `WorldSessionController` base. It centralizes streamed-world component ownership, schema-1 save/restore, diagnostics and rollback reporting; the Surface Chunk Streaming Playground still supplies player/environment/HUD/chunk factory.
- Save compatibility: optional inventory payload is validated through a temporary SurvivalInventory model; a failed target stream rolls inventory, minerals, crops and player position back. Legacy schema-1 saves without inventory remain loadable.
- Integration test: `tests/world_session_controller_test.gd` covers idempotent initialization, initial 3×3 window, inventory weight round-trip, invalid inventory no-mutation, legacy saves and injected chunk-factory failure rollback.
- PR [#111](https://github.com/qaqp980520-prog/2126-Survival/pull/111) merged as `739ef96a5c99dbfc163fadfd25ca4025fe87e4e0`. Exact candidate `48589112a1daf7f15830d75b4e67b20dcb23ce97` passed Godot 4.3 CI [Run #513](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40801522315), including Echo Survey import/rules/runtime steps 147–149 and world-session integration step 150.
- Notion: [Run 38 daily record](https://app.notion.com/p/408bc6a809d7813c8589fcf03d99ffb8), [Echo Survey M0.1](https://app.notion.com/p/408bc6a809d781008062ea709e9cc1b0), [WorldSessionController M0.1](https://app.notion.com/p/408bc6a809d781c0a2f8e3a8868bf507).
- Remaining: complete generated terrain/object state persistence and asynchronous chunk streaming; manual GUI/GPU/iPhone QA is not claimed because no local Godot executable/device was available.

## Run 39 — Tidal Lock and persistent world-object state (2026-10-29)

- New game: `daily_games/KROLL_Tidal_Lock/`, a deterministic four-chamber water-lock puzzle. Gate, pressure difference, pump energy and 10-action budget are covered by rules and runtime tests.
- System: `systems/WorldObjectStateRegistry.gd` persists stable-ID object state per chunk. It validates before deep-copying, caps records at 50,000 and properties per object at 64, and only accepts bool/int/finite float/bounded string values.
- Integration: optional `world_objects` is saved in the schema-1 WorldSessionController envelope. Legacy saves without the field preserve the current registry. Failed target streaming rolls world-object state back with inventory/mineral/crop/player/window state.
- Tests: `tests/world_object_state_registry_test.gd` and expanded `tests/world_session_controller_test.gd` / `tests/surface_chunk_streaming_playground_test.gd` cover stable ID/chunk ownership, deep-copy snapshots, property cap, invalid payload atomicity, legacy compatibility and injected target-stream failure rollback.
- PR [#112](https://github.com/qaqp980520-prog/2126-Survival/pull/112) merged as `213c795382682b3d8a51c27be0a2d4da1ce2f671`. Final exact candidate `873ec47bb22ba93becc5f8b2a3b90cfb4b0e6fd2` passed Godot 4.3 CI [Run #40810244136](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40810244136): 157/157 reported job steps succeeded, zero failures/skips. Tidal Lock import/rules/runtime steps 151–153, registry test step 154, and world-session rollback step 150 passed.
- Notion: [Run 39 daily record](https://app.notion.com/p/408bc6a809d78171b12cf0bb7e9ac702), [Tidal Lock M0.1](https://app.notion.com/p/408bc6a809d7816db17bf97c1eb120f4), [WorldObjectStateRegistry M0.1](https://app.notion.com/p/408bc6a809d78110bcc0c2dfea03c560).
- Limits: registry does not automatically apply saved state to every scene node; chunk factories must apply records to interactable objects. Full generated terrain/object persistence and asynchronous chunk streaming remain open. Manual GUI/GPU/iPhone QA is not claimed.

## 2026-10-29 Run 40 — Rotor Rescue + streamed world-object lifecycle (merged / exact-head CI passed)

- Feature PR [#114](https://github.com/qaqp980520-prog/2126-Survival/pull/114) merged as `d3b2192c55a9808e85d80f111eb24e89c3894571`; validated candidate HEAD `5915d46016d53f6ea58a0e32e6e7a7bfb73c1730`.
- Exact-head Godot 4.3 CI [Run #532](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40822891951) completed successfully. The validate job passed all 157 numbered workflow steps plus three post/cleanup steps (160 step entries total), with zero failures. Rotor Rescue import, rules and runtime smoke steps 155–157 passed; world-session integration step 150 and world-object registry step 154 also passed.
- New game `daily_games/KROLL_Rotor_Rescue/`: deterministic 2D inertial flight rescue with three layouts, fuel/time limits, obstacle collision, three crew pickups and safe landing extraction. Godot 4.3+, no external assets/add-ons.
- Added `systems/WorldObjectStatefulProp.gd`; stable IDs derive from chunk ID + node path. `MineralChunkController` captures live object state before save/unload and applies it on load. Invalid semantic state rejects capture/restore without partial registry mutation or losing chunk ownership.
- The Surface Chunk Streaming Playground now spawns a persistent SalvageCrate per streamed chunk with F interaction. World save schema remains version 1; `world_objects` is optional for legacy saves.
- Run #531 exposed a smoke-test assumption about default Button node names; explicit touch/action button names and matching assertions fixed it. Only Run #532 is the final exact-head success evidence.
- No local Godot executable; no manual GUI/GPU/iPhone hardware QA is claimed.
- Remaining: connect stateful-prop restoration to every production interactable factory; persist complete generated terrain/object mutations; integrate asynchronous chunk streaming and failure recovery.

## Run 40 documentation closeout — final external-state correction (2026-10-29)

- Documentation PR [#115](https://github.com/qaqp980520-prog/2126-Survival/pull/115) exact candidate `65c729bd95a94cb6884157d548a946255bcad81c` passed Godot 4.3 CI [Run #537](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40833525231): 157 numbered validation steps plus three post/cleanup entries, 160 step entries total, all successful.
- PR #115 merged as `1368827db0a3d62411f9c5551fae604a0f9c2626`. Earlier pending checkpoints in historical records are superseded. Run 41 started from this exact main SHA.

## 2026-10-29 Run 41 — Thermal Sort + aggregate world-object registry budgets (merged / exact-head CI passed)

- Start-of-run reconciliation: main was `1368827db0a3d62411f9c5551fae604a0f9c2626`; PR #115 was merged, and open-PR search was empty. A fresh feature branch was created from that SHA.
- New game: `daily_games/KROLL_Thermal_Sort/`, a deterministic temperature-routing arcade game with three layouts (seeds 101, 202, 303), 12 canisters per shift, cold/stable/hot thresholds, two allowed mistakes, keyboard/mouse/touch controls, restart/next-layout, and no external assets/add-ons. Import via `daily_games/KROLL_Thermal_Sort/project.godot` in Godot 4.3+.
- Game tests: `daily_games/KROLL_Thermal_Sort/tests/rules_test.gd` checks threshold boundaries, deterministic seeds, invalid-bin non-mutation, clean completion for all layouts and third-error failure. `tests/game_smoke_test.gd` instantiates the real scene, checks stable button names, completes a shift, restarts and advances seed.
- Existing-system hardening: `systems/WorldObjectStateRegistry.gd` now caps aggregate state at 100,000 total properties and 1,000,000 total string-value characters in addition to the existing 50,000 record cap, 64 properties per object and 256 characters per string. Incremental counters are updated on insert/replacement/deletion and restored from validated snapshots.
- Regression: `tests/world_object_state_registry_test.gd` exercises aggregate string and property limits, budget release on replacement/deletion, over-budget save validation and all-or-nothing rejection of over-budget restore.
- Shared workflow `.github/workflows/godot-validation.yml` now imports Thermal Sort and runs its rules/runtime tests; the existing world-object registry test executes against the expanded aggregate-budget cases.
- Feature PR [#116](https://github.com/qaqp980520-prog/2126-Survival/pull/116) merged as `093e45116b56da7be33b04d5a536d967b13214a9`. Exact candidate HEAD `981eda60d12d7253efa15934e283de4f07b8a769` passed Godot 4.3 CI [Run #539](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40838865278): 160 numbered validation steps plus three post/cleanup entries, 163 total step entries, all successful. Registry aggregate tests passed at step 154; Rotor Rescue import/rules/runtime passed at 155–157; Thermal Sort import/rules/runtime passed at 158–160.
- Save schema remains version 1. Ordinary legacy saves remain compatible, but a schema-1 object-registry payload above the new aggregate limits is intentionally rejected.
- Notion records: [Run 41 daily log](https://app.notion.com/p/408bc6a809d7814d817bc82af5132e90), [Thermal Sort M0.1](https://app.notion.com/p/408bc6a809d7813b9cd9e9d1e0a97946), [WorldObjectStateRegistry Aggregate Budget M0.1](https://app.notion.com/p/408bc6a809d7810a941cca02f5a9d2b1).
- Limits: Thermal Sort is standalone and not connected to the survival inventory. The registry stores bounded primitive state; production prop factories still need comprehensive semantic restoration. Full terrain mutation persistence and asynchronous streaming remain open. No local Godot executable, manual GUI/GPU or iPhone hardware pass is claimed.


## Run 42 — 2026-10-29: Span Engineer + transactional salvage crate rewards

- Add standalone KROLL Span Engineer M0.1 at `daily_games/KROLL_Span_Engineer/`: five-span bridge-design puzzle, three deterministic anchor layouts (seeds 101/202/303), budget 12, cart load 3, standard/reinforced decks and anchored braces. Godot 4.3+, no external assets/add-ons.
- Tests: `daily_games/KROLL_Span_Engineer/tests/rules_test.gd` checks deterministic blueprints, invalid/over-budget non-mutation, anchor constraints, exact-budget solutions, load capacity and terminal edit lock. `tests/game_smoke_test.gd` instantiates the scene, performs edits, passes a load test and advances blueprint.
- Existing-system gameplay fix: `systems/WorldObjectStatefulProp.gd` adds `interact_with_inventory()`. The Surface Chunk Streaming Playground now grants one `iron_ore` through SurvivalWorldBridge before consuming crate loot; full inventory leaves crate state unchanged, and a rejected prop-state transition attempts to restore the inventory snapshot.
- New end-to-end test `tests/salvage_crate_inventory_integration_test.gd` verifies item count, weight, crate state, joint world save/restore and full-count rejection without overfill.
- CI workflow `.github/workflows/godot-validation.yml` now checks and runs Span Engineer import/rules/runtime steps plus the salvage inventory integration test.
- Feature PR [#118](https://github.com/qaqp980520-prog/2126-Survival/pull/118) merged as `fcadbb4b6afd2a29af58d99d5149075c6a018def`. Exact candidate `92731d84de28ab7adce6707c26a000bad7d30f2f` passed [Godot 4.3 CI Run #40855286483](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40855286483): 164 numbered validation steps plus three post/cleanup entries (167 total), all successful. Span Engineer import/rules/runtime passed at steps 161–163; salvage inventory integration passed at step 164.
- Validation history: earlier candidates failed the new test's Object/Dictionary get() arity and a brittle stable-ID substring lookup. The causes were fixed and retained in the Run 42 log; only the final exact-head Run #40855286483 is the pass evidence.
- World save schema remains version 1. Loot is currently fixed to one iron ore per crate interaction; if multiple loot types are added, loot identity should be persisted in stable object state.
- Notion records: [Run 42 daily log](https://app.notion.com/p/408bc6a809d781eaa403c4dd5aab9a74), [Span Engineer M0.1](https://app.notion.com/p/408bc6a809d78101b157cc20978b0926), [SalvageCrate Inventory Transaction M0.1](https://app.notion.com/p/408bc6a809d781449760e32f08729468), [Godot Validation Workflow M0.1](https://app.notion.com/p/408bc6a809d781ac98f8f71fa9f44be6).
- Limits: Span Engineer uses discrete load-capacity rules, not a rigid-body stress simulation. No local Godot executable, manual GUI/GPU or iPhone hardware pass is claimed. Production prop factories still need comprehensive semantic restoration; full terrain mutation persistence and asynchronous streaming remain open.


## 2026-10-29 Run 43 — Biome Balance + deterministic salvage loot identity (feature merged / exact-head CI passed)

- Feature PR [#120](https://github.com/qaqp980520-prog/2126-Survival/pull/120) merged as `3530f5145f98895d58e914b392b57ff0062cd9e7`; exact candidate HEAD `bd5aebb35f8c23fc190d52ea75ae7281d76718b7`.
- Exact-head Godot 4.3 CI [Run #554](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40862702927) completed successfully: 168 numbered workflow steps plus three post/cleanup entries, 171 step entries total, zero failures. Biome Balance import/rules/runtime passed at steps 165–167; salvage loot identity regression passed at step 168; active-world salvage inventory integration passed at step 164.
- New game `daily_games/KROLL_Biome_Balance/`: six-turn ecosystem management puzzle, three deterministic habitat orderings (seeds 17/29/41), two interventions per turn, bounded seed/grazer/water resources, keyboard/mouse/touch controls, rules tests and scene runtime smoke test. Godot 4.3+, no external assets/add-ons.
- Existing-system improvement: `systems/WorldObjectStatefulProp.gd` persists `loot_item_id`, validates it against MineralCatalog, and preserves schema-1 legacy two-field state. `prototypes/SurfaceChunkStreamingPlayground.gd` assigns deterministic loot by chunk coordinates and displays the catalog mineral name. Origin chunk remains iron ore; adjacent chunk (1,0) is copper ore. Inventory must accept the item before crate state decrements; rejection leaves the crate unchanged.
- Tests: `tests/salvage_crate_loot_identity_test.gd` covers save/restore, legacy state, unknown ID/field rejection, copper inventory grant, full-inventory rejection and non-mutation. `tests/salvage_crate_inventory_integration_test.gd` now checks deterministic factory mapping.
- World-save envelope remains schema 1. Loot is deterministic by chunk coordinate, not a weighted random loot table. Full generated terrain/object mutation persistence and asynchronous chunk streaming remain open.
- Notion: [Run 43 daily log](https://app.notion.com/p/408bc6a809d7811d8aa2dc58cde40771), [Biome Balance M0.1](https://app.notion.com/p/408bc6a809d7814faacad0bac4d728ea), [Salvage Loot Identity Persistence M0.1](https://app.notion.com/p/408bc6a809d781fa9ac3f1f18cea10df), [Godot Validation Workflow M0.1](https://app.notion.com/p/408bc6a809d7816c84adc08886871c8f).
- Limits: no local Godot executable; no manual GUI/GPU/iPhone hardware pass is claimed.


## 2026-10-29 Run 44 — Frequency Tuner + salvage crate state invariants (feature merged / exact-head CI passed)

- Feature PR [#122](https://github.com/qaqp980520-prog/2126-Survival/pull/122) merged as `bb8265977ce4d885680c5861943fb162766b354f`. Exact candidate HEAD `8334fd2d3b6fc0ed97ec2159bce44cb80698c126` passed [Godot 4.3 CI Run #562](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40879170090): 174/174 workflow steps completed, zero failures and zero skipped steps.
- New game `daily_games/KROLL_Frequency_Tuner/`: three coupled modulo-10 frequency dials, fixed seeds 13/27/41, 14-move budget, keyboard/mouse/touch UI, rules tests and runtime smoke test. Godot 4.3+, no external assets or plugins. CI steps 168–170 passed; the rules suite exhaustively verifies the output mapping across all 1,000 possible dial states and the scene smoke test emits a real dial-button signal.
- Existing-system fix: `systems/WorldObjectStatefulProp.gd` now rejects inconsistent state combinations: a closed crate must be full; a crate with consumed loot must be marked opened. `tests/salvage_crate_loot_identity_test.gd` verifies rejected restores do not mutate live state while preserving valid schema-1 two-field legacy records. CI step 171 passed.
- PR #122 includes 10 changed files and the canonical workflow extension in `.github/workflows/godot-validation.yml`. Latest main at this docs branch start is `bb8265977ce4d885680c5861943fb162766b354f`.
- Remaining engineering: production interactable factories need comprehensive state binding; full terrain/object mutations and asynchronous chunk streaming/recovery remain open. No local Godot executable or hardware was available; manual GUI/GPU/iPhone tests are not claimed.
- Notion: [Run 44 daily log](https://app.notion.com/p/408bc6a809d78173a006e89b74283536), [Frequency Tuner M0.1](https://app.notion.com/p/408bc6a809d7813ca98bd73d007c24b5), [WorldObjectStatefulProp M0.2](https://app.notion.com/p/408bc6a809d781c595affc57d4d83c58), [asset index](https://app.notion.com/p/400bc6a809d781269143fa5379833145).

## Run 45 — 2026-10-29

### KROLL Rail Yard M0.1
- Project: `daily_games/KROLL_Rail_Yard/`; Godot 4.3+; no external assets or add-ons.
- Queue/stack shunting puzzle: five cars A–E, three deterministic layouts, siding capacity 3, 12-move limit, keyboard and touch controls.
- Tests: `daily_games/KROLL_Rail_Yard/tests/rules_test.gd` and `tests/game_smoke_test.gd`; includes malformed/duplicate car rejection, stack capacity, move budget, terminal lock, actual button signals, restart and wraparound.
- Targeted Godot 4.3 CI: [Run #40897295646](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40897295646), all 12 job steps successful.
- Full repository Godot 4.3 CI: [Run #40897295631](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40897295631), all 171 validation steps plus setup/post/cleanup successful; zero failed or skipped steps.

### Salvage inventory compensation
- `systems/WorldObjectStatefulProp.gd` now attempts `restore_inventory(snapshot)` if `collect_world_item()` returns false, covering adapters that mutate before rejecting.
- If compensation fails, the result explicitly reports `inventory_rollback_failed`; it does not claim rollback succeeded.
- Regression: `tests/salvage_crate_inventory_rollback_test.gd`, passed in targeted Run #40897295646.
- World save schema remains unchanged.

### Merge record
- Feature PR [#124](https://github.com/qaqp980520-prog/2126-Survival/pull/124) merged after both exact-head workflows passed.
- Merge commit: `7c95896145c735fb6a0f1f4d8cb41165c3216988`.
- Candidate head tested: `c02aa304b3eeeed80bf2b97cfcfe97d365581a5c`.
- Remaining: integrate stateful lifecycle into all production interactable factories; full terrain/object-change persistence; asynchronous chunk streaming; manual GUI/GPU/iPhone QA. No device QA is claimed.


## Run 46 — 2026-10-30 — Beat Lab + salvage reentrancy guard (feature merged; exact-head CI passed)

- Feature PR [#126](https://github.com/qaqp980520-prog/2126-Survival/pull/126) merged as \`f9599478512416ffc64192550518989f620ca7e0\`. Exact candidate HEAD \`75357e463780d3ec1502aef5210ebb0af5a0afdc\`.
- Canonical Godot 4.3 CI [Run #574](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40970079987) completed successfully: all 183 workflow steps succeeded, zero failed/skipped steps. Final steps verified Run 45 Rail Yard import/rules/runtime, inventory rollback, Run 46 Beat Lab import/rules/runtime, and salvage reentrancy.
- Focused Run 45 Godot 4.3 CI [Run #6](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40970079995) passed all 12/12 steps, including root import, inventory rollback regression and Rail Yard import/rules/runtime.
- New game \`daily_games/KROLL_Beat_Lab/\`: original visual rhythm game, 4 lanes (A/S/D/F), 100 BPM, 3 deterministic 24-note charts, ±0.18-second hit window, 100 points per hit, 1,800-point target and at most 4 misses. Godot 4.3+, no external assets, plugins or audio files. Tests: \`tests/rules_test.gd\` and \`tests/game_smoke_test.gd\`.
- Existing-system fix: \`systems/WorldObjectStatefulProp.gd\` rejects reentrant inventory interaction with \`interaction_in_progress\` while a grant transaction is running; legacy state-only \`interact()\` is also blocked during the transaction. New \`tests/salvage_crate_reentrancy_test.gd\` verifies nested calls cannot duplicate the reward and later independent transactions still work.
- Workflow correction: the fetched pre-Run-46 main workflow did not include explicit Run 45 Rail Yard or inventory rollback steps, despite the prior Run 45 narrative. The feature PR added these checks to \`.github/workflows/godot-validation.yml\` alongside Run 46 tests. The current workflow now contains those explicit test steps.
- Save schema remains version 1. The guard is synchronous single-node reentrancy protection, not a multiplayer server-authoritative lock. No local Godot executable, manual GUI/GPU or iPhone hardware test is claimed.
- Remaining: production-wide stateful prop factory binding; complete terrain/object delta persistence; asynchronous chunk streaming/recovery; manual device QA.
- Notion records: [Run 46 daily log](https://app.notion.com/p/408bc6a809d78155b851edc25e8acb6e), [Beat Lab M0.1](https://app.notion.com/p/408bc6a809d781b9a970c05627fdcbfb), [reentrancy guard M0.1](https://app.notion.com/p/408bc6a809d781cb8714c5c620dbc268), [workflow record](https://app.notion.com/p/408bc6a809d78167a16aec00062d22f9).

## Run 47 — 2026-10-30 — Pipe Relay and SalvageCrate state mutation guard

- Feature PR [#128](https://github.com/qaqp980520-prog/2126-Survival/pull/128) merged as `be912f75aa0580681e5e337ede5383f4f963b888`; exact tested candidate HEAD `f8cca4b91c99dfaa910a9e635bd3c61c63e35cb7`.
- Canonical Godot 4.3 CI [Run #578](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40984092639) completed successfully. All 185 numbered workflow steps and 3 post/cleanup steps succeeded (188 job step entries total); zero failures or skips. Steps 182–184 imported, tested rules and ran the Pipe Relay scene smoke test; step 185 passed the SalvageCrate state-mutation guard regression.
- Added `daily_games/KROLL_Pipe_Relay/`: deterministic 4×4 pipe-routing puzzle, three layouts, 10-rotation budget, source-to-target graph traversal requiring every pipe segment to be powered, keyboard shortcuts plus mouse/touch tile rotation. Godot 4.3+, no external assets/plugins/audio. Tests: `tests/rules_test.gd`, `tests/game_smoke_test.gd`.
- Independent exhaustive topology audit found exactly one solving orientation among 32 distinct configurations for Docking Spur and among 1,024 configurations for each of Cargo Descent and Crosswind Relay. This is a separate algorithm simulation, not a replacement for CI.
- Updated `systems/WorldObjectStatefulProp.gd`: `set_loot_item()` and `apply_world_object_state()` reject state changes during an active inventory grant; transaction commit validates then applies the internal state directly while the public mutators remain guarded.
- Added `tests/salvage_crate_state_mutation_guard_test.gd`, whose inventory bridge attempts both public mutations during `collect_world_item()`; verifies both are rejected, the original reward identity remains stable, only one item is granted, and the crate consumes exactly one unit. Also verifies the public APIs still work outside a transaction.
- Extended `.github/workflows/godot-validation.yml` with explicit Pipe Relay import/rules/runtime checks and the mutation-guard regression.
- World save schema remains version 1. The guard protects supported API methods during a synchronous single-node transaction; direct writes to the script's public fields are not intercepted, and this is not a multiplayer server-authoritative lock.
- No local Godot executable was available. The exact-head GitHub Godot 4.3 CI is the engine evidence; no manual GUI/GPU/iPhone hardware test is claimed.
- Notion records: [Run 47 daily log](https://app.notion.com/p/409bc6a809d7817c82ebc5eaba9e6af9), [Pipe Relay M0.1](https://app.notion.com/p/409bc6a809d78107b8d6d548694e6cb3), [state mutation guard M0.1](https://app.notion.com/p/409bc6a809d781cdbe01eea47439e921), [workflow M0.1](https://app.notion.com/p/409bc6a809d781a8bc9bf795410c31d9).
- Remaining: consider private backing fields/read-only accessors for stronger encapsulation; bind stateful lifecycle into every production interactable factory; persist complete terrain/object deltas; integrate asynchronous chunk streaming/recovery; conduct device QA.


## Run 48 — 2026-10-30

### New playable Godot 4 project: KROLL Magnetic Maze M0.1

- Project: \`daily_games/KROLL_Magnetic_Maze/\`
- Import: open \`daily_games/KROLL_Magnetic_Maze/project.godot\` with Godot 4.3+ Project Manager.
- Dependencies: Godot 4.3+ only; no external assets, plugins, audio files, or network services.
- Gameplay: deterministic 7×7 magnetic crate-routing puzzle with PUSH/PULL pulses, wall-blocked magnetic rays, three authored layouts, keyboard controls, and mouse/touch buttons.
- Controls: WASD/arrows move and set facing; Space pulses; Tab toggles PUSH/PULL; R restarts; N advances layout.
- Tests: \`tests/rules_test.gd\` covers all three authored solutions, push/pull, blocked rays, invalid directions, charge accounting, and blocked turning. \`tests/game_smoke_test.gd\` instantiates the real scene and emits UI button signals.
- Independent BFS verification found shortest solutions of 3, 20, and 22 input actions for the three layouts respectively. This is a separate rules-model check, not a substitute for engine CI.

### WorldObjectStatefulProp read-only state accessors M0.1

- File: \`systems/WorldObjectStatefulProp.gd\`.
- Tests: \`tests/salvage_crate_read_only_state_test.gd\` and the updated corruption fixture in \`tests/mineral_chunk_controller_test.gd\`.
- Backing fields: \`_opened\`, \`_loot_remaining\`, \`_loot_item_id\`.
- Compatibility readers: \`opened\`, \`loot_remaining\`, and \`loot_item_id\` remain getter-only properties; state changes use \`set_loot_item()\` and \`apply_world_object_state()\`.
- Save payload keys and world-save schema 1 remain unchanged.
- GDScript leading underscores are a convention, not enforced private access. Callers must treat backing fields as internal and use the validated APIs.
- Repository compatibility review covered 42 test scripts plus 30 system/prototype/script files; the one direct-write test fixture was migrated to deliberate backing-field corruption for atomic-capture testing.

### Exact validation evidence

- Functional PR #130: https://github.com/qaqp980520-prog/2126-Survival/pull/130
- Functional candidate SHA: \`7e16dde771b5be31f6d41689d86ceba6601c7cf8\`
- Squash merge SHA: \`024dca1f82f550cf5676d3b3a5795287346ab93c\`
- Canonical Godot 4.3 CI Run #584: https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40995941086 — 193/193 job steps succeeded, zero failures, zero skipped.
- Targeted Run #10: https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40995941214 — 12/12 job steps succeeded.
- Local environment has no Godot executable; manual GUI, GPU performance, and iPhone device QA were not performed.


## 2026-10-30 Run 49 — Drone Relay + real world-object chunk lifecycle

- Feature PR [#132](https://github.com/qaqp980520-prog/2126-Survival/pull/132) merged as `1792752a237e3d2d035c3f9c7e74a07baf0090c2`. Exact tested candidate: `8995b49d6961984c72aa54c2c499ef766f4030b3`.
- Canonical Godot 4.3 CI [Run #589](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41006189052) passed: 195 numbered validation steps plus 3 post/cleanup entries, 198 job entries total; zero failures and zero skipped.
- Added `daily_games/KROLL_Drone_Relay/`: 6×6 simultaneous three-agent routing puzzle, three deterministic layouts, per-drone directional commands, nine-tick/battery budgets, collision blocking, keyboard and mouse/touch controls. Godot 4.3+, no external assets/plugins/audio/network. Tests: `tests/rules_test.gd` and `tests/game_smoke_test.gd`.
- Rules tests cover cardinal command validation, simultaneous moves, wall blocking, battery use, same-destination collision, moving into a stationary drone, terminal states, and authored solutions of 5, 7, and 6 ticks. Independent Python path-model verification is supplementary and not a substitute for Godot CI.
- Added `tests/world_object_chunk_lifecycle_test.gd`: creates the actual SurfaceChunkStreamingPlayground, collects from its live SalvageCrate through SurvivalWorldBridge, verifies stable ID/state serialization, unloads and regenerates the origin chunk, verifies a new crate instance restores loot identity/count without duplicate inventory, then restores a matching world+inventory snapshot and checks empty-crate behavior.
- Extended `.github/workflows/godot-validation.yml` with explicit Drone Relay file checks/import/rules/runtime and real chunk lifecycle regression. Exact CI steps 192–195 all passed.
- Initial candidate `61e28582bdc1131b081958717e40d649af6f5ed9` failed root import because two Node.get calls used an unsupported second argument. Both were corrected; final candidate `8995b49d6961984c72aa54c2c499ef766f4030b3` passed Run #589. The initial failure is retained as history, not treated as a pass.
- World save schema remains version 1; no production runtime factory or save envelope was changed. The new lifecycle test covers the SurfaceChunkStreamingPlayground factory path, not every production factory.
- No local Godot executable was available; manual GUI, GPU, and iPhone hardware QA are not claimed.
- Notion: [Run 49 daily log](https://app.notion.com/p/409bc6a809d7810f9d98c6fea34114c4), [Drone Relay M0.1](https://app.notion.com/p/409bc6a809d781889323f1c18940f958), [world-object lifecycle regression M0.1](https://app.notion.com/p/409bc6a809d781b19485ea31b0cf27ea), [workflow M0.1](https://app.notion.com/p/409bc6a809d781679a06dbc68f80f0f3), [asset index](https://app.notion.com/p/400bc6a809d781269143fa5379833145).
- Remaining: migrate all production interactable factories to stable IDs/validated restore; persist complete terrain/object deltas across chunk and save/load boundaries; integrate asynchronous chunk streaming and recovery; perform device QA.


## 2026-10-30 Run 50 — Outpost Architect + legacy world-object rollback

- Feature PR [#134](https://github.com/qaqp980520-prog/2126-Survival/pull/134) merged as \`84dfae68a7170fb66ba60c17093292ccd6018f69\`. Exact tested candidate: \`0e5be2ea6a4f3b70ebd0646488091355101febe0\`.
- Canonical Godot 4.3 CI [Run #596](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41018084060) passed: 202/202 job step entries succeeded, zero failures and zero skipped. Step 150 validates the world-session rollback regression; steps 196–199 verify/import/test Outpost Architect.
- Added \`daily_games/KROLL_Outpost_Architect/\`: 5×5 deterministic outpost-building puzzle, three authored decks, three scenarios, 8 placements, 18-energy budget, orthogonal adjacency scoring, keyboard/mouse/touch controls. Godot 4.3+, no external assets/plugins/audio/network. Tests cover exact authored routes/scores, energy and turn budgets, invalid indices, occupied cells, insufficient energy, button signals, keyboard controls, restart and layout switching.
- Independent scoring model confirms the three first-card routes reach 27/27, 25/25 and 25/25 with 4 energy remaining. This is supplementary model analysis, not a substitute for engine CI.
- Fixed \`scripts/world.gd\` (\`WorldSessionController\`): on failed target streaming, always restore the pre-attempt world-object Registry snapshot, even when a legacy schema-1 payload omits optional \`world_objects\`. Failed streaming can create temporary object records while loading chunks; the absent payload field must not skip rollback.
- Extended \`tests/world_session_controller_test.gd\` with deterministic factory failure after one temporary target chunk loads. Exact Registry payload and stable IDs, active chunk IDs, player position, and rollback report all passed.
- World-save schema remains version 1. Successful legacy restore without \`world_objects\` still preserves the current Registry; the change applies to failed target-stream recovery.
- Responsive UI uses 52×54 board cells, 84×58 hand buttons, compact controls and wrapping labels for narrow viewports. This is source-level layout support, not proof of iPhone hardware QA.
- Source audit correction: \`scripts/world.gd\` exists on current main as the reusable \`WorldSessionController\` base. Earlier “file absent” notes describe historical snapshots before its Run 38 addition. A production-specific world subclass/scene and migration of every production factory are still outstanding; do not conflate the base controller with a finished production world.
- Local environment has no Godot executable; manual GUI, GPU performance and iPhone device QA were not performed.
- Notion: [Run 50 daily log](https://app.notion.com/p/409bc6a809d78122b735dcd0ed03f236), [Outpost Architect M0.1](https://app.notion.com/p/409bc6a809d781019571c946df716438), [WorldSessionController rollback M0.2](https://app.notion.com/p/409bc6a809d781bcbc1ac70641522597), [workflow M0.1](https://app.notion.com/p/409bc6a809d7818d8b05d9295dabd151), [asset index](https://app.notion.com/p/400bc6a809d781269143fa5379833145).
- Remaining: migrate every production interactable factory to stable IDs/validated restore; persist complete terrain and object deltas across chunk unload/reload and save/load; integrate asynchronous chunk streaming and recovery; perform device QA.


## Run 51 reconciliation and Run 52 — 2026-10-30

### Run 51 final-state correction

- Feature PR [#136](https://github.com/qaqp980520-prog/2126-Survival/pull/136) merged into main at 771bc9f2171e1f638457cd17fb64a542fd7e90f4.
- Exact candidate 862ee711cc62801d378ac6d8215aabf202cc1b4f passed Godot 4.3 CI [Run #602](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41025383273): 208/208 successful workflow steps, zero failures/skips.
- The old branch docs/run51-closeout-2026-10-30 was checked and is identical to Run 51 main (0 ahead, 0 behind, 0 changed files); no separate Run 51 documentation PR existed. Earlier pending wording is historical and was corrected in Notion and this Run 52 closeout.

### Run 52 verified feature assets

- Feature PR [#137](https://github.com/qaqp980520-prog/2126-Survival/pull/137) merged at 5b5a534e22dd0b27bed60b3ed6530357c869581b. Exact tested candidate: d5d6c565cbb14a3a5128075d153d5e343fc507dd.
- Godot 4.3 CI [Run #609](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41027928173) passed: 213/213 workflow step entries succeeded, zero failures/skips. Steps 207–209 import, rules-test and physically simulate Gravity Courier; step 210 exercises the real production SurfaceWorld underground mining path.
- Added daily game daily_games/KROLL_Gravity_Courier/: a 2D gravity-switching cargo platformer with four cargo cells, floor/ceiling physics, keyboard and touch controls, rules tests and runtime smoke tests. Godot 4.3+, no external assets/plugins/audio/network.
- Added systems/UndergroundMineFactory.gd and integrated a stable underground/mine_0_0 chunk into world/SurfaceWorld.gd. The visible mine-shaft lift uses G to descend/ascend; F mines the nearest reachable vein through the shared SurvivalWorldBridge inventory. The mine contains iron, copper and uranium veins using the existing MineralMiningNode and 300-second regeneration configuration.
- Added MineralChunkController.get_loaded_mineral_nodes(). The SurfaceWorld HUD switches CRATE to MINE, DESCEND to ASCEND, and disables crop interaction underground.
- World save schema remains version 1. SurfaceWorld adds optional location_layer and surface_return_position fields. Older schema-1 saves without these fields default to the surface layer.
- MineralGridStreamingDirector now ignores only the explicit underground/* namespace while reconciling surface recovery. Unknown and malformed non-underground IDs remain rejected. The first broad non-surface skip failed existing validation at Run #607 step 47; the narrowed fix passed the final Run #609.
- End-to-end tests cover surface-only mining restriction, shaft distance, mining via the F interaction route, shared inventory count and carry weight, mine chunk unload/reload, stable vein stock, world save/restore, legacy schema-1 saves, and surface recovery with an underground chunk loaded.

### Limitations and next work

- The current mine entrance is a visible lift/level transition, not a continuous physics ladder.
- One fixed underground mine chunk is kept loaded; a separate multi-level underground streaming director and spatial load/unload policy are not yet implemented.
- Surface-generated veins remain below ground; the newly accessible mine currently provides the reachable iron/copper/uranium veins.
- No local Godot executable was available. Manual GUI, GPU performance and iPhone hardware QA are not claimed.
- Next: implement multi-level underground chunk streaming and transactional recovery; migrate all formal interactable factories to stable IDs/validated restore; persist terrain and object deltas across chunk unload/reload; perform device QA.


## 2026-10-30 Run 53 — Orbital Docking + transactional underground 3×3 streaming (merged / exact-head CI passed)

- Start-of-run baseline: main was `144e5785aab3549bf8b00b07a7587e193482f320`; Run 52 PR #137 and documentation PR #138 were both merged. The Run 53 asset records initially described candidate `b4e83f7b8236bfd6dffab11d2e5db7371685eaa6` as pending, but that was superseded. GitHub's actual PR #139 head at final validation was `6298da84c4bfc46272e939aa7ba00d1541caedac`; treat GitHub PR/commit/CI state as authoritative.
- Feature PR [#139](https://github.com/qaqp980520-prog/2126-Survival/pull/139) merged as `a40e25b0be8ed948c2324914f2b7151db993026c`.
- Exact-head Godot 4.3 workflow [Run #620](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41032518860) on candidate `6298da84c4bfc46272e939aa7ba00d1541caedac` succeeded: 218/218 job step entries successful, zero failures and zero skipped. New Run 53 steps 211–215 passed: UndergroundMineDirector transaction tests, Orbital Docking file verification/import/rules/runtime.
- The cancelled Run #619 targeted superseded candidate `b4e83f7b8236bfd6dffab11d2e5db7371685eaa6`; it is not final evidence. Earlier Run #617 was a failed diagnostic for a physics/process-frame observation timing assertion. The final candidate moved the assertion after the process-frame boundary while preserving actual SurfaceWorld physics-driven movement; Run #620 passed the exact final head.
- Added `daily_games/KROLL_Orbital_Docking/`: Godot 4.3+ 2D inertial spacecraft docking simulator, three deterministic approaches, finite fuel/time, rotate/forward/reverse thrust, keyboard and touch controls, rules and runtime tests. No external assets, plugins, audio or network dependencies.
- Added `systems/UndergroundMineDirector.gd`: transactional horizontal 3×3 underground chunk window, stable coordinate-derived IDs, bounded load/unload, registry snapshot rollback and failure diagnostics. `systems/UndergroundMineFactory.gd` now builds aligned doorways between adjacent 10 m rooms and deterministic coordinate-derived mineral identities. `systems/MineralVeinRegistry.gd` adds exact snapshot restoration without regeneration-clock catch-up during failed transaction rollback.
- Integrated underground movement streaming into `world/SurfaceWorld.gd` using the actual CharacterBody3D physics path. The surface hatch remains available during layer transitions; failed return/stream operations restore the previous position/layer state. The mine is a horizontal single-elevation 3×3 window.
- Production tests cover nine active underground rooms, real physics-driven travel, stable mineral stock after unload/reload, aligned doorways, invalid positions, factory failure rollback and absence of orphan Registry records. Canonical workflow now runs the director test and Orbital Docking import/rules/runtime.
- World-save schema remains version 1; existing stable IDs, MineralVeinRegistry and SurvivalWorldBridge inventory are reused.
- Limits: vertical multi-level mine connections and asynchronous streaming are not implemented. The 3×3 room window is horizontal at one elevation; long-term explored-room Registry growth may require partitioned/compacted persistence.
- No local Godot executable was available; no local GUI/GPU/iPhone test is claimed. Exact engine evidence is the GitHub-hosted Godot 4.3 workflow above.
- Notion: [Run 53 daily log](https://app.notion.com/p/409bc6a809d781daabf0eafbb6c6ec51), [Orbital Docking M0.1](https://app.notion.com/p/409bc6a809d78110b0d0f8b4a1f68a32), [UndergroundMineDirector M0.1](https://app.notion.com/p/409bc6a809d78126b796ea8053513d18), [Run 53 workflow record](https://app.notion.com/p/409bc6a809d7818982f1df75ac9f9e95), [asset index](https://app.notion.com/p/400bc6a809d781269143fa5379833145).
- Remaining: vertical multi-level underground connections, asynchronous chunk streaming/recovery, production-wide factory persistence audit, terrain/object delta persistence, and manual device QA.


## 2026-10-30 Run 54 — Fossil Lab + production carry-weight movement (merged / exact-head CI passed)

- Baseline: Run 53 feature PR #139 and documentation PR #140 are both merged. Main before Run 54 feature merge was `ab33e146c9b1a71b349efa96fe349edeb72890f1`.
- Feature PR [#141](https://github.com/qaqp980520-prog/2126-Survival/pull/141) merged as `c24c881e497e0f71b56462d672db143ae55a5639`. Exact feature candidate HEAD: `d1aca4feafacafdc1f7789ec15d75457c235203c`.
- Exact-head Godot 4.3 [Run #623](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41038847298) succeeded: 223/223 workflow job step entries successful, zero failures, zero skipped. New steps 216–220 all passed: production carry-movement integration, Fossil Lab file verification, import/parse, rules tests and runtime smoke test.
- Added `daily_games/KROLL_Fossil_Lab/`: deterministic 5×5 fossil assembly puzzle, four three-cell fragments (RIB/JAW/HIP/CLAW), three authored blueprints, quarter-turn rotation, target-mask placement, overlap/out-of-bounds rejection, undo, keyboard/mouse/touch controls, rules tests and scene smoke test. No external assets/plugins/audio/network dependencies.
- Updated `world/SurfaceWorld.gd` to consume the existing `SurvivalWorldBridge.get_summary()` movement profile. Normal speed remains 5.0 m/s; above the day-based carry limit the existing 0.68 multiplier applies; above 90 kg the existing 0.42 multiplier applies and jumping is disabled. Exactly 90 kg remains jump-capable. Dropping weight recalculates on the next physics update. HUD reports movement percentage and jump availability.
- Added `tests/production_surface_world_carry_movement_test.gd`: validates 63/66/90/93 kg boundaries, actual horizontal speeds 5.0/3.4/2.1 m/s, jump lock above 90 kg, and immediate speed/jump recovery after dropping one 3 kg iron ore.
- Reused existing `SurvivalInventory` and `SurvivalWorldBridge`; no duplicate weight model, item-weight changes or world-save schema changes.
- The feature branch was one docs-only commit behind current main when merged; changed paths did not overlap Run 53 docs and GitHub reported the PR mergeable. PR #141 was merged only after exact-head Run #623 succeeded.
- Limits: this change connects existing movement multiplier and jump gating only. It does not add a stamina model or overweight stamina consumption; stamina fields/rates/save semantics must be designed before implementation. No local Godot executable was available; no manual GUI/GPU/iPhone test is claimed.
- Notion: [Run 54 daily log](https://app.notion.com/p/409bc6a809d781f39c7df45031f212c9), [Fossil Lab M0.1](https://app.notion.com/p/409bc6a809d781b2a068c7faa74f8cc9), [Carry Weight Movement M0.1](https://app.notion.com/p/409bc6a809d781c09558db9ea73a27ce), [workflow record](https://app.notion.com/p/409bc6a809d78147b3d5f4b07e5ad24d), [asset index](https://app.notion.com/p/400bc6a809d781269143fa5379833145).
- Remaining: stamina system design/integration, production-wide interactable factory persistence audit, vertical multi-level underground connections, asynchronous chunk streaming, terrain/object delta persistence and manual device QA.


## 2026-10-30 Run 55 — Tidal Survey + production stamina M0.1 (feature merged)

- Baseline main before Run 55: `2504e62b3208c49ba7374bd858a8e68b6e51cb94`. Start-of-run branch inventory was fully paged at 148 branches and there were no open PRs. Run 54 daily log and asset records were checked before work; no Run 55 record existed at start.
- Feature PR [#143](https://github.com/qaqp980520-prog/2126-Survival/pull/143) merged as `de11e4a77962fdfbafe950f2ad9e63a6c1b07d4c`. Exact candidate HEAD: `26745ff0bc302e8c25a1c04342cc86a58ef35e17`.
- Exact-head Godot 4.3 [Run #637](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41047042931) succeeded: 229/229 workflow job step entries successful, zero failures and zero skipped. New checks 221–226 all passed.
- Added `daily_games/KROLL_Tidal_Survey/`: deterministic 2D top-down underwater navigation with inertial thrust, drag, constant current fields, ordered beacons, hazard cooldowns, oxygen depletion and return-to-dock objective. Includes keyboard and on-screen mouse/touch directional controls, three authored layouts, rules tests and scene smoke test. No external assets/add-ons/audio.
- Tidal Survey acceptance includes a deterministic route-follower simulation that completes all three authored layouts within the oxygen budget. Scene smoke test emits actual NEXT/RESTART and directional Button signals, not only direct helper calls.
- Added `systems/SurvivalStamina.gd` and integrated it into production `world/SurfaceWorld.gd`. Horizontal movement drains stamina; stationary time regenerates; a successful jump spends 10 stamina. Movement drain is derived from the existing inventory movement multiplier: 2.0/s at normal speed, about 2.94/s at the overweight 0.68 multiplier, and about 4.76/s at the super-heavy 0.42 multiplier. Existing inventory remains the sole owner of weight thresholds and movement multipliers.
- Stamina prototype defaults: maximum 100, normal movement drain 2.0/s, idle recovery 6.0/s, jump cost 10. These are provisional tuning values, not final balance locks. Same-frame jump is resolved before movement drain so exactly 10 stamina is sufficient to initiate a jump.
- Production SurfaceWorld saves stamina as an optional payload schema 1 while keeping the world envelope at schema 1. New saves round-trip current stamina; legacy schema-1 saves without the optional key remain valid and initialize stamina to full. Invalid or unknown stamina fields are rejected before world restore mutation.
- Added `tests/survival_stamina_test.gd` and `tests/production_surface_world_stamina_test.gd`. Coverage includes normal/overweight/super-heavy drain, idle recovery, exact jump threshold, invalid delta, save validation, actual physics-input drain, carry-weight coupling, legacy fallback, invalid-payload non-mutation, position/inventory/chunk-window preservation and restore diagnostics.
- Added design notes: `docs/KROLL_TIDAL_SURVEY_M0_1_2026-10-30.md` and `docs/SURVIVAL_STAMINA_MODEL_M0_1_2026-10-30.md`.
- Updated `.github/workflows/godot-validation.yml` with Tidal Survey import/rules/runtime checks and stamina model/production integration tests.
- The Run 54 note that no stamina model existed is historical and is superseded by this Run 55 M0.1 integration.

### Known limits

- Stamina rates are provisional. Sprinting, food/hotbar restoration and a separate exhaustion movement penalty at zero stamina are not implemented.
- Current fields in Tidal Survey are constant within their radius; no saved campaign/high-score progression.
- Formal world-wide factory migration, terrain/object delta persistence, vertical multi-level underground connections and asynchronous chunk streaming remain open.
- No local Godot executable was available; no manual GUI, GPU or iPhone hardware QA is claimed. Engine evidence is GitHub-hosted Godot 4.3 CI.

### Notion

- Run 55 daily log: https://app.notion.com/p/409bc6a809d7815895d9c58a4144225b
- KROLL Tidal Survey M0.1: https://app.notion.com/p/409bc6a809d78129a9e5f61b70b53ae9
- SurvivalStamina Model M0.1: https://app.notion.com/p/409bc6a809d78100ad02ffa906026980
- Workflow Run 55 M0.1: https://app.notion.com/p/409bc6a809d781f6ae23f95d26d80aeb
- Asset index: https://app.notion.com/p/400bc6a809d781269143fa5379833145


## 2026-10-30 Run 56 — Station Shift + SurvivalStamina M0.2 (feature merged)

- Run 56 started from verified main `273ed4077c1402e715ebdb500979ffe217ba75a1`; Run 55 feature PR #143 and documentation PR #144 were both merged. The Run 56 feature branch was `feature/run56-station-shift-stamina-2026-10-30`.
- Feature PR [#145](https://github.com/qaqp980520-prog/2126-Survival/pull/145) merged as `52f47d61b992a2449dcaae35b1c4b230ccd9925a). Exact final candidate HEAD: `169d9b394cd09636896790b91d4951f01cf2c090`.
- Exact-head Godot 4.3 [Run #645](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41052380165) succeeded: 233/233 workflow step entries successful, zero failures and zero skipped. The final new checks 227–230 passed: Station Shift input verification, project import, rules tests and scene runtime smoke test.
- Added `daily_games/KROLL_Station_Shift/`: deterministic six-cycle station operations management, three authored scenarios, five crew assigned across Power / Life Support / Repairs, Energy/Oxygen/Hull reserves, keyboard controls and mouse/touch buttons. Rules tests contain a winning six-cycle allocation for each scenario; runtime smoke test emits actual UI button signals. Godot 4.3+, no external assets, add-ons or audio.
- Upgraded `systems/SurvivalStamina.gd` to M0.2 and integrated it into production `world/SurfaceWorld.gd`: hold Shift or touch SPRINT while moving; sprint speed factor 1.35, stamina drain factor 2.25, sprint threshold 5; at zero stamina the player can still walk at 0.65 of post-carry speed and cannot sprint. Stationary recovery remains 6/s; jump cost remains 10.
- Carry weight remains owned by SurvivalInventory. Stamina speed/drain factors multiply the existing inventory movement multiplier; no duplicate carry-weight rules were added.
- Sprint/exhaustion are derived from current stamina and are not separately persisted. Stamina payload schema 1 and world-save envelope schema 1 remain unchanged; legacy saves without stamina still initialize to full stamina.
- Expanded `tests/survival_stamina_test.gd` and `tests/production_surface_world_stamina_test.gd` for sprint threshold, drain, exhaustion, recovery, touch button signal, real physics input, carry-weight coupling, jump boundary and save compatibility. Added Station Shift import/rules/runtime steps to `.github/workflows/godot-validation.yml`.
- Exact-head failure history was retained and corrected rather than hidden: Run #642 had stale stamina snapshot expectations; Run #643 used the wrong post-reset overweight baseline; Run #644 found an invalid two-argument `Object.get()` in the new game smoke test. The final correction is the one-line `Object.get("scenario_index")` call in commit `169d9b394cd09636896790b91d4951f01cf2c090`; only Run #645 is final acceptance evidence.
- Run 56 Notion records: [daily log](https://app.notion.com/p/409bc6a809d7816893d9d35c5ceda603), [Station Shift M0.1](https://app.notion.com/p/409bc6a809d781c88377e90360990a11), [SurvivalStamina M0.2](https://app.notion.com/p/409bc6a809d7817c8990e1643856edb4), [workflow record](https://app.notion.com/p/409bc6a809d7813e9eb1e584efadb294), [asset index](https://app.notion.com/p/400bc6a809d781269143fa5379833145).

### Run 56 limits

- Stamina rates are provisional and require playable-world tuning.
- Food/hotbar stamina restoration and sprint animation/camera feedback remain unimplemented.
- The Run 55 note that sprinting and zero-stamina exhaustion were not implemented is historical and superseded by Run 56 M0.2.
- Production-wide interactable factory migration, terrain/object delta persistence, vertical multi-level underground connections, asynchronous chunk streaming/recovery and manual GUI/GPU/iPhone QA remain open.
- No local Godot executable is available; no local GUI, GPU or iPhone hardware test is claimed. Engine evidence is the exact-head GitHub-hosted Godot 4.3 CI above.


## 2026-10-30 Run 57 — Void Runner + SurvivalQuickUse M0.1 (feature merged / exact-head CI passed)

- Run 57 started from verified main `dca26e854229e35dc1dc5b7251609344fc2df96c`. The initial candidate branches/PRs #147–#149 were superseded and closed unmerged; the selected correction branch was `fix/run57-quick-use-hud-full-stamina-test-2026-10-30`.
- Feature PR [#150](https://github.com/qaqp980520-prog/2126-Survival/pull/150) merged as `9428c90f88d3e50cd90c46a29e717d7e5b56a245`. Exact candidate HEAD: `b4b9cca82280ffb8d887c346acff929720fa2ed3`.
- Exact-head Godot 4.3 [Run #659](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41064963418) completed successfully: all 236 numbered validation steps passed, zero failed and zero skipped; the three job post/cleanup steps also succeeded. The final new checks 231–236 passed: Void Runner asset verification, project import, rules tests, scene runtime smoke test, quick-use model tests and production SurfaceWorld integration.
- Added `daily_games/KROLL_Void_Runner/`: deterministic three-lane runner with three authored routes, lane changes, jump/slide windows, barriers/gates/drones, data-cell collection, two integrity points, keyboard and mouse/touch controls. Godot 4.3+, no external assets, add-ons, audio or network dependencies.
- Added `systems/SurvivalQuickUse.gd` and integrated it through `systems/SurvivalWorldBridge.gd` and production `world/SurfaceWorld.gd`. Four default slots: berries (+8), herbs (+12), meat (+24), food (+30) stamina. Restoration clamps to remaining capacity; a full stamina bar or empty slot preserves inventory. Keyboard 1–4 selects, C consumes; touch buttons expose each slot.
- Inventory counts remain owned by SurvivalInventory and consumption uses the shared bridge signals. The quick-use model guards synchronous re-entry. If stamina becomes full after item removal but before restoration, it attempts a bridge-based refund and reports `stamina_rejected` with `rollback_complete`; the regression proves guard release and a later successful retry.
- Optional quick-use payload schema 1 is stored inside the existing world-save envelope schema 1. Legacy saves without the key reset to default slots; invalid payloads are rejected before world mutation. No save-envelope version bump.
- Exact-head failure history is retained: Runs #655/#656 exposed a test expecting the full-stamina HUD button to remain enabled; production behavior correctly disables it to avoid wasting a ration. Run #657 then exposed absolute stamina assertions that ignored legitimate idle physics recovery. The tests were corrected to check HUD state transitions and live pre-use stamina deltas. Run #658 targeted a superseded intermediate SHA. Only exact-head Run #659 is final acceptance evidence.
- Run 57 Notion records: [daily log](https://app.notion.com/p/409bc6a809d78105bc15f86debfbb55f), [KROLL Void Runner](https://app.notion.com/p/409bc6a809d7816bb98fe2fb3aaaaeaa), [SurvivalQuickUse](https://app.notion.com/p/409bc6a809d7819bbdf6f5e5e3e6a92d), [HUD correction](https://app.notion.com/p/409bc6a809d781459bdef0097774689f), [asset index](https://app.notion.com/p/400bc6a809d781269143fa5379833145).

### Run 57 limits / next

- Consumable restoration values are provisional; no drag-and-drop hotbar assignment UI exists.
- Sprint animation/camera feedback, production-wide interactable factory migration, terrain/object delta persistence, vertical underground connections and asynchronous chunk streaming/recovery remain open.
- GitHub repository `main` is not branch-protected and required status checks are not enabled. This merge used a manual exact-head Godot 4.3 gate; repository protection settings were not changed.
- No local Godot executable is available; manual GUI, GPU and iPhone device QA are not claimed. Engine evidence is the exact-head GitHub-hosted Godot 4.3 workflow above.


## Run 58 — KROLL Orbital Imager and underground salvage cache integration (2026-10-31)

### New playable Godot 4 mini-game
- Project: `daily_games/KROLL_Orbital_Imager/`
- Entry scene: `daily_games/KROLL_Orbital_Imager/main.tscn`
- Rules: `daily_games/KROLL_Orbital_Imager/rules.gd`
- Tests: `daily_games/KROLL_Orbital_Imager/tests/rules_test.gd` and `tests/game_smoke_test.gd`
- Gameplay: camera-framing puzzle across Lunar Beacon Array, Crater Relay, and Orbital Debris Field. Pan with WASD/arrows, zoom with Q/E, capture with Space; mouse/touch buttons are provided.
- Capture requires all three green targets inside the camera frame and every red interference marker outside. Each assignment has three shutter attempts.
- Godot 4.3+, no external assets or add-ons.

### Existing world-system integration
- `systems/UndergroundMineFactory.gd`: the origin room `underground/mine_0_0` now creates `MineCache_Gold` and `MineCache_Coal` using `WorldObjectStatefulProp`.
- Both caches reuse `WorldObjectStateRegistry` and `MineralChunkController`; no world-save schema change.
- `world/SurfaceWorld.gd`: underground F interaction chooses the closest valid target. A nearer cache opens; a nearer mineable vein continues through the existing mining path.
- Underground touch action label is `CACHE`; HUD help describes cache/mining behavior.
- Stable cache ID includes the underground chunk ID and scene-node path.

### Regression coverage
- `tests/production_surface_world_mining_test.gd`: verifies cache registration, touch label, gold-ore transaction, save snapshot, stable ID, chunk unload/reload, restored remaining stock, and no duplicate inventory grant.
- `tests/production_surface_world_test.gd`: asserts nine surface crates plus two underground caches (11 world objects total).
- `tests/underground_mine_director_test.gd`: binds both mineral and world-object registries and asserts the two origin caches are registered.
- Orbital Imager rules and scene smoke tests are wired into `.github/workflows/godot-validation.yml`.

### Exact GitHub evidence
- Feature PR #152 merged: https://github.com/qaqp980520-prog/2126-Survival/pull/152
- Feature candidate HEAD tested: `44256ddc52b9c90396b9035f0a9493408f5fcb78`
- Merge commit / current main at closeout: `13bc8d218bafc79cfa1cd4cc4532d43563069310`
- Godot 4.3 exact-head CI Run #665: 240/240 numbered workflow steps successful, zero failures and zero skipped steps.
- Historical failures retained: Run #663 exposed a stale object-count expectation (9 versus the correct 11); Run #664 exposed a missing WorldObjectStateRegistry binding in the isolated mine-director test fixture. Both were corrected before Run #665.

### Known limits
- Salvage caches are currently placed only in `mine_0_0`; other underground rooms remain mineral-only.
- Orbital Imager M0.1 uses fixed 2D maps, with no 3D orbital camera or campaign persistence.
- No local Godot executable was available; GUI, GPU performance, and iPhone device testing are not claimed.


## Run 59 — KROLL Cargo Audit M0.1 and Underground Cache Distribution M0.1 (2026-10-31)

### New Godot 4 game: KROLL Cargo Audit
- Project: `daily_games/KROLL_Cargo_Audit/`
- Three authored manifest-investigation cases, four containers per case, three inspection fields (mass/seal/count), one certified field per case, eight-scan budget, two incorrect accusations, score and case progression.
- The player-facing case projection removes both actual sensor readings and the hidden answer metadata. Rules tests validate exactly one discrepancy per case and the runtime smoke test exercises actual mouse/touch button signals and keyboard container/field selection.
- Import with Godot 4.3+ via `daily_games/KROLL_Cargo_Audit/project.godot`. No external assets, audio, plugins or network dependencies.

### Underground mine cache distribution
- Updated `systems/UndergroundMineFactory.gd` with four directional weighted loot tables: west, east, north and south.
- The origin service room keeps the existing `MineCache_Gold` and `MineCache_Coal` identities and contents. Non-origin rooms use a deterministic coordinate hash: one third remain cache-free; the remaining rooms receive at most one cache selected from the regional weighted table.
- Cache node name, room chunk ID and scene path provide stable world-object identity. Caches continue using `WorldObjectStatefulProp`, `WorldObjectStateRegistry` and `MineralChunkController`; world save schema remains version 1.
- The initial 3×3 mine window contains seven caches across six rooms: two origin service caches plus five regional caches.
- Independent deterministic formula simulation over a 13×13 sample (excluding origin) yields 168 non-origin rooms: 112 spawned and 56 empty. The four directional tables are all exercised and all seven catalog minerals appear. This is a separate formula simulation, not a Godot engine test.

### Regression coverage
- `tests/underground_cache_distribution_test.gd`: verifies deterministic spawn decisions, exact two-thirds / one-third ratio, four table regions, all seven mineral IDs, unique stable IDs, initial-window density and cache/vein non-overlap.
- `tests/underground_mine_director_test.gd`: verifies seven stateful caches in the initial nine-room window.
- `tests/production_surface_world_test.gd`: verifies nine surface crates plus seven underground caches (16 world objects).
- `tests/production_surface_world_mining_test.gd`: collects a regional coal cache through the shared inventory bridge, verifies catalog weight is applied immediately, then unloads/reloads the room and verifies stable identity, remaining stock and no duplicate inventory grant.
- `.github/workflows/godot-validation.yml` adds Cargo Audit import/rules/runtime and underground cache distribution steps; existing production SurfaceWorld, mine director and mining lifecycle regressions also run.

### Exact GitHub evidence
- Feature PR [#154](https://github.com/qaqp980520-prog/2126-Survival/pull/154) merged as `63913a4cfea8da1af0e05242373a0a0d1226f455`.
- Exact feature candidate HEAD `6394fe6c8c686ec91656c5a7bdefdc5555f4e4de` passed Godot 4.3 [Run #672](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41146228476): all 245 numbered validation steps and all setup/cleanup/completion step records succeeded (248/248), zero failures and zero skipped steps.
- Current main at feature closeout: `63913a4cfea8da1af0e05242373a0a0d1226f455`.

### Known limits
- Cache selection is deterministic from room coordinates and fixed weighted tables; there is no saved world seed or data-driven editable loot-table resource yet.
- Underground world remains a single elevation with synchronous chunk streaming. Vertical floors, ladders/elevators and asynchronous load/recovery remain pending.
- Cargo Audit has three fixed cases only; no generated manifests, persistent campaign scores or multiplayer.
- No local Godot executable was available; manual GUI, GPU performance and iPhone device testing are not claimed.


## Run 60 — KROLL Orbital Pinball M0.1 + vertical underground mine layers M0.1 (2026-10-31)

### New Godot 4 game
- Project: `daily_games/KROLL_Orbital_Pinball/`.
- Three authored bumper layouts, three balls, deterministic 2D ball integration, launch, rail/bumper/flipper collisions, scoring, drain/life loss, reset and next-table progression.
- Keyboard controls: A/D hold flippers, Space launches, R resets, N advances the table. On-screen buttons provide mouse/touch input.
- No external assets, audio, plugins or network dependencies. Import via `daily_games/KROLL_Orbital_Pinball/project.godot` with Godot 4.3+.
- Rules and runtime smoke tests are included and the Survival Test Hub exposes the game.

### Vertical underground mine layers
- `systems/UndergroundMineDirector.gd` now manages a bounded 3×3 chunk window at one active depth, supporting layer 0–8.
- Layer 0 keeps legacy IDs `underground/mine_x_z`; deeper floors use `underground/layer_N/mine_x_z`.
- `systems/UndergroundMineFactory.gd` offsets each floor by 20m, creates a stable `MineLiftAnchor` in the origin room on every layer, and includes depth in deterministic mineral/cache placement.
- `world/SurfaceWorld.gd` exposes V / DOWN ONE to descend at the lift and G / UP ONE to ascend; returning from layer 0 uses the surface shaft. HUD reports the current level.
- The schema-v1 world payload adds optional `mine_depth`. Legacy saves without it infer depth from player Y; surface saves default to zero.
- Failed depth transitions roll back both MineralVeinRegistry and WorldObjectStateRegistry snapshots, including partial factory-load failure. The old layer window and exact registry IDs are preserved.

### Regression coverage
- `tests/underground_mine_layers_test.gd`: depth mapping, layer bounds, legacy/deep stable IDs, factory root offsets, lift anchors and deterministic cache data.
- `tests/underground_mine_director_test.gd`: layer 0↔1 switching, bounded window, legacy ID compatibility and injected partial-load rollback.
- `tests/production_surface_world_mining_test.gd`: descend, mine, stream/unload/reload, ascend, return to surface, depth save/restore and legacy schema-v1 save without `mine_depth`.
- Workflow adds Orbital Pinball import/rules/runtime smoke tests.

### Exact GitHub evidence
- Feature PR [#156](https://github.com/qaqp980520-prog/2126-Survival/pull/156) merged as `857c8a9cccd4dda380a8dd893750d6f6b91d409a`.
- Exact feature HEAD `87c249bc2844b744190c1c413b5a85dadefe3ae8` passed Godot 4.3 [Run #678](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41149499503): 253/253 total step records successful, zero failures, zero skipped.
- Post-merge main-push [Run #679](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41150013939) also completed successfully with 253 steps.
- Main at feature closeout equals merge commit `857c8a9cccd4dda380a8dd893750d6f6b91d409a`; PR #156 is closed/merged and no open PR remained before this documentation closeout.

### Known limits
- Only one depth window is active at a time; maximum supported depth is layer 8.
- Lift travel is an immediate layer transition at the origin anchor; no continuous elevator animation or visible full-height shaft yet.
- Cache/ore distribution remains deterministic coordinate hashing and fixed tables, not a saved world seed or editable data resource.
- Chunk generation and rollback remain synchronous; no asynchronous request queue is claimed.
- No local Godot executable was available; manual GUI, GPU performance and iPhone device QA are not claimed.


## Run 61 — KROLL Tether Recovery M0.1 + data-driven underground cache tables M0.2 (2026-10-31)

### New Godot 4 game
- Project: `daily_games/KROLL_Tether_Recovery/`.
- Top-down inertial salvage drone, three authored missions, three cargo pods per mission, WASD thrust, Shift brake, Space tether attach/release, hazard/hull damage, fuel/time limits, dock delivery, score, reset/next mission.
- On-screen hold/action buttons support mouse/touch. Rules are deterministic manual 2D integration; no external assets/audio/plugins/network dependencies.
- Import via `daily_games/KROLL_Tether_Recovery/project.godot` with Godot 4.3+.
- Added rules and runtime smoke tests; Survival Test Hub exposes the game and its smoke test verifies the new entry.

### Data-driven underground cache tables
- `systems/data/underground_loot_tables.json` stores schema-v1 west/east/north/south weighted tables.
- `UndergroundMineFactory.load_cache_tables()` loads the JSON and `validate_cache_tables()` rejects unsupported schema, missing/extra regions, unknown mineral IDs, non-numeric/non-integral/non-positive weights, duplicate item IDs and empty tables.
- Godot's JSON parser represents integer-looking numeric values as numeric Variants; validation accepts int or integral float, while rejecting fractional values.
- Existing coordinate/layer hash formulas, layer-zero service cache pair and representative output identities remain unchanged. No world-save schema change or cache-ID migration.
- No persisted world seed yet; this is a data externalization step only.

### Regression coverage
- `tests/underground_loot_tables_resource_test.gd`: resource presence, four regions, all seven MineralCatalog IDs, positive integral weights, malformed resource rejection, golden cache identities and deterministic 13×13 samples across layers 0–8.
- Workflow adds Tether Recovery import/rules/runtime and loot-table resource compatibility steps.

### Exact GitHub evidence
- Feature PR [#158](https://github.com/qaqp980520-prog/2126-Survival/pull/158) merged as `dd23ce770df08a0e93403ee6942ab36bd98484af`.
- Final exact feature HEAD `b8c33dd301179158cc4c82bc26c5501d9322f439` passed Godot 4.3 [Run #685](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41153746104): 258/258 total step records successful, zero failures, zero skipped.
- Failed historical candidate Run #683 (`c3270da44b130f0925a2b663b9913ad9a2f14cc6`) is retained: step 204 failed because the loader rejected integral JSON numeric values parsed as floats. The validator was corrected and Run #685 passed; do not cite #683 as a pass.
- GitHub refs/heads/main was re-read and confirmed at merge SHA `dd23ce770df08a0e93403ee6942ab36bd98484af`; PR #158 is closed/merged.

### Known limits
- Tether Recovery uses deterministic manual integration, not a physical rope joint; no persistent campaign, audio, multiplayer or haptics.
- Mine loot tables are data-driven but still use the legacy deterministic coordinate/layer hash; no persisted world seed, loot-table editor or weighted authoring UI.
- No local Godot executable was available; manual GUI, GPU performance and iPhone device QA are not claimed.


## 2026-10-31 Run 63 — Flux Hockey + contextual mine interaction prompts (feature merged / exact-head CI passed)

- Start-of-run reconciliation: Run 62 feature PR #160 and documentation PR #161 were merged; main was `fe52f342038971780f1bbaa712a8ad752bd9562e`. Run 63 began with one open feature PR (#162) and 168 repository branches after full pagination.
- New game: `daily_games/KROLL_Flux_Hockey/`, a real-time air-hockey arcade game with an AI upper paddle, player-controlled lower paddle, three bumper arenas (Dock Ring, Reactor Pair, Split Orbit), first-to-five scoring, mouse/touch drag and A/D or arrow-key movement, R reset and N next arena. Godot 4.3+, procedural vector drawing, no external assets/audio/add-ons/network dependencies.
- Game tests: deterministic rules cover paddle movement, bounds, side-wall and bumper reflection, goal detection, first-to-five lock, arena progression/reset and swept collision protection against high-speed puck tunneling through either paddle. Runtime smoke test covers scene instantiation, touch-drag, arena progression and reset.
- Existing system: `world/SurfaceWorld.gd` now displays contextual interaction guidance. Surface targets distinguish crop plots (E), salvage crates (F) and the mine lift (G). Underground targets compare the nearest stateful cache and mineral vein; cache prompts include MineralCatalog display name and remaining stock, vein prompts identify the mineral, and lift/no-target states explain available controls. Existing transaction rejection messages remain authoritative. World-save schema remains version 1; no migration.
- Production regression: `tests/production_surface_world_interaction_prompt_test.gd` instantiates the real SurfaceWorld, verifies the surface crate/lift, enters the actual mine, checks the gold cache prompt and remaining stock, checks nearest-vein selection, and checks the out-of-range state.
- Exact candidate HEAD `c887e82b92874765a42be298b5e1a384b374bdc8` passed Godot 4.3 exact-head [Run #710](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41159492726): 268/268 total step records successful, zero failures and zero skipped. Flux Hockey import/rules/runtime passed steps 262–264; production interaction prompt passed step 265.
- Historical failed candidate Run #709 targeted superseded HEAD `fef2607d9e2bbc1475843c2e0f449da2db79a21f` and failed only at step 265 because the test expected English `GOLD ORE` while the canonical catalog display name is `金礦`. The test was corrected to derive the expected name from MineralCatalog and assert remaining stock; production prompt logic and save schema were not changed. Run #709 remains historical failure evidence, not a pass.
- Feature PR [#162](https://github.com/qaqp980520-prog/2126-Survival/pull/162) merged as `ceccc7ea1bcb0c46fb72af6a9c1fec29b131f05d`. GitHub compare confirms main is identical to that merge SHA. The only PR #162 branch-behind commit was the docs-only Run 62 closeout; comparison showed it changed only `PROJECT_INDEX.md` and `docs/DEVELOPMENT_ISSUES.md`, with no overlap with feature files.
- No local Godot executable was available. Manual GUI, GPU performance and iPhone hardware QA are not claimed.

### Known limits and next steps
- Interaction target selection is distance-based rather than camera-raycast-based; cache lid animation and a dedicated inventory-full modal are not included.
- Flux Hockey opponent is a simple paddle-following AI; no adaptive difficulty, audio, haptics or saved high scores.
- Next: consider raycast-based interaction targeting and animated cache feedback as separate increments; add adaptive opponent behavior only after play-balance testing; complete manual GUI/GPU/iPhone QA when devices and a local Godot executable are available.


## 2026-10-31 Run 66 — KROLL Molecule Forge + production world-object chunk reload regression

### New playable Godot 4 game
- Added `daily_games/KROLL_Molecule_Forge/`, a 5×5 molecular construction puzzle for Water (H2O), Ammonia (NH3) and Methane (CH4).
- Orthogonally adjacent atoms form single bonds. Valence limits are H=1, O=2, N=3 and C=4. Over-valence placements are rejected without mutating the board.
- Completion requires the exact formula, a single connected graph, the exact target bond count and saturated valence for every atom.
- Keyboard, mouse and touch placement; atom removal, undo, reset and next-level progression. No external assets, audio, add-ons or network dependency.
- Standalone project: open `daily_games/KROLL_Molecule_Forge/project.godot` in Godot 4.3+. Registered in the root Survival Test Hub; root hub smoke test confirms the 11-entry launch list and instantiates the game from the repository root.
- Main files: `main.gd`, `main.tscn`, `rules.gd`, standalone path shim, `README.md`, `tests/rules_test.gd`, `tests/game_smoke_test.gd`.

### Production world-object lifecycle regression
- Added `tests/production_surface_world_interaction_stream_reload_test.gd` against the real `world/SurfaceWorld.tscn` and production streaming director/controller.
- The test selects a real stateful salvage crate through the production camera ray, mutates it, moves the player so the director unloads `surface/chunk_0_0`, and verifies the controller writes the state under the deterministic ID `surface/chunk_0_0/object/Chunk_0_0/SalvageCrate`.
- It verifies the old crate and Area3D proxy are freed, the same chunk reload creates a new crate instance with the saved opened/remaining state, a fresh Area3D proxy is registered on collision layer 2, the camera target cache references the new proxy, and F interaction still succeeds after reload.
- This is an end-to-end regression for the existing SurfaceChunkFactory/MineralChunkController/WorldObjectStateRegistry path. No production runtime logic or world-save schema change was needed.

### Exact GitHub evidence
- Feature PR [#168](https://github.com/qaqp980520-prog/2126-Survival/pull/168) merged as `87a0ca940a1f4269fc8919e9bf1292c5be29de15`.
- Exact feature HEAD `79647c9083b0369e86ba22ce24a23500920fa58d` passed Godot 4.3 [Run #751](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41171780488): 283/283 total workflow step records successful, zero failures, zero skipped. New-game standalone import, rules and runtime smoke tests passed steps 277–279; production SurfaceWorld chunk unload/reload passed step 280.
- Historical superseded candidate runs #746–#750 are not final evidence. The exact-head Run #751 is authoritative.

### Known limits
- The molecule model is a 2D orthogonal single-bond puzzle, not a chemistry simulator; bond order, 3D geometry, charge and reaction kinetics are not modelled.
- The new production reload regression covers the stateful salvage crate in the production surface-grid factory. It does not yet prove every future interactable factory, terrain-edit persistence or asynchronous streaming cancellation.
- No local Godot executable was available; manual GUI, GPU performance and iPhone hardware QA are not claimed.


## Run 66 documentation closeout correction — 2026-10-31

- Run 66 feature PR #168 merged as `87a0ca940a1f4269fc8919e9bf1292c5be29de15`.
- Run 66 documentation PR [#169](https://github.com/qaqp980520-prog/2126-Survival/pull/169) subsequently merged as `3c38d492acc5d5c00d0e9de876336516a1881002`.
- Exact-head Godot 4.3 Run #753 on the documentation candidate passed 283/283 total step records, zero failures/skips: [CI](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41172325019). Earlier Run 66 pending snapshots are historical only.

## 2026-10-31 Run 67 — KROLL Hex Frontier + crop plot binding and production chunk reload

### New playable Godot 4 game

- Added `daily_games/KROLL_Hex_Frontier/`, a turn-based axial radius-two territory strategy game with 19 hexes and three deterministic resource layouts: Dockside, Ridge and Floodplain.
- Player and deterministic KROLL AI expand from opposite headquarters. A faction may perform one claim or upgrade action per turn; claiming a connected neutral hex costs 1 energy, upgrading an owned hex costs 2 and increases its income yield up to 3. Energy caps at 9; first faction to control 10 hexes wins.
- Mouse/touch hex selection, C claim, U upgrade, Enter end turn, R reset and N next map. Legal action cells are highlighted.
- Registered in the root Survival Test Hub. A nested script shim and dynamic rules path allow both standalone project import and root-project launch. No external assets/audio/plugins/network dependency.
- Files: `project.godot`, `main.tscn`, `main.gd`, `rules.gd`, standalone shim, `README.md`, `tests/rules_test.gd`, `tests/game_smoke_test.gd`.

### Crop plot binding hardening

- `systems/CropPlotVisual.gd` adds `can_configure()` to validate a live CropPlotController interface, deterministic stable-ID shape/length, supported crop ID and positive plot index. `configure()` now returns false without binding invalid data.
- `systems/MineralChunkController.gd` preflights every discovered crop plot before catch-up/registration and defensively restores the captured CropRegistry snapshot if a later configure call rejects.
- `tests/mineral_chunk_controller_test.gd` covers unsupported crop IDs, repeated stable-ID separators, non-positive indices, incomplete controller interfaces and atomic chunk rejection with no partial registry/chunk state.

### Production chunk reload regression

- Extended `tests/production_surface_world_interaction_stream_reload_test.gd` using the real SurfaceWorld and streaming director. It plants, waters and advances a real crop plot, unloads the origin chunk, verifies the exact CropRegistry record remains, reloads a new scene instance with the same stable ID, verifies a fresh Area3D interaction proxy and confirms production camera-ray selection plus E interaction after reload.
- Existing salvage-crate state/proxy unload/reload assertions remain in the same test. CropRegistry remains the source of crop state; world-save schema remains version 1, with no migration.

### Exact GitHub evidence

- Feature PR [#170](https://github.com/qaqp980520-prog/2126-Survival/pull/170) merged as `34112f2f478174d78e8f419c5bf825bfa94f86fb`.
- Exact feature HEAD `a3c28e92f7225fc84165ae24e60f2e9ce900898f` passed Godot 4.3 [Run #760](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41173732144): 287/287 total step records successful, zero failures and zero skipped.
- New acceptance steps: root Test Hub smoke #8; mineral chunk controller integration #41; crop plot controller integration #132; crop plot visual interaction #133; production SurfaceWorld crop/salvage chunk reload #280; Hex Frontier input verification/import/rules/runtime #281–284.
- Documentation closeout is tracked separately in PR #171; its exact-head full CI must pass before merge.

### Known limits and next steps

- Hex Frontier AI is deterministic and intentionally lightweight; no campaign save/load, multiplayer, audio or adaptive difficulty.
- Crop binding preflight currently covers CropPlotVisual/MineralChunkController. It does not prove every other formal interactable factory (mineral veins/caches, lift and future KROLL devices) is fully integrated.
- Terrain-edit persistence and asynchronous/cancellable chunk streaming remain unfinished.
- No local Godot executable was available; manual GUI, GPU performance and iPhone device QA are not claimed.


## 2026-10-31 Run 68 — KROLL Thermal Glider + mineral registration preflight and production vein reload

### New playable Godot 4 game

- Added `daily_games/KROLL_Thermal_Glider/`, a 2D flight-and-landing challenge with three deterministic courses: Coastal Thermals, Ridge Crossing and Floodplain Wind.
- Pilot the glider through three ordered survey beacons, use localized thermal columns for lift and assist-battery recharge, manage pitch/boost/airbrake, then land within bounded runway speed, vertical-speed, pitch and altitude constraints.
- Keyboard: W/Up nose up, S/Down nose down, Space boost, Shift airbrake, R restart, N next course. On-screen hold controls support touch.
- Includes deterministic reference-flight coverage proving all three course layouts can reach a safe landing; standalone and root Survival Test Hub import/runtime smoke coverage.
- Files: `project.godot`, `main.tscn`, `main.gd`, `rules.gd`, standalone path shim, README, `tests/rules_test.gd`, `tests/game_smoke_test.gd`.
- No external assets, audio, plugins or network services. Godot 4.3+.

### Mineral registration preflight and atomic chunk binding

- Added pure, non-mutating `MineralMiningNode.can_register()` validation for catalog ID, max/remaining stock, units-per-hit, regeneration interval and timestamp.
- `MineralChunkController.load_chunk()` and direct `MineralChunkLifecycleAdapter.load_chunk()` preflight every vein and deterministic stable ID before registering mineral nodes or binding sibling crop visuals.
- Regression coverage proves malformed mineral data cannot leave a partial CropRegistry record, direct adapter loads do not partially register valid veins when another input is invalid, and rejected roots remain caller-owned.
- Updated `tests/crop_chunk_offline_growth_test.gd` to match the stronger preflight contract: after duplicate mineral stable-ID rejection, the crop record remains unchanged and the detached crop visual remains unbound (null controller, empty stable ID). The previous post-binding refresh expectation was stale.

### Production underground mineral-vein unload/reload regression

- Added `tests/production_surface_world_mineral_vein_chunk_reload_test.gd` using the real SurfaceWorld, production mine lift, UndergroundMineDirector/Factory, MineralChunkController, MineralVeinRegistry and MineralMiningNode.
- Enters the real mine, camera-selects and mines a factory-created vein, streams the origin chunk out, verifies stable-ID stock persists while the old live node/proxy is invalidated, reloads a new node and Area3D proxy with the same ID and remaining stock, then camera-selects and mines the replacement.
- World-save and mineral-registry payload schemas remain version 1; no migration or second state store was introduced.

### Exact GitHub evidence

- Feature PR [#172](https://github.com/qaqp980520-prog/2126-Survival/pull/172) merged as `5afefd60ff11a4170ceac6aae7abe682345ac5bc`.
- Exact feature candidate HEAD: `b1d0b09d6f05dda485f011e8c8dd7b228a237eca`.
- Canonical exact-head Godot 4.3 [Run #770](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41179031212) passed 292/292 workflow step records, zero failures and zero skipped. Run 68-specific steps 285–289 passed: input verification, Thermal Glider import, rules, runtime smoke, and production SurfaceWorld mineral-vein chunk reload.
- Supplemental exact-head mineral-regeneration [Run #40](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41179031107) passed 13/13 step records, zero failures and zero skipped.
- Historical Run #769 failed at step 146 because the old crop offline-growth test expected a detached visual to be bound/refreshed after the new preflight correctly rejected the chunk before binding. The corrected test passed at step 146 on Run #770; no skipped steps remained.
- Feature PR changed 17 files (943 additions, 2 deletions); branch was 25 commits ahead / 3 docs-only commits behind main at merge. GitHub reported mergeable=true.

### Known limits and next steps

- Preflight and production reload coverage now include mineral veins, but do not yet prove every cache, lift and future stateful KROLL interactable proxy lifecycle.
- Terrain-edit persistence across chunk unload/reload remains unfinished.
- Chunk streaming is still synchronous; bounded asynchronous requests, cancellation-safe ownership and deterministic rollback remain future work.
- No local Godot executable was available; manual GUI, GPU performance and iPhone hardware QA are not claimed.


## 2026-10-31 Run 69 — KROLL Gravity Foundry and underground cache/lift lifecycle

### New playable Godot 4 game

- Added `daily_games/KROLL_Gravity_Foundry/`, a self-contained 7×7 turn-based gravity puzzle with three sectors: Reactor Bay, Coolant Vault and Core Archive.
- Move the operator, push a loose energy core, rotate gravity with Q/E, settle the core on a pressure plate and reach the exit. Invalid moves do not consume a turn; the 30-turn limit is enforced.
- Keyboard: WASD/arrow keys move, Q/E rotate gravity, R restart, N advance after a win. Eight on-screen buttons provide equivalent touch actions.
- Includes deterministic winning sequences for all three sectors, rules coverage for movement/pushing/gravity/terminal states, and a runtime smoke test that emits a real touch-button action and completes all three sectors.
- No external assets, plugins, audio or network dependencies; Godot 4.3+.

### Stateful underground mine lift

- Added `systems/UndergroundMineLift.gd` as a stateful world object with validated `layer_index` payload and stable-ID registration.
- UndergroundMineFactory now creates a lift anchor per streamed mine layer; each anchor owns a fresh Area3D interaction proxy and preserves its authored layer index.
- SurfaceWorld resolves `MineLiftAnchor` before generic stateful props so dedicated G/V ascent/descent routing is not swallowed by generic cache interaction. Stale/unloaded proxies are rejected.

### Production cache/lift unload and reload regression

- Added `tests/production_surface_world_underground_cache_lift_reload_test.gd` using the real SurfaceWorld, mine shaft, UndergroundMineDirector/Factory, WorldObjectStateRegistry, salvage cache, lift and camera-ray interaction.
- The test enters the mine, collects from the real gold cache, descends to layer 1, verifies saved cache state and lift layer identity, unloads the origin chunk and invalidates old nodes/proxies, ascends, then confirms fresh cache/lift instances with the same stable IDs and new proxies. It collects the remaining unit and returns to the surface.
- World-save schema remains version 1; no migration or second state store.

### Exact GitHub acceptance and merge

- Feature PR [#175](https://github.com/qaqp980520-prog/2126-Survival/pull/175) merged as `20411a02205f33cdfe5a9aa2340923d861c417c0`.
- Exact feature HEAD `ae0179d95424c1389a4d706a5c7c775cc0794752` passed canonical Godot 4.3 [Run #787](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41193133433): 294/294 main validation steps succeeded, zero failures and zero skipped; job cleanup completed successfully.
- Run #787 acceptance highlights: root project/Test Hub smoke steps 7–8; production SurfaceWorld inventory and hub smoke steps 204–205; production underground mining and mine director steps 210–211; world-seed/cache/lift identity step 260; KROLL Gravity Foundry import/rules/runtime steps 291–293; production cache/lift unload/reload step 294.
- Historical Run #786 passed 293/294 but failed the cache camera-ray fixture because the test player was placed against the south wall. Fix commit `ae0179d95424c1389a4d706a5c7c775cc0794752` moved both initial/reloaded cache approach positions to the open room side (Z -2); Run #787 passed the exact-head test.
- Earlier Run #785 world-seed test failure was corrected by commit `addab83ed7d0952743a24cbdf25844d6152367b0`: cache identity helpers now filter `MineCache_*` and assert lift identity separately across seed restore, rollback, unload/reload and legacy schema-1 fallback.

### Known limits and next steps

- Run 69 verified the origin cache/lift cycle; Run 70 verifies lift anchors across all supported mine layers 0–8, including stable IDs, fresh proxies and schema-1 world save/load roundtrip. Cache loot lifecycle across every generated cache placement and every future stateful KROLL interactable is still not proven.
- Terrain-edit persistence across chunk unload/reload remains unfinished.
- Chunk streaming remains synchronous; bounded asynchronous requests, cancellation-safe ownership and deterministic rollback remain future work.
- No local Godot executable was available; manual GUI, GPU performance and iPhone device QA are not claimed.


## 2026-10-31 Run 70 — KROLL Echo Mapper and all-layer underground lift lifecycle

### New playable Godot 4 game

- Added \`daily_games/KROLL_Echo_Mapper/\`, a top-down sonar exploration puzzle with three missions: Dockside Echo, Coolant Echo and Archive Echo.
- The 9×9 grid hides unvisited cells; sonar uses Manhattan radius 3 and reveals nearby walls/signals for five turns. Each mission has six sonar charges, a 60-turn budget, three signal beacons and an extraction hatch.
- Keyboard: WASD/arrow keys move, Space pings sonar, R restarts and N advances after extraction. Seven on-screen controls provide touch input.
- Added deterministic route tests for all three missions, sonar range/expiry/charge tests, runtime smoke coverage that emits real touch-button signals, and root Survival Test Hub registration.
- Root hub now exposes 15 launch buttons and its smoke test loads Echo Mapper from the root project.
- No external assets, plugins, audio or network dependencies; Godot 4.3+.

### All-layer underground mine lift lifecycle and save/load regression

- Added \`tests/production_surface_world_underground_lift_all_layers_test.gd\` using the real SurfaceWorld, UndergroundMineDirector, UndergroundMineFactory, WorldObjectStateRegistry, camera-ray selection and G/V interaction paths.
- Traverses every supported mine layer 0–8, verifying each MineLiftAnchor layer payload, deterministic stable ID, live Area3D proxy, camera selection, old root/node/proxy release after streaming out, and fresh node/proxy recreation with the same stable ID on return.
- Verifies maximum-depth descent is rejected without moving the player or changing the active chunk window.
- After the full round trip, verifies all nine lift records appear in the world save and survive the production schema-1 \`restore_stream_state\` roundtrip with the correct layer index.
- No world-save schema change; remains version 1.

### Exact GitHub acceptance and merge

- Feature PR [#177](https://github.com/qaqp980520-prog/2126-Survival/pull/177) merged as \`dff16b375c19a01ec8d39257dd3fe793493c2c08\`.
- Exact feature HEAD \`4c3e537a1228bcac55e771e0135d15615e21f3b5\` passed canonical Godot 4.3 [Run #793](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41195456289): 299/299 main validation steps succeeded, zero failures and zero skipped; checkout and container cleanup also succeeded.
- Run #793 acceptance highlights: root SurfaceWorld integration step 204; root Test Hub smoke step 205; mine cache distribution and layer model steps 245–246; Run 69 cache/lift regression step 294; Run 70 input verification, Echo Mapper import/rules/runtime and all-layer lift lifecycle steps 295–299.
- Superseded candidate runs #791 and #792 were cancelled after newer commits, with no failed steps; neither is used as final acceptance evidence.
- PR #177 was merged only after the exact current HEAD completed the full workflow.

### Known limits and next steps

- All nine mine lift anchors are covered, but cache inventory lifecycle is not yet proven for every generated cache placement and every mine layer; other future stateful interactables also need the same contract.
- Terrain-edit persistence across chunk unload/reload remains unfinished.
- Chunk streaming is still synchronous; bounded asynchronous requests, cancellation-safe ownership and deterministic rollback remain future work.
- Echo Mapper is a fixed-map prototype with no campaign save, audio, animation, randomized map generation or controller remapping.
- No local Godot executable was available; manual GUI, GPU performance and iPhone hardware QA are not claimed.


## 2026-10-31 Run 71 — KROLL Knight Circuit and all-layer cache lifecycle

### New playable Godot 4 game

- Added \`daily_games/KROLL_Knight_Circuit/\`, a 5×5 knight's-tour puzzle with three authored 25-square circuits.
- Every move follows the chess knight's L-shaped rule; visited squares cannot be revisited. Includes undo, reset, route-prefix hint, keyboard cursor/Enter, mouse and touch input.
- Deterministic route tests validate bounds, uniqueness and legal consecutive jumps for all three circuits; malformed duplicate-square routes are rejected.
- Registered the game in the root Survival Test Hub with root-project scene-load smoke coverage.
- No external assets, plugins, audio or network dependencies; Godot 4.3+.

### Production underground cache lifecycle regression

- Added \`tests/production_surface_world_underground_cache_all_layers_test.gd\`.
- Exercises the real SurfaceWorld, UndergroundMineDirector, UndergroundMineFactory, MineralChunkController, WorldObjectStateRegistry and inventory transaction contract.
- Covers the deterministic 5×5 sample across mine layers 0–8: exactly 151 cache placements, with per-layer counts \`[18, 17, 16, 17, 17, 16, 17, 17, 16]\`.
- For every cache: load/register, collect one unit, unload and release the original node/proxy, verify stable ID and opened/remaining state, recreate a fresh node/proxy, collect the second unit, unload again, and verify the exhausted state survives schema-1 registry roundtrip.
- Inventory transaction adapter accepted exactly 302 units across the 151 two-unit caches.
- No production runtime or save-schema change; this is lifecycle regression coverage, not a claim that every coordinate in the unbounded procedural world was exhaustively enumerated.

### Exact-head failures, corrections and acceptance

- Superseded Run #801 failed at step 304 because SurfaceWorld initially creates the director-owned origin 3×3 mine window; the direct sample's first overlapping room was (-1,-1). Commit \`107a51677ca9251a1cafbf83faaa1c84301057d4\` moved the real director to a disjoint grid region centered at (100,100) and asserted zero overlap across all 151 sample IDs.
- Run #802 passed all 151 cache lifecycle and schema-roundtrip assertions but exited 1 due an unfreed standalone registry-copy Node and shutdown resource warnings. Commit \`76b19dff907f8f88ecba1354991eed3c4f81e6fa\` explicitly frees the temporary registry and waits two process frames after world teardown.
- Feature PR [#179](https://github.com/qaqp980520-prog/2126-Survival/pull/179) merged as \`ca458c1ace507bbee78bc03c69093077dadfba0d\`.
- Exact final feature HEAD \`76b19dff907f8f88ecba1354991eed3c4f81e6fa\` passed canonical Godot 4.3 [Run #803](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41199269383): 307/307 steps succeeded, zero failures, zero skipped; checkout and container cleanup succeeded.
- Run #803 verified root project import and Test Hub smoke, all pre-existing game and production integration tests, Run 70 Echo Mapper/all-layer lift lifecycle, Knight Circuit import/rules/runtime, and the new 151-cache all-layer lifecycle regression.

### Known limits and next steps

- The cache test covers a deterministic finite 5×5 sample across all nine supported layers, not every possible procedural coordinate.
- Terrain-edit persistence across chunk unload/reload remains unfinished.
- Bounded asynchronous chunk streaming, cancellation-safe ownership and deterministic rollback remain future work; current streaming remains synchronous.
- Other formal stateful interactables still need the same factory/ID/state/proxy lifecycle proof.
- No local Godot executable was available; manual GUI, GPU performance and iPhone hardware QA are not claimed.


## 2026-10-31 Run 72 — KROLL Atmosphere Lab and persistent surface terrain patches

### New playable Godot 4 game

- Added `daily_games/KROLL_Atmosphere_Lab/`, a deterministic weather-station balancing puzzle with three stations: Coastal Front, Desert Thermal and Polar Calm.
- Four instruments (temperature, humidity, pressure and wind) are adjusted in ±5 steps. Each station has a 14-action budget and a deterministic storm-load limit.
- Controls: click/tap the instrument ±5 buttons; keyboard 1–4 selects an instrument, Left/Right adjusts, R resets and N advances after a stable forecast.
- The authored solution routes require 13, 11 and 12 adjustments respectively; target storm loads are 5, 0 and 0, all below the limit of 25.
- Added deterministic rules tests and a runtime smoke test covering adjustment, reset, stable completion and station progression. Registered the game in the root Survival Test Hub.
- No external assets, plugins, audio or network dependencies; Godot 4.3+.
- The storm-load equation is an arcade puzzle model, not a meteorological forecast.

### Production surface terrain patch

- Added `systems/SurfaceTerrainPatch.gd`; every generated surface chunk now owns one 2 m terrain patch.
- Stateful fields: `height_level` (0–2), `surface_type` (soil/rock/metal) and `revision`.
- The patch rebuilds its collision and visual geometry when edited or restored. T-key and touch TERRAIN controls use a dedicated camera-ray target kind and only act on loaded registered patches; terrain editing is disabled underground.
- Stable ID example: `surface/chunk_0_0/object/Chunk_0_0/TerrainPatch`.
- State is collected and restored by the existing WorldObjectStateRegistry; world-save schema remains version 1.

### Production regression coverage

- Added `tests/production_surface_world_terrain_patch_reload_test.gd` using the real SurfaceWorld, chunk controller, camera-ray target resolver and world-object registry.
- Covers invalid-state rejection without mutation, touch editing, collision height/grounding, same-window save/restore, revision-limit rejection, chunk unload, old node/proxy release, stable-ID state retention, fresh node/proxy reconstruction and T-key editing after reload.
- Added 15 collision/state boundary assertions in the final candidate.
- Updated the world-session controller test for 9 salvage crates + 9 terrain patches = 18 stateful objects. The production SurfaceWorld test accounts for 9 crates + 9 terrain patches + 7 underground caches + 1 lift = 26.

### Exact-head failures, corrections and acceptance

- Superseded Run #810 failed step 150 because the world-session test expected nine crates but did not account for the nine new terrain patches. Commit `6631f8f37123d6cd29b49b3db72caf441c78a146` corrected the count to 9 crates + 9 patches.
- Run #811 passed steps 1–304, then failed step 305 because the workflow grep expected `SurfaceTerrainPatchScript`; the actual factory constant is `TerrainPatchScript`. Commit `b6234ecf32d21057d2fb387e7d95c91f58c24aec` corrected the workflow assertion without changing production factory code.
- Commit `6b33d9f5ab249f43666e99f42f9527a54d38741e` added collision-geometry, invalid-state and revision-boundary assertions.
- Feature PR [#181](https://github.com/qaqp980520-prog/2126-Survival/pull/181) merged as `cfedc9ea03f953cf1b508c13bd120e16a762a61d`.
- Exact feature HEAD `6b33d9f5ab249f43666e99f42f9527a54d38741e` passed canonical Godot 4.3 [Run #813](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41206050265): 309/309 primary validation steps succeeded, zero failures and zero skipped; all three post-job cleanup steps also succeeded.
- Main was rechecked and is identical to the feature merge SHA before this documentation-only follow-up.

### Known limits and next steps

- The current feature is one 2 m patch per surface chunk with three height levels and three material states; it is not arbitrary voxel sculpting, multi-tile blending or a smoothed terrain system.
- Chunk streaming remains synchronous. Bounded asynchronous requests, cancellation-safe ownership and deterministic rollback remain future work.
- No local Godot executable was available; manual GUI, GPU performance and iPhone hardware QA are not claimed.
