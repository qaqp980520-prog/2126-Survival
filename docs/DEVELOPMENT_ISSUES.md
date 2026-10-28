# 《2126 Survival》開發問題與待辦清單

這份清單是目前的開發追蹤文件，與 GitHub Issues 功能不同；之後可逐項搬成正式 Issues。

## Run 26 verification note — 2026-10-27

- PR #86 is merged as adaf93ab255bff720d3bc70af1221ea4cc58f727. Exact candidate HEAD 453358cfae88a4f62511dd33bb40a807d04a2f6d passed Godot 4.3 CI Run #406 (40527501347), with 108/108 job steps successful; focused Run #11 (40527501336) passed 13/13.
- KROLL Orbit Warden is a non-combat space-navigation prototype: recover six energy cells, avoid drifting asteroids and use a brief deflection shield. Import/rules/runtime smoke tests are wired into the shared workflow.
- MineralMiningNode.restore_vein now returns actual accepted units and accepts an injectable timestamp for deterministic testing. Tests cover capacity caps, no-op cases and fresh regeneration timing.
- This does not close local GUI/GPU/iPhone QA or the production M1.3 world-controller integration. The fixed-cave mining prototype and crop-persistence integration remain open.

## P0 — 優先處理
- [ ] 在 Godot 4 實際開啟並測試既有背包／存檔原型，記錄錯誤與執行結果。
- [ ] 確認 `SurvivalInventory.gd` 與 `SurvivalWorldBridge.gd` 在 Godot 4 的類別掃描、型別與訊號連接沒有解析錯誤。
- [ ] 為所有正式物品補齊重量定義，避免未登記物品以 0 kg 計算。

## P1 — 系統整合
- [ ] 將採礦產物接入共用背包。
- [ ] 將世界拾取與丟棄接入共用背包，確認重量立即重算。
- [ ] 將負重倍率與跳躍限制接到角色控制器。
- [ ] 與既有 M1.3 存檔流程整合，檢查舊存檔載入相容性。
- [ ] 在 Godot 4 中測試拾取、採礦、丟棄、存檔、讀檔完整流程。

## P2 — 跨平台與品質
- [ ] 為背包、採礦與小遊戲補上 iPhone 觸控操作。
- [ ] 為每個原型建立最小重現測試與已知問題紀錄。
- [ ] 將經過驗證的原始 ZIP 與資產以可核對的方式保存到 GitHub。

## 狀態原則
- 「已提交」只表示檔案已進入 GitHub。
- 「已整合」需確認遊戲專案已引用該模組。
- 「已測試」必須記錄實際使用的 Godot 版本與測試結果。
- 本清單建立時，上述項目尚未宣稱完成。

## Run 19 source audit and verification — 2026-10-27
- GitHub main does not contain scripts/world.gd (contents API returned 404). M1.3 save-validation changes remain patch files, not applied code; do not claim they are integrated until the actual controller source is present and tested.
- PR #70 merged as 66e18a1350bc81c42ffac86eb440c4eba739e4da. Exact-head Godot 4.3 CI Run #317 (40454156074) passed all 78 validation steps with zero failed steps.
- The SurvivalWorldBridge save-adapter test owns and frees its watchdog Timer and covers malformed inventory containers, unknown IDs, fractional/negative/out-of-range counts, invalid game day and unsupported schema. Rejected restore must leave live inventory unchanged; rejected export must leave its input envelope unchanged.
- No local Godot executable, GUI/GPU or iPhone test was available. Production world controller integration remains open.


## Run 20 verification checklist｜2026-10-27

