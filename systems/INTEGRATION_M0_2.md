# Survival World Bridge — M0.2

## 目標
為既有世界探索／採礦原型提供一個小型適配器，讓世界拾取、採礦產出、丟棄物品與負重查詢共用 `SurvivalInventory`，並用訊號通知 UI 或角色控制器。

## 新增檔案
- `SurvivalWorldBridge.gd`：世界互動與共用背包之間的橋接節點。
- `SurvivalInventory.gd`：M0.1 共用背包模型。

## 主要 API
- `collect_world_item(item_id, amount)`：拾取物品。
- `collect_mined_ore(ore_id, amount)`：採礦產物進背包，內部走同一拾取 API。
- `drop_item(item_id, amount)`：丟棄物品並立即重算重量。
- `get_summary()`：提供重量、負重上限、超重狀態、移動倍率與跳躍權限。
- `serialize_inventory()` / `restore_inventory(data)`：提供存檔字典接口。
- `inventory_changed`、`item_collected`、`item_dropped`：供 HUD、角色控制器或世界掉落物系統連接。

## 接入方式（尚待實際專案整合）
1. 把兩個 `.gd` 檔放入同一個 Godot 4 專案路徑。
2. 確認 Godot 已掃描 `class_name SurvivalInventory` 與 `class_name SurvivalWorldBridge`。
3. 將 `SurvivalWorldBridge` 加入世界場景，連接 `inventory_changed` 到 HUD。
4. 採礦成功時呼叫 `collect_mined_ore("iron_ore", amount)`；拾取物件時呼叫 `collect_world_item(item_id, amount)`。
5. 角色移動前讀取 `get_movement_multiplier()`；跳躍前檢查 `can_player_jump()`。
6. 存檔時將 `serialize_inventory()` 放入既有存檔字典，讀檔時呼叫 `restore_inventory()`。
7. 把每個正式物品加入 `SurvivalInventory.ITEM_WEIGHTS`，避免未知物品以 0 kg 計算。

## 本版完成與未完成
- 已新增橋接腳本與整合說明，目的是定義一致的接口。
- 尚未修改或覆蓋現有 M1.3 場景，也尚未實際接線至採礦控制器、拾取物、HUD、角色控制器或本機存檔。
- 尚未在 Godot 4 執行、編譯或實測；不宣稱已完成遊戲內整合。
- 這個適配器使用 `SurvivalInventory` 的 `class_name`，因此需確認腳本類別快取已建立後再執行。
