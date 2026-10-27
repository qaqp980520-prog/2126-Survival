# 《2126 Survival》目前可執行原型與測試入口

更新日期：2026-10-27

## 啟動方式

根目錄的 `project.godot` 現在會先啟動 `prototypes/SurvivalTestHub.tscn`。選單提供兩個原型入口：

1. **地表探索／區塊與礦物串流** — `prototypes/SurfaceChunkStreamingPlayground.tscn`
2. **後室傳送門實驗場** — `prototypes/BackroomsPortalPlayground.tscn`

地表原型現在可按 **E** 開採身邊 2.8 公尺內的礦脈，產出會進入 `SurvivalWorldBridge` 共用背包並即時更新負重 HUD。`tests/surface_mining_integration_test.gd` 覆蓋礦脈扣量、物品入包與重量變更。

在這兩個原型中按 **F10** 回到選單；按 **Esc** 可釋放滑鼠。

## 重要界線

這個選單只是測試入口，不是完整主遊戲。兩個場景目前各自承載不同子系統，並不代表生存流程、地表世界、採集／採礦、後室與所有存檔已經全部整合。不要將原型可啟動誤認為完整遊戲已完成。

## 自動驗證

`tests/survival_test_hub_smoke_test.gd` 檢查：
- 專案預設啟動場景指向測試選單；
- 兩個原型場景存在；
- 選單產生兩個對應的啟動按鈕和說明文字。

GitHub Actions 的 Godot 4.3 headless workflow 會執行這項 smoke test。它只能驗證場景資源、選單結構與啟動設定，不能取代圖形介面、GPU、輸入裝置或 iPhone 實機測試。
