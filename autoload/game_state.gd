extends Node
## ゲーム全体の状態（オートロード: GameState）。
## 所持金・日数・在庫・評判、営業準備の内容（仕入れ予定・仕込み数・開店時の置き場）、
## 今日の集計を持ち、セーブ／ロードを行う。
##
## 用語:
##   仕込み数: その日に出せる料理の数（料理ごとに 0〜99）。食材は営業開始のときにまとめて在庫から引く
##             仕込み数が1以上の料理が「今日出す料理」（今日のメニュー）。解放済みの料理だけ仕込める
##             仕込み数は在庫に関係なく決められる。足りない食材は仕入れの手順で補う（足りないままでは置き場の手順へ進めない）
##   残り:     仕込み数のうち、まだ店主が作っていない数（営業中）
##   置き場:   完成した料理を置く場所（6枠）。開店時に並べておく分も仕込み数から使う
##   トッピング: 追加の1皿（ToppingData）。仕込み・仕入れ・置き場・調理は料理と同じに扱う（prep_counts などに料理と一緒に入る）
##   従業員:   ホールスタッフ（StaffData）。雇える人数はランクで決まり、営業した日ごとに日給がかかる

signal money_changed(value: int)
## 在庫・仕入れ予定・仕込み数・置き場の初期配置のどれかが変わった
signal inventory_changed
signal reputation_changed(value: int)

const DEFAULT_SAVE_PATH := "user://save.json"
const SAVE_VERSION := 10

var money: int = 0
var day: int = 1
var reputation: int = 0
## 確定した在庫 { 食材id: 個数 }
var inventory: Dictionary = {}
## 仕入れ予定 { 食材id: 個数 }（「仕入れる」で確定するまで、お金も在庫も変わらない。保存しない）
var purchase_plan: Dictionary = {}
var today: DayStats = DayStats.new()
## 仕込み数 { 料理id: 個数 }
var prep_counts: Dictionary = {}
## 開店時に置き場に並べておく料理（並べる順。最大は置き場の枠の数）
var shelf_plan: Array[String] = []
## 前回の営業の仕込み数と置き場の初期配置（「前回と同じ仕込み」用。セーブする）
var last_prep_counts: Dictionary = {}
var last_shelf_plan: Array[String] = []
## 前回の営業で、仕込んだ料理ごとに売れた数 { 料理id: 数 }（準備画面の「前回 ○食売れた」用。セーブする）
var last_sold_counts: Dictionary = {}
## 前回の営業の、料理ごとの売り逃し（頼みたかったのに頼めなかった人数）{ 料理id: 人数 }（セーブする）
var last_missed_counts: Dictionary = {}
## 店舗ランク（1始まり）。評判で上がり、一度上がったら評判が下がっても下げない（セーブする）
var rank: int = 1
## 日ごとの結果の履歴（カレンダー用。セーブする）。1日1行の配列で持つ（何年分たまっても軽いように）
##   [営業日, 売上, 利益, 来客数, 評価×10（評価なしは -1）, 評判の増減]
var history: Array[PackedInt32Array] = []
## 営業日 → history の位置
var _history_index: Dictionary = {}
## 設備のレベル { 設備id: レベル }（0 = まだ買っていない。セーブする）
var equipment_levels: Dictionary = {}
## 解放済みの料理・トッピングのid（ランクと日数で解放する。一度解放したら評判が下がっても使える。セーブする）
var unlocked_dishes: Array[String] = []
## 雇っているホールスタッフのid（雇った順。セーブする）
var hired_staff: Array[String] = []
## その日の準備を始めた時点の所持金と、その日に仕入れに使ったお金（結果画面の「所持金の増減」用。保存しない）
var day_start_money: int = 0
var day_purchase_cost: int = 0
var day_start_stock_value: int = 0
## セーブファイルの場所。テストのときだけ別の場所に切り替える
var save_path: String = DEFAULT_SAVE_PATH


func _ready() -> void:
	_new_game()
	load_game()


## セーブの場所を切り替え、その場所のデータで状態を作り直す（テスト用）。
## 切り替えた後は、元のセーブを読み書きしない
func use_save_path(path: String) -> void:
	save_path = path
	_new_game()
	load_game()


## 今のセーブの場所にあるファイルを消す
func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _new_game() -> void:
	var cfg: GameConfig = Database.config
	money = cfg.start_money
	day = 1
	reputation = 0
	inventory.clear()
	for ing: IngredientData in Database.ingredients:
		inventory[ing.id] = int(cfg.start_inventory.get(ing.id, 0))
	purchase_plan.clear()
	prep_counts.clear()
	shelf_plan.clear()
	last_prep_counts.clear()
	last_shelf_plan.clear()
	last_sold_counts.clear()
	last_missed_counts.clear()
	rank = 1
	history.clear()
	_history_index.clear()
	equipment_levels.clear()
	unlocked_dishes.clear()
	hired_staff.clear()
	_unlock_by_rank()
	_start_day_accounting()


