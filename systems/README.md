# 2126 Survival — 共用背包資料服務 M0.1

## 目的
提供採礦、世界探索與背包原型共用的物品數量、重量、負重狀態及存檔序列化規則，避免每個原型各自維護不同計算方式。

## 檔案
- `SurvivalInventory.gd`：Godot 4 `RefCounted` 資料服務，使用 `class_name SurvivalInventory`。

## 使用範例
```gdscript
var inventory := SurvivalInventory.new({"meat": 4, "iron_ore": 3}, 2)
inventory.add_item("berries", 5)
print(inventory.total_weight_kg())
print(inventory.movement_multiplier())
var save_data: Dictionary = inventory.to_save_dict()
```

若在專案中以全域 class name 使用，請先讓 Godot 掃描腳本類別；也可以把腳本複製到專案並使用 `preload()` 建立實例。

## 規則
- 初始負重上限 65 kg；每遊戲日增加 0.2 kg。
- 超過負重上限時，移動倍率為 0.68；超過 90 kg 時倍率為 0.42 且禁止跳躍。
- `add_item` / `remove_item` 立即更新數量；重量每次從目前數量重新計算，不使用可能失真的快取。
- `to_save_dict()` 與 `load_save_dict()` 負責背包資料的 JSON 相容字典序列化，不直接讀寫檔案。
- 未列在 `ITEM_WEIGHTS` 的物品目前預設重量為 0；正式整合時應為每個物品定義明確重量。

## 驗證狀態
- 已靜態檢視腳本內容。
- 尚未在 Godot 4 執行或編譯測試。
- 這是新增的共用資料服務，尚未替換既有 M1.3 原型中的變數與函式；需要下一步整合並以引擎測試確認相容性。
