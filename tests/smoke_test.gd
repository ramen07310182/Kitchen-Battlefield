extends Node
## 動作確認用のボット。準備 → 営業 → 結果 → 次の日 を自動で2日分まわし、主なルールを確かめる。
## 実行: Godot --headless --path . res://tests/smoke_test.tscn
## 本物のセーブ（user://save.json）は読み書きしない。テスト用のファイルに保存し、終わったら消す。
## 確かめる項目は [check] で始まる行に出し、1つでも失敗したら終了コード1で終わる。
##   1日目: 仕込みを少なくして、売り切れで早く閉店すること・置き場から外した料理が残りに戻ること
##   2日目: 確定前の仕入れでは所持金が減らないこと・「前回と同じ仕込み」・仕入れ予定が残ったままの営業開始・廃棄

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const DAYS_TO_RUN := 2
const TEST_SAVE_PATH := "user://save_smoke_test.json"

var _main: Node
var _days_done: int = 0
var _cooldown: float = 0.0
var _made_mistake: bool = false
var _return_tested: bool = false
var _last_screen: String = ""
var _failures: PackedStringArray = PackedStringArray()
## 本物のセーブがテストの前後で変わっていないか確かめるため
var _real_save_before: String = ""
## 営業画面の最後に見た残り時間（売り切れで早く終わったかの確認用）
var _last_time_left: float = 0.0
## 1日目の仕込み数と置き場（2日目の「前回と同じ仕込み」の確認用）
var _day1_prep: Dictionary = {}
var _day1_shelf: Array[String] = []


func _ready() -> void:
	_real_save_before = _read_real_save()
	# 前回のテストが途中で止まって残ったファイルがあれば消してから始める
	GameState.use_save_path(TEST_SAVE_PATH)
	GameState.delete_save()
	_check_migration()
	GameState.delete_save()
	GameState.use_save_path(TEST_SAVE_PATH)
	_check_rules()
	GameState.use_save_path(TEST_SAVE_PATH)
	Engine.time_scale = 8.0
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	print("[smoke] start money=%d day=%d rep=%d inv=%s" % [GameState.money, GameState.day, GameState.reputation, GameState.inventory])


func _check(name: String, ok: bool, detail: String = "") -> void:
	print("[check] %s %s %s" % ["OK  " if ok else "FAIL", name, detail])
	if not ok:
		_failures.append(name)


func _process(delta: float) -> void:
	if _main == null or _main.get_child_count() == 0:
		return
	var screen: Node = _main.get_child(_main.get_child_count() - 1)
	if screen.name != _last_screen:
		_last_screen = screen.name
		_cooldown = 0.5
		print("[smoke] screen: ", screen.name)
	if String(screen.name) == "Business":
		_last_time_left = float(screen.get("_time_left"))
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = 0.25
	match String(screen.name):
		"PrepScreen":
			_do_prep(screen)
		"Business":
			_do_business(screen)
		"ResultScreen":
			_do_result(screen)


# ---------------------------------------------------------------
# 画面を使わないルールの確認
# ---------------------------------------------------------------