## その日のお金の記録を始める（準備画面を始める時点）。在庫の原価も覚えておく（結果画面の「在庫の増減」用）
func _start_day_accounting() -> void:
	day_start_money = money
	day_purchase_cost = 0
	day_start_stock_value = get_stock_value()


## 確定した在庫の原価の合計
func get_stock_value() -> int:
	var total: int = 0
	for ing: IngredientData in Database.ingredients:
		total += ing.price * get_stock(ing.id)
	return total


# ---------------------------------------------------------------
# お金・評判・在庫
# ---------------------------------------------------------------

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func add_reputation(delta: int) -> void:
	reputation = maxi(0, reputation + delta)
	reputation_changed.emit(reputation)


## 確定した在庫（仕入れ予定は含まない）
func get_stock(ingredient_id: String) -> int:
	return int(inventory.get(ingredient_id, 0))


# ---------------------------------------------------------------
# 仕入れ予定（確定式）
# ---------------------------------------------------------------

func get_planned_purchase(ingredient_id: String) -> int:
	return int(purchase_plan.get(ingredient_id, 0))


## 仕入れ予定を増減する。0未満にはならない（今ある在庫は減らせない）
func change_purchase(ingredient_id: String, delta: int) -> void:
	if Database.get_ingredient(ingredient_id) == null:
		return
	var next: int = maxi(0, get_planned_purchase(ingredient_id) + delta)
	if next == 0:
		purchase_plan.erase(ingredient_id)
	else:
		purchase_plan[ingredient_id] = next
	inventory_changed.emit()


func has_purchase_plan() -> bool:
	return not purchase_plan.is_empty()


## 仕入れ予定の合計金額
func get_purchase_total() -> int:
	var total: int = 0
	for ing_id: String in purchase_plan:
		var ing: IngredientData = Database.get_ingredient(ing_id)
		if ing != null:
			total += ing.price * int(purchase_plan[ing_id])
	return total


## 仕入れても所持金がマイナスにならないか（マイナスになっても仕入れはできる。表示の注意に使う）
func can_afford_purchase() -> bool:
	return get_purchase_total() <= money


## 予定どおり仕入れたあとの所持金
func get_money_after_purchase() -> int:
	return money - get_purchase_total()


## 仕入れ予定を確定する（お金を払って在庫に入れる）。所持金が足りなくても仕入れられる（所持金はマイナスになる）
func confirm_purchase() -> bool:
	if not has_purchase_plan():
		return false
	var total: int = get_purchase_total()
	day_purchase_cost += total
	for ing_id: String in purchase_plan:
		inventory[ing_id] = get_stock(ing_id) + int(purchase_plan[ing_id])
	purchase_plan.clear()
	add_money(-total)
	inventory_changed.emit()
	return true


func clear_purchase_plan() -> void:
	purchase_plan.clear()
	inventory_changed.emit()


# ---------------------------------------------------------------
# 今日のメニューと仕込み数（営業準備画面）
# ---------------------------------------------------------------

## 今日出す料理か（仕込み数が1以上）
func is_on_menu(dish_id: String) -> bool:
	return get_prep_count(dish_id) > 0


## 今日のメニュー＝仕込み数が1以上の料理（データの並び順。トッピングは含まない）
func get_menu_dishes() -> Array[DishData]:
	return _filter_on_menu(Database.dishes)


## 今日出すトッピング（仕込み数が1以上）
func get_menu_toppings() -> Array[DishData]:
	var list: Array[DishData] = []
	list.assign(Database.toppings)
	return _filter_on_menu(list)


## 今日出す料理とトッピングの両方（料理が先）
func get_menu_items() -> Array[DishData]:
	return _filter_on_menu(Database.items)


func _filter_on_menu(list: Array[DishData]) -> Array[DishData]:
	var result: Array[DishData] = []
	for dish: DishData in list:
		if is_on_menu(dish.id):
			result.append(dish)
	return result


# ---------------------------------------------------------------
# 料理の解放（評判）
# ---------------------------------------------------------------

func is_unlocked(dish_id: String) -> bool:
	return unlocked_dishes.has(dish_id)


## 解放済みの料理（データの並び順。トッピングは含まない）
func get_unlocked_dishes() -> Array[DishData]:
	return _filter_unlocked(Database.dishes, true)


## 解放済みのトッピング
func get_unlocked_toppings() -> Array[DishData]:
	var list: Array[DishData] = []
	list.assign(Database.toppings)
	return _filter_unlocked(list, true)


## 解放済みの料理とトッピングの両方（料理が先）
func get_unlocked_items() -> Array[DishData]:
	return _filter_unlocked(Database.items, true)


## まだ解放していない料理（解放される日が早い順。同じ日ならランクが低い順。トッピングは含まない）
func get_locked_dishes() -> Array[DishData]:
	return _sort_locked(_filter_unlocked(Database.dishes, false))


