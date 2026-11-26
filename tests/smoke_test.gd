extends Node
## 動作確認用のボット。準備 → 営業 → 結果 → 次の日 を自動で2日分まわす。
## 実行: Godot --headless --path . res://tests/smoke_test.tscn
## 注意: user://save.json を書き換える。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const DAYS_TO_RUN := 2

var _main: Node
var _days_done: int = 0
var _cooldown: float = 0.0
var _made_mistake: bool = false
var _last_screen: String = ""


func _ready() -> void:
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
	for ing: IngredientData in Database.ingredients:
		GameState.buy_ingredient(ing.id, 5)
	for dish: DishData in Database.dishes:
		GameState.change_prep(dish.id, 1)
	print("[smoke] prep: money=%d prep_total=%d" % [GameState.money, GameState.get_total_prep()])
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
		print("[smoke] save: ", FileAccess.get_file_as_string(GameState.SAVE_PATH).replace("\n", " "))
		print("[smoke] done")
		get_tree().quit()
