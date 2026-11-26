extends Node
## ゲーム全体の状態（オートロード: GameState）。
## 所持金・日数・在庫・評判・今日のメニューと仕込み・今日の集計を持ち、セーブ／ロードを行う。

signal money_changed(value: int)
signal inventory_changed
signal reputation_changed(value: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var money: int = 0
var day: int = 1
var reputation: int = 0
## { 食材id: 個数 }
var inventory: Dictionary = {}
var today: DayStats = DayStats.new()
## 今日出す料理のid（保存しない。アプリを起動中は前日の選択を引き継ぐ）
var today_menu: Array[String] = []
## 営業開始時に作っておく個数 { 料理id: 個数 }
var prep_counts: Dictionary = {}


func _ready() -> void:
	_new_game()
	load_game()


func _new_game() -> void:
	var cfg: GameConfig = Database.config
	money = cfg.start_money
	day = 1
	reputation = 0
	inventory.clear()
	for ing: IngredientData in Database.ingredients:
		inventory[ing.id] = int(cfg.start_inventory.get(ing.id, 0))
	today_menu.clear()
	for dish: DishData in Database.dishes:
		today_menu.append(dish.id)
	prep_counts.clear()


# ---------------------------------------------------------------
# お金・評判・在庫
# ---------------------------------------------------------------

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func add_reputation(delta: int) -> void:
	reputation = maxi(0, reputation + delta)
	reputation_changed.emit(reputation)


func get_stock(ingredient_id: String) -> int:
	return int(inventory.get(ingredient_id, 0))


func buy_ingredient(ingredient_id: String, count: int) -> bool:
	var ing: IngredientData = Database.get_ingredient(ingredient_id)
	if ing == null or count <= 0:
		return false
	var cost: int = ing.price * count
	if cost > money:
		return false
	inventory[ingredient_id] = get_stock(ingredient_id) + count
	add_money(-cost)
	inventory_changed.emit()
	return true


## 営業中に料理を1つ作れるだけの食材があるか
func has_ingredients(dish: DishData) -> bool:
	for ing_id: String in dish.ingredients:
		if get_stock(ing_id) < int(dish.ingredients[ing_id]):
			return false
	return true


## 料理1つ分の食材を使う。原価は今日の集計に入る
func consume_ingredients(dish: DishData) -> void:
	for ing_id: String in dish.ingredients:
		inventory[ing_id] = get_stock(ing_id) - int(dish.ingredients[ing_id])
	today.ingredient_cost += Database.get_dish_cost(dish)
	inventory_changed.emit()


# ---------------------------------------------------------------
# 今日のメニューと仕込み（営業準備画面）
# ---------------------------------------------------------------

func is_on_menu(dish_id: String) -> bool:
	return today_menu.has(dish_id)


func set_on_menu(dish_id: String, on: bool) -> void:
	if on and not today_menu.has(dish_id):
		today_menu.append(dish_id)
	elif not on:
		today_menu.erase(dish_id)
		prep_counts.erase(dish_id)
	inventory_changed.emit()


## 今日のメニュー（データの並び順）
func get_menu_dishes() -> Array[DishData]:
	var result: Array[DishData] = []
	for dish: DishData in Database.dishes:
		if today_menu.has(dish.id):
			result.append(dish)
	return result


func get_prep_count(dish_id: String) -> int:
	return int(prep_counts.get(dish_id, 0))


func get_total_prep() -> int:
	var total: int = 0
	for dish_id: String in prep_counts:
		total += int(prep_counts[dish_id])
	return total


## 仕込みのために取っておく食材の数
func get_reserved(ingredient_id: String) -> int:
	var total: int = 0
	for dish_id: String in prep_counts:
		var dish: DishData = Database.get_dish(dish_id)
		if dish != null and dish.ingredients.has(ingredient_id):
			total += int(dish.ingredients[ingredient_id]) * int(prep_counts[dish_id])
	return total


func can_add_prep(dish: DishData) -> bool:
	if not is_on_menu(dish.id):
		return false
	if get_total_prep() >= Database.config.shelf_capacity:
		return false
	for ing_id: String in dish.ingredients:
		if get_stock(ing_id) - get_reserved(ing_id) < int(dish.ingredients[ing_id]):
			return false
	return true


func change_prep(dish_id: String, delta: int) -> void:
	var dish: DishData = Database.get_dish(dish_id)
	if dish == null:
		return
	if delta > 0 and not can_add_prep(dish):
		return
	var next: int = maxi(0, get_prep_count(dish_id) + delta)
	if next == 0:
		prep_counts.erase(dish_id)
	else:
		prep_counts[dish_id] = next
	inventory_changed.emit()


# ---------------------------------------------------------------
# 営業の開始・集計・終了
# ---------------------------------------------------------------

## 今日の集計をリセットし、仕込みの分の食材を使う。作っておいた料理のidを返す
func begin_business() -> Array[String]:
	today = DayStats.new()
	var prepared: Array[String] = []
	for dish: DishData in get_menu_dishes():
		for i: int in get_prep_count(dish.id):
			if not has_ingredients(dish):
				break
			consume_ingredients(dish)
			prepared.append(dish.id)
	prep_counts.clear()
	return prepared


func record_visit() -> void:
	today.visitors += 1


func record_served(level: Satisfaction.Level) -> void:
	today.completed_orders += 1
	_apply_rating(level)


func record_payment(amount: int) -> void:
	today.sales += amount
	add_money(amount)


func record_angry() -> void:
	today.left_angry += 1
	_apply_rating(Satisfaction.Level.ANGRY)


func record_mistake() -> void:
	today.mistakes += 1


func _apply_rating(level: Satisfaction.Level) -> void:
	var cfg: GameConfig = Database.config
	var delta: int = Satisfaction.reputation_delta(level, cfg)
	var before: int = reputation
	add_reputation(delta)
	today.reputation_change += reputation - before
	today.add_rating(Satisfaction.stars(level, cfg))


## 営業終了時に1回だけ呼ぶ。その他経費を払う
func finish_business() -> void:
	today.other_expense = Database.config.other_expense
	add_money(-today.other_expense)


## 「次の日へ」で呼ぶ。日数を進めてセーブする
func advance_day() -> void:
	day += 1
	save_game()


# ---------------------------------------------------------------
# セーブ／ロード
# ---------------------------------------------------------------

func save_game() -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"money": money,
		"day": day,
		"reputation": reputation,
		"inventory": inventory.duplicate(),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("セーブできません: %s (%d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary):
		push_warning("セーブデータが壊れているため読み込みません")
		return false
	var data: Dictionary = _migrate(parsed as Dictionary)
	if data.is_empty():
		return false
	money = int(data.get("money", money))
	day = maxi(1, int(data.get("day", day)))
	reputation = maxi(0, int(data.get("reputation", reputation)))
	var saved_inventory: Variant = data.get("inventory", {})
	if saved_inventory is Dictionary:
		for ing: IngredientData in Database.ingredients:
			if (saved_inventory as Dictionary).has(ing.id):
				inventory[ing.id] = maxi(0, int(saved_inventory[ing.id]))
	money_changed.emit(money)
	reputation_changed.emit(reputation)
	inventory_changed.emit()
	return true


## 古いバージョンのセーブデータを今の形式に変換する。読めないものは空の辞書を返す
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		push_warning("対応していないセーブデータのバージョンです: %d" % version)
		return {}
	# 例: if version == 1: （v1 → v2 の変換）; version = 2
	data["version"] = version
	return data