## まだ解放していないトッピング（解放される日が早い順）
func get_locked_toppings() -> Array[DishData]:
	var list: Array[DishData] = []
	list.assign(Database.toppings)
	return _sort_locked(_filter_unlocked(list, false))


func _filter_unlocked(list: Array[DishData], unlocked: bool) -> Array[DishData]:
	var result: Array[DishData] = []
	for dish: DishData in list:
		if is_unlocked(dish.id) == unlocked:
			result.append(dish)
	return result


func _sort_locked(result: Array[DishData]) -> Array[DishData]:
	result.sort_custom(func(a: DishData, b: DishData) -> bool:
		return a.unlock_day < b.unlock_day or (a.unlock_day == b.unlock_day and a.unlock_rank < b.unlock_rank))
	return result


## 解放済みの料理・トッピングで使う食材（データの並び順）
func get_unlocked_ingredients() -> Array[IngredientData]:
	var result: Array[IngredientData] = []
	var dishes: Array[DishData] = get_unlocked_items()
	for ing: IngredientData in Database.ingredients:
		for dish: DishData in dishes:
			if dish.ingredients.has(ing.id):
				result.append(ing)
				break
	return result


## 解放の条件（ランクと営業日数）を満たした料理・トッピングを解放する。新しく解放したものを返す。
## for_day: どの営業日について判定するか（省略すると今の日。営業結果のあとは次の営業日で判定する）
func _unlock_by_rank(for_day: int = -1) -> Array[DishData]:
	var target_day: int = day if for_day < 0 else for_day
	var newly: Array[DishData] = []
	for dish: DishData in Database.items:
		if not is_unlocked(dish.id) and rank >= dish.unlock_rank and target_day >= dish.unlock_day:
			unlocked_dishes.append(dish.id)
			newly.append(dish)
	return newly


# ---------------------------------------------------------------
# 店舗ランク
# ---------------------------------------------------------------

func get_rank_name() -> String:
	return Database.get_rank_name(rank)


func is_max_rank() -> bool:
	return rank >= Database.get_max_rank()


## 次のランクまでの進み具合（0〜1）。最高ランクなら1
func get_rank_progress() -> float:
	if is_max_rank():
		return 1.0
	var from: int = Database.get_rank_threshold(rank)
	var to: int = Database.get_rank_threshold(rank + 1)
	return clampf(float(reputation - from) / float(maxi(1, to - from)), 0.0, 1.0)


## 評判でランクを上げる（下げない）。上がったら新しいランク、上がらなければ 0 を返す。
## ランクが上がったら、そのランクで使える料理も解放する
func _update_rank() -> int:
	var by_reputation: int = Database.get_rank_for_reputation(reputation)
	if by_reputation <= rank:
		return 0
	rank = by_reputation
	return rank


func get_prep_count(dish_id: String) -> int:
	return int(prep_counts.get(dish_id, 0))


## 料理（トッピングは含まない）の仕込み数の合計。料理が1つもなければ営業を始められない
func get_total_prep() -> int:
	var total: int = 0
	for dish: DishData in get_menu_dishes():
		total += get_prep_count(dish.id)
	return total


## トッピングの仕込み数の合計
func get_total_topping_prep() -> int:
	var total: int = 0
	for dish: DishData in get_menu_toppings():
		total += get_prep_count(dish.id)
	return total


## 仕込みで使う食材の数（営業開始のときに在庫から引く分）
func get_reserved(ingredient_id: String) -> int:
	var total: int = 0
	for dish_id: String in prep_counts:
		var dish: DishData = Database.get_dish(dish_id)
		if dish != null and dish.ingredients.has(ingredient_id):
			total += int(dish.ingredients[ingredient_id]) * int(prep_counts[dish_id])
	return total


## 仕込み数をあと1増やせるか（解放済みで、上限 99 未満。在庫は関係ない）
func can_add_prep(dish: DishData) -> bool:
	return is_unlocked(dish.id) and get_prep_count(dish.id) < Database.config.max_prep_per_dish


## 仕込み数に対して、確定した在庫で足りない食材 { 食材id: 足りない数 }（仕入れ予定は含めない）
func get_prep_shortage() -> Dictionary:
	var result: Dictionary = {}
	for ing: IngredientData in Database.ingredients:
		var lack: int = get_reserved(ing.id) - get_stock(ing.id)
		if lack > 0:
			result[ing.id] = lack
	return result


func has_prep_shortage() -> bool:
	return not get_prep_shortage().is_empty()


## その料理で使う食材のうち、仕込み数の合計に対して足りないもの { 食材id: 足りない数 }
func get_dish_shortage(dish: DishData) -> Dictionary:
	var shortage: Dictionary = get_prep_shortage()
	var result: Dictionary = {}
	for ing_id: String in dish.ingredients:
		if shortage.has(ing_id):
			result[ing_id] = shortage[ing_id]
	return result


