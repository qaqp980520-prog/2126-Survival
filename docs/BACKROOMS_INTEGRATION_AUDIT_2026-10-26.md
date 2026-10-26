# 後室原型整合稽核 — 2026-10-26

## 範圍
檢查根目錄 Godot 4 後室傳送門遊玩場景、程序化迷宮、第一人稱控制、共用背包橋接、世界存檔與現有 headless 測試。這份紀錄區分靜態檢查與 CI 實測結果，不把程式碼提交視為遊戲已實測。

## 本輪發現並修正

### 1. 迷宮區塊索引與實際邊界不一致
- 問題：格子以每個整數座標乘以 CELL_SIZE 作為中心，但串流中心原先使用 floor(position / CELL_SIZE)，導致在 x/z = ±4m 等實際半格邊界處，載入／卸載格子會晚半格。
- 修正：新增 `_maze_cell_for_position()`，改用 `floor((position + CELL_SIZE * 0.5) / CELL_SIZE)`。
- 回歸測試：涵蓋正負半格邊界附近的座標。

### 2. 後室內仍可能生成主世界傳送門
- 問題：世界控制器即使在 Backrooms 仍呼叫傳送門 director，計時到期後可能在迷宮座標內生成原本只應在地表出現的傳送門。
- 修正：只有在 Surface 狀態才推進自然傳送門生成計時器。
- 回歸測試：進入 Backrooms 後將計時器設為零，確認不會生成新的地表傳送門。

### 3. 存檔可帶有互相矛盾的世界狀態
- 問題：載入資料可同時標記玩家位於 Backrooms，卻帶著尚未消耗的主世界傳送門。
- 修正：在改動遊戲狀態前拒絕此不一致的存檔。
- 回歸測試：提交一份有有效傳送門 ID／座標、但標記在 Backrooms 的存檔，確認拒絕且既有背包不被改動。

### 4. 共用背包尚未影響玩家移動
- 問題：SurvivalWorldBridge 能計算負重，但玩家控制器先前仍用固定移動速度與無條件跳躍，造成背包規則沒有真正整合到遊玩流程。
- 修正：遊玩場景將 bridge 綁定至玩家控制器；移動速度讀取負重倍率，超過超重門檻時禁止開始跳躍。
- 回歸測試：40 個 rock 造成超重時速度倍率應為 0.42 且不能跳；丟棄 15 個 rock 後重量降至門檻以下，速度與跳躍立即恢復。

### 5. 共享牆面重複碰撞體與迷宮單調
- 修正：共享格子邊界由單側牆體擁有；加入座標決定的內部隔牆與 OmniLight3D，保留隔牆端部通路。
- 回歸測試：驗證相鄰格子的通道開口判定對稱，以及 7×7 格子都可沿生成樹連通到原點。

### 6. 自動驗證未在 main push 時觸發
- 修正：`.github/workflows/godot-validation.yml` 將 `main` 加入 push 觸發分支，讓直接提交也會跑 Godot headless 驗證。
- 驗證流程包含後室 portal director、portal scene、playground 整合測試與共用系統測試。

## 本輪新增／更新檔案
- `prototypes/BackroomsPortalPlayground.gd`
- `prototypes/BackroomsPlayerController.gd`
- `tests/backrooms_portal_playground_test.gd`
- `.github/workflows/godot-validation.yml`

## 驗證狀態
- 靜態檢查：已檢查相關腳本、場景與測試的整合介面。
- 迷宮拓樸：獨立驗證程式確認 7×7 區域 49 格皆可從原點連通；這不等於 Godot 執行測試。
- Godot 4 headless CI：等待本輪最新 main commit 的 workflow 結果；只有成功完成後才能標示為已通過。
- 尚未完成：圖形模式人工遊玩、真實滑鼠與全螢幕行為、iPhone 實機測試、完整正式世界生成器與礦脈 chunk controller 的場景級連接。

## 架構界線
- `SurvivalWorldBridge` 已接到後室遊玩場景的玩家負重與背包流程。
- `MineralChunkController`／`MineralVeinRegistry` 是共用礦脈 chunk 生命週期系統，仍需由正式世界生成器呼叫載入／卸載；不應假裝它已自動接入所有獨立小遊戲。
- `daily_games/*` 的小遊戲保留獨立 Godot 專案，除非明確需要共用核心系統，否則不應把不同玩法硬塞進同一個執行場景。
