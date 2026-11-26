extends Node
## 動作確認用のボット。準備 → 営業 → 結果 → 次の日 を自動で2日分まわす。
## 実行: Godot --headless --path . res://tests/smoke_test.tscn
## 本物のセーブ（user://save.json）は読み書きしない。テスト用のファイルに保存し、終わったら消す。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const DAYS_TO_RUN := 2
const TEST_SAVE_PATH := "user://save_smoke_test.json"

var _main: Node
var _days_done: int = 0
var _cooldown: float = 0.0
var _made_mistake: bool = false
var _last_screen: String = ""
## 本物のセーブがテストの前後で変わっていないか確かめるため
var _real_save_before: String = ""


func _ready() -> void:
	_real_save_before = _read_real_save()
	# 前回のテストが途中で止まって残ったファイルがあれば消してから始める
	GameState.use_save_path(TEST_SAVE_PATH)
	GameState.delete_save()
	_check_migration_v1()
	GameState.delete_save()
	GameState.use_save_path(TEST_SAVE_PATH)
	Engine.time_scale = 8.0
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	print("[smoke] start money=%d day=%d rep=%d inv=%s" % [GameState.money, GameState.day, GameState.reputation, GameState.inventory])


func _process(delta: float) -> void:
	if _main.get_child_count() == 0:
		return
	var screen: Node = _main.get_child(_main.get_child_count() - 1)
	if screen.name != _last_screen:
		_last_screen = screen.name
		_cooldown = 0.5
		print("[smoke] screen: ", screen.name)
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


func _do_prep(screen: Node) -> void:
	var repeat_button: Button = screen.get("_repeat_button")
	if _days_done == 0:
		print("[smoke] repeat button disabled on day1=%s" % repeat_button.disabled)
		for dish: DishData in Database.dishes:
			GameState.change_prep(dish.id, 1)
	else:
		# 食材が足りないうちに押すと一部だけ入る → 買ってから押すと全部入る
		var last: Dictionary = GameState.last_prep_counts.duplicate()
		repeat_button.pressed.emit()
		print("[smoke] repeat prep (before buying): now=%s notice=%s" % [GameState.prep_counts, screen.get("_notice")])
		for ing: IngredientData in Database.ingredients:
			GameState.buy_ingredient(ing.id, 3)
		repeat_button.pressed.emit()
		print("[smoke] repeat prep (after buying): last=%s now=%s same=%s notice=%s" % [
			last, GameState.prep_counts, last == GameState.prep_counts, screen.get("_notice")])
	print("[smoke] shortage before buying: %s" % _shortages())
	# 足りない食材を目安まで買う
	var needs: Dictionary = GameState.get_ingredient_needs()
	for ing: IngredientData in Database.ingredients:
		var lack: int = GameState.get_shortage(ing.id, needs)
		if lack > 0:
			GameState.buy_ingredient(ing.id, lack)
	print("[smoke] shortage after buying: %s" % _shortages())
	print("[smoke] prep: money=%d prep_total=%d rep=%d interval_scale=%.3f expected_visitors=%.1f" % [
		GameState.money, GameState.get_total_prep(), GameState.reputation,
		Database.config.get_spawn_interval_scale(GameState.reputation),
		DemandEstimator.expected_visitors(Database.config, GameState.reputation)])
	(screen.get("_start_button") as Button).pressed.emit()


func _do_business(screen: Node) -> void:
	var shelf: ReadyShelf = screen.get("_shelf")
	var kitchen: Kitchen = screen.get("_kitchen")
	var dining: DiningArea = screen.get("_dining")
	var customers: Array[Customer] = screen.get("_customers")
	var slots: Array[String] = shelf.get("_slots")
	var shelf_buttons: Array[Button] = shelf.get("_buttons")
	var tables: Array[DiningTable] = dining.get("_tables")

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


func _shortages() -> Dictionary:
	var needs: Dictionary = GameState.get_ingredient_needs()
	var result: Dictionary = {}
	for ing: IngredientData in Database.ingredients:
		var lack: int = GameState.get_shortage(ing.id, needs)
		if lack > 0:
			result[ing.id] = lack
	return result


## version 1 のセーブを読み込んで、version 2 に移行できるか確かめる
func _check_migration_v1() -> void:
	var v1: Dictionary = {"version": 1, "money": 4321, "day": 5, "reputation": 12, "inventory": {"rice": 7}}
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1))
	file.close()
	GameState.use_save_path(TEST_SAVE_PATH)
	var ok: bool = GameState.money == 4321 and GameState.day == 5 and GameState.reputation == 12 		and GameState.get_stock("rice") == 7 and not GameState.has_last_prep()
	print("[smoke] migration v1 -> v2 ok=%s" % ok)


func _hold(shelf: ReadyShelf, buttons: Array[Button], slot: int) -> void:
	if int(shelf.get("_held_index")) != slot:
		buttons[slot].pressed.emit()


func _do_result(screen: Node) -> void:
	var s: DayStats = GameState.today
	print("[smoke] result day=%d sales=%d cost=%d other=%d profit=%d visitors=%d completed=%d angry=%d mistakes=%d stars=%.2f rep=%d money=%d" % [
		GameState.day, s.sales, s.ingredient_cost, s.other_expense, s.profit(), s.visitors,
		s.completed_orders, s.left_angry, s.mistakes, s.average_stars(), GameState.reputation, GameState.money])
	(screen.get("_next_button") as Button).pressed.emit()
	_days_done += 1
	if _days_done >= DAYS_TO_RUN:
		print("[smoke] save: ", FileAccess.get_file_as_string(GameState.save_path).replace("\n", " "))
		_finish()


func _finish() -> void:
	GameState.delete_save()
	var test_file_left: bool = FileAccess.file_exists(TEST_SAVE_PATH)
	var real_unchanged: bool = _read_real_save() == _real_save_before
	print("[smoke] test save removed=%s, real save unchanged=%s" % [not test_file_left, real_unchanged])
	var ok: bool = real_unchanged and not test_file_left
	print("[smoke] done" if ok else "[smoke] FAILED")
	get_tree().quit(0 if ok else 1)


func _read_real_save() -> String:
	if not FileAccess.file_exists(GameState.DEFAULT_SAVE_PATH):
		return "<なし>"
	return FileAccess.get_file_as_string(GameState.DEFAULT_SAVE_PATH)
