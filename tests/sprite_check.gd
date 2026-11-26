extends Control
## 絵の確認画面: ゲームで使うすべての絵について、置いたPNGが読めているか・アニメーションの動きを一覧で見る。
## 実行: エディタで tests/sprite_check.tscn を開いて F6（現在のシーンを実行）。
##       コマンドなら: Godot --path . res://tests/sprite_check.tscn
## 読めた絵は動く絵で、ない絵は「なし」と、代わりに何が出るかを表示する。コンソールにも同じ一覧を出す。

const CELL_SIZE := Vector2(150, 92)
const PREVIEW_SIZE := Vector2(144, 56)
const COLOR_FOUND := Color(0.55, 1.0, 0.55)
const COLOR_MISSING := Color(0.65, 0.65, 0.65)

@onready var _grid: GridContainer = %Grid
@onready var _summary_label: Label = %SummaryLabel
@onready var _reload_button: Button = %ReloadButton


func _ready() -> void:
	_reload_button.pressed.connect(_rebuild)
	_rebuild()
	# -- --shot=<保存先.png> を付けて起動すると、画面を保存して終わる（自動確認用）
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--shot="))
			get_tree().quit()


func _rebuild() -> void:
	SpriteLibrary.clear_cache()
	for child: Node in _grid.get_children():
		child.queue_free()
	var found: int = 0
	var total: int = 0
	print("[sprite_check] ---- 絵の一覧（あり/なし） ----")
	for entry: Dictionary in SpriteKeys.all_entries():
		var key: String = entry["key"]
		var anims: PackedStringArray = entry["anims"]
		var names: Array[String] = []
		if anims.is_empty():
			names.append(key)
		else:
			for anim: String in anims:
				names.append(SpriteKeys.with_anim(key, anim))
			names.append(key)  # アニメーション別の絵がないときに使う共通の絵
		for name: String in names:
			total += 1
			var sheet: SpriteSheet = SpriteLibrary.get_sheet(name)
			if sheet != null:
				found += 1
			_add_cell(name, key, sheet)
	_summary_label.text = "絵が見つかった数: %d / %d（緑 = あり、灰色 = なし）" % [found, total]
	print("[sprite_check] %d / %d 見つかりました" % [found, total])


func _add_cell(name: String, base_key: String, sheet: SpriteSheet) -> void:
	var cell: PanelContainer = PanelContainer.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.2, 0.2, 0.22)))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	cell.add_child(box)

	var preview_bg: ColorRect = ColorRect.new()
	preview_bg.custom_minimum_size = PREVIEW_SIZE
	preview_bg.color = Color(0.32, 0.3, 0.3)
	box.add_child(preview_bg)
	var view: SpriteView = SpriteView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_bg.add_child(view)

	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"SmallLabel"
	name_label.text = name
	name_label.clip_text = true
	box.add_child(name_label)

	var status: Label = Label.new()
	status.theme_type_variation = &"SmallLabel"
	status.clip_text = true
	box.add_child(status)

	var line: String
	if sheet != null:
		# アニメーション名で探し直さないよう、名前そのものを表示する
		view.set_sprite(name)
		status.text = "あり %dx%d %dコマ" % [sheet.frame_size.x, sheet.frame_size.y, sheet.get_frame_count()]
		status.add_theme_color_override("font_color", COLOR_FOUND)
		name_label.add_theme_color_override("font_color", COLOR_FOUND)
		line = "あり  %-32s %dx%d %dコマ %.1ffps" % [name, sheet.frame_size.x, sheet.frame_size.y, sheet.get_frame_count(), sheet.fps]
	else:
		var fallback: String = "図形で代用" if name == base_key else "共通の絵を使う"
		status.text = "なし → %s" % fallback
		status.add_theme_color_override("font_color", COLOR_MISSING)
		name_label.add_theme_color_override("font_color", COLOR_MISSING)
		line = "なし  %-32s → %s（置き場所 %s）" % [name, fallback, SpriteLibrary.get_texture_path(name)]
	print("[sprite_check] ", line)
	_grid.add_child(cell)