- [x] KROLL Magnetic Salvage import, rules and runtime smoke tests passed exact-head Godot 4.3 CI Run #321 (40465124945).
- [x] Active world save file roundtrip passed in Run #321 step #82 using `prototypes/BackroomsPortalPlayground.tscn`; valid inventory/player position were restored, while unknown item IDs and non-finite positions were rejected without partial live-state mutation.
- [x] PR #72 merged as `fa4f680434fe7e961b1d6266a8a7357b9ef0e77a`.
- [x] Post-merge main-push Run #322 (40465398061) passed on that exact main SHA; all 82 numbered validation steps passed with no failed steps.
- [x] Documentation-only PR #73 merged as `31b8038824caf0f368262d243c2052abc4848e8b` after exact-head Godot 4.3 CI Run #325 (`40465789044`) succeeded with all 82 numbered validation steps.
- Source boundary remains: `scripts/world.gd` is absent. The active playground test improves coverage but does not complete the missing M1.3 production controller; crop persistence patches remain unapplied.
- No local Godot GUI/GPU or iPhone hardware test is claimed.
- Next: integrate the actual production world controller when its source is added to the repository.

## Run 21 final verification — 2026-10-27
- [x] KROLL Neon Breaker import, deterministic rules, and runtime smoke test passed on exact feature HEAD `55b2bd8248af756f3bcbaafa19fa396c37455aec`.
- [x] Atomic world-save replacement test passed: a blocked temporary path preserved the existing save bytes; a complete temporary JSON replaced the old save.
- [x] Backup-only recovery passed when the primary save was missing; existing active-world save/load and invalid-payload non-mutation checks also passed.
- [x] PR #74 merged as `2625b3a0460305ab0759a1e01f9040ed74db36a0` after exact-head Godot 4.3 CI Run #327 (`40471674229`) passed all 85 numbered validation steps with zero failures.
- Main compare confirms `main` is identical to merge commit `2625b3a0460305ab0759a1e01f9040ed74db36a0`. The GitHub connector did not expose a separate main-push run for this commit; exact-head PR CI is the verified evidence.
- The change applies to `prototypes/BackroomsPortalPlayground.gd`; `scripts/world.gd` remains absent, so formal M1.3 production-controller integration and crop persistence are still open.
- No local Godot GUI/GPU or iPhone hardware test is claimed.

## Run 22 baseline reconciliation and candidate work｜2026-10-27

- Start-of-run audit found main advanced from Run 21 closeout SHA `d2a9d8a9fef010af49eedbb5b8e231a7bec96209` to `7ee84c5e61a61bd5d30a9d7ebf391e1a6fe887d7` (21 commits ahead, 0 behind). The actual intervening commit history adds the prototype test hub, surface mining bridge integration and an explicit underground-only vein rule; this supersedes stale Run 21 context, not the code.
- Candidate branch `feature/run22-underground-mine-cargo-crane-2026-10-27` adds `daily_games/KROLL_Command_Grid/` and an underground cave prototype integrated with `MineralChunkController`, `MineralVeinRegistry`, `MineralMiningNode` and `SurvivalWorldBridge`.
- Added `tests/underground_mining_playground_test.gd` for mine-to-inventory transfer, vein snapshot restore, immediate weight change on drop, stable underground chunk ID, and negative checks for surface mining.
- Exact-head Godot 4.3 CI is pending. Keep the candidate unmerged until the new game import/rules/runtime tests, hub smoke test, cave integration test and all prior regressions pass.
- Production M1.3 world controller and crop persistence remain outstanding; this prototype does not mark those tasks complete. No local Godot GUI/GPU/iPhone test is claimed.

- Run 22 CI finding: exact-head Run #354 (40485476724) failed at the existing Survival Test Hub smoke step, not in the new game/cave tests (those steps were skipped). The test's explanatory-label assertion depended on an implicit runtime Label name. Fixed by assigning `StatusLabel` explicitly and asserting that stable name. The updated candidate must pass a fresh exact-head CI before merge.

- Run 22 CI finding: exact-head Run #357 (40485742072) passed the test-hub smoke test and prior regression steps, then failed at step 73 because the workflow expected the obsolete marker `Surface mining integration test passed.` while the existing test correctly prints `Surface underground-vein placement test passed.`. Updated the workflow step name and success-marker check; the latest HEAD still requires a fresh full CI run before merge.

## Run 22 final reconciliation｜2026-10-27

