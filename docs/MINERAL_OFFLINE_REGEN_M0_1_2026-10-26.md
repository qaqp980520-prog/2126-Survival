# 《2126 Survival》礦脈離線再生 M0.1 — 2026-10-26

## 內容
- `systems/MineralMiningNode.gd` 新增可設定的礦脈容量 `max_vein_units` 與每單位再生間隔 `regen_seconds_per_unit`。
- `apply_elapsed_regeneration(now_unix_time)` 依 Unix 時間差計算完整間隔；離線時間可在載入存檔後補算，不需要每秒計時器。
- 再生只補完整間隔，保留未滿一個間隔的時間；系統時鐘倒退不會扣除礦量。
- 存檔升級至 schema v2，儲存容量、再生間隔與最後再生時間；仍可讀取 schema v1，舊存檔從首次載入時開始計算再生。
- 非法的再生設定或時間戳記會被拒絕，不改動原本礦脈狀態。

## 測試
新增自動測試涵蓋部分間隔、跨多個完整間隔、容量上限、時間倒退、schema v2 往返、schema v1 相容及非法資料拒絕。須等待 GitHub Actions 完整 headless 驗證後，才能將本版本視為通過。

## 尚未完成
- 尚未連接正式世界地圖的所有礦脈生成器。
- 尚未做圖形介面遊玩測試；CI 只驗證 Godot headless 匯入、解析及自動測試。
- 再生間隔是原型預設值，可依不同礦種或區域調整。
