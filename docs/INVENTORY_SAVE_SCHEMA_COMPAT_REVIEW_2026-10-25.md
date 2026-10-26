# 共用背包 × M1.3 存檔 Schema 相容性審查｜狀態更新 2026-10-26

## 文件性質
本文件起源於 2026-10-25 的靜態審查。下列「已修正」項目以目前 main 的原始碼及 Godot 4.3 CI 為準；本文件不是完整 M1.3 世界整合已完成的聲明。

## 已確認的資料邊界
1. `systems/SurvivalInventory.gd` 使用 `schema_version: 1`，背包放在 `inventory`，遊戲日放在 `game_day`。
2. M1.3 世界存檔外層使用 `version: 1|2`，另含快捷欄、玩家位置、體力及 `world_state`。不能把完整世界存檔直接交給 `SurvivalInventory.load_save_dict()`。
3. `SurvivalWorldBridge.gd` 的背包序列化與 `SurvivalInventorySaveAdapter.gd` 負責不同層次：adapter 轉換世界存檔 envelope 與背包 payload；bridge 不代表完整 M1.3 世界控制器已接線。
4. `bind_inventory()` 支援同一個 RefCounted 背包實例注入 bridge；正式 M1.3 世界控制器與 HUD 仍需接線驗證。

## 歷史發現與目前狀態
- **小數／非有限數量：已修正。** `_is_integer_in_range()` 會拒絕非數值、NaN／Infinity、超界與小數；`load_save_dict()` 先驗證暫存 payload，再一次替換 counts／game_day。測試：`tests/inventory_save_validation.gd`。
- **game_day 型別／範圍：已修正。** 存檔載入要求有限整數，範圍 1–1,000,000,000；失敗時不改變既有背包狀態。測試同上。
- **未知物品 ID 重量為零：已修正。** 正式 constructor／add／remove／save-load 路徑拒絕未登錄 ID；若舊呼叫端直接改公開 `counts` 字典，`total_weight_kg()` 使用 `UNKNOWN_ITEM_WEIGHT_KG = 1.0`，不再默認零重量。測試：`tests/inventory_weight_boundaries.gd` 與 `tests/inventory_save_validation.gd`。
- **完整原子驗證：已修正於共用背包 payload。** 不相容 schema、無效遊戲日、未知 ID 或無效數量會在寫入 live state 前拒絕。這不等於 M1.3 整份世界存檔所有欄位都已整合。
- **橋接器生命週期：原型已驗證。** 預先注入的 inventory 不會在 `_ready()` 被覆蓋；無效替換會被拒絕。測試：`tests/world_bridge_binding_test.gd`。正式世界場景尚未接線。

## 仍待處理
- M1.3 世界存檔 envelope 與共用背包 payload 仍需在正式世界控制器中統一呼叫 adapter。
- main 目前沒有可核對的正式 `scripts/world.gd`，不能猜測接線位置。
- 需在整合後的 M1.3 場景驗證 v1／v2 世界存檔、快捷欄、玩家座標、體力、作物狀態與 inventory 一起往返，且任何失敗都不部分覆寫世界。
- 正式物品 ID 清單仍需與 M1.3 舊資料比對。

## 測試證據
- Godot 4.3 CI Run #181（`40316093821`）於候選 head `d4dc2fa58274e30d82d48cf647aa9124fc014aae` 成功；包含 inventory save validation、weight boundaries、save adapter 與 world bridge adapter／binding 測試。
- PR #49 已合併，merge commit `2cca29d30481a3943e07600cf4b73a757f7ea976`。
- 本機 GUI／手動遊玩未完成。

## 下一步
1. 找回／匯入真正使用的 M1.3 世界控制器完整專案。
2. 在獨立分支接入 adapter 與共用 inventory。
3. 新增完整世界快照往返與失敗原子性整合測試，CI 通過後再合併。
