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

- PR #96 merged as \`9e134d317f98d81a2b5061f81abf80ba6e92dd86\`; exact validated head \`59338ab48cc1a1b860200df029d6bbec81fbc470\`.
- Exact-head Godot 4.3 Run #445 (40668945834) passed all 127 workflow steps with zero failures. Shadow Trace import/rules/runtime steps 121–123 and crop registry integration step 124 passed. Root project import, existing Signal Sleuth tests, mineral registry atomicity and the world mining/vein persistence integration also passed.
- New \`daily_games/KROLL_Shadow_Trace/\`: 8×8 deterministic turn-based stealth prototype, three intel caches, two patrol routes, line-of-sight blocked by walls, 40-turn limit and three-alert failure; keyboard/mouse/touch controls, no external assets/add-ons.
- Added \`systems/CropRegistry.gd\` and integrated \`crop_registry_state\` into the active Backrooms playground save envelope. Payloads are validated in full before mutation; legacy saves missing the field preserve the current registry snapshot. \`tests/crop_registry_persistence_test.gd\` covers real save/load, fresh-world restore, invalid update and restore atomicity, detached snapshots, schema validation and legacy compatibility.
- **Scope boundary:** this is a data-only crop state registry, not the full crop gameplay system. Planting, visuals, growth simulation, watering and harvesting remain unimplemented. The production \`scripts/world.gd\` controller is still absent; complete generated chunk scene persistence remains outstanding.
- No local Godot executable was available; GUI/GPU/iPhone device tests are not claimed.
- Documentation closeout is on branch \`docs/run31-shadow-trace-crop-registry-closeout-2026-10-28\`; do not merge until its own exact-head Godot 4.3 CI succeeds.
- Next: finish docs closeout, then connect crop lifecycle and chunk persistence to the production world-session controller and add production-scene load/unload/save/reload acceptance tests.
