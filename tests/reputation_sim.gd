extends Node
## 評判の上がり方を確かめるための自動プレイ。何日分も遊ばせて、日ごとの評判・ランクの推移を表で出す。
## 実行: Godot --headless --path . res://tests/reputation_sim.tscn -- --skill=good --days=15 --seed=1
##   --skill=good   : 上手なボット（目安どおりに仕込み、すぐに作って出す。ミスをしない）
##   --skill=normal : ふつうのボット（仕込みは目安より少し少なめ、動きは少し遅い、たまに違う料理を出す）
##   --skill=sloppy : ミスの多いボット（仕込みが少なめ、動きが遅い、ときどき違う料理を出す）
## 本物のセーブ（user://save.json）は読み書きしない。テスト用のファイルを使い、終わったら消す。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const SIM_SAVE_PATH := "user://save_reputation_sim.json"

## ボットの設定（上手／ミスが多い）
const SKILLS: Dictionary = {
	"good": { "prep_factor": 1.1, "reaction": 0.4, "wrong_rate": 0.0, "precook": true },
	"normal": { "prep_factor": 0.9, "reaction": 2.0, "wrong_rate": 0.05, "precook": false },
	"sloppy": { "prep_factor": 0.6, "reaction": 5.0, "wrong_rate": 0.25, "precook": false },
}

var _skill_name: String = "good"
var _skill: Dictionary = {}
var _days_to_run: int = 15
var _main: Node
var _days_done: int = 0
var _cooldown: float = 0.0
var _last_screen: String = ""
var _prepared_today: bool = false
var _rows: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var seed_value: int = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--skill="):
			_skill_name = arg.trim_prefix("--skill=")
		elif arg.begins_with("--days="):
			_days_to_run = int(arg.trim_prefix("--days="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
	_skill = SKILLS.get(_skill_name, SKILLS["good"])
	seed(seed_value)
	GameState.use_save_path(SIM_SAVE_PATH)
	GameState.delete_save()
	GameState.use_save_path(SIM_SAVE_PATH)
	Engine.time_scale = 12.0
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_rows.append("| 日 | 来客 | 提供 | 怒って帰った | 売り逃し | ★ | 評判の増減 | 評判 | ランク |")
	_rows.append("|---|---|---|---|---|---|---|---|---|")


func _process(delta: float) -> void:
	if _main.get_child_count() == 0:
		return
	var screen: Node = _main.get_child(_main.get_child_count() - 1)
	if screen.name != _last_screen:
		_last_screen = screen.name
		_cooldown = 0.5
		_prepared_today = false
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	match String(screen.name):
		"PrepScreen":
			_cooldown = 0.3
			_do_prep(screen)
		"Business":
			_cooldown = float(_skill["reaction"])
			_do_business(screen)
		"ResultScreen":
			_cooldown = 0.5
			_do_result(screen)


## 準備: 解放済みの料理を「注文の目安 × 倍率」だけ仕込み、足りない食材を仕入れ、置き場に並べて開始
func _do_prep(screen: Node) -> void:
	if _prepared_today:
		return
	_prepared_today = true
	var expected: Dictionary = GameState.get_expected_orders()
	for dish: DishData in GameState.get_unlocked_dishes():
		var target: int = maxi(1, ceili(float(expected.get(dish.id, 0.0)) * float(_skill["prep_factor"])))
		GameState.change_prep(dish.id, -999)
		GameState.change_prep(dish.id, target)
	GameState.plan_prep_shortage()
	if not GameState.confirm_purchase():
		GameState.clear_purchase_plan()
	GameState.reduce_prep_to_stock()
	var dishes: Array[DishData] = GameState.get_menu_dishes()
	var i: int = 0
	while dishes.size() > 0 and GameState.shelf_plan.size() < Database.config.shelf_capacity and i < 50:
		GameState.add_to_shelf_plan(dishes[i % dishes.size()].id)
		i += 1
	screen.call("_on_start_pressed")


func _do_business(screen: Node) -> void:
	var shelf: ReadyShelf = screen.get("_shelf")
	var kitchen: Kitchen = screen.get("_kitchen")
	var dining: DiningArea = screen.get("_dining")
	var supply: DishSupply = screen.get("_supply")
	var customers: Array[Customer] = screen.get("_customers")
	var slots: Array[String] = shelf.get("_slots")
	var shelf_buttons: Array[Button] = shelf.get("_buttons")
	var tables: Array[DiningTable] = dining.get("_tables")
	var cook_buttons: Dictionary = kitchen.get("_buttons")

	# 待っている客（注文の古い順）に出せる料理があれば出す
	var waiting: Array[Customer] = []
	for c: Customer in customers:
		if c.is_waiting_food():
			waiting.append(c)
	waiting.sort_custom(func(a: Customer, b: Customer) -> bool: return a.order_sequence < b.order_sequence)
	var needed: Dictionary = {}
	for c: Customer in waiting:
		var slot: int = slots.find(c.dish.id)
		if slot >= 0:
			if randf() < float(_skill["wrong_rate"]):
				for j: int in slots.size():
					if slots[j] != "" and slots[j] != c.dish.id:
						slot = j
						break
			_hold(shelf, shelf_buttons, slot)
			(tables[c.table_index].get("_tap_button") as Button).pressed.emit()
			return
		DayStats.add_to(needed, c.dish.id, 1)
	# 足りない料理を作る（作っている分・置き場の分を引く）
	var queue: Array[DishData] = kitchen.get("_queue")
	var current: DishData = kitchen.get("_current")
	for d: DishData in queue:
		DayStats.add_to(needed, d.id, -1)
	if current != null:
		DayStats.add_to(needed, current.id, -1)
	for dish_id: String in needed:
		if int(needed[dish_id]) > 0 and cook_buttons.has(dish_id) and supply.get_remaining(dish_id) > 0:
			(cook_buttons[dish_id] as Button).pressed.emit()
			return
	# 上手なボットは、手が空いたら残りの多い料理を先に作っておく（置き場に2枠は空けておく）
	if bool(_skill["precook"]) and kitchen.get_pending_count() == 0 and shelf.free_count() > 2:
		var best: String = ""
		for dish_id: String in cook_buttons:
			if supply.get_remaining(dish_id) > (supply.get_remaining(best) if best != "" else 0):
				best = dish_id
		if best != "":
			(cook_buttons[best] as Button).pressed.emit()


func _hold(shelf: ReadyShelf, buttons: Array[Button], slot: int) -> void:
	if int(shelf.get("_held_index")) != slot:
		buttons[slot].pressed.emit()


func _do_result(screen: Node) -> void:
	var s: DayStats = GameState.today
	var missed: int = 0
	for dish_id: String in s.dish_missed:
		missed += int(s.dish_missed[dish_id])
	var stars: String = "%.1f" % s.average_stars() if s.has_ratings() else "-"
	_rows.append("| %d | %d | %d | %d | %d | %s | %s | %d | %d %s%s |" % [
		GameState.day, s.visitors, s.completed_orders, s.left_angry, missed, stars,
		UIText.signed(s.reputation_change), GameState.reputation, GameState.rank, GameState.get_rank_name(),
		"（ランクアップ）" if s.rank_up > 0 else ""])
	(screen.get("_next_button") as Button).pressed.emit()
	_days_done += 1
	if _days_done >= _days_to_run:
		print("[sim] skill=%s" % _skill_name)
		for row: String in _rows:
			print("[sim] ", row)
		GameState.delete_save()
		get_tree().quit()