## 仕込み数に足りない分を、仕入れ予定にまとめて入れる（予定がすでに足りていれば変えない）。入れたら true
func plan_prep_shortage() -> bool:
	var changed: bool = false
	var shortage: Dictionary = get_prep_shortage()
	for ing_id: String in shortage:
		if get_planned_purchase(ing_id) < int(shortage[ing_id]):
			purchase_plan[ing_id] = int(shortage[ing_id])
			changed = true
	if changed:
		inventory_changed.emit()
	return changed


## 確定した在庫で作れるように、仕込み数を減らす（一覧の下の料理から1つずつ減らす）
func reduce_prep_to_stock() -> void:
	var dishes: Array[DishData] = get_menu_items()
	dishes.reverse()
	var guard: int = 0
	while has_prep_shortage() and guard < 10000:
		guard += 1
		var shortage: Dictionary = get_prep_shortage()
		var reduced: bool = false
		for dish: DishData in dishes:
			if get_prep_count(dish.id) <= 0:
				continue
			for ing_id: String in dish.ingredients:
				if shortage.has(ing_id):
					_set_prep(dish.id, get_prep_count(dish.id) - 1)
					reduced = true
					break
			if reduced:
				break
		if not reduced:
			break
	inventory_changed.emit()


func _set_prep(dish_id: String, count: int) -> void:
	if count <= 0:
		prep_counts.erase(dish_id)
	else:
		prep_counts[dish_id] = count
	_trim_shelf_plan(dish_id)


## 仕込み数を増減する（0〜99。解放済みの料理だけ）。実際に変わった数を返す
func change_prep(dish_id: String, delta: int) -> int:
	var dish: DishData = Database.get_dish(dish_id)
	if dish == null or delta == 0:
		return 0
	var before: int = get_prep_count(dish_id)
	var next: int = before
	if delta > 0:
		for i: int in delta:
			if not can_add_prep(dish):
				break
			next += 1
			prep_counts[dish_id] = next
	else:
		next = maxi(0, before + delta)
	if next == 0:
		prep_counts.erase(dish_id)
	else:
		prep_counts[dish_id] = next
	_trim_shelf_plan(dish_id)
	if next != before:
		inventory_changed.emit()
	return next - before


## 仕込み数が1以上の料理・トッピングについて、注文の目安と仕込み数から見た食材ごとの必要数の目安 { 食材id: 個数 }
func get_ingredient_needs() -> Dictionary:
	return DemandEstimator.ingredient_needs(get_menu_items(), prep_counts, get_expected_orders(), Database.config)


## 料理・トッピングごとの注文数の目安 { id: 数 }。解放済みのものをすべて出したときの目安（仕込み数で変わらない）
func get_expected_orders() -> Dictionary:
	return DemandEstimator.expected_orders(get_unlocked_dishes(), Database.customer_types, Database.config, reputation,
		get_unlocked_toppings())


## 目安に対して、確定した在庫で足りない数（足りていれば0）
func get_shortage(ingredient_id: String, needs: Dictionary) -> int:
	return maxi(0, int(needs.get(ingredient_id, 0)) - get_stock(ingredient_id))


## 目安に対して、仕入れ予定どおりに仕入れても足りない数
func get_shortage_after_purchase(ingredient_id: String, needs: Dictionary) -> int:
	return maxi(0, get_shortage(ingredient_id, needs) - get_planned_purchase(ingredient_id))


# ---------------------------------------------------------------
# 開店時の置き場
# ---------------------------------------------------------------

func get_shelf_plan_count(dish_id: String) -> int:
	return shelf_plan.count(dish_id)


## 開店時の置き場にもう1つ並べられるか（枠が空いていて、仕込み数を超えない）
func can_add_to_shelf_plan(dish_id: String) -> bool:
	return shelf_plan.size() < get_shelf_capacity() \
		and get_shelf_plan_count(dish_id) < get_prep_count(dish_id)


func add_to_shelf_plan(dish_id: String) -> bool:
	if not can_add_to_shelf_plan(dish_id):
		return false
	shelf_plan.append(dish_id)
	inventory_changed.emit()
	return true


## 開店時の置き場の index 番目を外す
func remove_from_shelf_plan(index: int) -> void:
	if index < 0 or index >= shelf_plan.size():
		return
	shelf_plan.remove_at(index)
	inventory_changed.emit()


func clear_shelf_plan() -> void:
	shelf_plan.clear()
	inventory_changed.emit()


## 仕込み数を超えて並べている分を、後ろから外す
func _trim_shelf_plan(dish_id: String) -> void:
	while get_shelf_plan_count(dish_id) > get_prep_count(dish_id):
		shelf_plan.remove_at(shelf_plan.rfind(dish_id))


# ---------------------------------------------------------------
# 前回と同じ仕込み
# ---------------------------------------------------------------

func has_last_prep() -> bool:
	return not last_prep_counts.is_empty()


