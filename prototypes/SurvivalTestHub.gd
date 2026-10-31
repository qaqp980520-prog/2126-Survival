extends Control

const WORLD_SCENE := "res://world/SurfaceWorld.tscn"
const SURFACE_SCENE := "res://prototypes/SurfaceChunkStreamingPlayground.tscn"
const BACKROOMS_SCENE := "res://prototypes/BackroomsPortalPlayground.tscn"
const UNDERGROUND_SCENE := "res://prototypes/UndergroundMiningPlayground.tscn"
const PINBALL_SCENE := "res://daily_games/KROLL_Orbital_Pinball/main.tscn"
const TETHER_SCENE := "res://daily_games/KROLL_Tether_Recovery/main.tscn"
const SHADOW_SCENE := "res://daily_games/KROLL_Shadow_Courier/main.tscn"
const FLUX_HOCKEY_SCENE := "res://daily_games/KROLL_Flux_Hockey/main.tscn"

var status_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.035, 0.055, 0.075)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "2126 SURVIVAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "DEVELOPMENT TEST HUB"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	column.add_child(subtitle)

	var note := Label.new()
	note.text = "主世界已整合地表區塊、礦物、作物、打撈箱與共用背包；下方保留獨立子系統測試入口。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

	_add_scene_button(
		column,
		"主世界／地表生存",
		"進入可遊玩的地表世界：WASD 移動、E 管理作物、F 回收打撈箱；支援鍵盤與觸控操作。",
		WORLD_SCENE
	)
	_add_scene_button(
		column,
		"地表探索／區塊與礦物串流",
		"測試第一人稱移動、地表區塊載入與卸載、礦脈資料和串流存檔。",
		SURFACE_SCENE
	)
	_add_scene_button(
		column,
		"地下礦坑／採礦與共用背包",
		"進入地下洞穴，開採銅、鐵與鈾礦，驗證礦脈持久化及負重即時更新。",
		UNDERGROUND_SCENE
	)
	_add_scene_button(
		column,
		"KROLL Orbital Pinball",
		"三張彈珠台、三顆球、碰撞反彈與雙側擋板；支援鍵盤、滑鼠與觸控。",
		PINBALL_SCENE
	)
	_add_scene_button(
		column,
		"KROLL Tether Recovery",
		"駕駛回收無人機，使用繫索拖運三件貨物返回停靠區；支援推進、煞車與觸控。",
		TETHER_SCENE
	)
	_add_scene_button(
		column,
		"KROLL Shadow Courier",
		"回收三份資料、避開旋轉巡邏視線，使用誘餌穿越 KROLL 設施；支援鍵盤與觸控。",
		SHADOW_SCENE
	)
	_add_scene_button(
		column,
		"KROLL Flux Hockey",
		"操控下方擋板，把能量球打進上方球門；三座競技場，支援拖曳與鍵盤。",
		FLUX_HOCKEY_SCENE
	)
	_add_scene_button(
		column,
		"後室傳送門實驗場",
		"測試後室無限迷宮、傳送門、背包負重、設定與存檔。",
		BACKROOMS_SCENE
	)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "提示：在世界或原型場景按 Esc 可釋放滑鼠；按 F10 返回此選單。地表世界已整合共用系統，其他區域仍在開發中。"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.82))
	column.add_child(status_label)

func _add_scene_button(parent: VBoxContainer, title_text: String, description: String, scene_path: String) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	parent.add_child(group)

	var button := Button.new()
	button.text = title_text
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_open_scene.bind(scene_path))
	group.add_child(button)

	var details := Label.new()
	details.text = description
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color(0.76, 0.81, 0.85))
	group.add_child(details)

func _open_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK and is_instance_valid(status_label):
		status_label.text = "無法開啟場景：%s（錯誤碼 %d）" % [scene_path, error]
