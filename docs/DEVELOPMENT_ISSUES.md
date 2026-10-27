# 《2126 Survival》開發問題與待辦清單

這份清單是目前的開發追蹤文件，與 GitHub Issues 功能不同；之後可逐項搬成正式 Issues。

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

- Documentation PR #81 merged as `487c9740a9248315fd7f2f3489ef9135b9bc74a6`. GitHub compare confirms current `main` is identical to this commit; the code feature PR #80 merge `29915be423318a4c3be4a2fbceeb2ec78f1e59b9` remains the feature integration point, not the latest main SHA.
- No separate main-push workflow run was exposed for the documentation merge; exact-head Run #389 (40493657236) passed 98/98 numbered validation steps.
