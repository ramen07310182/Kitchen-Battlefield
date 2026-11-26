extends Node
## 見た目の確認用: 準備・営業・結果の3画面を自動で進めて、スクリーンショットを保存する。
## 実行（ウィンドウが開く。--headless では撮れない）:
##   Godot --path . --resolution 1280x720 res://tests/screenshot.tscn -- --out=<保存先フォルダ> --name=16x9
## 保存先を省略すると user://screenshots/ に保存する。
## 本物のセーブ（user://save.json）は読み書きしない。テスト用のファイルを使い、終わったら消す。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const TEST_SAVE_PATH := "user://save_screenshot.json"
## 営業画面を撮るまでの、営業開始からのゲーム内の秒数
const BUSINESS_SHOT_TIME := 24.0

var _out_dir: String = "user://screenshots"
var _shot_name: String = "shot"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--name="):
			_shot_name = arg.trim_prefix("--name=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	GameState.use_save_path(TEST_SAVE_PATH)
	GameState.delete_save()
	GameState.use_save_path(TEST_SAVE_PATH)
	_run()


func _run() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _wait_frames(3)

	# 準備画面: 1品だけ仕込んで、ほかは食材不足の赤い表示が見える状態にする
	var prep: Node = _current_screen(main)
	GameState.change_prep(Database.dishes[0].id, 2)
	await _wait_frames(3)
	await _shot("prep")

	(prep.get("_start_button") as Button).pressed.emit()
	await _wait_frames(2)
	Engine.time_scale = 4.0
	await get_tree().create_timer(BUSINESS_SHOT_TIME, true, false, false).timeout
	# 料理を1つ持った状態にして、テーブルの光り方も見えるようにする
	var business: Node = _current_screen(main)
	var shelf: ReadyShelf = business.get("_shelf")
	var buttons: Array[Button] = shelf.get("_buttons")
	if not buttons.is_empty() and not buttons[0].disabled:
		buttons[0].pressed.emit()
	Engine.time_scale = 1.0
	await _wait_frames(3)
	await _shot("business")

	# 残りの営業は早送りして結果画面へ
	business.set("_time_left", 0.0)
	Engine.time_scale = 30.0
	while String(_current_screen(main).name) != "ResultScreen":
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await _wait_frames(5)
	await _shot("result")

	GameState.delete_save()
	get_tree().quit()


func _current_screen(main: Node) -> Node:
	return main.get_child(main.get_child_count() - 1)


func _wait_frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _shot(screen_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%s.png" % [_out_dir, _shot_name, screen_name]
	image.save_png(path)
	print("[shot] ", path, " ", image.get_size())
