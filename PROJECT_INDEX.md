# 2126 Survival — 開發資產索引

這個儲存庫用於保存《2126 Survival》的程式碼與原型版本。

## 專案原則
- 引擎：Godot 4
- 類型：跨平台 3D 生存遊戲（PC／iPhone 目標）
- 世界觀：西元 2126 年；KROLL、軍閥與野區並存；後室傳送門可能出現在主世界。
- 每次更新應記錄版本、變更、檔案、測試狀態與已知限制。

## 重要驗證規則
本索引不代表所有原型都已上傳或測試。每個版本必須以實際提交紀錄與引擎測試結果為準。未在 Godot 4 執行的版本會明確標示「尚未在 Godot 4 實測」。

## 開發追蹤
- [M1.3.3 存檔欄位驗證修補](patches/M1_3_3_SaveValidation.patch)：讀檔前驗證版本、背包數量、快捷欄、座標與作物狀態欄位；尚未經 Godot 4 測試。
- [M1.3.2 合併後靜態複核](docs/M1_3_2_STATIC_REVIEW_2026-10-25.md)：核對 M1.3.1 作物存檔與 M1.3.2 重複讀檔修補的整合關係，列出尚未測試的風險。
- [M1.3 跨系統整合檢查清單](docs/INTEGRATION_CHECKLIST_M1_3.md)：追蹤存檔修補、共用背包、世界互動與回歸測試之間的依賴。
- [M1.3.2 重複讀檔整合修補檔](patches/M1_3_2_IdempotentWorldRestore.patch)：避免重複載入時複製動態作物／玩家種植作物，並將標籤設為作物子節點；尚未在 Godot 4 實測。
- [M1.3.1 世界作物存檔修補檔](patches/M1_3_1_WorldCropPersistence.patch)：補上種植作物、野生作物重生倒數與已採集固定作物的存檔資料；僅為 patch，尚未在 Godot 4 測試。
- [程式碼稽核與強制驗證流程](docs/CODE_AUDIT_2026-10-25.md)：第一輪靜態檢查、已知問題與後續測試順序。
- [開發問題與待辦清單](docs/DEVELOPMENT_ISSUES.md)：整合、測試、跨平台與資產保存待辦。

## 共用系統
- [SurvivalWorldBridge.gd](systems/SurvivalWorldBridge.gd)：世界拾取、採礦產出、丟棄、負重查詢與存檔接口橋接（M0.2；尚未接入既有遊戲場景，尚未在 Godot 4 實測）。[整合說明](systems/INTEGRATION_M0_2.md)
- [SurvivalInventory.gd](systems/SurvivalInventory.gd)：背包數量、重量、負重倍率與存檔字典服務（M0.1；尚未在 Godot 4 實測，也尚未替換既有原型實作）。

## 專案分類
- [歷史原型與資產目錄](docs/HISTORICAL_ASSET_CATALOG.md)：依世界／後室、背包與收藏室、KROLL、採礦、每日小遊戲分類，並註明整理原則。

## 上傳狀態
- 已提交：專案索引與歷史資產目錄。
- 已上傳原始 ZIP（提交已核對）：
  - [KROLL Circuit Relay（2026-10-21）](releases/mini-games/KROLL_Circuit_Relay_Godot4_2026-10-21.zip)
- 已上傳原始程式檔（非 ZIP）：
  - [KROLL Drone Rescue 原始專案檔](prototypes/KROLL_Drone_Rescue/README.md)（project.godot、main.tscn、main.gd、README 已分別提交；原始 ZIP 不在此資料夾）
  - [KROLL Signal Runner 原始專案檔](prototypes/KROLL_Signal_Runner/README.md)（project.godot、main.tscn、scripts/game.gd、README 已分別提交；原始 ZIP 不在此資料夾）
  - [Ore Shift 採礦小遊戲原始專案檔](prototypes/Ore_Shift/README.md)（project.godot、main.tscn、scripts/main.gd、README 已分別提交；原始 ZIP 不在此資料夾）
- [Portal Courier 原始專案檔](prototypes/Portal_Courier/README.md)（project.godot、main.tscn、scripts/game.gd、README 已分別提交；原始 ZIP 不在此資料夾）。
- 尚未完成：工作區中其餘原始 ZIP 與模型的二進位檔上傳。歷史目錄中的其他檔名不代表已進入 GitHub。
- 測試狀態：現有原型不能一概視為已在 Godot 4 實測。

## 版本索引
- KROLL Circuit Relay：提交 `6b46c1e5e6549e0ae5f827f3b1580281c55fb12a`；ZIP 已上傳，尚未在 Godot 4 實測。
- KROLL Drone Rescue：原始專案文字檔已分別提交；README、project.godot、main.tscn、main.gd；尚未在 Godot 4 實測。
- KROLL Signal Runner：原始專案文字檔已分別提交；README、project.godot、main.tscn、scripts/game.gd；尚未在 Godot 4 實測。
- Ore Shift：原始專案文字檔已分別提交；README、project.godot、main.tscn、scripts/main.gd；尚未在 Godot 4 實測。
- Portal Courier：原始專案文字檔已分別提交；README、project.godot、main.tscn、scripts/game.gd；尚未在 Godot 4 實測。
- SurvivalInventory 共用背包服務 M0.1：`18777282039f1f5fab8427bee71b2163ddb22549`；程式與說明文件已提交，尚未在 Godot 4 實測，尚未整合進 M1.3 原型。
- SurvivalWorldBridge 橋接接口 M0.2：`732f32ed09db88b66d5304e4b61f8204b8b91b7d`；橋接腳本與整合說明已提交，尚未接入既有場景或在 Godot 4 實測。
- 新版本完成並實際提交後，繼續新增對應路徑與提交資訊。
