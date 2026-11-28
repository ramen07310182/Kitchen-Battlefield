extends Node
## 見た目の確認用: 準備・営業・結果の3画面を自動で進めて、スクリーンショットを保存する。
## 実行（ウィンドウが開く。--headless では撮れない）:
##   Godot --path . --resolution 1280x720 res://tests/screenshot.tscn -- --out=<保存先フォルダ> --name=16x9
## 保存先を省略すると user://screenshots/ に保存する。
## オプション: --seat-level=N（席の拡張のレベル）、--all-dishes（料理とトッピングをすべて解放）、
##   --staff=N（ランクを最大にして、従業員を N 人雇った状態で撮る。営業画面ではスタッフが運んでいるところを撮る。
##   3人以上のときは3人目を厨房担当にして、営業画面では店主とスタッフが同時に調理しているところも撮る）
## 本物のセーブ（user://save.json）は読み書きしない。テスト用のファイルを使い、終わったら消す。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const TEST_SAVE_PATH := "user://save_screenshot.json"
## 営業画面を撮るまでの、営業開始からのゲーム内の秒数
const BUSINESS_SHOT_TIME := 24.0

var _out_dir: String = "user://screenshots"
var _shot_name: String = "shot"
var _seat_level: int = 0
var _all_dishes: bool = false
var _staff_count: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--name="):
			_shot_name = arg.trim_prefix("--name=")
		elif arg.begins_with("--seat-level="):
			_seat_level = int(arg.trim_prefix("--seat-level="))
		elif arg == "--all-dishes":
			_all_dishes = true
		elif arg.begins_with("--staff="):
			_staff_count = int(arg.trim_prefix("--staff="))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	GameState.use_save_path(TEST_SAVE_PATH)
	GameState.delete_save()
	GameState.use_save_path(TEST_SAVE_PATH)
	# -- --seat-level=N で、1日目から「席の拡張」をそのレベルにして撮る（見た目の確認用）
	if _seat_level > 0:
		GameState.equipment_levels["seats"] = _seat_level
	# -- --all-dishes で、料理25品をすべて解放して撮る（料理が多いときの画面の確認用）
	if _all_dishes:
		GameState.rank = Database.get_max_rank()
		for dish: DishData in Database.items:
			if not GameState.is_unlocked(dish.id):
				GameState.unlocked_dishes.append(dish.id)
	if _staff_count > 0:
		GameState.rank = Database.get_max_rank()
		for data: StaffData in Database.staff:
			if GameState.hired_staff.size() < _staff_count:
				GameState.hire_staff(data.id)
		# 準備③の見た目の確認用: 1人目は退職まであと3日（予告が出る）・Lv2、2人目は Lv3。1日目は金曜なので田中さんは定休で休み
		if GameState.hired_staff.size() >= 2:
			var first: StaffData = Database.get_staff(GameState.hired_staff[0])
			GameState.get_staff_state(first.id)["enrolled"] = first.tenure_days - 3
			GameState.staff_levels[first.id] = 2
			GameState.staff_levels[GameState.hired_staff[1]] = 3
		# 3人目は厨房担当（Lv1 なので、かんたんな料理だけ作れる。ほかの料理のボタンに「店主」が付く）
		if GameState.hired_staff.size() >= 3:
			GameState.set_staff_role(GameState.hired_staff[2], GameState.ROLE_KITCHEN)
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
	GameState.change_prep("tamagoyaki", 3)
	if _all_dishes:
		GameState.change_prep("karaage_extra", 2)
	await _wait_frames(3)
	await _shot("prep1")
	# トッピングの区切りが見えるところまでスクロールして撮る
	var menu_step: PrepMenuStep = prep.get("_menu_step")
	var header: Label = menu_step.get("_topping_header")
	if header != null:
		var scroll: ScrollContainer = menu_step.get_node("%MenuScroll")
		var rows: Array[MenuRow] = menu_step.get("_menu_rows")
		scroll.ensure_control_visible(rows[rows.size() - 1])
		await _wait_frames(3)
		await _shot("prep1_toppings")
		scroll.scroll_vertical = 0
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
	GameState.add_to_shelf_plan("tamagoyaki")
	await _wait_frames(3)
	await _shot("prep3")
	# 今日のスタッフの一覧を下までスクロールして、厨房担当の行も撮る
	var shift_panel: StaffShiftPanel = prep.find_children("*", "StaffShiftPanel", true, false)[0] as StaffShiftPanel
	var shift_rows: Array[Node] = shift_panel.find_children("*", "PanelContainer", true, false)
	var shift_scroll: Node = shift_panel.get_parent()
	while shift_scroll != null and not shift_scroll is ScrollContainer:
		shift_scroll = shift_scroll.get_parent()
	if shift_scroll != null and not shift_rows.is_empty():
		(shift_scroll as ScrollContainer).ensure_control_visible(shift_rows[shift_rows.size() - 1] as Control)
		await _wait_frames(3)
		await _shot("prep3_staff")
		(shift_scroll as ScrollContainer).scroll_vertical = 0

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
	# 厨房のスタッフがいれば、店主とスタッフが同時に調理しているところを撮る（焼き魚は店主、唐揚げはスタッフ）
	var kitchen: Kitchen = business.get("_kitchen")
	if kitchen.get_kitchen_staff() != null:
		var cook_buttons: Dictionary = kitchen.get("_buttons")
		for dish_id: String in ["yakizakana", "karaage"]:
			if cook_buttons.has(dish_id) and not (cook_buttons[dish_id] as Button).disabled:
				(cook_buttons[dish_id] as Button).pressed.emit()
		await get_tree().create_timer(2.0, true, false, false).timeout
	Engine.time_scale = 1.0
	await _wait_frames(3)
	await _shot("business")

	# 残りの営業は、簡単な自動配膳をしながら早送りして結果画面へ（内訳の表に数字が入るように）。
	# 営業時間は残り20秒にして、売り切れと廃棄の両方が出やすくする
	business.set("_time_left", minf(float(business.get("_time_left")), 20.0))
	# 結果画面の「ランクアップ」「新メニュー解放」も撮るため、評判をランク2のしきい値にしておく（見た目の確認用）
	GameState.add_reputation(maxi(0, Database.get_rank_threshold(2) - GameState.reputation))
	# 結果画面の「○○さんが今日で退職しました」も撮るため、1人目を今日で退職するようにしておく（見た目の確認用）
	if not GameState.hired_staff.is_empty():
		var retiring: StaffData = Database.get_staff(GameState.hired_staff[0])
		GameState.get_staff_state(retiring.id)["enrolled"] = retiring.tenure_days - 1
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
	# 従業員の区切りまでスクロールして撮る
	var staff_header: Label = upgrade.get("_staff_header")
	var staff_rows: Array[StaffRow] = upgrade.get("_staff_rows")
	(upgrade.get_node("%Scroll") as ScrollContainer).ensure_control_visible(staff_rows[staff_rows.size() - 1])
	await _wait_frames(4)
	await _shot("upgrade_staff")
	(upgrade.get_node("%Scroll") as ScrollContainer).scroll_vertical = 0
	upgrade.call("_show_detail", "seats")
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

	# 通算の記録（見た目の確認用に、テスト用のセーブの履歴を作る。最初の20日は所持金の記録がない古いセーブのつもり）
	var keep_history: Array[PackedInt32Array] = GameState.history.duplicate()
	var fake: Array = []
	var fake_money: int = 10000
	for d: int in range(1, 121):
		var sales: int = 8000 + d * 150 + (d * 37 % 11) * 600
		# 最初の1か月くらいは赤字続きで所持金がマイナスになる（赤い線の確認用）
		fake_money += sales - 9000 - (6000 if d % 17 == 0 else 0) - (4500 if d <= 45 else 0)
		var stars10: int = 30 + (d * 13 % 17)
		fake.append([d, sales, sales - 9000, 10 + d / 8, stars10, 1, GameState.HISTORY_NO_MONEY if d <= 20 else fake_money])
	GameState.call("_set_history", fake)
	var records: RecordsPopup = prep2.get("_records")
	records.open()
	records.call("_set_period", 2)
	await _wait_frames(3)
	(records.get("_chart") as RecordsChart).select_index(60)
	await _wait_frames(3)
	await _shot("records")
	records.call("_set_period", 0)
	await _wait_frames(3)
	(records.get("_chart") as RecordsChart).select_index(25)
	await _wait_frames(3)
	await _shot("records_30")
	records.hide()
	var restore: Array = []
	for row: PackedInt32Array in keep_history:
		restore.append(Array(row))
	GameState.call("_set_history", restore)

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
	var business_max: Node = _current_screen(main)
	var waited: float = 0.0
	while waited < BUSINESS_SHOT_TIME:
		_auto_cook(business_max)
		await get_tree().create_timer(0.1, true, false, false).timeout
		waited += 0.1
	# スタッフがいれば、料理を運んでいるところを撮る（少し待っても運ばなければそのまま撮る）
	var staff: StaffDispatcher = business_max.get("_staff")
	var tries: int = 0
	while _staff_count > 0 and tries < 800 and not _any_staff_carrying(staff):
		_auto_cook(business_max)
		await get_tree().create_timer(0.05, true, false, false).timeout
		tries += 1
	Engine.time_scale = 1.0
	await _wait_frames(3)
	await _shot("business_max")

	GameState.delete_save()
	get_tree().quit()


