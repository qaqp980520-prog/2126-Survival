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


## Run 8 update — 2026-10-26 — Mineral Chunk Controller + KROLL Pulse Rhythm

- Working branch: `feature/kroll-pulse-rhythm-mineral-chunk-controller-m0-1-2026-10-26`; base `main` at `9d2554c8e02ff5b4fa2528697d98b1a5a30700d2`.
- New survival controller: `systems/MineralChunkController.gd` owns instantiated chunk-root lifetime, discovers nested `MineralMiningNode` nodes using stable scene-name paths, connects them through `MineralChunkLifecycleAdapter`, and delegates mineral save/restore to `MineralVeinRegistry`.
- New regression test: `tests/mineral_chunk_controller_test.gd` covers save -> unload -> registry restore -> reload with elapsed regeneration, empty chunks, and duplicate chunk ID rejection.
- New mini-game: `daily_games/KROLL_Pulse_Rhythm/` (Godot 4.3, no external assets): four-lane rhythm timing, 32 authored notes, PERFECT/GOOD/MISS scoring, five reactor cores, keyboard and lower-screen touch input.
- New validation: `.github/workflows/godot-validation.yml` now checks the new project files, imports Pulse Rhythm, runs its rules and scene smoke tests, and runs the mineral chunk controller integration test with explicit success markers and runtime-error guards.
- Documentation: `docs/MINERAL_CHUNK_CONTROLLER_M0_1_2026-10-26.md`.
- Validation status at branch creation: no local Godot binary is available. Static source review only so far; remote Godot 4.3 CI must pass before merge. No GUI playtest or iPhone device test is claimed.
- At the time of this original feature-branch index commit, PR #39 had not yet been opened; it was subsequently opened, fully validated by Run #115, and merged into main as `1b48e11f1638e56d63263fa3ed6cb37fd9106624`.
- Integration limit: this controller owns instantiated chunk roots provided by a world generator, but does not yet perform distance-based spatial selection, asynchronous scene loading, or procedural world generation. It is the first lifecycle owner, not a complete streaming engine.
- Next: inspect the complete diff, run the new CI, fix any actual failures on this branch, and only merge after the full regression suite passes. Then reconcile the Notion asset index with the resulting PR/commit/test IDs.

## Run 8 validation update — 2026-10-26

- PR #39 was merged into `main`: https://github.com/qaqp980520-prog/2126-Survival/pull/39. Merge commit: `1b48e11f1638e56d63263fa3ed6cb37fd9106624`.
- Initial full CI Run #113 (40284210713) failed at controller compilation because the new script referenced its own global class name in the ID check. Fixed in commit 052ff685d27cd0e7007d36c41ee23c59756f3b09 by calling the preloaded adapter's static ID builder.
- Full Godot 4.3 CI Run #114 (40284396621) then succeeded. Required steps 1–35 all passed; explicit success markers were present for Pulse Rhythm rules tests, Pulse Rhythm runtime smoke test, and mineral chunk controller integration test. Job logs showed no actual Godot script/runtime error output.
- The feature-branch index update was validated by final-head Godot 4.3 CI Run #115 (`40284605381`) before PR #39 merged. Run #115 passed; required steps 1–35 succeeded, including the new rhythm and chunk-controller tests.
- Current limitations remain: no local Godot binary, no GUI/iPhone playtest, and no distance-based or asynchronous chunk selection. Controller owns chunk roots supplied by the world generator; integration into the production world generator remains a separate step.

## Run 8 final mainline reconciliation — 2026-10-26

- PR #39 is merged; mainline merge commit is `1b48e11f1638e56d63263fa3ed6cb37fd9106624`.
- Validating run on the exact PR head before merge: Godot 4.3 CI Run #115 (`40284605381`) success; all required steps 1–35 passed. The merge commit has the same tree as the validated PR head.
- This reconciliation was PR #40, merged as `349ff77f2fcd2e2ac136d2dc8432793408c883a7` after Godot 4.3 CI Run #116 (`40284833278`) passed with 38 steps and zero failures.
- Remaining: connect `MineralChunkController` to the actual production world generator; no distance-based chunk selection, async streaming, GUI playtest, or iPhone test is claimed.