func _check_rules() -> void:
	var cfg: GameConfig = Database.config
	# 仕入れ予定は確定するまでお金も在庫も変わらない。0未満にならない
	var money_before: int = GameState.money
	var rice_before: int = GameState.get_stock("rice")
	GameState.change_purchase("rice", 5)
	GameState.change_purchase("chicken", 2)
	GameState.change_purchase("fish", -3)
	_check("仕入れ予定では所持金も在庫も変わらない",
		GameState.money == money_before and GameState.get_stock("rice") == rice_before
		and GameState.get_planned_purchase("fish") == 0,
		"money=%d plan=%s" % [GameState.money, GameState.purchase_plan])
	var total: int = GameState.get_purchase_total()
	GameState.confirm_purchase()
	_check("「仕入れる」で合計金額が引かれ在庫が増える",
		GameState.money == money_before - total and GameState.get_stock("rice") == rice_before + 5
		and not GameState.has_purchase_plan(), "total=%d money=%d" % [total, GameState.money])
	# 所持金が足りない仕入れはできない
	GameState.change_purchase("fish", 1000)
	_check("所持金が足りない仕入れは確定できない",
		not GameState.can_afford_purchase() and not GameState.confirm_purchase())
	GameState.clear_purchase_plan()

	# 仕込み数の上限は「99」と「確定した在庫で作れる数」の小さいほう
	var karaage: DishData = Database.get_dish("karaage")
	GameState.change_purchase("chicken", 200)
	GameState.change_purchase("rice", 200)
	GameState.change_purchase("cabbage", 200)
	var limit_by_stock: int = mini(GameState.get_stock("chicken"), mini(GameState.get_stock("rice"), GameState.get_stock("cabbage")))
	GameState.change_prep("karaage", 150)
	_check("仕込み数は確定した在庫までしか増やせない（予定は含めない）",
		GameState.get_prep_count("karaage") == limit_by_stock, "prep=%d stock_limit=%d" % [GameState.get_prep_count("karaage"), limit_by_stock])
	GameState.change_purchase("fish", 200)
	GameState.add_money(100000)
	GameState.confirm_purchase()
	GameState.change_prep("karaage", 150)
	_check("仕込み数の上限は99", GameState.get_prep_count("karaage") == cfg.max_prep_per_dish and not GameState.can_add_prep(karaage),
		"prep=%d" % GameState.get_prep_count("karaage"))

	# 開店時の置き場は合計6個まで、仕込み数を超えない
	GameState.change_prep("karaage", -97)
	for i: int in 4:
		GameState.add_to_shelf_plan("karaage")
	GameState.change_prep("yakizakana", 10)
	for i: int in 10:
		GameState.add_to_shelf_plan("yakizakana")
	_check("開店時の置き場は仕込み数を超えず、6枠まで",
		GameState.get_shelf_plan_count("karaage") == 2 and GameState.shelf_plan.size() == cfg.shelf_capacity,
		"plan=%s" % [GameState.shelf_plan])
	GameState.change_prep("yakizakana", -9)
	_check("仕込み数を減らすと置き場の初期配置も減る", GameState.get_shelf_plan_count("yakizakana") == 1, "plan=%s" % [GameState.shelf_plan])

	# 営業中の数の管理（DishSupply）
	var supply: DishSupply = DishSupply.new({"karaage": 3}, ["karaage"] as Array[String])
	supply.take_for_cooking("karaage")
	supply.reserve("karaage")
	supply.reserve("karaage")
	supply.reserve("karaage")
	_check("確保済みの料理は注文できない", supply.get_orderable("karaage") == 0 and not supply.reserve("karaage"))
	supply.return_to_remaining("karaage")
	_check("置き場から戻すと残りが1増える", supply.get_remaining("karaage") == 2)
	supply.serve("karaage")
	supply.release("karaage")
	_check("出した分は出せる数から引かれ、帰った客の確保は戻る", supply.get_units("karaage") == 2 and supply.get_orderable("karaage") == 1)
	# 状態を作り直す（テスト用のセーブはまだないので、新しいゲームになる）
	GameState.delete_save()


## 古いセーブ（version 1・2）を読み込んで、version 3 に移行できるか確かめる
func _check_migration() -> void:
	_write_test_save({"version": 1, "money": 4321, "day": 5, "reputation": 12, "inventory": {"rice": 7}})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v1 -> v3", GameState.money == 4321 and GameState.day == 5 and GameState.reputation == 12
		and GameState.get_stock("rice") == 7 and not GameState.has_last_prep() and GameState.last_shelf_plan.is_empty())
	_write_test_save({"version": 2, "money": 5000, "day": 3, "reputation": 5, "inventory": {"rice": 9},
		"last_prep": {"karaage": 2, "yakizakana": 1}})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v2 -> v3（前回の仕込みを仕込み数と置き場の両方に）",
		GameState.get_stock("rice") == 9 and GameState.last_prep_counts == {"karaage": 2, "yakizakana": 1}
		and GameState.last_shelf_plan == (["karaage", "karaage", "yakizakana"] as Array[String]),
		"prep=%s shelf=%s" % [GameState.last_prep_counts, GameState.last_shelf_plan])