## 仕込み数と置き場の初期配置を前回と同じにする。食材が足りなくても仕込み数はそのまま入れる
## （足りない食材は仕入れの手順で補う）。解放されていない料理があれば false
func apply_last_prep() -> bool:
	prep_counts.clear()
	shelf_plan.clear()
	var complete: bool = true
	for dish: DishData in Database.items:
		var target: int = int(last_prep_counts.get(dish.id, 0))
		if target <= 0:
			continue
		if not is_unlocked(dish.id):
			complete = false
			continue
		prep_counts[dish.id] = mini(target, Database.config.max_prep_per_dish)
	for dish_id: String in last_shelf_plan:
		if can_add_to_shelf_plan(dish_id):
			shelf_plan.append(dish_id)
		else:
			complete = false
	inventory_changed.emit()
	return complete


# ---------------------------------------------------------------
# 営業の開始・集計・終了
# ---------------------------------------------------------------

## 今日の集計をリセットし、仕込み数の分の食材をまとめて在庫から引く。
## 仕込み数と開店時の置き場を返し、準備画面の入力は空にする。
## 戻り値: { "prep": { 料理id: 仕込み数 }, "shelf": Array[String] }
func begin_business() -> Dictionary:
	today = DayStats.new()
	var prep: Dictionary = {}
	for dish: DishData in get_menu_items():
		var count: int = get_prep_count(dish.id)
		# 念のため、在庫で作れる分に収める（ふつうは準備画面で、足りないままでは先へ進めない）
		for ing_id: String in dish.ingredients:
			count = mini(count, get_stock(ing_id) / maxi(1, int(dish.ingredients[ing_id])))
		if count <= 0:
			continue
		for ing_id: String in dish.ingredients:
			inventory[ing_id] = get_stock(ing_id) - int(dish.ingredients[ing_id]) * count
		today.ingredient_cost += Database.get_dish_cost(dish) * count
		prep[dish.id] = count
	today.dish_prepared = prep.duplicate()
	today.staff_count = hired_staff.size()
	today.day_start_money = day_start_money
	today.purchase_cost = day_purchase_cost
	today.day_start_stock_value = day_start_stock_value
	var shelf: Array[String] = []
	var placed: Dictionary = {}
	for dish_id: String in shelf_plan:
		if shelf.size() < get_shelf_capacity() and int(placed.get(dish_id, 0)) < int(prep.get(dish_id, 0)):
			shelf.append(dish_id)
			placed[dish_id] = int(placed.get(dish_id, 0)) + 1
	last_prep_counts = prep.duplicate()
	last_shelf_plan = shelf.duplicate()
	prep_counts.clear()
	shelf_plan.clear()
	purchase_plan.clear()
	inventory_changed.emit()
	return { "prep": prep, "shelf": shelf }


func record_visit() -> void:
	today.visitors += 1


## 料理だけの注文（トッピングなし）を出し終えた。料理1皿の記録と、注文の完了をまとめて記録する
func record_served(dish_id: String, level: Satisfaction.Level) -> void:
	record_item_served(dish_id)
	record_order_completed(level)


## 料理またはトッピングを1皿出した（売れた数に数える）
func record_item_served(item_id: String) -> void:
	DayStats.add_to(today.dish_sold, item_id, 1)


## 1人の注文（料理＋トッピング）をすべて出し終えた。満足度を記録する
func record_order_completed(level: Satisfaction.Level) -> void:
	today.completed_orders += 1
	_apply_rating(level)


func record_payment(dish_id: String, amount: int) -> void:
	today.sales += amount
	DayStats.add_to(today.dish_sales, dish_id, amount)
	add_money(amount)


func record_angry() -> void:
	today.left_angry += 1
	_apply_rating(Satisfaction.Level.ANGRY)


func record_mistake() -> void:
	today.mistakes += 1


func record_sold_out() -> void:
	today.sold_out = true


## 売り逃し（その料理を頼みたかったのに頼めなかった人数）を記録する
func record_missed(dish_id: String, count: int) -> void:
	if count > 0:
		DayStats.add_to(today.dish_missed, dish_id, count)


## 営業終了時に残った料理（残り・置き場・調理中）を廃棄として記録する。原価はすでに食材原価に入っている
func record_waste(leftover: Dictionary) -> void:
	for dish_id: String in leftover:
		var count: int = int(leftover[dish_id])
		var dish: DishData = Database.get_dish(dish_id)
		if dish == null or count <= 0:
			continue
		today.waste_count += count
		today.waste_cost += Database.get_dish_cost(dish) * count
		DayStats.add_to(today.dish_waste, dish_id, count)


## 客1人の満足度を記録する。評判の点数はその日の分を足しておき、営業結果のときにまとめて反映する
func _apply_rating(level: Satisfaction.Level) -> void:
	var cfg: GameConfig = Database.config
	today.reputation_points += Satisfaction.reputation_points(level, cfg)
	today.add_rating(Satisfaction.stars(level, cfg))


## その日の評判の点数（客ごとの点数＋売り逃し・ミスの点数）
func get_day_reputation_points() -> float:
	var missed: int = 0
	for dish_id: String in today.dish_missed:
		missed += int(today.dish_missed[dish_id])
	return today.reputation_points + float(missed) * Database.config.reputation_missed 		+ float(today.mistakes) * Database.config.reputation_mistake


