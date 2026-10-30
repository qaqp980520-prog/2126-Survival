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

## Run 37 — 2026-10-29: streamed crop offline growth and Skyline Courier

- [x] Add KROLL Skyline Courier M0.1 with deterministic three-lane routes, hazard collisions, packet collection, timer/lives, keyboard and touch controls.
- [x] Add bounded `CropRegistry.advance_to_time()` and atomic `CropPlotController.advance_crops_to_time()`; catch up crop records on streamed chunk reload without changing schema 1.
- [x] If mineral registration rejects a chunk after crop catch-up, restore the prior crop snapshot and refresh detached crop visuals.
- [x] Add offline growth, clock rollback, failed registration and visual rollback regression tests.
- [x] PR #109 merged as `7b9c589985a9af87a9ba3a3f7b98dc1cc60e8041`; exact candidate `cefa1b0b4255752755c2ff4c289fe67ed38973bb`. Godot 4.3 CI Run #502 passed 149/149 job steps, zero failures/skips.
- [ ] Build formal production `scripts/world.gd` and migrate world-facing systems behind it.
- [ ] Persist complete generated chunk scene state (terrain, all interactive objects and world mutations), not only crop/mineral registry records.
- [ ] Integrate asynchronous chunk streaming with save/restore and failure recovery.
- [ ] Run interactive GUI, GPU performance and iPhone hardware acceptance tests; no local Godot executable/device was available, so these are not claimed.
- No separate post-merge main-push workflow is claimed; the test evidence applies to exact PR candidate HEAD.


## Run 38 — final status (2026-10-29)

- [x] PR #111 merged as `739ef96a5c99dbfc163fadfd25ca4025fe87e4e0`; exact candidate `48589112a1daf7f15830d75b4e67b20dcb23ce97` passed Godot 4.3 CI [Run #513](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40801522315).
- [x] Add KROLL Echo Survey and the first reusable `scripts/world.gd` WorldSessionController base; integrate schema-1 inventory payload validation and failure rollback.
- [ ] Finish production chunk scene state persistence for all generated terrain and interactable objects.
- [ ] Integrate asynchronous chunk streaming and recovery with the formal world-session layer.
- [ ] Run manual GUI/GPU/iPhone hardware acceptance tests; no local Godot executable/device was available.

## Run 39 — final status (2026-10-29)

- [x] PR #112 merged as `213c795382682b3d8a51c27be0a2d4da1ce2f671`; exact candidate `873ec47bb22ba93becc5f8b2a3b90cfb4b0e6fd2` passed Godot 4.3 CI [Run #40810244136](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40810244136), 157/157 reported steps, no failures/skips.
- [x] Add KROLL Tidal Lock with import/rules/runtime tests.
- [x] Add WorldObjectStateRegistry with stable IDs, chunk ownership, bounded primitive properties, 64-property per-object cap, atomic save validation and schema-1 optional integration.
- [x] Extend failure-injection tests to assert object-state rollback when target chunk creation fails; preserve legacy saves without `world_objects`.
- [ ] Wire registry records to every real interactable object's spawn/apply-state path; current registry is persistent storage and query API, not automatic scene-node binding.
- [ ] Finish complete generated terrain/object persistence and asynchronous chunk streaming.
- [ ] Run manual GUI/GPU/iPhone hardware acceptance tests; no local Godot executable/device was available.
- No separate post-merge main-push workflow is claimed; CI evidence applies to the exact PR candidate SHA.

## Run 40 final verified status — 2026-10-29

