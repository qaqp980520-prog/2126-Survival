# 每日手搓遊戲計畫｜2026-10-26 Run 4

## 本輪工作目標

- 新增與近期玩法不同的小遊戲：KROLL Gravity Lander。
- 將後室入口 director、3D portal visual、共用背包橋接與世界存檔轉接器接到一個可啟動的 3D 測試場景。
- 確認保留原本垂直環姿態，修正入口中心高度，並處理世界切換的碰撞隔離。
- 更新 Godot CI，讓新遊戲和端到端場景一起測試。
- 不在 CI 未通過前合併 MAIN。

## 產物

- daily_games/KROLL_Gravity_Lander/
- project.godot
- prototypes/BackroomsPortalPlayground.tscn
- prototypes/BackroomsPortalPlayground.gd
- prototypes/BackroomsPlayerController.gd
- tests/backrooms_portal_playground_test.gd
- systems/BackroomsPortalVisual.gd / .tscn
- tests/backrooms_portal_scene_test.gd
- docs/BACKROOMS_PORTAL_PLAYGROUND_M0_1.md

## 實際測試結果

- GitHub Actions Godot 4.3 run #32：成功，PR head `85fd6345029a2aef9a8e0d7236eae586c6a001cd`。
- 通過項目：Signal Sweep／Orbital Convoy／Gravity Lander 匯入、規則與 smoke tests；portal director、visual scene、playground 端到端存讀檔與碰撞隔離；既有 inventory save validation、save adapter 與 world bridge 整合回歸。
- PR #16 已合併，main commit `9f2ff2e03d972f067125d1fe7129200cd1913452`。
- 本機沒有 Godot 執行檔，未聲稱本機引擎測試通過；手動視覺、碰撞手感、iPhone 實機仍未驗證。

## 狀態規則

- 本機沒有 Godot 執行檔，不能宣稱本機引擎測試通過。
- 只在 PR head 的 Godot 4.3 CI 完成且成功後，才將引擎測試狀態更新為通過。
- 手動遊玩、實際視覺、碰撞與 iPhone 測試仍需另外確認。
