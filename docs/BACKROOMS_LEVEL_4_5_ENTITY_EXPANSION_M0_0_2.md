# Backrooms Level 4／Level 5 實體擴充 — M0.0.2

## 目標

延續層級限定生成系統，讓傳送門可抵達 Level 4 與 Level 5，並在各層級生成獨立白名單中的實體。Level 1 的既定規則不變：只生成 Window 與 Smiler。

## 層級名單

| 層級 | 允許生成 | 原型機率 |
|---|---|---:|
| Level 0 | 無 | — |
| Level 1 | Window、Smiler | 18%、7% |
| Level 2 | Hound、Skin-Stealer | 8%、5% |
| Level 3 | Clump、Faceling | 6%、8% |
| Level 4 | Duller | 6% |
| Level 5 | Deathmoth | 4% |

機率是每格獨立、由固定座標雜湊決定的原型參數，不代表官方設定或全層級人口密度。未知層級採 fail-closed，不生成實體。

## 實作

- `systems/BackroomsEntityDirector.gd`：增加 Level 4／5 白名單、機率與獨立 hash salt。
- `systems/BackroomsPortalDirector.gd`：傳送門目的地擴充至 Level 0–5；存檔 schema 不變，既有目的地仍有效。
- `prototypes/BackroomsPortalPlayground.gd`：增加 Duller 無面孔人形與 Deathmoth 昆蟲外觀；維持座標決定生成，區塊卸載／重載結果一致。
- 同時修正既有 Clump 原型的高度：根節點由 y=1.0 降至 y=0.42，避免球體群整體懸浮在地面上方。

## 依賴與匯入

- Godot 4.3。
- 依賴既有 `BackroomsEntityDirector`、`BackroomsPortalDirector`、`BackroomsPortalPlayground` 與程序化 MeshInstance3D／StandardMaterial3D。
- Headless 模式不建立實體視覺 MeshInstance3D；層級白名單與確定性生成由獨立 Director 測試驗證，避免 dummy renderer 在區塊卸載時產生無效 mesh 錯誤。圖形模式仍建立完整視覺原型。
- 無外部套件、autoload、Project Settings、場景接線或存檔 schema 變更。
- Repository root 執行：`godot --headless --path . --import`。

## 回歸測試

- `godot --headless --path . --script res://tests/backrooms_entity_director_test.gd`
  - 驗證 Level 0–5 精確白名單、每種實體在固定測試格網可生成、同格重載結果穩定、生成不越界、未知層級 fail-closed。
- `godot --headless --path . --script res://tests/backrooms_portal_playground_test.gd`
  - 驗證傳送門目的地層級清單、Level 3 Clump／Level 4 Duller／Level 5 Deathmoth 外觀實例化，以及 Clump 地面高度。
- PR 會觸發既有 Godot 4.3 headless full compatibility gate。

## 限制與下一步

- 新增實體目前只有靜態視覺原型，尚無巡邏、感知、追逐、互動或傷害 AI。
- Level 0 仍刻意維持空白；Level 6 以後尚未加入名單。
- 仍需圖形模式確認 Deathmoth 翼片材質與 Duller 比例；Headless 測試只驗證層級規則及不建立 render-only meshes，不能取代實際畫面檢查。
- 下一步先驗證本 PR exact-head Godot CI，再擴充 Level 6 以後的層級內容，避免一次把未驗證的實體鋪滿所有層級。
