# M1.3 共用背包整合邊界審查｜狀態更新 2026-10-26

## 狀態與外部事實
- 本文件是整合邊界審查，不代表正式 M1.3 世界已接線。
- 目前 main 有 `SurvivalInventory.gd`、`SurvivalWorldBridge.gd`、`SurvivalInventorySaveAdapter.gd` 與對應回歸測試；可核對的正式 M1.3 `scripts/world.gd` 仍不在 main 檔案樹。
- Godot 4.3 CI Run #181（`40316093821`）通過 inventory validation、weight boundaries、save adapter、bridge binding 與 world-save adapter integration tests；這是共用系統／adapter 證據，不是正式 M1.3 世界端到端測試。

## 已確認的資料邊界
1. 共用背包 payload 為 `{ schema_version: 1, game_day: int, inventory: Dictionary }`。
2. M1.3 世界存檔使用頂層 `version`（v1／v2）及世界狀態欄位；不能把整份世界存檔直接交給 `SurvivalInventory.load_save_dict()`。
3. `SurvivalWorldBridge.bind_inventory()` 可接受有效共用背包並保留預先注入實例；但 HUD、正式世界控制器與玩家仍需共用同一個 instance。
4. `SurvivalInventorySaveAdapter` 負責在世界存檔 envelope 與 inventory payload 之間轉換，並需在正式世界流程中實際使用。
5. constructor／正式 API 拒絕未知 item ID；若直接修改公開 counts 字典，未知 ID 以 1 kg 保守計重。物品登錄表與舊世界 item ID 仍需核對。

## 建議整合方式（未完成）
- 保留 M1.3 世界存檔外層 schema、地形／作物／時間與玩家欄位。
- 在單一轉接函式中把舊 inventory 字典轉成共用背包 payload；只允許已登錄 ID、有限非負整數數量及有效 game_day。
- 轉換前先驗證完整世界快照；任何欄位失敗都不應部分套用玩家位置、快捷欄、體力或作物。
- 世界控制器建立唯一 inventory instance，注入 bridge、HUD 與角色負重查詢；避免每個節點各自建立背包。
- 存檔回寫只替換 world envelope 的 inventory/day 欄位，不得丟掉其他世界狀態。

## 整合前阻擋條件
- [ ] 將實際使用中的 M1.3 世界專案與世界控制器納入 GitHub 可審查版本。
- [ ] 在 Godot 4 執行 v1/v2 世界存檔往返、重複讀檔、作物狀態、快捷欄與玩家位置／體力整合測試。
- [ ] 證明 bridge、HUD、角色控制器讀寫同一份 inventory instance。
- [ ] 核對正式 item ID 與重量。
- [ ] 完成後才開整合 PR；未測試的變更不得合併 main。

## 結論
共用背包與 adapter 的部分風險已有 CI 測試，但缺少正式 M1.3 世界控制器仍是阻斷條件。下一步應先取得完整世界專案，而不是在不存在的檔案上猜測接線。
