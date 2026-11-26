class_name FastDayModel
extends RefCounted
## 営業1日分を、画面を出さずに短時間で計算する（365日分のバランス確認用の近似）。
## 実際の営業画面と同じルール（来店間隔・席・注文の選び方・仕込み数と確保・店主1人の調理・置き場・待てる時間）を
## 時刻の計算でまねて、結果は GameState の記録の関数（record_visit など）に入れる。
## 歩く時間やボットの操作の細かい動きは、平均的な値で置き換えている。

## 入口から席まで・席から出口までの歩く時間（秒、近似）
const WALK_TIME := 1.5

var _config: GameConfig
## ボットの設定（reaction: 操作の間隔の秒数、wrong_rate: 違う料理を出す割合、precook: 手が空いたら先に作る）
var _skill: Dictionary


func _init(skill: Dictionary) -> void:
	_config = Database.config
	_skill = skill


## GameState.begin_business() の戻り値を受け取り、1日分の営業を計算して記録する
func run_day(opening: Dictionary) -> void:
	var prep: Dictionary = opening["prep"]
	var shelf_items: Array[String] = opening["shelf"]
	var supply: DishSupply = DishSupply.new(prep, shelf_items)
	var menu: Array[DishData] = []
	for dish: DishData in Database.dishes:
		if int(prep.get(dish.id, 0)) > 0:
			menu.append(dish)
	# 置き場にある料理の数（開店時の置き場と、先に作った分）
	var buffer: Dictionary = {}
	for dish_id: String in shelf_items:
		DayStats.add_to(buffer, dish_id, 1)
	var shelf_capacity: int = GameState.get_shelf_capacity()
	var tables_free_at: Array[float] = []
	for i: int in GameState.get_table_count():
		tables_free_at.append(0.0)
	var reaction: float = float(_skill["reaction"])
	var interval_scale: float = _config.get_spawn_interval_scale(GameState.reputation)
	var chef_free: float = 0.0
	var t: float = _config.first_spawn_delay
	while t < _config.business_duration:
		var next_t: float = t + randf_range(_config.spawn_interval_min, _config.spawn_interval_max) * interval_scale
		var table: int = _free_table(tables_free_at, t)
		if table >= 0:
			var customer_type: CustomerTypeData = _pick_customer_type()
			var wanted: DishData = OrderChooser.choose(customer_type, menu, _config)
			var dish: DishData = wanted
			var missed_id: String = ""
			if wanted != null and supply.get_orderable(wanted.id) <= 0:
				missed_id = wanted.id
				var available: Array[DishData] = supply.filter_orderable(menu)
				dish = OrderChooser.choose(customer_type, available, _config) if not available.is_empty() else null
			if dish != null and supply.reserve(dish.id):
				GameState.record_visit()
				if missed_id != "":
					GameState.record_missed(missed_id, 1)
				var order_time: float = t + WALK_TIME + _config.order_delay
				# 上手なボットは、手が空いているあいだに残りの多い料理を先に作って置き場に並べる
				if bool(_skill["precook"]):
					chef_free = _precook(supply, buffer, shelf_capacity, chef_free, order_time)
				var ready: float
				if int(buffer.get(dish.id, 0)) > 0:
					buffer[dish.id] = int(buffer[dish.id]) - 1
					ready = order_time + reaction
				else:
					supply.take_for_cooking(dish.id)
					var start: float = maxf(order_time + reaction, chef_free)
					chef_free = start + GameState.get_cook_time(dish)
					ready = chef_free + reaction
				var wait: float = ready - order_time
				if randf() < float(_skill["wrong_rate"]):
					GameState.record_mistake()
					wait += reaction
				if wait >= customer_type.patience:
					# 待ちきれずに帰った。作った料理は置き場に残る
					GameState.record_angry()
					supply.release(dish.id)
					DayStats.add_to(buffer, dish.id, 1)
					tables_free_at[table] = order_time + customer_type.patience + WALK_TIME
				else:
					var level: Satisfaction.Level = Satisfaction.from_wait(wait, customer_type.patience, _config)
					supply.serve(dish.id)
					GameState.record_served(dish.id, level)
					GameState.record_payment(dish.id, dish.price)
					tables_free_at[table] = order_time + wait + customer_type.eat_time + WALK_TIME
			# 注文できる料理がなくなったら、売り切れで閉店。残りの時間に来たはずの客は売り逃し
			if not supply.has_orderable(menu):
				GameState.record_sold_out()
				_count_missed_after(menu, next_t, interval_scale)
				break
		t = next_t
	GameState.record_waste(supply.get_leftover())


func _free_table(tables_free_at: Array[float], t: float) -> int:
	var free: Array[int] = []
	for i: int in tables_free_at.size():
		if tables_free_at[i] <= t:
			free.append(i)
	return free.pick_random() if not free.is_empty() else -1


func _precook(supply: DishSupply, buffer: Dictionary, capacity: int, chef_free: float, until: float) -> float:
	var free_at: float = chef_free
	while true:
		var stocked: int = 0
		for dish_id: String in buffer:
			stocked += int(buffer[dish_id])
		# 置き場は2枠空けておく（実際のボットと同じ）
		if stocked >= capacity - 2:
			break
		var best: DishData = null
		for dish: DishData in Database.dishes:
			if supply.get_remaining(dish.id) > 0 and (best == null or supply.get_remaining(dish.id) > supply.get_remaining(best.id)):
				best = dish
		if best == null or free_at + GameState.get_cook_time(best) > until:
			break
		supply.take_for_cooking(best.id)
		free_at += GameState.get_cook_time(best)
		DayStats.add_to(buffer, best.id, 1)
	return maxf(free_at, chef_free)


func _count_missed_after(menu: Array[DishData], from_t: float, interval_scale: float) -> void:
	var t: float = from_t
	while t < _config.business_duration:
		var wanted: DishData = OrderChooser.choose(_pick_customer_type(), menu, _config)
		if wanted != null:
			GameState.record_missed(wanted.id, 1)
		t += randf_range(_config.spawn_interval_min, _config.spawn_interval_max) * interval_scale


func _pick_customer_type() -> CustomerTypeData:
	var types: Array[CustomerTypeData] = Database.customer_types
	var total: float = 0.0
	for c: CustomerTypeData in types:
		total += maxf(0.0, c.spawn_weight)
	var roll: float = randf() * total
	for c: CustomerTypeData in types:
		roll -= maxf(0.0, c.spawn_weight)
		if roll <= 0.0:
			return c
	return types[types.size() - 1]
