# 《2126 Survival》主線入口與測試 Hub 邊界

原始文件日期：2026-10-27  
本次依目前 main 原始碼校正：2026-11-09

## 1. 唯一權威啟動入口

目前根目錄 `project.godot` 設定：

```ini
[application]
run/main_scene="res://world/SurfaceWorld.tscn"
```

因此，從 Repository 根目錄開啟專案並按下執行，會直接進入 `world/SurfaceWorld.tscn`。`prototypes/SurvivalTestHub.tscn` 不是專案預設啟動場景。

來源快照：main `fbf2b8a971cd5ff04946b0e0316da6576c685b5e`。

## 2. SurfaceWorld 實際初始化路徑

`world/SurfaceWorld.tscn` 是掛載 `world/SurfaceWorld.gd` 的最小 `Node3D` 場景。主腳本在 `_ready()` 中：

1. 呼叫 `initialize_world_session()`，建立共用世界 Session、Director、Controller 與背包橋接。
2. 連接地表非同步串流完成訊號及背包變更訊號。
3. 建立 WorldEnvironment 與 DirectionalLight3D。
4. 建立 CharacterBody3D 玩家、膠囊碰撞體及 Camera3D。
5. 建立 HUD、互動提示、觸控按鈕與串流診斷面板。
6. 執行初始地表 Chunk 同步。
7. 建立並註冊地下礦坑 Chunk 與入口視覺。

目前主世界已串接地表 Chunk 串流、礦物互動、作物、打撈箱、共用背包、體力、快捷使用及地下礦坑入口。這是可執行的 3D 生存系統原型，不代表 KROLL 設施、軍閥領地、完整野外生態、後室層級與大型世界內容都已完成整合。

### SurfaceChunkFactory 的實際 Chunk 結構

`systems/SurfaceChunkFactory.gd` 使用 10m × 10m Chunk，並建立：

- 一個 Ground StaticBody3D 與碰撞形狀；非 Headless 執行時另建立地面 Mesh。
- 七個 SurfaceTerrainPatch。
- 一個地下位置的 Ore 節點（Chunk local y = -3）。
- 一個 SalvageCrate。
- 兩個 CropPlot 場景。

不要把地表互動與地下採礦混為一談：礦物節點位於地面以下，正式採礦入口由 SurfaceWorld 的地下礦坑流程管理。

## 3. 目前 main 的玩家視覺邊界

main 的 `SurfaceWorld.gd` 目前以 CharacterBody3D、CapsuleShape3D、執行時 CapsuleMesh（非 Headless）及 Camera3D 建立玩家。這不是完整的 KROLL 裝備視覺骨架。

PR [#275 — SurfaceWorld player visual/locomotion and mobile input](https://github.com/qaqp980520-prog/2126-Survival/pull/275) 包含額外的程序化玩家視覺、移動姿態與觸控視角工作，但該 PR 仍未合併；不可把 PR 內容描述成目前 main 已有功能。實際整合前仍須完成獨立審查及必要的裝置 QA。

## 4. SurvivalTestHub 的正確定位

`prototypes/SurvivalTestHub.tscn` 是可選的 Control 型開發／測試入口，不是根專案的啟動場景。

- SurfaceWorld 的鍵盤 F10 路徑會返回 `prototypes/SurvivalTestHub.tscn`。
- Hub 提供主世界、地表串流原型、地下採礦原型、後室傳送門原型及既有歷史遊戲的啟動入口。
- `tests/survival_test_hub_smoke_test.gd` 明確驗證根專案 main scene 指向 `SurfaceWorld.tscn`，並驗證 Hub 有垂直 ScrollContainer 及 50 個啟動按鈕。

因此，Hub 的存在及其按鈕數量不會改變專案真正的預設啟動場景。

## 5. daily_games 舊資產凍結界線

Repository 內既有 `daily_games/` 內容保留為歷史／舊版資產：

- 不新增獨立小遊戲。
- 不增加 Hub 的歷史遊戲入口。
- 不把舊遊戲列為每日交付或主線工作。
- 不因凍結政策而批次刪除既有檔案；若未來需要整理，應另行評估依賴與回歸影響。

Hub 目前仍引用部分舊遊戲場景，是既有選單內容，不代表它們是目前的開發優先事項。

## 6. 匯入與驗證

- 引擎基線：Godot 4.3。
- 匯入方式：以 Repository 根目錄的 `project.godot` 開啟專案，執行正常資源匯入。
- 本文件校正依據：GitHub main 的 `project.godot`、`SurfaceWorld.tscn`、`SurfaceWorld.gd`、`SurfaceChunkFactory.gd`、`SurvivalTestHub.gd` 與 Hub smoke test 靜態讀取。
- `tests/survival_test_hub_smoke_test.gd` 的既有 CI 覆蓋啟動場景設定、場景存在性、Hub 捲動容器及 50 個按鈕契約。
- 本次文件更新沒有在本機執行 Godot；不能把本次靜態文件檢查說成新的引擎測試。
- Headless CI 不驗證 GPU 畫面品質、實際觸控手感、iPhone 安全區或裝置效能。

## 7. 待完成事項

1. 保持既有玩家、Mineral Grid 與地形 PR 的父子依賴順序，取得獨立審查後再整合。
2. 在 Issue [#288](https://github.com/qaqp980520-prog/2126-Survival/issues/288) 的父分支審查條件滿足後，實作真實四向 Corner Cap 生產生命週期測試。
3. 更新過期文件時，以實際 main 原始碼和精確 commit 為準；不要把歷史 Hub 說明覆蓋成目前啟動設定。
4. 將開發資源集中於主世界、地表／地下串流、玩家操作與生存系統；daily_games 維持凍結。

## 8. 本次修訂來源

- `project.godot`: blob `bcbe4cfddefa70571cb74d8649a25a4ae229908b`
- `world/SurfaceWorld.tscn`: blob `2baa949c5d4a31b4ab7c65757d43e828fba183ba`
- `world/SurfaceWorld.gd`: blob `bf665aa4500fab46ade416a29b438c765d82faaa`
- `systems/SurfaceChunkFactory.gd`: blob `499c83c3136497cb0e62ec513e91b6c53e86fe9f`
- `prototypes/SurvivalTestHub.gd`: blob `3b2e4a47d2ff8089106e503c0f96b5ba1a275b13`
- `tests/survival_test_hub_smoke_test.gd`: blob `288dfc0e80434c1979abe9431ba23743f8d6ec41`