func _any_staff_carrying(staff: StaffDispatcher) -> bool:
	for s2: HallStaff in staff.get_staff():
		if s2.state == HallStaff.State.CARRYING:
			return true
	return false


## 待っている客の料理・トッピングで、置き場にないものを作る（配膳はスタッフに任せる）
func _auto_cook(business: Node) -> void:
	var shelf: ReadyShelf = business.get("_shelf")
	var kitchen: Kitchen = business.get("_kitchen")
	var slots: Array[String] = shelf.get("_slots")
	var cook_buttons: Dictionary = kitchen.get("_buttons")
	# 厨房にスタッフがいれば2つまで（店主とスタッフが同時に作る）
	if kitchen.get_pending_count() >= (2 if kitchen.get_kitchen_staff() != null else 1):
		return
	for c: Customer in (business.get("_customers") as Array[Customer]):
		for item_id: String in c.get_needed_items():
			if not slots.has(item_id) and cook_buttons.has(item_id) and not (cook_buttons[item_id] as Button).disabled:
				(cook_buttons[item_id] as Button).pressed.emit()
				return


## 待っている客の料理が置き場にあれば出し、なければ作る（見た目の確認用の簡単な自動操作）
func _auto_serve(business: Node) -> void:
	var shelf: ReadyShelf = business.get("_shelf")
	var kitchen: Kitchen = business.get("_kitchen")
	var dining: DiningArea = business.get("_dining")
	var slots: Array[String] = shelf.get("_slots")
	var shelf_buttons: Array[Button] = shelf.get("_buttons")
	var cook_buttons: Dictionary = kitchen.get("_buttons")
	for c: Customer in (business.get("_customers") as Array[Customer]):
		for item_id: String in c.get_needed_items():
			var slot: int = -1
			for i: int in slots.size():
				if slots[i] == item_id and not shelf.is_reserved(i):
					slot = i
					break
			if slot >= 0:
				if int(shelf.get("_held_index")) != slot:
					shelf_buttons[slot].pressed.emit()
				(dining.get_seat(c.seat_index).get("_tap_button") as Button).pressed.emit()
				return
			if kitchen.get_pending_count() == 0 and cook_buttons.has(item_id):
				(cook_buttons[item_id] as Button).pressed.emit()
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