## 営業終了時に1回だけ呼ぶ。その他経費と人件費（雇っている従業員の日給）を払う
func finish_business() -> void:
	today.other_expense = Database.config.other_expense
	add_money(-today.other_expense)
	today.labor_cost = get_daily_wage_total()
	today.staff_count = hired_staff.size()
	add_money(-today.labor_cost)
	# 次の準備画面で「前回 ○食売れた」と出すため、仕込んだ料理ごとに売れた数を覚える（0食も含める）
	last_sold_counts.clear()
	last_missed_counts.clear()
	for dish_id: String in today.get_prepared_dish_ids():
		last_sold_counts[dish_id] = int(today.dish_sold.get(dish_id, 0))
		last_missed_counts[dish_id] = int(today.dish_missed.get(dish_id, 0))
	# その日の評判をまとめて反映する（点数 × 今のランクの倍率。マイナスの日は少しだけ下がる）
	var before: int = reputation
	add_reputation(Database.get_reputation_delta(get_day_reputation_points(), rank))
	today.reputation_change = reputation - before
	# 評判が届いていればランクを上げ、そのランクの料理を解放する
	today.rank_up = _update_rank()
	today.new_unlocks.clear()
	for dish: DishData in _unlock_by_rank(day + 1):
		today.new_unlocks.append(dish.id)
	_record_history()


# ---------------------------------------------------------------
# 従業員（ホールスタッフ）
# ---------------------------------------------------------------

## 今のランクで雇える人数
func get_staff_limit() -> int:
	return Database.get_staff_limit(rank)


func is_hired(staff_id: String) -> bool:
	return hired_staff.has(staff_id)


## 雇っている従業員（雇った順）
func get_hired_staff() -> Array[StaffData]:
	var result: Array[StaffData] = []
	for staff_id: String in hired_staff:
		var data: StaffData = Database.get_staff(staff_id)
		if data != null:
			result.append(data)
	return result


## 雇えるか（候補にいて、まだ雇っておらず、ランクの人数の上限に空きがある）
func can_hire(staff_id: String) -> bool:
	return Database.get_staff(staff_id) != null and not is_hired(staff_id) and hired_staff.size() < get_staff_limit()


## 雇う（費用はかからない。日給は営業した日ごとにかかる）。雇えたら true
func hire_staff(staff_id: String) -> bool:
	if not can_hire(staff_id):
		return false
	hired_staff.append(staff_id)
	return true


## やめてもらう。やめてもらえたら true
func dismiss_staff(staff_id: String) -> bool:
	if not is_hired(staff_id):
		return false
	hired_staff.erase(staff_id)
	return true


## 雇っている従業員の日給の合計（営業した日ごとにかかる）
func get_daily_wage_total() -> int:
	var total: int = 0
	for data: StaffData in get_hired_staff():
		total += data.daily_wage
	return total


# ---------------------------------------------------------------
# 設備（お店の強化）
# ---------------------------------------------------------------

## 設備を買えない理由
enum BuyBlock { NONE, MAX_LEVEL, RANK, MONEY }


func get_equipment_level(equipment_id: String) -> int:
	return int(equipment_levels.get(equipment_id, 0))


## その効果の設備の今の値（設備のデータがなければ fallback）
func _equipment_value(effect: EquipmentData.Effect, fallback: float) -> float:
	for e: EquipmentData in Database.equipment:
		if e.effect == effect:
			return e.get_value(get_equipment_level(e.id))
	return fallback


## 席の数（イスの数。お客さん1人が1席。テーブルは相席してよい）
func get_seat_count() -> int:
	return int(_equipment_value(EquipmentData.Effect.SEATS, Database.config.seat_count))


## 置き場の枠の数
func get_shelf_capacity() -> int:
	return int(_equipment_value(EquipmentData.Effect.SHELF, Database.config.shelf_capacity))


## 設備の効果を入れた、料理1つの調理時間（秒）
func get_cook_time(dish: DishData) -> float:
	return dish.cook_time * get_cook_time_scale(dish)


## 設備による調理時間の倍率（1.0 = そのまま）
func get_cook_time_scale(dish: DishData) -> float:
	var scale: float = 1.0
	for e: EquipmentData in Database.equipment:
		if e.affects_dish(dish):
			scale *= e.get_value(get_equipment_level(e.id))
	return scale


## 設備をあと1レベル上げられるか。上げられなければ理由
func get_buy_block(equipment_id: String) -> BuyBlock:
	var e: EquipmentData = Database.get_equipment(equipment_id)
	if e == null:
		return BuyBlock.MAX_LEVEL
	var level: int = get_equipment_level(equipment_id)
	if level >= e.get_max_level():
		return BuyBlock.MAX_LEVEL
	if rank < e.get_required_rank(level):
		return BuyBlock.RANK
	if money < e.get_price(level):
		return BuyBlock.MONEY
	return BuyBlock.NONE