- This final block supersedes the earlier Run 22 candidate/pending notes above.
- PR #76 merged after exact-head CI Run #360 (40486271348) completed successfully. Candidate HEAD: `67f2818e6269ce87f6b36054bae59d38c54abfcd`; functional merge commit: `0c232c540d2d479ab71a22e065384e55aea5ca54`. Documentation PR #77 then merged as `a975e111853b94ae5684911812796bdd9d63d04e`, which is the final main SHA.
- Run #360 passed all 91 numbered validation steps with zero failures. The hub smoke test passed after assigning an explicit `StatusLabel`; the surface underground-vein regression passed after the workflow marker was corrected; KROLL Command Grid import/rules/runtime and the underground mining integration test all passed at steps 88–91.
- Run #354 and #357 are historical failed candidates; their causes and fixes are recorded above. Do not treat those failures as the final result.
- GitHub compare after PR #76 confirmed main equalled `0c232c540d2d479ab71a22e065384e55aea5ca54`; after PR #77, final compare confirms main equals `a975e111853b94ae5684911812796bdd9d63d04e`. PR #77 exact-head Run #362 (40486889706) passed 91/91 steps; final open PR search is empty. No separate main-push workflow run was exposed for the final docs SHA.
- Still outstanding: the formal M1.3 world controller does not exist in the repository; the cave is a fixed prototype, not procedural/asynchronous world streaming. Local GUI, GPU performance and iPhone device tests were not performed because no local Godot executable is available.
- Next engineering priority: introduce a real world-session controller and connect the tested shared inventory/mineral lifecycle to it, then add an end-to-end production-scene test for mining, drop/weight recalculation, save, reload and failure recovery.


## Run 24 final reconciliation｜2026-10-27

- PR #80 merged as `29915be423318a4c3be4a2fbceeb2ec78f1e59b9`; exact candidate HEAD `b6316a60561eb0590021cd086426ca95d8fa80fa`.
- Exact-head canonical Godot 4.3 CI Run #387 (40493037193) passed 98/98 numbered validation steps with zero failures. Focused Run 24 workflow Run #2 (40493037265) also passed root import, Frequency Lock import/rules/runtime, mineral regeneration tests and underground mining compatibility.
- `MineralMiningNode.restore_vein(units)` now resets the regeneration clock whenever it actually increases stock. The deterministic regression confirms old depleted time is not banked after a manual restore; invalid save data remains non-mutating and schema-v1 records remain compatible.
- PR #79 Run 23 was reconciled: exact-head Run #384 (40489504444) passed 94 numbered steps; PR #79 merged as `6cd7a8bf2372972a7f64064f5c6653145141657e`.
- Still outstanding: the production M1.3 world controller is absent; crop-persistence patch files are not integrated; underground mining remains a fixed-cave prototype; streaming is synchronous/factory-driven; local GUI/GPU/iPhone tests remain unavailable.
- Next engineering priority: introduce/locate the actual production world-session controller, connect the tested shared inventory/mining/save lifecycle, then add end-to-end production-scene load/unload/save/restore acceptance tests.


## Run 24 documentation merge SHA reconciliation｜2026-10-27

- Documentation PR #81 merged as `487c9740a9248315fd7f2f3489ef9135b9bc74a6`; at that point, GitHub compare confirmed `main` equalled this commit. Follow-up SHA-correction PR #82 then merged as `ae2a6e443926bc716c582ec0031f2176e83330f2`. These are chronological merge points, not a claim that the earlier SHA remains current after later documentation commits.
- Exact-head Run #389 (40493657236) for PR #81 and Run #391 (40494066682) for PR #82 each passed 98/98 numbered validation steps. No separate main-push workflow run was exposed for these documentation merges.


## Run 25 final reconciliation｜2026-10-27