## 2026-10-26 Run 9 — merged and validated
- KROLL Hydroponics Shift M0.1: standalone Godot 4.3+ crop-care arcade game in daily_games/KROLL_Hydroponics_Shift/; three beds, moisture/growth simulation, ten-harvest target, keyboard and touch controls; no external assets.
- MineralChunkController M0.1.1: failed registration detaches but preserves the caller-owned root. Integration tests cover duplicate stable-ID load preservation and rollback when a later vein unregister fails.
- Code head `92568e240abe1bd25149bba5a8da47d41ab451ce` passed Godot 4.3 CI Run #123 (`40290454611`); all 38 required validation steps succeeded, zero failures.
- Final pre-merge head `9c519e47b4e77fcf53392647716fcd4db03c04ab` passed Run #126 (`40291085414`); all 38 required validation steps succeeded, zero failures, including Hydroponics import/rules/runtime smoke and MineralChunkController integration tests.
- PR #42 merged to main as `e0545d7a5bcd7a2bb44e810ca6d56d8fef4b93c0`. Current index reconciliation is a docs-only follow-up PR; do not confuse it with the already merged feature PR.
- Limits: formal world generator integration, distance/asynchronous streaming, manual GUI play and iPhone testing remain incomplete.


## 2026-10-26 Run 9 — Backrooms integration audit
- Audit report: [docs/BACKROOMS_INTEGRATION_AUDIT_2026-10-26.md](docs/BACKROOMS_INTEGRATION_AUDIT_2026-10-26.md).
- Fixed maze streaming cell indexing to align with the actual half-cell wall boundaries; added coordinate-boundary regression cases.
- Natural portal director now ticks only on the Surface; added a regression test to prevent portal spawning inside Backrooms.
- World-save restore rejects a state that combines a Backrooms location with an active surface portal, before mutating live inventory/world state.
- Bound the playground player's movement and jump permissions to SurvivalWorldBridge weight calculations; regression tests cover super-heavy movement slowdown and immediate recovery after dropping items.
- Removed duplicate shared-edge wall collision bodies, added deterministic corridor baffles and ceiling OmniLight3D nodes; topology tests cover edge symmetry and 7×7 connectivity.
- Enabled Godot headless validation on pushes to `main` so direct commits receive automated checks.
- Current status: changes committed to main; latest Godot headless CI result must be checked before claiming engine validation passed. Graphical manual playtest and iPhone test remain outstanding.

- Camera/avatar follow-up: root prototype now has a visible primitive humanoid in third-person mode and `V` toggles first-person mode; first-person hides the avatar to prevent camera clipping. Headless camera-toggle regression coverage is included in `tests/backrooms_portal_playground_test.gd`.


## 2026-10-26 Run 11 — Sentinel Escape + persistent shadow settings + mineral streaming reconciliation
- Current implementation branch merged: PR #49; merge commit `2cca29d30481a3943e07600cf4b73a757f7ea976`. Parent/main base before merge: `2d7f346f1d7d199278f4e5896c1fdb506d850a55`.
- Exact implementation head `d4dc2fa58274e30d82d48cf647aa9124fc014aae` passed Godot 4.3 CI Run #181 (`40316093821`) before merge. Verified success markers include settings profile/integration, MineralGridStreamingDirector, Signal Siphon rules/runtime, and Sentinel Escape rules/runtime tests.
- KROLL Sentinel Escape: `daily_games/KROLL_Sentinel_Protocol/`; collect 8 energy cells, avoid security drones, short nonviolent dash; keyboard/touch paths; no external assets. The README-listed Space dash was found missing from the keyboard input path and fixed in PR #51, merge commit `fb08be72eb0f68be75b352bb73e4ec715030f4c8`; exact-head CI Run #185 passed with explicit dash timer/cooldown assertions.
- KROLL Signal Siphon remains included at `daily_games/KROLL_Signal_Siphon/`.
- Backrooms settings persistence now saves camera mode, mouse sensitivity, and shadow/graphics quality. Fluorescent flicker is automatic (no user toggle); legacy `flicker_enabled` config keys are ignored. The shadow-quality toggle controls deterministic local shadows and procedural detail.
- MineralGridStreamingDirector and its explicit CI test are included; still synchronous/factory-driven and not wired to the production world generator.
- Superseded PR #46, #47, #48 are closed without merge. PR #49 is merged.
- Main push CI Run #182 (`40316354828`) completed successfully; exact-head PR CI Run #181 also succeeded before PR #49 merge.
- Local GUI/manual play, GPU shader compilation check, and iPhone device test remain unverified.


