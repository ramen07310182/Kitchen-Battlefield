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

	# 準備画面: 仕込み数・開店時の置き場・仕入れ予定を入れ、食材不足の赤い表示も見える状態にする
	var prep: Node = _current_screen(main)
	GameState.change_prep(Database.dishes[0].id, 3)
	GameState.change_prep(Database.dishes[1].id, 2)
	GameState.change_prep(Database.dishes[2].id, 3)
	GameState.add_to_shelf_plan(Database.dishes[0].id)
	GameState.add_to_shelf_plan(Database.dishes[1].id)
	GameState.change_purchase(Database.ingredients[0].id, 10)
	GameState.change_purchase(Database.ingredients[1].id, 5)
	await _wait_frames(3)
	await _shot("prep")
	# 仕入れの確認ダイアログ
	(prep.get("_purchase_button") as Button).pressed.emit()
	await _wait_frames(3)
	await _shot("prep_dialog")
	var dialog: ConfirmDialog = prep.get("_dialog")
	(dialog.get("_ok_button") as Button).pressed.emit()
	await _wait_frames(2)

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

	# 残りの営業は、簡単な自動配膳をしながら早送りして結果画面へ（内訳の表に数字が入るように）。
	# 営業時間は残り20秒にして、売り切れと廃棄の両方が出やすくする
	business.set("_time_left", minf(float(business.get("_time_left")), 20.0))
	Engine.time_scale = 20.0
	while String(_current_screen(main).name) == "Business":
		_auto_serve(business)
		await get_tree().process_frame
	while String(_current_screen(main).name) != "ResultScreen":
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await _wait_frames(5)
	await _shot("result")

	# 次の日の準備画面（「前回 ○食売れた」が出る）
	(_current_screen(main).get("_next_button") as Button).pressed.emit()
	await _wait_frames(5)
	await _shot("prep_day2")

	GameState.delete_save()
	get_tree().quit()


## 待っている客の料理が置き場にあれば出し、なければ作る（見た目の確認用の簡単な自動操作）
func _auto_serve(business: Node) -> void:
	var shelf: ReadyShelf = business.get("_shelf")
	var kitchen: Kitchen = business.get("_kitchen")
	var dining: DiningArea = business.get("_dining")
	var slots: Array[String] = shelf.get("_slots")
	var shelf_buttons: Array[Button] = shelf.get("_buttons")
	var tables: Array[DiningTable] = dining.get("_tables")
	var cook_buttons: Dictionary = kitchen.get("_buttons")
	for c: Customer in (business.get("_customers") as Array[Customer]):
		if not c.is_waiting_food():
			continue
		var slot: int = slots.find(c.dish.id)
		if slot >= 0:
			if int(shelf.get("_held_index")) != slot:
				shelf_buttons[slot].pressed.emit()
			(tables[c.table_index].get("_tap_button") as Button).pressed.emit()
			return
		if kitchen.get_pending_count() == 0 and cook_buttons.has(c.dish.id):
			(cook_buttons[c.dish.id] as Button).pressed.emit()
			return


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