- Feature PR #84 merged as `4d465dab1b966617c4bf08ab57d344bffb5eb5a9`; exact candidate HEAD `f2b0d5aa6cdad0be26ae3063ccabd8a82332e334`.
- Exact-head Godot 4.3 CI Run #395 (40509153168) completed successfully. All 102 numbered validation steps passed with zero failed steps; new KROLL Vent Runner import/rules/runtime tests passed at steps 99–101, and inventory/mineral catalog compatibility passed at step 102.
- Added `tests/inventory_mineral_catalog_compatibility_test.gd`: verifies every MineralCatalog ID has a matching SurvivalInventory weight, all registered weights are finite/non-negative, and unknown IDs injected through the public counts dictionary are not treated as zero-weight cargo and are rejected by save validation without mutation. This is a regression guard; it does not centralize the duplicate catalogs.
- New game `daily_games/KROLL_Vent_Runner/` is a Godot 4.3+ side-view platformer with five cells, moving hazards, vent boosts, three lives and a 90-second timer; no external assets/add-ons.
- No local Godot GUI/GPU/iPhone test is claimed.
- Remaining: formal M1.3 world controller absent; fixed-cave mining prototype and synchronous/factory-driven streaming remain; crop persistence is not integrated. Next: wire inventory/mining/save lifecycle into a real world-session controller and add end-to-end production-scene tests.


## Run 27 final reconciliation — 2026-10-28

- PR #88 passed exact-head Godot 4.3 CI Run #418 (40612225426) and was merged as `103399080afc19a1a0b7e3141a8252c862d78cee`; validated candidate HEAD `c4e624c2ce838fdf44f140ff10cd90842fe1a12d`. The validate job concluded success. New Pressure Circuit import/rules/runtime steps 106–108 and active-world save roundtrip step 87 passed, along with all existing regression steps.
- Run #415's failure was an expected malformed-JSON fixture producing an engine ERROR line through `JSON.parse_string()`. Replaced this with `JSON.new().parse()` and explicit error handling. Run #416 then confirmed save recovery passed but caught the reversed previous-cell connector direction in Pressure Circuit. Fixed mask generation and added reciprocal-adjacency assertions before Run #418.
- New game `daily_games/KROLL_Pressure_Circuit/`: deterministic 6×6 pipe-routing puzzle, 30-move budget, keyboard/mouse/touch controls, no external assets. Import through `daily_games/KROLL_Pressure_Circuit/project.godot`.
- Save fallback now tries a validated `.bak` when primary JSON or world-envelope validation fails; preserves corrupt primary bytes at `.corrupt` when possible and attempts validated primary repair without discarding the known-good backup on failure.
- PR #88 merge SHA is `103399080afc19a1a0b7e3141a8252c862d78cee`. The separate documentation PR must pass its own exact-head CI before merge; no post-merge main-push workflow result is claimed unless independently observed.
- Limits remain: production M1.3 world controller absent; underground mining is a fixed-cave prototype; async streaming and crop persistence are not integrated. No local Godot executable or local GUI/GPU/iPhone test was available.
- Next: complete the separate docs PR and verify its CI, then integrate inventory/mining/save lifecycle into a production world-session controller with end-to-end load/unload/save/restore tests.


## Run 28 final verified state｜2026-10-28

- PR #90 merged as 1bcc210d0ceb16fc6cbd04ebbd95a506c9325761 after exact-head Godot 4.3 Run #40636164856 succeeded. All 115 job steps completed successfully, with zero failed steps. New Microgrid Operator import/rules/runtime steps 109–111 and the world inventory mining lifecycle integration step 112 passed.
- New game daily_games/KROLL_Microgrid_Operator/: deterministic eight-cycle power-management game; balances power, fuel, heat and stability; keyboard/mouse/touch input; no external assets/add-ons.
- New tests/world_inventory_mining_lifecycle_test.gd joins previously separate paths: actual MineralMiningNode mining → SurvivalWorldBridge → inventory weight → real active-world save/load → restored inventory and player position → post-load drop/weight recalculation. This does not yet persist vein remaining_units/chunk state.
- Current main at feature closeout: 1bcc210d0ceb16fc6cbd04ebbd95a506c9325761; documentation PR is separate and must pass exact-head CI.
- Remaining: formal M1.3 production world controller absent; crop persistence and vein/chunk stock persistence are not integrated into active world save; no local GUI/GPU/iPhone hardware test is claimed.
- Next: finish documentation PR, then build production world-session integration and add vein/chunk save/restore to the end-to-end acceptance suite.


## Run 29 final verified state — 2026-10-28