## 2026-10-26 Run 11 — Consolidated integration/audit references
- [Branch-first integration workflow](docs/BRANCH_AND_INTEGRATION_WORKFLOW.md)：分支、差異審查、測試、合併與 Notion 同步規則。
- [Cross-version integration regression matrix](docs/INTEGRATION_REGRESSION_MATRIX.md)：更新至目前 main 狀態，區分已通過 CI 的原型與尚未接入的正式 M1.3 世界。
- [Inventory/save schema compatibility review](docs/INVENTORY_SAVE_SCHEMA_COMPAT_REVIEW_2026-10-25.md)：把舊靜態發現標記為已修正或仍待正式世界整合，附 Run #181 證據。
- [M1.3 inventory integration boundary](docs/M1_3_INVENTORY_INTEGRATION_BOUNDARY_2026-10-25.md)：保留正式世界控制器缺席與單一資料來源接線的阻斷條件。
- These four documents were consolidated from stale draft PRs #1/#2/#6/#8 after reviewing and updating their content against current main. They are reference/audit documents, not evidence that the full M1.3 world is integrated.
- PR #50 merged as `f6732519736697725a612e4c3a1a8836591c7aaa`; PRs #1/#2/#6/#8 were closed without merge after their documentation was consolidated and updated here.

- PR #51 keyboard dash fix merged as `fb08be72eb0f68be75b352bb73e4ec715030f4c8`; exact-head Godot 4.3 CI Run #185 (`40316901157`) succeeded with explicit dash timer/cooldown assertions.
- Current main after the documentation consolidation is `f6732519736697725a612e4c3a1a8836591c7aaa`. Main push CI Run #188 (`40317515975`) is pending at the time of this index update; the PR-level exact-head CI Run #187 succeeded before the docs merge.
- GitHub open PR list was empty after closing superseded drafts #1/#2/#6/#8 and old feature branches #46/#47/#48.


## Run 12 external-state correction and candidate — 2026-10-26

- Cross-chat source check found the previous Run 11 Notion closeout recorded main as f11ec700d57394b79b5ea73df2079e8794fe7a1f, but the actual GitHub main ref now resolves to 45d84ffd3990cbe16f56f4bc06ad3c4c94b78584 (commit message: “Use simple SVG wallpaper pattern compatible with Godot SVG importer”).
- GitHub compare main...f11ec700 reports main is 18 commits ahead of the previous closeout SHA. The fetched PROJECT_INDEX was not updated to reflect this later main history; this section supersedes prior “current main” statements for present-day state without rewriting their historical context.
- At run start, GitHub API returned no open PRs. The main commit combined-status endpoint returned an empty status list; this is not treated as a successful CI result.
- Candidate branch: feature/run12-reactor-balance-streaming-rollback-2026-10-26, created from actual main SHA 45d84ffd3990cbe16f56f4bc06ad3c4c94b78584.
- New mini-game: daily_games/KROLL_Reactor_Balance/ — three-reactor output/heat balancing game, 60-second round, keyboard and mouse/touch input; no external assets.
- Survival fix: systems/MineralGridStreamingDirector.gd now records stale chunks unloaded during a sync; if a later stale unload fails, it rolls back newly loaded chunks and attempts to recreate prior stale chunks via the factory with the same stable IDs. An incomplete rollback emits push_error and returns failure.
- Regression test: tests/mineral_grid_streaming_transaction_test.gd with tests/helpers/FakeMineralChunkController.gd injects failure on the second stale unload and checks the original 3x3 active set is restored.
- Workflow additions: import + rules + runtime smoke tests for Reactor Balance and an explicit transactional rollback test; all use explicit success markers and error guards.
- Design note: docs/MINERAL_GRID_STREAMING_ROLLBACK_M0_1_2026-10-26.md.
- Validation at this index edit: source files have been committed to the candidate branch, but exact-head remote Godot 4.3 CI has not yet completed. Do not merge before all required steps pass. No local Godot binary, GUI playtest, GPU check, or iPhone test is claimed.
- Known rollback limit: if the chunk factory repeatedly fails while recreating stale chunks, complete restoration cannot be guaranteed; the director reports the rollback failure. This is a synchronous prototype, not production world streaming.
