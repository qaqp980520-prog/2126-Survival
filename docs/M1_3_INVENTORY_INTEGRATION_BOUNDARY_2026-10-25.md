# M1.3 共用背包整合邊界審查｜2026-10-25

## 狀態
- 類型：靜態整合審查／不改動執行流程
- 分支：`audit/m1-3-inventory-integration-boundary-2026-10-25`
- 驗證：已讀取 `main` 的 `SurvivalInventory.gd`、`SurvivalWorldBridge.gd`、`INTEGRATION_CHECKLIST_M1_3.md`；未執行 Godot 4。
- 限制：目前 GitHub `main` 的檔案樹沒有 M1.3 活躍世界控制器 `scripts/world.gd`，所以不能安全地直接修改或聲稱已整合舊世界原型。

## 已確認的資料邊界
1. 共用背包序列化格式是 `{ schema_version: 1, game_day: int, inventory: Dictionary }`。
2. M1.3 舊世界存檔使用頂層 `version`（v1/v2）與世界狀態欄位；不能把整份舊世界存檔直接交給 `SurvivalInventory.load_save_dict()`。
3. `SurvivalWorldBridge` 的拾取、採礦與丟棄都經由背包 API，但它必須與角色、HUD、世界控制器共用同一個 inventory instance；若橋接器自行建立第二份背包，畫面數量與負重可能不同步。
4. 新背包會拒絕 `ITEM_WEIGHTS` 未登錄的物品 ID。接線前必須比對所有拾取、採礦、食物、貨幣與存檔中的 ID。
5. 舊存檔的世界資料與背包資料需要分層驗證：先驗證完整世界快照，再轉換背包欄位，任何一步失敗都不應部分覆寫現有遊戲狀態。

## 建議的整合方式（尚未實作）
- 保留 M1.3 的世界存檔外層 schema 與地形／作物／時間欄位。
- 在單一轉接函式中把舊 `inventory` 字典轉成共用背包接受的 payload；明確傳入有效的 `game_day`，並只允許已登錄 item ID 與非負整數數量。
- 轉換前先檢查所有 key/value；不要用靜默截斷或自動把小數取整，避免存檔資料遺失被掩蓋。
- 從共用背包轉回世界存檔時，只替換世界快照中的 inventory 欄位，不得丟掉其他世界狀態。
- 世界控制器建立一次 inventory instance，將同一個 instance 注入 bridge、HUD 與玩家負重控制；禁止每個節點各自 new 一份。
- 整合測試應覆蓋 v1 舊存檔、v2 新存檔、重複載入、未知 item ID、錯誤數量、採礦／拾取／丟棄後的重量即時更新。

## 整合前阻擋條件
- [ ] 把實際使用中的 M1.3 世界專案與 `scripts/world.gd` 納入 GitHub 可審查版本。
- [ ] 在 Godot 4 執行背包驗證測試與世界存檔回歸測試。
- [ ] 證明 bridge、HUD、角色控制器讀寫同一份 inventory instance。
- [ ] 確認所有正式 item ID 已登錄且權重合理。
- [ ] 完成後再建立整合 PR；目前不合併任何未經引擎測試的變更。

## 結論
本次只提交整合邊界審查文件，不修改既有遊戲邏輯。這能先固定資料轉換與單一資料來源的要求，避免在缺少實際 M1.3 世界腳本時猜測接線方式。