- **Supersedes the Run 28 statement that vein stock was not integrated into the active-world save.** PR #92 is now merged at `23b531319a5bed8c215c4292ad2dc30e9e98fcfa`; main is at that commit, and the last open-PR search was empty.
- `BackroomsPortalPlayground` now serializes `MineralVeinRegistry` as `mineral_veins`, validates the registry payload before applying inventory/player state, restores live vein stock, and preserves unloaded stable-ID records across a fresh world instance. Old schema-v2 saves without the field remain compatible.
- Godot 4.3 exact merge-candidate Run #433: https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40649646947 — 118/118 steps succeeded. The expanded world inventory/mining/vein test, mineral registry JSON round-trip test and Memory Matrix import/rules/runtime checks all passed.
- Earlier issues were fixed before merge: Run #426's untyped test path, Run #430's registry schema type mismatch after JSON decode, and Run #432's outdated workflow success marker. Their causes and commits are recorded in the Run 29 Notion daily log and asset pages.
- New game `daily_games/KROLL_Memory_Matrix/` is included in main. No external assets or add-ons; import with Godot 4.3+.
- Remaining engineering work: formal `scripts/world.gd` production controller is still absent; crop persistence and full generated chunk scene state remain unintegrated. Vein records now persist, but not complete chunk scenes. No local GUI/GPU/iPhone hardware test is claimed.
- Next: integrate the registry with the production world-session controller and actual chunk load/unload lifecycle, then add crop and chunk-state save/reload tests.


## Run 30 closeout — 2026-10-28

- PR #94 merged as `cf102401dd1bb7536a286f09f5f34e89613bd662` after exact-head Godot 4.3 Run #441 (40651700256) succeeded on candidate `b717e7bd2b1d392d9823b3e584fb93ac68fa8736`.
- Run #441 completed all 119 primary validation steps successfully. New steps: 116 Signal Sleuth import, 117 rules tests, 118 runtime smoke test, 119 mineral registry transactionality regression. Post-job cleanup steps also succeeded.
- Signal Sleuth adds a deterministic 5×5 nonogram puzzle with three patterns, generated row/column clues, 60-change budget, keyboard/mouse/touch, restart and next-puzzle controls.
- Registry regression covers atomic rejection of valid-then-invalid multi-record restore, side-effect-free validation, successful valid restore, unknown mineral IDs in unloaded stable-ID snapshots, and fractional schema rejection.
- Current documentation closeout is in PR branch `docs/run30-signal-sleuth-registry-atomicity-closeout-2026-10-28`, based on feature merge `cf102401dd1bb7536a286f09f5f34e89613bd662`. Do not merge the docs PR until its exact-head CI passes.
- Remaining P0/P1 work: production M1.3 world-session controller; crop persistence; full generated chunk scene state; local GUI/GPU/iPhone QA. No local Godot executable was available for this run.

## Run 31 — Shadow Trace + crop registry persistence (2026-10-28)

- PR #96 merged as `9e134d317f98d81a2b5061f81abf80ba6e92dd86`; exact validated head `59338ab48cc1a1b860200df029d6bbec81fbc470`.
- Exact-head Godot 4.3 Run #445 (40668945834) passed all 127 workflow steps with zero failures. Shadow Trace import/rules/runtime steps 121–123 and crop registry integration step 124 passed. Root project import, existing Signal Sleuth tests, mineral registry atomicity and the world mining/vein persistence integration also passed.
- New `daily_games/KROLL_Shadow_Trace/`: 8×8 deterministic turn-based stealth prototype, three intel caches, two patrol routes, line-of-sight blocked by walls, 40-turn limit and three-alert failure; keyboard/mouse/touch controls, no external assets/add-ons.
- Added `systems/CropRegistry.gd` and integrated `crop_registry_state` into the active Backrooms playground save envelope. Payloads are validated in full before mutation; legacy saves missing the field preserve the current registry snapshot. `tests/crop_registry_persistence_test.gd` covers real save/load, fresh-world restore, invalid update and restore atomicity, detached snapshots, schema validation and legacy compatibility.
- **Scope boundary:** this is a data-only crop state registry, not the full crop gameplay system. Planting, visuals, growth simulation, watering and harvesting remain unimplemented. The production `scripts/world.gd` controller is still absent; complete generated chunk scene persistence remains outstanding.
- No local Godot executable was available; GUI/GPU/iPhone device tests are not claimed.
- Documentation closeout is on branch `docs/run31-shadow-trace-crop-registry-closeout-2026-10-28`; do not merge until its own exact-head Godot 4.3 CI succeeds.
- Next: finish docs closeout, then connect crop lifecycle and chunk persistence to the production world-session controller and add production-scene load/unload/save/reload acceptance tests.

