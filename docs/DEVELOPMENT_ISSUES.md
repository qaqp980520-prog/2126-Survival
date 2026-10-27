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


## Run 20 candidate — 2026-10-27
- [x] Validate KROLL Magnetic Salvage import, rules and runtime smoke test with exact-head Godot 4.3 CI (Run #321, 40465124945).
- [x] Validate active world save file roundtrip using prototypes/BackroomsPortalPlayground.tscn, including invalid inventory and non-finite position rejection without live-state mutation (Run #321 step #82).
- Source boundary remains: scripts/world.gd is absent. The active playground test improves coverage but does not complete the missing M1.3 production controller.
- No local Godot GUI or iPhone hardware test is claimed. Do not merge before full CI succeeds.


## Run 20 functional closeout｜2026-10-27
- PR #72 merged as `fa4f680434fe7e961b1d6266a8a7357b9ef0e77a` after exact-head Godot 4.3 CI Run #321 passed all 82 numbered validation steps.
- KROLL Magnetic Salvage import, rules and runtime smoke tests passed; active world save file roundtrip and invalid-save atomicity test passed.
- Main-push Run #322 (40465398061) targets the exact merge SHA and is still in progress at `Initialize containers` at the time of this update. Do not mark it successful until its conclusion is success.
- `scripts/world.gd` remains absent; this run validates the active BackroomsPortalPlayground controller, not a separate M1.3 production controller. GUI/iPhone hardware tests remain outstanding.


## Run 20 main-push verification closeout｜2026-10-27
- Main-push Godot 4.3 CI Run #322 (40465398061) completed successfully on main SHA `fa4f680434fe7e961b1d6266a8a7357b9ef0e77a`.
- All 82 numbered validation steps passed, including Magnetic Salvage import/rules/runtime and active world save roundtrip integration. No failed steps.
- Local GUI/iPhone testing and the separate M1.3 production world controller remain outstanding.
