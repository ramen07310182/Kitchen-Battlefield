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

	# 準備画面 ①仕込み: 在庫より多く仕込んで、食材が足りない表示も見える状態にする
	var prep: Node = _current_screen(main)
	GameState.change_prep("karaage", 5)
	GameState.change_prep("yakizakana", 2)
	GameState.change_prep("shogayaki", 2)
	await _wait_frames(3)
	await _shot("prep1")
	prep.call("_show_dish_detail", "karaage")
	await _wait_frames(4)
	await _shot("prep1_detail")
	(prep.get("_detail") as DetailPopup).close()
	# ②仕入れ: 不足分を予定に入れた状態と、食材不足で③へ進めないときの確認
	(prep.get("_next_button") as Button).pressed.emit()
	await _wait_frames(2)
	GameState.plan_prep_shortage()
	GameState.change_purchase("cabbage", 5)
	await _wait_frames(3)
	await _shot("prep2")
	(prep.get("_next_button") as Button).pressed.emit()
	await _wait_frames(3)
	await _shot("prep2_shortage_dialog")
	var dialog: ConfirmDialog = prep.get("_dialog")
	(dialog.get("_cancel_button") as Button).pressed.emit()
	# 仕入れの確認ダイアログ →「仕入れる」
	(prep.get("_purchase_button") as Button).pressed.emit()
	await _wait_frames(3)
	await _shot("prep2_purchase_dialog")
	(dialog.get("_ok_button") as Button).pressed.emit()
	await _wait_frames(2)
	# ③置き場
	(prep.get("_next_button") as Button).pressed.emit()
	GameState.add_to_shelf_plan("karaage")
	GameState.add_to_shelf_plan("yakizakana")
	await _wait_frames(3)
	await _shot("prep3")

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
	# 結果画面の「ランクアップ」「新メニュー解放」も撮るため、評判をランク2のしきい値にしておく（見た目の確認用）
	GameState.add_reputation(maxi(0, Database.get_rank_threshold(2) - GameState.reputation))
	Engine.time_scale = 20.0
	while String(_current_screen(main).name) == "Business":
		_auto_serve(business)
		await get_tree().process_frame
	while String(_current_screen(main).name) != "ResultScreen":
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await _wait_frames(5)
	await _shot("result")

	# お店の強化画面（見た目の確認のため、お金を足しておく）
	GameState.add_money(20000)
	(_current_screen(main).get("_upgrade_button") as Button).pressed.emit()
	await _wait_frames(5)
	await _shot("upgrade")
	var upgrade: Node = _current_screen(main)
	upgrade.call("_show_detail", "tables")
	await _wait_frames(4)
	await _shot("upgrade_detail")
	(upgrade.get("_detail") as DetailPopup).close()
	(upgrade.get("_next_button") as Button).pressed.emit()
	await _wait_frames(5)

	# 次の日の準備画面（「前回 ○食売れた」が出る）とカレンダー
	await _shot("prep_day2")
	var prep2: Node = _current_screen(main)
	var calendar: CalendarPopup = prep2.get("_calendar")
	calendar.open()
	await _wait_frames(3)
	calendar.call("_on_cell_pressed", GameCalendar.offset_for_business_day(1))
	await _wait_frames(3)
	await _shot("calendar")
	calendar.hide()

	# テーブル8卓・置き場8枠の営業画面（見た目の確認のため、設備を最大にする）
	for e: EquipmentData in Database.equipment:
		GameState.equipment_levels[e.id] = e.get_max_level()
	for dish: DishData in GameState.get_unlocked_dishes():
		GameState.change_prep(dish.id, 6)
	GameState.plan_prep_shortage()
	GameState.add_money(50000)
	GameState.confirm_purchase()
	prep2.call("_on_start_pressed")
	await _wait_frames(2)
	Engine.time_scale = 6.0
	await get_tree().create_timer(BUSINESS_SHOT_TIME, true, false, false).timeout
	Engine.time_scale = 1.0
	await _wait_frames(3)
	await _shot("business8")

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
