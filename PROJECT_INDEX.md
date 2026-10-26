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
- [M1.3.4 世界狀態欄位驗證補強](patches/M1_3_4_WorldStateValidation.patch)：要求作物記錄具有有效三維座標，驗證文字與成熟狀態型別；尚未經 Godot 4 測試。
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


## 2026-10-26 Run 4 — 新增原型
- KROLL Gravity Lander：daily_games/KROLL_Gravity_Lander/；獨立 Godot 4.3+ 專案，含規則測試與場景 smoke test。PR #16 的 Godot 4.3 CI run #32 已通過；iPhone 實機尚未測試。
- Backrooms Portal Playground：根目錄 project.godot + prototypes/BackroomsPortalPlayground.tscn；將 portal director、3D portal visual、共用 SurvivalWorldBridge、save adapter 串成可啟動的整合測試場景。這是測試場，不代表正式 M1.3 world.gd 已接線。
- 後室入口視覺修正：保留原場景 90° X 軸旋轉以維持垂直 ring，入口中心提高至地面上方 1m；新增 scene test 覆蓋姿態與位置映射。

## 2026-10-26 Run 5 — Core Defense + shared inventory binding
- KROLL Core Defense：`daily_games/KROLL_Core_Defense/`；獨立 Godot 4.3+ 塔防小遊戲，含規則測試與場景 smoke test。玩法為點擊格子部署砲塔、三波無人機路線防守；無外部素材。
- SurvivalWorldBridge binding fix：新增 `bind_inventory()`，保留進入 SceneTree 前注入的共用背包，並拒絕缺少必要方法的物件；新增 `tests/world_bridge_binding_test.gd` 覆蓋 ready 前／後綁定與無效替換回歸。
- CI：`.github/workflows/godot-validation.yml` 新增 Core Defense 匯入、規則測試、場景 smoke test 與 bridge binding lifecycle 測試。
- 分支：`feature/kroll-core-defense-bridge-binding-2026-10-26`；PR #18 已合併至 main，merge commit `7ab6a6f14aaff0bd3b65cb72f782442394f7c05b`；Godot 4.3 CI run #34 全部驗證步驟成功。
- 本機沒有 Godot 執行檔；Run 5 程式碼已合併 main，Godot 4.3 引擎驗證證據為 PR #18 的 CI run #34。


## 2026-10-26 Run 6 — KROLL Freight Sorter M0.1（已驗證／已合併）
- 小遊戲路徑：daily_games/KROLL_Freight_Sorter/；60 秒貨物分流反應遊戲，原礦／醫療／資料核心分流至對應倉口，危險貨箱必須隔離；無外部素材。
- 包含 project.godot、main.tscn、main.gd、rules.gd、規則測試、場景 smoke test、README。
- PR #25 已合併，commit `8baf8a7653ec8a255c159e6fd1c4b3a24c1afe21`；Godot 4.3 CI Run #44 success，29 個主要步驟全部成功。
- 本機沒有 Godot 執行檔；尚未進行人工視覺或 iPhone 測試。


## 2026-10-26｜離線礦脈再生 M0.1（已驗證／已合併）
- 修改：systems/MineralMiningNode.gd；schema 升至 v2，新增 max_units、regen_interval_seconds、last_regen_unix，支援依 Unix 時間進行線上／離線再生、保留部分間隔、容量上限與時鐘倒退防護。
- 相容：仍接受舊 schema-v1 存檔；缺少再生欄位時從載入時間開始計時。無效 schema、容量、間隔、時間戳或存量會在改動狀態前拒絕。
- 測試：tests/mineral_catalog_test.gd 新增離線回補、部分間隔、容量上限、時鐘倒退、schema-v2 往返、舊 schema-v1 相容與無效資料拒絕。
- 文件：docs/MINERAL_VEIN_OFFLINE_REGENERATION_M0_1_2026-10-26.md。
- PR #28 已合併 main，commit `4990b15700654bbadeac29784662c2e7b9a58bf8`；Godot 4.3 CI Run #55 success，31 個 workflow steps 全部成功。
- 舊候選 PR #26、#27 已關閉且未合併；Run #45／#50 為舊候選紀錄，Run #53／#54 cancelled，不作為成功證據。


## 2026-10-26｜未知物品負重防禦 M0.1（已驗證／已合併）
- 修改：systems/SurvivalInventory.gd 新增 UNKNOWN_ITEM_WEIGHT_KG=1.0；total_weight_kg() 對直接注入 public counts 的未知 key 不再預設為 0kg。
- 相容：已登錄物品重量不變；constructor、add_item()、load_save_dict() 仍拒絕未登錄 ID，存檔驗證失敗不會部分改動狀態。
- 測試：tests/inventory_weight_boundaries.gd 新增未知 key 防禦性計重、未知 ID API 拒絕與無效存檔狀態保留測試。
- PR #30 已合併 main，commit `9e05c47dc91a361aee4e49af7304ca812a802b06`；Godot 4.3 CI Run #57 success，31 個 workflow steps 全部成功。
- PR #3 已關閉為 superseded；其嚴格存檔驗證已在 main，剩餘未知重量 fallback 由 PR #30 完成。
- 限制：1.0kg 只作防禦性 fallback；正式物品仍需登錄 ITEM_WEIGHTS。counts 仍是公開字典，長期可考慮封裝存取。


## 2026-10-26 Run 7 — Mineral registry streamed-chunk persistence M0.2 (verified and merged)
- PR #34 is merged to main as 14869cffd543d8d33dec427fb84ddb493e206fc6.
- Exact merged head e6a55bcec7a160a1ae8fd27a295deae661f9d58e passed Godot 4.3 shared CI Run 40276109216 on base 6c6f2779541175b3cc372d3cb73319ceac98f354. All 33 workflow steps succeeded; guarded logs contained no actual SCRIPT ERROR, ERROR:, or FAIL output.
- Mineral registry behavior: systems/MineralVeinRegistry.gd retains records for unloaded chunk IDs; unregister captures final state; register restores by stable ID; saved IDs are deterministic; invalid restore payloads are rejected before mutation; same-node registration is idempotent; disabling offline catch-up resets the clock so the next _process() cannot apply skipped time.
- Regression files: tests/mineral_catalog_test.gd and tests/mineral_vein_chunk_stream_test.gd. The dedicated step printed “Mineral vein chunk-stream persistence tests passed.” and the catalog step printed “Mineral catalog regression tests passed.”
- Workflow guard: .github/workflows/godot-validation.yml rejects SCRIPT ERROR, ERROR:, and FAIL output and requires explicit success markers.
- Design note: docs/MINERAL_VEIN_CHUNK_STREAM_PERSISTENCE_M0_2_2026-10-26.md.
- Related verified changes: PR #35 strict Variant typing fix merged as 6c6f2779541175b3cc372d3cb73319ceac98f354 (Run 40275478307 success); PR #36 KROLL Magnetic Pinball M0.1 merged as abe695c08adc26b699033d9d500dadd98fcb8b64 (dedicated Run 40275642300 and shared Run 40275642253 success). PR #33 was closed without merge as superseded.
- Limit: the formal world/chunk streaming controller is not yet present; its lifecycle still needs to call registry register/unregister with deterministic IDs. No local Godot binary, graphical manual playtest, or iPhone device test is claimed.
- Next step: integrate the registry into the actual world/chunk load-unload lifecycle, then add a scene-level integration test covering chunk unload, save/load, and world travel.
- Old documentation PRs #1, #2, #6, and #8 remain open and are not claimed as merged.
