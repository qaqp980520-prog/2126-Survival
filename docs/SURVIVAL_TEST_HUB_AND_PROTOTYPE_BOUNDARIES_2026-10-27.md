# 《2126 Survival》目前可執行原型與測試入口

更新日期：2026-10-27

## 啟動方式

根目錄的 `project.godot` 現在會先啟動 `prototypes/SurvivalTestHub.tscn`。選單提供三個原型入口：

1. **地表探索／區塊與礦物串流** — `prototypes/SurfaceChunkStreamingPlayground.tscn`
2. **地下礦坑／採礦與共用背包** — `prototypes/UndergroundMiningPlayground.tscn`\n3. **後室傳送門實驗場** — `prototypes/BackroomsPortalPlayground.tscn`

地表原型只負責地表探索與區塊串流。礦脈資料節點已放在地面以下，不可從地表直接開採；真正的採礦互動應放進地下洞穴／礦坑場景，再接入 `SurvivalWorldBridge` 共用背包。新增地下礦坑原型以穩定 chunk ID `underground/cave_0_0` 註冊三種礦脈，支援 F 開採、G 丟棄、礦脈快照還原及即時負重 HUD。`tests/surface_mining_integration_test.gd` 現在改為驗證礦脈位於地面以下，而且地表原型不會直接把礦石放進背包。

在這兩個原型中按 **F10** 回到選單；按 **Esc** 可釋放滑鼠。

## 重要界線

這個選單只是測試入口，不是完整主遊戲。兩個場景目前各自承載不同子系統，並不代表生存流程、地表世界、採集／採礦、後室與所有存檔已經全部整合。不要將原型可啟動誤認為完整遊戲已完成。

## 自動驗證

`tests/survival_test_hub_smoke_test.gd` 檢查：
- 專案預設啟動場景指向測試選單；
- 三個原型場景存在；
- 選單產生三個對應的啟動按鈕和說明文字。

GitHub Actions 的 Godot 4.3 headless workflow 會執行這項 smoke test。它只能驗證場景資源、選單結構與啟動設定，不能取代圖形介面、GPU、輸入裝置或 iPhone 實機測試。