## Run 32 closeout — 2026-10-28

- PR #98 merged as f58ccdadc521aed46dc6c5b6c03dc3fdd5528070 after exact-head Godot 4.3 Run #454 (40678627167) succeeded on candidate e56efc36819cdc29ca42339060ff11409fd4601d.
- Run #454 completed 128 numbered validation steps plus setup/cleanup (131/131 total steps successful, zero failures/skips). Greenhouse Keeper import/rules/runtime steps 125–127 and CropRegistry lifecycle step 128 passed. Crop registry persistence step 124 and all existing regression tests passed.
- Added daily_games/KROLL_Greenhouse_Keeper/: deterministic three-plot crop-management game, limited watering, daily moisture drain, growth stages, harvest target, keyboard/mouse/touch controls, no external assets/add-ons.
- systems/CropRegistry.gd now exposes caller-driven water_crop, advance_growth and harvest_crop operations while retaining schema 1. Candidate records are validated before mutation; invalid elapsed times and timestamp rollback are rejected; dry soil pauses growth; harvest increments harvest_count and resets the cycle.
- tests/crop_registry_lifecycle_test.gd covers watering clamp/no-op, invalid elapsed, multi-stage growth, dry pause, maturity, harvest receipt/reset/count, timestamp rollback and schema-1 round-trip. Existing crop_registry_persistence_test.gd remains green.
- Failure correction: Run #452 failed at root import because CropRegistry.gd could not be preloaded. The new lifecycle block had spaces in a tab-indented script; commit e56efc3 normalized the block to tabs. Run #453 was cancelled at step 32 after steps 1–31 succeeded; only Run #454 is the full exact-head pass.
- No local Godot executable; no GUI/GPU/iPhone hardware QA claimed.
- Remaining P0/P1 work: formal production scripts/world.gd controller; scene-based planting/watering/harvest; connect CropRegistry lifecycle to world-session and chunk load/unload; persist complete generated chunk scene state; asynchronous streaming and device QA.
- Next: production world-session integration and crop/chunk unload/reload/save-failure end-to-end tests.


## Run 33 closeout — 2026-10-28

- PR #100 merged as `3b010096c6ee0c73fe0039a9a0ba87398aaf2bfc` after exact-head Godot 4.3 CI Run #459 (40693583329) passed on candidate `8f7af262b6d4c4e7da64661859088bc8d7f67a32`.
- Run #459 completed all 132 validation steps with zero failures/skips. Deep Current Angler import/rules/runtime passed at steps 129–131; CropPlotController world integration passed at step 132. Existing regressions through step 128 also passed.
- Added `systems/CropPlotController.gd` and bound it into `prototypes/BackroomsPortalPlayground.gd`; the schema-1 CropRegistry remains the source of truth. Batch growth snapshots and restores the whole registry if any crop tick fails.
- Added `tests/crop_plot_controller_integration_test.gd` for planting, atomic rollback, batch growth, active-world save/reload, watering, maturity and harvest.
- Run #458 targeted the pre-fix head and was cancelled; only Run #459 is the exact-head full pass. The test-only line-snap setup was corrected in commit `8f7af26`.
- No local Godot executable; GUI/GPU/iPhone hardware tests are not claimed.
- Remaining P1 work: visible crop plots and proximity interaction; formal `scripts/world.gd` world-session controller; persist complete generated chunk state across unload/reload; asynchronous streaming.
- Next: create a scene-backed crop interaction layer and chunk lifecycle save/restore tests, without claiming the production controller exists until implemented.


## Current verified status — Runs 34–35 (2026-10-28)

The older checklist and historical run notes above describe their respective snapshots. Use this section as the current verified state:

- [x] Scene-backed crop plots are integrated into the active Backrooms Portal Playground with stable IDs, proximity interaction, surface-only guard and save/load visual refresh. PR #102 merged as `b6fcdc039ea78cff478ef7f2415a3a2d6d410198`; exact-head Godot 4.3 Run #479 passed 139/139 total steps, zero failures/skips.
- [x] Touch-safe crop interaction is available through `HUD/CropInteractButton`, while keyboard E remains supported. The button is disabled in Backrooms and re-enabled on the surface.
- [x] KROLL Cargo Crane is integrated into the shared Godot validation workflow. PR #103 merged as `8d74ef8b3ae96be94fa930d48ee69402070e73d1`; exact-head Run #481 passed 142/142 total steps, zero failures/skips. New game import/rules/runtime steps 137–139 and crop visual interaction step 133 passed.
- [ ] Build the formal production `scripts/world.gd` world-session controller and migrate world-facing systems behind it.
- [ ] Persist full generated chunk scene state across unload/reload, including crop/mineral state and visual reconstruction.
- [ ] Integrate asynchronous chunk streaming with save/restore and failure recovery.
- [ ] Run interactive GUI, GPU performance and iPhone hardware acceptance tests; no local Godot executable/device was available during Runs 34–35, so those tests are not claimed.
- Run 34 Notion candidate status saying PR #102 was open / Run #479 pending is historical and superseded by the final pass and merge SHA above.
- Run 35 PR #103 is merged as `8d74ef8b3ae96be94fa930d48ee69402070e73d1`. Documentation closeout PR #104 is also merged as `df3ba169aeab8440102386706bcc8e0117bc26b8` after exact-head Run #483 passed 142/142 total steps; final main matched that SHA and the final open-PR search was empty.

## Run 35 documentation CI final correction — 2026-10-28

- Exact-head docs CI Run #483 (40718477267) passed all 142/142 total steps, zero failures/skips. The docs candidate was `0aa7c0e10c2cd295af38f7a729849934be33f36c`; PR #104 merged as `df3ba169aeab8440102386706bcc8e0117bc26b8`.
- Final main compared identical to `df3ba169aeab8440102386706bcc8e0117bc26b8`; open-PR search returned empty. Earlier pending wording is historical only.
- No separate post-merge main-push workflow or local GUI/GPU/iPhone pass is claimed.

## Current verified status — Run 36 (2026-10-29)

- [x] KROLL Prism Relay M0.1 added at `daily_games/KROLL_Prism_Relay/`. Deterministic 7×7 mirror-routing puzzle, three layouts, 18-rotation budget, visible beam trace, mouse/touch controls and reset/next. Import/rules/runtime validation passed in exact-head Godot 4.3 Run #491, steps 140–142.
- [x] Crop plots are now part of generated Surface Chunk Streaming Playground chunks. `MineralChunkController` assigns stable IDs from chunk ID + local node path and reconstructs plot visuals from the authoritative CropRegistry after unload/reload. E interacts with the nearest plot within 3.25 units.
- [x] Stream-save schema 1 supports an optional crop registry payload. Invalid crop payloads are rejected before mineral/player/stream mutation; target-stream failure rolls back crop and mineral snapshots; legacy saves without the crop key remain compatible.
- [x] PR #106 merged as `915ae79a1f24ad67572d06854cf7248de8a6db20`; exact candidate HEAD `4628afcb82e7d6979fdefa65d04310332088b35d`. Run #491 passed 142/142 total steps (6 setup, 133 validation, 3 cleanup), zero failures/skips. Step 75 streaming crop integration passed.
- [ ] Build formal production `scripts/world.gd` and migrate world-facing systems behind it.
- [ ] Persist complete generated chunk scene state (all world objects/terrain/interactive state), not just mineral and crop registry data.
- [ ] Integrate asynchronous chunk streaming with save/restore and failure recovery.
- [ ] Run interactive GUI, GPU performance and iPhone hardware acceptance tests; no local Godot executable/device was available, so these are not claimed.
- No separate post-merge main-push workflow is claimed; CI evidence applies to the exact PR candidate SHA.