## 設備を1レベル上げる（お金を払う）。買えたら true
func buy_equipment(equipment_id: String) -> bool:
	if get_buy_block(equipment_id) != BuyBlock.NONE:
		return false
	var e: EquipmentData = Database.get_equipment(equipment_id)
	var level: int = get_equipment_level(equipment_id)
	add_money(-e.get_price(level))
	equipment_levels[equipment_id] = level + 1
	# 置き場の枠が増えても減っても、開店時の置き場が枠を超えないようにする
	while shelf_plan.size() > get_shelf_capacity():
		shelf_plan.remove_at(shelf_plan.size() - 1)
	inventory_changed.emit()
	return true


# ---------------------------------------------------------------
# 日ごとの結果の履歴（カレンダー）
# ---------------------------------------------------------------

const HISTORY_DAY := 0
const HISTORY_SALES := 1
const HISTORY_PROFIT := 2
const HISTORY_VISITORS := 3
const HISTORY_STARS10 := 4
const HISTORY_REPUTATION := 5


func _record_history() -> void:
	var stars10: int = roundi(today.average_stars() * 10.0) if today.has_ratings() else -1
	var row: PackedInt32Array = PackedInt32Array([day, today.sales, today.profit(), today.visitors, stars10, today.reputation_change])
	if _history_index.has(day):
		history[int(_history_index[day])] = row
	else:
		_history_index[day] = history.size()
		history.append(row)


## その営業日の結果（なければ空の配列）
func get_history(business_day: int) -> PackedInt32Array:
	if not _history_index.has(business_day):
		return PackedInt32Array()
	return history[int(_history_index[business_day])]


func _set_history(rows: Variant) -> void:
	history.clear()
	_history_index.clear()
	if not (rows is Array):
		return
	for item: Variant in rows:
		if not (item is Array) or (item as Array).size() < 6:
			continue
		var row: PackedInt32Array = PackedInt32Array()
		for i: int in 6:
			row.append(int((item as Array)[i]))
		_history_index[row[HISTORY_DAY]] = history.size()
		history.append(row)


## 前回の営業で、その料理が何食売れたか。前回仕込んでいない（または前回がない）なら -1
func get_last_sold(dish_id: String) -> int:
	return int(last_sold_counts.get(dish_id, -1))


## 前回の営業の、その料理の売り逃し（頼みたかったのに頼めなかった人数）
func get_last_missed(dish_id: String) -> int:
	return int(last_missed_counts.get(dish_id, 0))