- [x] PR #114 merged as `d3b2192c55a9808e85d80f111eb24e89c3894571`; exact candidate `5915d46016d53f6ea58a0e32e6e7a7bfb73c1730` passed Godot 4.3 CI Run #532 (40822891951), 157 numbered workflow steps plus three post/cleanup steps (160 step entries total), zero failures.
- [x] KROLL Rotor Rescue import/rules/runtime passed at steps 155–157. The smoke test failure from Run #531 was corrected by assigning stable names to controls and asserting those names.
- [x] WorldObjectStatefulProp lifecycle is integrated with MineralChunkController and WorldSessionController; save/unload capture and load/restore apply stable-ID state transactionally. Failure injection confirms rollback.
- [x] World save envelope remains schema 1 and `world_objects` is optional for legacy saves.
- [ ] Apply saved state to every production interactable object factory, not only the current Surface Chunk Streaming Playground salvage crate.
- [ ] Persist all generated terrain and object mutations across unload/reload, including changes not represented by current registry payloads.
- [ ] Integrate asynchronous chunk streaming with world-session save/restore and failure recovery.
- [ ] Run manual GUI/GPU/iPhone hardware acceptance tests; no local Godot executable/device was available, so these are not claimed.
- Documentation closeout is tracked in PR [#115](https://github.com/qaqp980520-prog/2126-Survival/pull/115); its final merge SHA and exact-head CI result are recorded in the Run 40 Notion closeout.

## Run 41 — 2026-10-29: Thermal Sort + aggregate world-object state budget

- [x] Add KROLL Thermal Sort M0.1 with deterministic 12-canister shifts, three layouts, explicit Celsius thresholds, two-error budget, keyboard/touch controls, rules tests and scene runtime smoke test.
- [x] Add import/rules/runtime steps to `.github/workflows/godot-validation.yml`.
- [x] Bound WorldObjectStateRegistry aggregate payload at 100,000 total properties and 1,000,000 total string-value characters, preserving per-object 64-property and per-string 256-character caps.
- [x] Add aggregate-limit regression coverage for rejected writes/restores, replacement/deletion budget release and non-mutation after failed restore.
- [x] Feature PR #116 merged as `093e45116b56da7be33b04d5a536d967b13214a9`. Exact candidate `981eda60d12d7253efa15934e283de4f07b8a769` passed Godot 4.3 CI Run #539: 160 numbered validation steps + three post/cleanup entries (163 total step entries), zero failures.
- [ ] Integrate saved state into every production interactable factory and define per-object semantic migrations.
- [ ] Persist all generated terrain/object mutations and integrate asynchronous chunk streaming with save/restore and failure recovery.
- [ ] Run manual GUI/GPU/iPhone hardware acceptance tests; no local Godot executable/device was available, so these are not claimed.
- Compatibility boundary: schema remains 1, but legacy object-registry payloads exceeding the new aggregate caps are intentionally rejected.


## Run 42 — 2026-10-29: Span Engineer and salvage inventory transaction

- [x] Add KROLL Span Engineer M0.1 with deterministic five-span bridge design, 12-unit material budget, three anchor layouts, rules tests and scene runtime smoke test.
- [x] Fix active Surface Chunk Streaming Playground crate interaction: inventory must accept one iron ore before loot is consumed; inventory rejection leaves the crate unchanged.
- [x] Add salvage crate end-to-end regression test for item count, weight, crate state, save/restore and max-count rejection.
- [x] Add the new game and salvage integration checks to the Godot 4.3 workflow.
- [x] Feature PR #118 merged as `fcadbb4b6afd2a29af58d99d5149075c6a018def`. Exact candidate `92731d84de28ab7adce6707c26a000bad7d30f2f` passed [Run #40855286483](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40855286483): 164 numbered validation steps + three post/cleanup entries (167 total), zero failures.
- [ ] Extend semantic state restore to every production interactable factory, not only the current Surface Chunk Streaming Playground.
- [ ] Add stable per-object loot identity and data migration before introducing multiple salvage loot types.
- [ ] Persist all generated terrain/object mutations and integrate asynchronous chunk streaming with save/restore and failure recovery.
- [ ] Run manual GUI/GPU/iPhone hardware acceptance tests; no local Godot executable/device was available, so these are not claimed.
- Compatibility: no world-save schema change; schema 1 remains. Current salvage crate reward is one `iron_ore` per successful interaction, and full inventory cannot consume crate loot.


## Run 43 — 2026-10-29: Biome Balance + persisted salvage loot identity

- [x] Add KROLL Biome Balance M0.1 with deterministic seeds 17/29/41, six-turn ecosystem management, two interventions per turn, bounded resources, keyboard/mouse/touch controls, rules tests and scene smoke test.
- [x] Extend the canonical Godot 4.3 workflow with game import, rules/runtime tests and salvage loot identity regression.
- [x] Persist MineralCatalog-backed `loot_item_id` on WorldObjectStatefulProp and preserve schema-1 legacy state containing only `opened` and `loot_remaining`.
- [x] Assign deterministic salvage loot by chunk coordinate; origin chunk remains `iron_ore`, adjacent chunk (1,0) is `copper_ore`; HUD displays the catalog mineral name.
- [x] Verify successful inventory grant, full-inventory rejection without crate mutation, invalid ID rejection, registry save/restore and legacy-state compatibility.
- [x] PR [#120](https://github.com/qaqp980520-prog/2126-Survival/pull/120) merged as `3530f5145f98895d58e914b392b57ff0062cd9e7`. Exact candidate `bd5aebb35f8c23fc190d52ea75ae7281d76718b7` passed Godot 4.3 CI [Run #554](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40862702927): 168 numbered workflow steps plus three post/cleanup entries (171 total), zero failures.
- [ ] Expand semantic state restoration to every production interactable object factory.
- [ ] Persist complete generated terrain and all world-object mutations across unload/reload.
- [ ] Integrate asynchronous chunk streaming with world-session save/restore and failure recovery.
- [ ] Run manual GUI/GPU/iPhone hardware acceptance tests; no local Godot executable/device was available, so these are not claimed.
- Compatibility boundary: save envelope remains schema 1. Old two-field crate state is accepted and preserves the deterministic factory identity. The previous Run 42 note saying crates only grant iron ore is historical and superseded by Run 43's coordinate-based deterministic loot IDs; this is not a weighted/random loot table yet.


## Run 44 — 2026-10-29: Frequency Tuner + salvage crate state invariants

- [x] Add KROLL Frequency Tuner M0.1 with three deterministic signal dials, modulo-10 coupled outputs, 14-move budget, mouse/touch/keyboard controls, rules tests and scene runtime smoke test.
- [x] Add exact-head Godot 4.3 workflow checks for Frequency Tuner import, rules and runtime.
- [x] Exhaustively test all 1,000 dial combinations for unique output mapping; test the real dial-button signal in the scene smoke test.
- [x] Tighten `WorldObjectStatefulProp` state validation: closed crates must be full; consumed loot requires `opened=true`; invalid state is rejected without mutating the live prop.
- [x] Preserve world-save schema 1 and valid legacy two-field crate state.
- [x] Feature PR [#122](https://github.com/qaqp980520-prog/2126-Survival/pull/122) merged as `bb8265977ce4d885680c5861943fb162766b354f`. Exact candidate `8334fd2d3b6fc0ed97ec2159bce44cb80698c126` passed [Godot 4.3 CI Run #562](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40879170090): 174/174 steps, zero failures, zero skipped steps. Frequency Tuner steps 168–170 and salvage loot identity step 171 passed.
- [ ] Extend semantic state restoration to all production interactable object factories.
- [ ] Persist complete generated terrain and world-object mutations across unload/reload.
- [ ] Integrate asynchronous chunk streaming with world-session save/restore and failure recovery.
- [ ] Run manual GUI/GPU/iPhone hardware acceptance tests; no local Godot executable/device was available, so these are not claimed.

## Run 45 — 2026-10-29 — Rail Yard and salvage compensation

**Merged feature:** PR [#124](https://github.com/qaqp980520-prog/2126-Survival/pull/124), merge commit `7c95896145c735fb6a0f1f4d8cb41165c3216988`; exact tested head `c02aa304b3eeeed80bf2b97cfcfe97d365581a5c`.

- Added `daily_games/KROLL_Rail_Yard/`: deterministic shunting puzzle; five cars, FIFO input, capacity-3 LIFO siding, A–E output, three layouts and 12-move budget.
- Added tests for invalid/duplicate car IDs, illegal moves, siding capacity, move-limit terminal behavior, three complete solutions, actual scene button signals, restart and seed wraparound.
- Hardened `WorldObjectStatefulProp.interact_with_inventory()`: a rejected inventory grant now attempts compensation from the pre-call snapshot; compensation failure is surfaced as `inventory_rollback_failed`.
- [Targeted CI Run #40897295646](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40897295646): all 12 job steps passed, including root import, rollback regression, Rail Yard import, rules and runtime smoke.
- [Full Godot 4.3 CI Run #40897295631](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40897295631): all 171 validation steps and setup/post/cleanup steps passed, zero failures or skips.
- A previous smoke test had an incorrect expectation after seed 3; corrected in commit `c02aa304b3eeeed80bf2b97cfcfe97d365581a5c` and revalidated on the exact final candidate.
- Save schema remains version 1. If an external inventory adapter mutates and then its compensation method also fails, the code reports the failure; it cannot guarantee external rollback in that case.
- Follow-up: bind stable object-state persistence into every production interactable factory, persist full terrain and object deltas, integrate async chunk streaming, and conduct device QA.


## Run 46 — 2026-10-30 — Beat Lab and salvage reentrancy guard

**Feature PR:** [#126](https://github.com/qaqp980520-prog/2126-Survival/pull/126), merged as \`f9599478512416ffc64192550518989f620ca7e0\`. Exact tested candidate \`75357e463780d3ec1502aef5210ebb0af5a0afdc\`.

- Added \`daily_games/KROLL_Beat_Lab/\`: deterministic 4-lane visual rhythm game, 100 BPM, 3 charts × 24 notes, keyboard/mouse/touch, rules and runtime smoke tests. Godot 4.3+, no external assets/audio/plugins.
- Added a reentrancy guard to \`WorldObjectStatefulProp.interact_with_inventory()\`; nested inventory interactions return \`interaction_in_progress\`, and the legacy \`interact()\` path is blocked during an active inventory transaction.
- Added \`tests/salvage_crate_reentrancy_test.gd\`, using a bridge that attempts nested interactions during \`collect_world_item()\`; verifies no duplicate grant and that later independent transactions still work.
- Reconciled canonical CI coverage: the pre-Run-46 main workflow did not contain explicit Run 45 Rail Yard/rollback steps. Added explicit input checks, Rail Yard import/rules/runtime, salvage inventory rollback, Beat Lab import/rules/runtime, and reentrancy regression steps.
- Canonical Godot 4.3 CI [Run #574](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40970079987): 183/183 steps successful, zero failed or skipped.
- Focused Run 45 validation [Run #6](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40970079995): 12/12 steps successful.
- World save schema remains version 1. Reentrancy guard is synchronous and local to the prop; it is not a server-authoritative multiplayer transaction lock.
- No local Godot executable was available; manual GUI/GPU/iPhone hardware testing is not claimed.
- Remaining: production-wide prop lifecycle binding, full terrain/object delta persistence, asynchronous chunk streaming/recovery and device QA.

## Run 47 — 2026-10-30 — Pipe Relay and state mutation guard

**Feature PR:** [#128](https://github.com/qaqp980520-prog/2126-Survival/pull/128), merged as `be912f75aa0580681e5e337ede5383f4f963b888`. Exact tested candidate `f8cca4b91c99dfaa910a9e635bd3c61c63e35cb7`.

- Added `daily_games/KROLL_Pipe_Relay/`: 4×4 deterministic pipe-routing puzzle, 3 layouts, 10 rotations, mouse/touch tile rotation and keyboard shortcuts. No external assets, plugins or audio. Godot 4.3+.
- Rules tests cover all three solutions, all-segment connectivity, malformed/duplicate tile coordinates, invalid indices, move-budget enforcement and terminal lock. Runtime smoke test verifies real button signals, restart, layout advance and visible status.
- Exact-head canonical Godot 4.3 CI [Run #578](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/40984092639): 185 numbered workflow steps plus 3 post/cleanup steps (188 total job step entries), all successful; zero failures/skips.
- Independent exhaustive enumeration: Docking Spur has 1 valid solution among 32 distinct orientations; Cargo Descent and Crosswind Relay each have 1 among 1,024. This is supplementary algorithm simulation, not engine CI.
- Hardened `WorldObjectStatefulProp`: block `set_loot_item()` and `apply_world_object_state()` during inventory transactions; commit validated internal state directly. New `tests/salvage_crate_state_mutation_guard_test.gd` verifies reentrant state mutation is rejected and reward identity/count remain consistent.
- Added Pipe Relay and state mutation guard steps to canonical workflow.
- Save schema remains version 1. Guard covers supported API methods in a synchronous single-node transaction; direct external assignment to the script's public state fields remains possible and should be addressed with private backing fields if stronger encapsulation is needed.
- No local Godot executable; no manual GUI/GPU/iPhone hardware QA is claimed.
- Remaining: private backing fields/read-only accessors review; production-wide stateful prop factory binding; full terrain/object delta persistence; asynchronous chunk streaming/recovery; device QA.


## Run 48 — 2026-10-30: magnetic maze and read-only salvage state

### Resolved in PR #130

- Added KROLL Magnetic Maze M0.1 with three deterministic layouts, PUSH/PULL magnetic pulses, wall-blocked rays, keyboard/touch UI, rules tests, and real-scene smoke coverage.
- Encapsulated SalvageCrate state behind getter-only compatibility properties and private-convention backing fields.
- Migrated the mineral chunk corruption fixture away from public property writes; it now mutates backing fields only to simulate an invalid internal state and verify registry capture remains atomic.
- Added canonical workflow steps for game import, rules, runtime smoke, and read-only accessor regression.
- Kept world-save schema at version 1.

### Validation

- Functional PR #130 merged as \`024dca1f82f550cf5676d3b3a5795287346ab93c\`.
- Exact candidate \`7e16dde771b5be31f6d41689d86ceba6601c7cf8\` passed canonical Godot 4.3 Run #584: 193/193 steps, zero failures, zero skipped.
- Targeted Run #10 passed 12/12 steps.
- Three authored puzzle layouts were independently checked with BFS; shortest input-action counts were 3, 20, and 22.
- No local Godot executable was available; GUI/GPU/iPhone device QA remains unverified.

### Remaining limitations / next work

1. GDScript underscore-prefixed backing fields are conventionally private, not a hard language access boundary. If a stronger boundary is required, move mutable state into a dedicated state object and expose only validated methods.
2. Migrate all formal interactable factories to stable IDs and validated state restore.
3. Persist terrain and object deltas across chunk unload/reload and save/load.
4. Integrate asynchronous chunk streaming with transactional rollback/recovery.
5. Run manual GUI, GPU performance, and iPhone device QA when a suitable device and local Godot runtime are available.


## Run 49 — 2026-10-30 — Drone Relay and real world-object chunk lifecycle

- [x] Add `daily_games/KROLL_Drone_Relay/`: deterministic 6×6 simultaneous multi-agent routing puzzle, three layouts, keyboard/touch UI, rules and scene smoke tests.
- [x] Verify authored routes independently: 5, 7, and 6 ticks. This is supplementary rules-model analysis, not engine CI.
- [x] Add `tests/world_object_chunk_lifecycle_test.gd` using the actual SurfaceChunkStreamingPlayground SalvageCrate and SurvivalWorldBridge. Verify real grant, stable-ID save, chunk unload, regenerated node restoration, inventory non-duplication, full world+inventory restore, and empty-crate rejection.
- [x] Extend canonical workflow with Drone Relay import/rules/runtime and chunk lifecycle regression.
- [x] Correct initial Run #588 root-import failure: two Node.get calls supplied unsupported default arguments. Fixed both in the lifecycle test; do not count Run #588 as a pass.
- [x] Feature PR [#132](https://github.com/qaqp980520-prog/2126-Survival/pull/132) merged as `1792752a237e3d2d035c3f9c7e74a07baf0090c2`; exact candidate `8995b49d6961984c72aa54c2c499ef766f4030b3` passed canonical Godot 4.3 [Run #589](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41006189052): 198/198 job entries succeeded, zero failures/skips. Steps 192–195 cover Drone Relay import/rules/runtime and the actual world-object chunk lifecycle regression.
- [x] Keep world-save schema at version 1; this run adds regression coverage, not a production factory migration.
- [ ] Integrate stable IDs and validated semantic state restoration into every production interactable object factory.
- [ ] Persist complete generated terrain and object deltas across unload/reload and save/load.
- [ ] Integrate asynchronous chunk streaming with world-session transactional save/restore and failure recovery.
- [ ] Perform manual GUI, GPU, and iPhone hardware acceptance; no local Godot executable/device was available.
- Compatibility boundary: the lifecycle regression exercises the SurfaceChunkStreamingPlayground factory path only; it does not prove all production factories are migrated. The initial Run #588 failed before new game/lifecycle tests and must remain recorded as a failed candidate; only Run #589 validates the corrected exact HEAD.


## Run 50 — 2026-10-30: Outpost Architect and legacy world-object rollback

### Resolved in PR #134

- Added KROLL Outpost Architect M0.1: a deterministic 5×5 outpost-building puzzle with three authored decks, eight placements, an 18-energy budget, adjacency scoring, keyboard/mouse/touch controls, rules tests and a real-scene smoke test.
- Added an exact rollback fix in \`scripts/world.gd\`. If target chunk streaming fails, restore the pre-attempt world-object Registry snapshot regardless of whether the incoming legacy schema-1 payload includes the optional \`world_objects\` key. The streaming attempt itself can create temporary world-object records before failing.
- Extended the actual SurfaceChunkStreamingPlayground world-session integration test with deterministic factory failure after one temporary target chunk loads. The test asserts the target failure phase, one temporary load, exact Registry payload and stable-ID set, active chunk IDs, player position and complete rollback report.
- Added canonical workflow steps for Outpost Architect file checks, Godot import, rules tests and runtime smoke.
- Kept world-save schema at version 1. A successful legacy restore without \`world_objects\` continues to preserve the current Registry; only the failed target-stream rollback path changes.

### Validation

- Functional PR #134 merged as \`84dfae68a7170fb66ba60c17093292ccd6018f69\`.
- Exact candidate \`0e5be2ea6a4f3b70ebd0646488091355101febe0\` passed canonical Godot 4.3 [Run #596](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41018084060): 202/202 job step entries succeeded, zero failures and zero skipped.
- Step 150: world-session controller integration test, including the new legacy failed-stream rollback injection, succeeded.
- Steps 196–199: Outpost Architect file verification, project import, rules tests and runtime smoke test all succeeded.
- Independent model calculation verifies the three authored build routes: 27/27, 25/25 and 25/25; each spends 14 of 18 energy. This is supplementary, not engine validation.
- No local Godot executable was available; manual GUI, GPU performance and iPhone hardware QA are not claimed.

### Source audit correction

- Current main contains \`scripts/world.gd\` with \`class_name WorldSessionController\`. It is a reusable world-session composition base, added in the earlier Run 38 work. Historical Run 19–37 notes saying the file was absent are correct for those earlier snapshots but must not be read as current state.
- A concrete production world subclass/scene and migration of every production interactable factory remain incomplete. The existing SurfaceChunkStreamingPlayground lifecycle path is not proof that all production factories are migrated.

### Remaining limitations / next work

1. Migrate all production interactable object factories to stable IDs and validated state restore.
2. Persist generated terrain and object deltas across chunk unload/reload and world save/load.
3. Integrate asynchronous chunk streaming with world-session transactional save/restore and failure recovery.
4. Strengthen backing-field encapsulation where required.
5. Perform manual GUI, GPU performance and iPhone device QA when a local Godot runtime and devices are available.


## Run 51 reconciliation and Run 52 — 2026-10-30

### Run 51 source-of-truth correction

- PR #136 is merged at 771bc9f2171e1f638457cd17fb64a542fd7e90f4.
- Exact candidate 862ee711cc62801d378ac6d8215aabf202cc1b4f passed Godot 4.3 Run #602 with 208/208 successful steps.
- docs/run51-closeout-2026-10-30 was compared with main and had no diff. No separate Run 51 docs PR existed; the old pending note was corrected in Notion and is explicitly reconciled here.

### Resolved in Run 52 feature PR #137

- Added KROLL Gravity Courier: 2D gravity-switching cargo platformer; real floor/ceiling CharacterBody2D movement is covered by the runtime smoke test.
- Added a dedicated stable-ID underground mine chunk and a visible surface lift entry. G enters/exits; F routes to MineralMiningNode.mine_hit(). Mined items enter the same SurvivalWorldBridge inventory and update carry weight.
- Persisted location_layer and surface_return_position as optional schema-1 fields. Legacy schema-1 surface saves without these fields continue to load.
- Added cross-layer recovery compatibility: the surface director ignores only underground/* IDs, while unknown/malformed IDs continue to fail validation.
- Added production integration tests for mine entry, mining, shared inventory and weight, chunk unload/reload, world restore, legacy saves, and surface recovery while the underground chunk is registered.
- Feature PR #137 merged as 5b5a534e22dd0b27bed60b3ed6530357c869581b. Exact candidate d5d6c565cbb14a3a5128075d153d5e343fc507dd passed [Godot 4.3 Run #609](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41027928173): 213/213 successful workflow entries, zero failures/skips.
- Failure history preserved: Run #607 failed at step 47 because the first recovery guard skipped every non-surface ID and weakened unknown-ID rejection. The final implementation skips only underground/*; Run #609 passed the same recovery test plus the new mine integration test.

### Remaining limitations

1. The mine shaft is a lift/teleport layer transition, not a continuous physical ladder.
2. Only one fixed underground mine chunk exists and remains loaded; multi-level underground streaming is future work.
3. Not all production interactable factories have been migrated to stable IDs and validated restore.
4. Complete terrain/object delta persistence and asynchronous chunk streaming still need work.
5. No local Godot runtime or iPhone device was available; manual GUI, GPU and device QA are not claimed.


## Run 53 — 2026-10-30 — Orbital Docking + underground 3×3 streaming

- [x] Add `daily_games/KROLL_Orbital_Docking/`: deterministic 2D inertial spacecraft docking with three approaches, fuel/time budgets, rotation, forward/reverse thrust, keyboard/touch controls, rules tests and scene smoke test.
- [x] Add transactional `systems/UndergroundMineDirector.gd`: bounded horizontal 3×3 active room window, stable coordinate IDs, snapshot rollback, failure reports and no orphan records.
- [x] Extend `UndergroundMineFactory.gd` with connected 10 m rooms, aligned doorway openings and coordinate-derived mineral identities; preserve the existing timestamp-first call contract.
- [x] Integrate actual physics-driven underground streaming and rollback-safe surface return into `world/SurfaceWorld.gd`.
- [x] Add production tests for nine-room windows, physical travel, stable mineral stock after unload/reload, doorway alignment, invalid coordinates, factory failure rollback and registry cleanup.
- [x] Feature PR [#139](https://github.com/qaqp980520-prog/2126-Survival/pull/139) merged as `a40e25b0be8ed948c2324914f2b7151db993026c`.
- [x] Exact candidate `6298da84c4bfc46272e939aa7ba00d1541caedac` passed Godot 4.3 [Run #620](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41032518860): 218/218 successful job entries, zero failures and zero skipped. New checks 211–215 all passed.
- [x] Reconcile stale Notion candidate references: `b4e83f7b8236bfd6dffab11d2e5db7371685eaa6` belonged to cancelled Run #619 and is superseded by the actual merged PR head `6298da84c4bfc46272e939aa7ba00d1541caedac`.
- [ ] Add vertical multi-level underground connections and their save/restore coverage.
- [ ] Integrate asynchronous chunk streaming and transactional recovery.
- [ ] Audit production interactable factories and terrain/object delta persistence.
- [ ] Perform manual GUI, GPU and iPhone device QA when a local Godot runtime and suitable devices are available.
- Compatibility: world-save schema remains version 1; the new director manages a horizontal single-elevation 3×3 window only. Local Godot is unavailable; no local GUI/GPU/device test is claimed.


## Run 54 — 2026-10-30 — Fossil Lab + production carry-weight movement

- [x] Add `daily_games/KROLL_Fossil_Lab/`: four triomino bone fragments, three deterministic 5×5 blueprints, rotation, target-mask placement, undo, keyboard/mouse/touch, rules tests and runtime smoke test.
- [x] Connect `world/SurfaceWorld.gd` movement to the existing SurvivalWorldBridge profile: 5.0 m/s normal, 0.68 multiplier above day-based carry limit, 0.42 multiplier above 90 kg, jump disabled only above 90 kg.
- [x] Add production integration coverage for 63/66/90/93 kg, actual movement speed, jump lock and immediate recovery after dropping 3 kg.
- [x] Feature PR [#141](https://github.com/qaqp980520-prog/2126-Survival/pull/141) merged as `c24c881e497e0f71b56462d672db143ae55a5639`.
- [x] Exact candidate `d1aca4feafacafdc1f7789ec15d75457c235203c` passed Godot 4.3 [Run #623](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41038847298): 223/223 successful job entries, zero failures and zero skipped. New steps 216–220 all passed.
- [x] Preserve existing inventory thresholds, item weights, stable IDs and world-save schema 1.
- [ ] Design and integrate stamina consumption/recovery before claiming overweight stamina penalties; current production world has no stamina model.
- [ ] Complete production-wide interactable factory persistence audit and terrain/object delta persistence.
- [ ] Add vertical multi-level underground connections and asynchronous chunk streaming/recovery.
- [ ] Perform manual GUI, GPU and iPhone device QA when a local Godot runtime and suitable devices are available.
- Compatibility: no inventory save schema or item weight changes. No local Godot GUI/GPU/device test is claimed.


## Run 55 — 2026-10-30 — Tidal Survey + production stamina integration

- [x] Add `daily_games/KROLL_Tidal_Survey/`: inertial underwater navigation, current fields, three ordered-beacon layouts, hazards, oxygen budget, dock return, keyboard and touch controls, deterministic rules tests and scene smoke test.
- [x] Add deterministic route-follower acceptance simulation; all three authored layouts are completable within the oxygen budget.
- [x] Add `systems/SurvivalStamina.gd` and connect it to production `world/SurfaceWorld.gd`.
- [x] Use the existing inventory movement multiplier as the single source of truth for encumbrance stamina drain. Normal/overweight/super-heavy movement drain is 2.0/approximately 2.94/approximately 4.76 stamina per second with provisional defaults.
- [x] Add idle recovery, 10-point jump cost, exact-threshold behavior and HUD stamina reporting.
- [x] Persist optional stamina schema 1 inside the existing world-save schema 1. Legacy saves without the stamina key default to full stamina; invalid payloads are rejected before world mutation.
- [x] Add model and production integration tests for actual physics-input drain, weight coupling, jump threshold, save/restore, legacy fallback, invalid payload non-mutation and chunk-window preservation.
- [x] Feature PR [#143](https://github.com/qaqp980520-prog/2126-Survival/pull/143) merged as `de11e4a77962fdfbafe950f2ad9e63a6c1b07d4c`.
- [x] Exact candidate `26745ff0bc302e8c25a1c04342cc86a58ef35e17` passed Godot 4.3 [Run #637](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41047042931): 229/229 successful job step entries, zero failures, zero skipped. New steps 221–226 all passed.
- [x] Add design notes `docs/KROLL_TIDAL_SURVEY_M0_1_2026-10-30.md` and `docs/SURVIVAL_STAMINA_MODEL_M0_1_2026-10-30.md`.

### Remaining limitations

1. Stamina tuning values are provisional and need playable-world feedback.
2. Sprinting, food/hotbar stamina restoration and a separate exhaustion movement penalty at zero stamina are not implemented.
3. Tidal Survey current fields are static within each radius; no campaign/high-score persistence.
4. Production-wide interactable factory migration, terrain/object delta persistence, vertical multi-level underground connections and asynchronous chunk streaming/recovery remain open.
5. No local Godot executable or iPhone device was available; manual GUI, GPU and device QA are not claimed.

Compatibility: world-save envelope remains schema 1. Stamina is an optional, separately validated schema-1 payload; legacy saves without it load with full stamina. Inventory weight rules and item weights are unchanged.


## Run 56 — 2026-10-30 — Station Shift + stamina sprint/exhaustion M0.2

- [x] Add `daily_games/KROLL_Station_Shift/`: deterministic six-cycle station operations management with three scenarios, five crew across Power/Life Support/Repairs, Energy/Oxygen/Hull reserves, keyboard and mouse/touch controls, rules tests and scene smoke test.
- [x] Validate a complete winning crew allocation for each of the three authored scenarios.
- [x] Upgrade `systems/SurvivalStamina.gd` to M0.2 and integrate sprinting into production `world/SurfaceWorld.gd`: Shift/touch sprint, 1.35 speed factor, 2.25x drain, 5-point sprint threshold and 0.65 walking factor at zero stamina.
- [x] Preserve SurvivalInventory as the only source of carry-weight movement multipliers; stamina factors multiply the existing carry factor rather than replacing it.
- [x] Preserve jump cost 10 and exact threshold; keep stamina payload and world-save envelope at schema 1; sprint/exhaustion are derived from current stamina.
- [x] Expand model and production SurfaceWorld tests for sprint threshold, drain, exhaustion, recovery, touch sprint signal, actual physics movement, carry-weight coupling, jump boundary, save/restore and legacy fallback.
- [x] Add Station Shift import, rules and runtime smoke tests to the full Godot 4.3 workflow.
- [x] Feature PR [#145](https://github.com/qaqp980520-prog/2126-Survival/pull/145) merged as `52f47d61b992a2449dcaae35b1c4b230ccd9925a`.
- [x] Exact candidate `169d9b394cd09636896790b91d4951f01cf2c090` passed Godot 4.3 [Run #645](https://github.com/qaqp980520-prog/2126-Survival/actions/runs/41052380165): 233/233 successful workflow entries, zero failures and zero skipped. New steps 227–230 all passed.
- [x] Retain failure history: #642 stale stamina expected values, #643 wrong overweight baseline, #644 invalid two-argument Object.get in Station Shift smoke test. The exact current candidate fixed the final parser issue; Run #645 is the only final acceptance run.
- [ ] Tune stamina rates after playable-world feedback.
- [ ] Add food/hotbar stamina restoration and sprint animation/camera feedback.
- [ ] Complete production-wide interactable factory migration and terrain/object delta persistence.
- [ ] Add vertical multi-level underground connections and asynchronous chunk streaming/recovery.
- [ ] Perform manual GUI, GPU and iPhone device QA when a local Godot runtime and suitable devices are available.
- Compatibility: stamina and world-save schema remain version 1; legacy saves without stamina still default to full. No inventory carry thresholds or item weights changed. No local GUI/GPU/device QA is claimed.



## Run 57 — 2026-10-30 — Void Runner + SurvivalQuickUse M0.1 (feature merged)

- [x] Add `daily_games/KROLL_Void_Runner/`: deterministic three-lane runner with three authored routes, lane changes, jump/slide, hazards, data-cell objectives, keyboard and mouse/touch controls, rules tests and scene runtime smoke test.
- [x] Add `systems/SurvivalQuickUse.gd` and integrate four consumable slots into `world/SurfaceWorld.gd` through `SurvivalWorldBridge.gd`; inventory remains authoritative in SurvivalInventory.
- [x] Implement full-stamina/empty-slot rejection, partial-capacity clamping, synchronous re-entry guard, save validation, legacy fallback and failed-restoration item refund.
- [x] Add model regression for synchronous callback filling stamina after item removal; verify the ration is refunded, `rollback_complete=true`, transaction guard released and a later retry consumes exactly once.
- [x] Add production HUD integration coverage for inventory-change refresh, full-stamina disable, enabling after stamina decreases, consumption count refresh, touch controls, save/restore, invalid payload non-mutation and legacy fallback.
- [x] Exact-head Godot 4.3 Run #659 passed all 236 numbered validation steps, zero failed, zero skipped. New checks 231–236 all passed.
- [x] Feature PR [#150](https://github.com/qaqp980520-prog/2126-Survival/pull/150) merged as `9428c90f88d3e50cd90c46a29e717d7e5b56a245`; exact candidate `b4b9cca82280ffb8d887c346acff929720fa2ed3`.
- [x] Preserve failed/superseded validation history: #655/#656 full-stamina HUD expectation, #657 absolute stamina expectations ignoring idle recovery, #658 superseded candidate. Only #659 is final acceptance evidence.
- [ ] Tune consumable restoration values after playable-world feedback and add drag-and-drop slot assignment UI.
- [ ] Add sprint animation/camera feedback; complete production-wide interactable factory persistence, terrain/object deltas, vertical underground connections and asynchronous streaming/recovery.
- [ ] Perform manual GUI, GPU and iPhone device QA when local runtime/device access is available.
- Compatibility: world-save envelope and quick-use payload remain schema 1; legacy saves without quick-use initialize default assignments. No local GUI/GPU/device QA is claimed.


## Run 58 follow-up issues (2026-10-31)

1. **Underground cache distribution remains prototype-scoped.** Two deterministic stateful caches exist only in `underground/mine_0_0`. Other rooms have no room-specific loot tables, random cache placement, or rarity weighting. Next: define per-room cache spawn tables and validate them against mineral density and inventory weight.
2. **Underground interaction is nearest-target based.** F selects the nearest cache or mineral vein. There is not yet a dedicated interaction prompt, raycast selection, cache animation, or inventory-full feedback panel for underground caches.
3. **Vertical mine layers are still pending.** Current mine streaming remains a horizontal chunk grid on one underground elevation. Multi-depth floors, ladders/elevators, and vertical transition persistence are not implemented.
4. **Asynchronous chunk streaming is still pending.** Current load/unload and failure rollback paths are synchronous; no background generation/stream queue is claimed.
5. **Orbital Imager M0.1 is a fixed 2D prototype.** It has three authored assignments and deterministic camera-frame rules; it does not yet provide a 3D orbital camera, procedural survey maps, or saved campaign progress.
6. **Device validation remains outstanding.** GitHub Actions Godot 4.3 headless CI passed, but no local Godot executable was available for manual GUI, GPU, or iPhone device testing.

### Run 58 validation note
- The isolated `UndergroundMineDirector` test fixture must bind both `MineralVeinRegistry` and `WorldObjectStateRegistry` whenever its factory creates `WorldObjectStatefulProp` nodes. The fixture was updated in Run 58; production registry validation must remain enabled.
- Current world save schema remains version 1; no migration is required for the two origin-room caches.
- Final feature candidate `44256ddc52b9c90396b9035f0a9493408f5fcb78` passed Godot 4.3 CI Run #665 (240/240) before PR #152 was merged as `13bc8d218bafc79cfa1cd4cc4532d43563069310`.