func _write_test_save(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


# ---------------------------------------------------------------
# 準備画面
# ---------------------------------------------------------------

func _do_prep(screen: Node) -> void:
	var dialog: ConfirmDialog = screen.get("_dialog")
	if dialog.is_open():
		return
	if _days_done == 0:
		_do_prep_day1(screen)
	else:
		_do_prep_day2(screen, dialog)


## 1日目: 少なめに仕込んで、売り切れで早く閉店させる
func _do_prep_day1(screen: Node) -> void:
	var repeat_button: Button = screen.get("_repeat_button")
	_check("1日目は「前回と同じ仕込み」を押せない", repeat_button.disabled)
	GameState.change_prep("karaage", 2)
	GameState.change_prep("yakizakana", 1)
	GameState.change_prep("shogayaki", 1)
	GameState.add_to_shelf_plan("karaage")
	GameState.add_to_shelf_plan("yakizakana")
	_day1_prep = GameState.prep_counts.duplicate()
	_day1_shelf = GameState.shelf_plan.duplicate()
	var stock_before: Dictionary = GameState.inventory.duplicate()
	var reserved_rice: int = GameState.get_reserved("rice")
	print("[smoke] day1 prep=%s shelf=%s" % [_day1_prep, _day1_shelf])
	(screen.get("_start_button") as Button).pressed.emit()
	_check("営業開始で仕込み数の食材がまとめて引かれる",
		GameState.get_stock("rice") == int(stock_before["rice"]) - reserved_rice,
		"rice %d -> %d" % [int(stock_before["rice"]), GameState.get_stock("rice")])


## 2日目: 画面のボタンで仕入れ予定 → 確定 →「前回と同じ仕込み」→ 多めに仕込む → 予定を残して営業開始
func _do_prep_day2(screen: Node, dialog: ConfirmDialog) -> void:
	# 画面の「+5」を押して仕入れ予定を作る（まだお金は減らない）
	var money_before: int = GameState.money
	var rows: Array[IngredientRow] = screen.get("_ingredient_rows")
	for row: IngredientRow in rows:
		for i: int in 3:
			(row.get("_plus_large") as Button).pressed.emit()
	(rows[0].get("_minus_small") as Button).pressed.emit()
	var total: int = GameState.get_purchase_total()
	_check("確定前の仕入れでは所持金が減らない", GameState.money == money_before and total > 0,
		"money=%d plan_total=%d" % [GameState.money, total])
	# 「仕入れる」→ 確認ダイアログ →「仕入れる」
	(screen.get("_purchase_button") as Button).pressed.emit()
	_check("「仕入れる」で確認が出る", dialog.is_open())
	(dialog.get("_ok_button") as Button).pressed.emit()
	_check("確認して仕入れると所持金が減る", GameState.money == money_before - total and not GameState.has_purchase_plan(),
		"money %d -> %d (total %d)" % [money_before, GameState.money, total])

	# 食材を買ったあとなら、前回と同じ仕込みが全部入る
	(screen.get("_repeat_button") as Button).pressed.emit()
	_check("「前回と同じ仕込み」で仕込み数と置き場が前回と同じになる",
		GameState.prep_counts == _day1_prep and GameState.shelf_plan == _day1_shelf,
		"prep=%s shelf=%s" % [GameState.prep_counts, GameState.shelf_plan])

	# 多めに仕込んで、残った分が廃棄になるようにする
	for dish: DishData in Database.dishes:
		GameState.change_prep(dish.id, 10)
	print("[smoke] day2 prep=%s shelf=%s shortage=%s" % [GameState.prep_counts, GameState.shelf_plan, _shortages()])

	# 仕入れ予定を残したまま営業開始 → 確認 →「仕入れずに開始」（予定は捨てる。お金は減らない）
	GameState.change_purchase("rice", 1)
	var money_at_start: int = GameState.money
	(screen.get("_start_button") as Button).pressed.emit()
	_check("仕入れ予定が残っていると営業開始の前に確認が出る", dialog.is_open())
	(dialog.get("_ok_button") as Button).pressed.emit()
	_check("「仕入れずに開始」では予定を捨て、所持金は減らない",
		GameState.money == money_at_start and not GameState.has_purchase_plan())


# ---------------------------------------------------------------
# 営業画面
# ---------------------------------------------------------------

func _do_business(screen: Node) -> void:
	var shelf: ReadyShelf = screen.get("_shelf")
	var kitchen: Kitchen = screen.get("_kitchen")
	var dining: DiningArea = screen.get("_dining")
	var supply: DishSupply = screen.get("_supply")
	var customers: Array[Customer] = screen.get("_customers")
	var slots: Array[String] = shelf.get("_slots")
	var shelf_buttons: Array[Button] = shelf.get("_buttons")
	var tables: Array[DiningTable] = dining.get("_tables")

	# 1日目の最初に1回だけ: 置き場の料理を持って「残りに戻す」
	if _days_done == 0 and not _return_tested:
		_return_tested = true
		var slot0: String = slots[0]
		var remaining_before: int = supply.get_remaining(slot0)
		var free_before: int = shelf.free_count()
		_hold(shelf, shelf_buttons, 0)
		(kitchen.get("_return_button") as Button).pressed.emit()
		_check("置き場から外した料理は残りに1戻り、枠が空く",
			supply.get_remaining(slot0) == remaining_before + 1 and shelf.free_count() == free_before + 1,
			"%s remaining %d -> %d, free %d -> %d" % [slot0, remaining_before, supply.get_remaining(slot0), free_before, shelf.free_count()])
		return

	var needed: Dictionary = {}
	for c: Customer in customers:
		if not c.is_waiting_food():
			continue
		var slot: int = slots.find(c.dish.id)
		if slot >= 0:
			# 1回だけわざと違う料理を出してミスを確認する
			if not _made_mistake:
				var wrong: int = -1
				for i: int in slots.size():
					if slots[i] != "" and slots[i] != c.dish.id:
						wrong = i
				if wrong >= 0:
					_hold(shelf, shelf_buttons, wrong)
					(tables[c.table_index].get("_tap_button") as Button).pressed.emit()
					_made_mistake = true
					print("[smoke] mistake test -> mistakes=%d" % GameState.today.mistakes)
			_hold(shelf, shelf_buttons, slot)
			(tables[c.table_index].get("_tap_button") as Button).pressed.emit()
			return
		needed[c.dish.id] = int(needed.get(c.dish.id, 0)) + 1
	var queue: Array[DishData] = kitchen.get("_queue")
	var current: DishData = kitchen.get("_current")
	for d: DishData in queue:
		needed[d.id] = int(needed.get(d.id, 0)) - 1
	if current != null:
		needed[current.id] = int(needed.get(current.id, 0)) - 1
	var buttons: Dictionary = kitchen.get("_buttons")
	for dish_id: String in needed:
		if int(needed[dish_id]) > 0 and buttons.has(dish_id):
			(buttons[dish_id] as Button).pressed.emit()
			return


func _hold(shelf: ReadyShelf, buttons: Array[Button], slot: int) -> void:
	if int(shelf.get("_held_index")) != slot:
		buttons[slot].pressed.emit()


# ---------------------------------------------------------------
# 結果画面
# ---------------------------------------------------------------

func _do_result(screen: Node) -> void:
	var s: DayStats = GameState.today
	print("[smoke] result day=%d sales=%d cost=%d waste=%d(¥%d) other=%d profit=%d visitors=%d completed=%d angry=%d mistakes=%d sold_out=%s time_left=%.1f rep=%d money=%d" % [
		GameState.day, s.sales, s.ingredient_cost, s.waste_count, s.waste_cost, s.other_expense, s.profit(), s.visitors,
		s.completed_orders, s.left_angry, s.mistakes, s.sold_out, _last_time_left, GameState.reputation, GameState.money])
	if _days_done == 0:
		var prepared: int = 0
		for dish_id: String in _day1_prep:
			prepared += int(_day1_prep[dish_id])
		_check("仕込み分を出し切ると売り切れで早く閉店する",
			s.sold_out and _last_time_left > 0.0 and s.completed_orders + s.left_angry >= prepared - s.waste_count,
			"time_left=%.1f" % _last_time_left)
		_check("注文は仕込み数を超えない", s.completed_orders <= prepared)
	else:
		var cost_check: int = 0
		for dish_id: String in GameState.last_prep_counts:
			cost_check += Database.get_dish_cost(Database.get_dish(dish_id)) * int(GameState.last_prep_counts[dish_id])
		_check("残った料理は廃棄として数え、原価に含める",
			s.waste_count > 0 and s.waste_cost > 0 and s.ingredient_cost == cost_check,
			"waste=%d cost=%d prep_cost=%d" % [s.waste_count, s.ingredient_cost, cost_check])
		_check("結果画面に廃棄の行が出る", _grid_has_text(screen.get("_money_grid"), UIText.RESULT_WASTE % s.waste_count))
	(screen.get("_next_button") as Button).pressed.emit()
	_days_done += 1
	if _days_done >= DAYS_TO_RUN:
		var saved: String = FileAccess.get_file_as_string(GameState.save_path)
		print("[smoke] save: ", saved.replace("\n", " "))
		_check("セーブは version 3 で、前回の置き場を含む", saved.contains("\"version\": 3") and saved.contains("last_shelf"))
		_finish()


func _grid_has_text(grid: GridContainer, text: String) -> bool:
	for child: Node in grid.get_children():
		if child is Label and (child as Label).text == text:
			return true
	return false


func _shortages() -> Dictionary:
	var needs: Dictionary = GameState.get_ingredient_needs()
	var result: Dictionary = {}
	for ing: IngredientData in Database.ingredients:
		var lack: int = GameState.get_shortage(ing.id, needs)
		if lack > 0:
			result[ing.id] = lack
	return result


func _finish() -> void:
	GameState.delete_save()
	var test_file_left: bool = FileAccess.file_exists(TEST_SAVE_PATH)
	var real_unchanged: bool = _read_real_save() == _real_save_before
	_check("テスト用のセーブを消した", not test_file_left)
	_check("本物のセーブは変わっていない", real_unchanged)
	var ok: bool = _failures.is_empty()
	print("[smoke] done" if ok else "[smoke] FAILED: " + ", ".join(_failures))
	get_tree().quit(0 if ok else 1)


func _read_real_save() -> String:
	if not FileAccess.file_exists(GameState.DEFAULT_SAVE_PATH):
		return "<なし>"
	return FileAccess.get_file_as_string(GameState.DEFAULT_SAVE_PATH)