## 「次の日へ」で呼ぶ。日数を進めてセーブする
func advance_day() -> void:
	day += 1
	save_game()
	_start_day_accounting()


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
		"last_prep": last_prep_counts.duplicate(),
		"last_shelf": Array(last_shelf_plan),
		"last_sold": last_sold_counts.duplicate(),
		"last_missed": last_missed_counts.duplicate(),
		"unlocked": Array(unlocked_dishes),
		"rank": rank,
		"equipment": equipment_levels.duplicate(),
		"staff": Array(hired_staff),
		"history": _history_for_save(),
	}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("セーブできません: %s (%d)" % [save_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _history_for_save() -> Array:
	var rows: Array = []
	for row: PackedInt32Array in history:
		rows.append(Array(row))
	return rows


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
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
	last_prep_counts.clear()
	var saved_prep: Variant = data.get("last_prep", {})
	if saved_prep is Dictionary:
		for dish: DishData in Database.items:
			var count: int = clampi(int((saved_prep as Dictionary).get(dish.id, 0)), 0, Database.config.max_prep_per_dish)
			if count > 0:
				last_prep_counts[dish.id] = count
	last_shelf_plan.clear()
	var saved_shelf: Variant = data.get("last_shelf", [])
	if saved_shelf is Array:
		for item: Variant in saved_shelf:
			var dish_id: String = str(item)
			if Database.get_dish(dish_id) != null and last_shelf_plan.size() < 64:
				last_shelf_plan.append(dish_id)
	last_sold_counts.clear()
	var saved_sold: Variant = data.get("last_sold", {})
	if saved_sold is Dictionary:
		for dish: DishData in Database.items:
			if (saved_sold as Dictionary).has(dish.id):
				last_sold_counts[dish.id] = maxi(0, int(saved_sold[dish.id]))
	last_missed_counts.clear()
	var saved_missed: Variant = data.get("last_missed", {})
	if saved_missed is Dictionary:
		for dish: DishData in Database.items:
			if (saved_missed as Dictionary).has(dish.id):
				last_missed_counts[dish.id] = maxi(0, int(saved_missed[dish.id]))
	unlocked_dishes.clear()
	var saved_unlocked: Variant = data.get("unlocked", [])
	if saved_unlocked is Array:
		for item: Variant in saved_unlocked:
			var dish_id: String = str(item)
			if Database.get_dish(dish_id) != null and not unlocked_dishes.has(dish_id):
				unlocked_dishes.append(dish_id)
	# ランクは下げない。セーブのランクと、今の評判から決まるランクの高いほう
	rank = clampi(maxi(int(data.get("rank", 1)), Database.get_rank_for_reputation(reputation)),
		1, Database.get_max_rank())
	_unlock_by_rank()
	_set_history(data.get("history", []))
	equipment_levels.clear()
	var saved_equipment: Variant = data.get("equipment", {})
	if saved_equipment is Dictionary:
		for e: EquipmentData in Database.equipment:
			if (saved_equipment as Dictionary).has(e.id):
				equipment_levels[e.id] = clampi(int(saved_equipment[e.id]), 0, e.get_max_level())
	hired_staff.clear()
	var saved_staff: Variant = data.get("staff", [])
	if saved_staff is Array:
		for item: Variant in saved_staff:
			var staff_id: String = str(item)
			if Database.get_staff(staff_id) != null and not hired_staff.has(staff_id) and hired_staff.size() < get_staff_limit():
				hired_staff.append(staff_id)
	_start_day_accounting()
	money_changed.emit(money)
	reputation_changed.emit(reputation)
	inventory_changed.emit()
	return true


## 席の数がいちばん近い「席の拡張」のレベル（同じくらい近いときは多いほう）
func _closest_seat_level(seats: int) -> int:
	var e: EquipmentData = Database.get_equipment("seats")
	if e == null:
		return 0
	var best: int = 0
	for level: int in range(0, e.get_max_level() + 1):
		if absf(e.get_value(level) - seats) <= absf(e.get_value(best) - seats):
			best = level
	return best


## 古いバージョンのセーブデータを今の形式に変換する。読めないものは空の辞書を返す
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		push_warning("対応していないセーブデータのバージョンです: %d" % version)
		return {}
	if version == 1:
		# v2 で「前回の仕込み」を追加。v1 のセーブには無いので空にする
		data["last_prep"] = {}
		version = 2
	if version == 2:
		# v3 で「仕込み数」と「開店時の置き場」を分けた。
		# v2 までの仕込みは、作ったものを全部置き場に並べて始めていたので、両方に同じ内容を入れる
		var shelf: Array = []
		var old_prep: Variant = data.get("last_prep", {})
		if old_prep is Dictionary:
			for dish: DishData in Database.dishes:
				for i: int in int((old_prep as Dictionary).get(dish.id, 0)):
					shelf.append(dish.id)
		data["last_shelf"] = shelf
		version = 3
	if version == 3:
		# v4 で「前回売れた数」を追加。v3 のセーブには記録がないので空にする（次の営業から出る）
		data["last_sold"] = {}
		version = 4
	if version == 4:
		# v5 で料理と食材を追加し、売り逃しの記録を追加した。
		# セーブにない食材（新しく追加した卵・玉ねぎなど）は、ゲーム開始時の在庫を入れる
		var raw_inventory: Variant = data.get("inventory", {})
		var inv: Dictionary = raw_inventory if raw_inventory is Dictionary else {}
		for ing: IngredientData in Database.ingredients:
			if not inv.has(ing.id):
				inv[ing.id] = int(Database.config.start_inventory.get(ing.id, 0))
		data["inventory"] = inv
		data["last_missed"] = {}
		version = 5
	if version == 5:
		# v6 で料理の解放を追加（v7 でランクによる解放に変わったので、ここでは空にして v7 の移行で決める）
		data["unlocked"] = []
		version = 6
	if version == 6:
		# v7 で評判の上がり方と店舗ランクを変えた。
		# 評判を今の範囲に換算し（来店ペースが同じになるように）、その評判でランクを決める。解放済みの料理はそのまま
		var converted: int = roundi(float(data.get("reputation", 0)) * Database.config.legacy_reputation_scale)
		data["reputation"] = maxi(0, converted)
		data["rank"] = Database.get_rank_for_reputation(maxi(0, converted))
		version = 7
	if version == 7:
		# v8 でカレンダーの履歴と設備を追加。古いセーブには履歴がないので空から始める（日付は日数から計算する）
		data["history"] = []
		data["equipment"] = {}
		version = 8
	if version == 8:
		# v9 で「テーブル（1人用 4〜8卓）」を「席の拡張（4・6・10・14・18席）」に変えた。
		# 席の数がなるべく近くなるレベルに換算する（同じくらい近いときは多いほう）
		var raw_equipment: Variant = data.get("equipment", {})
		var equipment: Dictionary = raw_equipment if raw_equipment is Dictionary else {}
		if equipment.has("tables"):
			var old_seats: int = 4 + int(equipment["tables"])
			equipment.erase("tables")
			equipment["seats"] = _closest_seat_level(old_seats)
		data["equipment"] = equipment
		version = 9
	if version == 9:
		# v10 でトッピングと従業員を追加。古いセーブには従業員がいないので空にする
		# （トッピングの解放は、読み込んだあとにランクと日数で決まる）
		data["staff"] = []
		version = 10
	data["version"] = version
	return data
