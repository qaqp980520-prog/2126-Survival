# 《2126 Survival》礦物資產 M0.1 — 2026-10-26

## 範圍
新增七種可識別礦物：銅礦、鐵礦、金礦、銀礦、鋁礦、煤礦、鈾礦。保留既有 item ID `copper_ore` 與 `iron_ore`，其餘使用 `gold_ore`、`silver_ore`、`aluminium_ore`、`coal_ore`、`uranium_ore`。

## 資產組成
- `systems/MineralCatalog.gd`：正式 ID、繁中名稱、重量、礦脈/碎屑顏色與建議採集量。
- `prototypes/minerals/MineralOreVisual.gd`：以 Godot Mesh 資源即時生成低多邊形礦塊群，金屬礦脈用材質色區分；鈾礦有綠色自發光。
- `prototypes/minerals/MineralMiningVFX.gd`：挖掘命中時建立短暫粒子爆發，金屬礦增加暖色火花，煤礦偏暗碎屑，鈾礦使用綠色光粒。
- `systems/SurvivalInventory.gd`：登記新增礦物重量，存檔 schema 維持 v1，舊存檔缺少新 ID 時仍預設為 0。
- `tests/mineral_catalog_test.gd`：測試七種登記、背包重量、存檔往返、未知 ID 防護、視覺與特效節點可建立。

## 暫定單位重量
| ID | 每單位重量 |
|---|---:|
| copper_ore | 2.8 kg |
| iron_ore | 3.0 kg |
| gold_ore | 3.2 kg |
| silver_ore | 3.1 kg |
| aluminium_ore | 2.4 kg |
| coal_ore | 1.4 kg |
| uranium_ore | 3.4 kg |

重量是第一版遊戲平衡值，之後可依實際採礦循環調整。

## 使用方式
1. 在礦脈節點加入 `MineralOreVisual`，設定 `mineral_id`。
2. 挖掘命中時呼叫 `MineralMiningVFX.play_hit(mineral_id, impact_position)`。
3. 採集程式依 `MineralCatalog.get_mineral(id)` 取得名稱、掉落範圍與特效顏色，再將物品加入 `SurvivalInventory`。
4. 所有採集量仍需由礦脈剩餘量/再生系統限制；此提交只提供礦物目錄與視覺原型，尚未宣稱已接通正式世界採礦控制器。

## 測試狀態
- GitHub Actions 新增 Godot headless 測試步驟。
- 在 CI 完成前狀態為「待驗證」；未通過不得合併。
- 這一版的 3D 礦塊使用程式化低多邊形網格，不是外部建模軟體製作的高模/貼圖包。
- 概念展示圖是視覺方向參考，不等於已產出的獨立模型檔、貼圖檔或完整背包 UI。


## 2026-10-26 補充｜離線礦脈再生 M0.1
- PR #21–#23 已合併 main；其 CI Run #41、#42、#43 均成功。
- 新增 `MineralMiningNode.apply_elapsed_regeneration(now_unix)`，依真實 Unix 時間回補礦脈單位，保留部分間隔並支援離線時間。
- 新增 `max_units`、`regen_interval_seconds`、`last_regen_unix` 存檔欄位；schema 升至 v2，仍可載入舊 schema-v1 格式；缺少再生欄位的舊存檔會從載入時間開始計算。
- `restore_vein` 現在以礦脈自身最大存量為上限；時鐘倒退不會增加存量或倒退時間戳。
- 新測試涵蓋離線 120 秒回補、部分間隔、容量上限、時鐘倒退、舊存檔相容與無效欄位拒絕。
- 文件：`docs/MINERAL_VEIN_OFFLINE_REGENERATION_M0_1_2026-10-26.md`。
- 狀態：PR #28 已合併 main，merge commit `4990b15700654bbadeac29784662c2e7b9a58bf8`；Godot 4.3 CI Run #55 success，31 個 workflow steps 全部成功。PR #26、#27 已關閉為 superseded，沒有合併。
