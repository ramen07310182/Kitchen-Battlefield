class_name FastDayModel
extends RefCounted
## 営業1日分を、画面を出さずに短時間で計算する（365日分のバランス確認用の近似）。
## 実際の営業画面と同じルール（来店間隔・席・注文の選び方・トッピング・仕込み数と確保・調理（店主と厨房担当のスタッフ）・置き場・待てる時間）を
## 時刻の計算でまねて、結果は GameState の記録の関数（record_visit など）に入れる。
## 歩く時間やボットの操作の細かい動きは、平均的な値で置き換えている。
## 調理ボタンを押すのもボットの操作（1回に reaction 秒）として順に数える（配膳とは別の列。料理を待つあいだに押せるため）。
## 配膳: ボット（1回に reaction 秒）とホールスタッフ（取る時間＋歩く時間。戻るまで次を運べない）を
## それぞれ1人ずつの「運ぶ人」として、いちばん早く届けられる人が運ぶ（スタッフが運んだ分はミスにならない）。厨房担当のスタッフは運ばない。
## 調理: 店主と厨房担当のスタッフ（いる日だけ）が並行して作る。調理ボタンを押した料理は、作れる人のうち先に手が空く人が作る
## （同じなら店主。スタッフは作れる難しさの料理だけ。スタッフの調理時間は「調理時間 ÷ 調理の速さ」）。

## 入口から席まで・席から出口までの歩く時間（秒、近似）
const WALK_TIME := 1.5
## ホールスタッフが置き場から席まで歩く距離（px、640×360基準の客席エリアでの平均の近似）
const STAFF_DISTANCE := 220.0

var _config: GameConfig
## ボットの設定（reaction: 操作の間隔の秒数、wrong_rate: 違う料理を出す割合、precook: 手が空いたら先に作る）
var _skill: Dictionary
## 今日の厨房担当のスタッフ（いなければ null）と、調理する人ごとの次に手が空く時刻（0番目が店主）
var _kitchen_staff: StaffData = null
var _cook_free: Array[float] = []


func _init(skill: Dictionary) -> void:
	_config = Database.config
	_skill = skill


## GameState.begin_business() の戻り値を受け取り、1日分の営業を計算して記録する
func run_day(opening: Dictionary) -> void:
	var prep: Dictionary = opening["prep"]
	var shelf_items: Array[String] = opening["shelf"]
	var supply: DishSupply = DishSupply.new(prep, shelf_items)
	var menu: Array[DishData] = []
	var toppings: Array[DishData] = []
	for dish: DishData in Database.items:
		if int(prep.get(dish.id, 0)) > 0:
			if dish.is_topping():
				toppings.append(dish)
			else:
				menu.append(dish)
	# 置き場にある料理の数（開店時の置き場と、先に作った分）
	var buffer: Dictionary = {}
	for dish_id: String in shelf_items:
		DayStats.add_to(buffer, dish_id, 1)
	var shelf_capacity: int = GameState.get_shelf_capacity()
	var tables_free_at: Array[float] = []
	for i: int in GameState.get_seat_count():
		tables_free_at.append(0.0)
	var reaction: float = float(_skill["reaction"])
	# 運ぶ人ごとの、次に手が空く時刻（0番目がボット、1番目からスタッフ）
	var server_free: Array[float] = [0.0]
	# ボットが次に調理ボタンを押せる時刻
	var press_free: float = 0.0
	var staff_list: Array[StaffData] = GameState.get_hall_staff()
	for s: StaffData in staff_list:
		server_free.append(0.0)
	var interval_scale: float = _config.get_spawn_interval_scale(GameState.reputation)
	# 調理する人ごとの、次に手が空く時刻（0番目が店主、1番目が厨房担当のスタッフ）
	_kitchen_staff = GameState.get_kitchen_staff()
	_cook_free = [0.0]
	if _kitchen_staff != null:
		_cook_free.append(0.0)
	var t: float = _config.first_spawn_delay
	while t < _config.business_duration:
		var next_t: float = t + randf_range(_config.spawn_interval_min, _config.spawn_interval_max) * interval_scale
		var table: int = _free_table(tables_free_at, t)
		if table >= 0:
			var customer_type: CustomerTypeData = _pick_customer_type()
			var wanted: DishData = OrderChooser.choose(customer_type, menu, _config)
			var dish: DishData = wanted
			var missed: Array[String] = []
			if wanted != null and supply.get_orderable(wanted.id) <= 0:
				missed.append(wanted.id)
				var available: Array[DishData] = supply.filter_orderable(menu)
				dish = OrderChooser.choose(customer_type, available, _config) if not available.is_empty() else null
			if dish != null and supply.reserve(dish.id):
				var items: Array[DishData] = [dish]
				if not toppings.is_empty() and OrderChooser.wants_topping(customer_type):
					var topping: DishData = OrderChooser.choose_topping(customer_type, toppings, _config)
					if topping != null and supply.reserve(topping.id):
						items.append(topping)
					elif topping != null:
						missed.append(topping.id)
				GameState.record_visit()
				for missed_id: String in missed:
					GameState.record_missed(missed_id, 1)
				var order_time: float = t + WALK_TIME + _config.order_delay
				# 上手なボットは、手が空いているあいだに残りの多い料理を先に作って置き場に並べる
				if bool(_skill["precook"]):
					_precook(supply, buffer, shelf_capacity, order_time)
				var done: float = order_time
				for item: DishData in items:
					var ready: float
					if int(buffer.get(item.id, 0)) > 0:
						buffer[item.id] = int(buffer[item.id]) - 1
						ready = order_time
					else:
						supply.take_for_cooking(item.id)
						# 調理ボタンを押すのもボットの操作（1回に reaction 秒）。料理を待つあいだに押せるので、配膳とは別に順に数える
						var press: float = maxf(order_time, press_free) + reaction
						press_free = press
						ready = _cook(item, press)
					# 届くまで: いちばん早く届けられる人が運ぶ
					var best: int = 0
					var best_time: float = maxf(ready, server_free[0]) + reaction
					for i: int in staff_list.size():
						var arrive: float = maxf(ready, server_free[i + 1]) + _staff_one_way(staff_list[i])
						if arrive < best_time:
							best = i + 1
							best_time = arrive
					if best == 0:
						if randf() < float(_skill["wrong_rate"]):
							GameState.record_mistake()
							best_time += reaction
						server_free[0] = best_time
					else:
						var s2: StaffData = staff_list[best - 1]
						server_free[best] = best_time + STAFF_DISTANCE / maxf(GameState.get_staff_walk_speed(s2), 1.0)
						GameState.record_staff_delivery(s2.id)
					done = maxf(done, best_time)
				var wait: float = done - order_time
				if wait >= customer_type.patience:
					# 待ちきれずに帰った。作った料理は置き場に残る
					GameState.record_angry()
					for item: DishData in items:
						supply.release(item.id)
						DayStats.add_to(buffer, item.id, 1)
					tables_free_at[table] = order_time + customer_type.patience + WALK_TIME
				else:
					var level: Satisfaction.Level = Satisfaction.from_wait(wait, customer_type.patience, _config)
					for item: DishData in items:
						supply.serve(item.id)
						GameState.record_item_served(item.id)
						GameState.record_payment(item.id, item.price)
					GameState.record_order_completed(level)
					tables_free_at[table] = order_time + wait + customer_type.eat_time + WALK_TIME
			# 注文できる料理がなくなったら、売り切れで閉店。残りの時間に来たはずの客は売り逃し
			if not supply.has_orderable(menu):
				GameState.record_sold_out()
				_count_missed_after(menu, toppings, next_t, interval_scale, tables_free_at)
				break
		t = next_t
	GameState.record_waste(supply.get_leftover())


## 料理を1つ作る: 作れる人のうち、いちばん早く始められる人（同じなら店主）が作る。できあがる時刻を返す
func _cook(item: DishData, earliest: float) -> float:
	var who: int = _pick_cook(item, earliest)
	var start: float = maxf(earliest, _cook_free[who])
	var seconds: float = _cook_seconds(who, item)
	_cook_free[who] = start + seconds
	GameState.record_cooked(who > 0, seconds)
	return _cook_free[who]


func _pick_cook(item: DishData, earliest: float) -> int:
	var who: int = 0
	if _cook_free.size() > 1 and GameState.can_staff_cook(_kitchen_staff, item) 			and maxf(earliest, _cook_free[1]) < maxf(earliest, _cook_free[0]):
		who = 1
	return who


func _cook_seconds(who: int, item: DishData) -> float:
	return GameState.get_cook_time(item) if who == 0 else GameState.get_staff_cook_time(_kitchen_staff, item)


## ホールスタッフが料理を取って席まで運ぶ時間
func _staff_one_way(s: StaffData) -> float:
	return GameState.get_staff_pick_time(s) + STAFF_DISTANCE / maxf(GameState.get_staff_walk_speed(s), 1.0)


func _free_table(tables_free_at: Array[float], t: float) -> int:
	var free: Array[int] = []
	for i: int in tables_free_at.size():
		if tables_free_at[i] <= t:
			free.append(i)
	return free.pick_random() if not free.is_empty() else -1


## 手が空いている人が、until までに作り終えられる分だけ、残りの多い料理を先に作って置き場に並べる
func _precook(supply: DishSupply, buffer: Dictionary, capacity: int, until: float) -> void:
	while true:
		var stocked: int = 0
		for dish_id: String in buffer:
			stocked += int(buffer[dish_id])
		# 置き場は2枠空けておく（実際のボットと同じ）
		if stocked >= capacity - 2:
			break
		var best: DishData = null
		for dish: DishData in Database.items:
			if supply.get_remaining(dish.id) > 0 and (best == null or supply.get_remaining(dish.id) > supply.get_remaining(best.id)):
				best = dish
		if best == null:
			break
		var who: int = _pick_cook(best, 0.0)
		if _cook_free[who] + _cook_seconds(who, best) > until:
			break
		supply.take_for_cooking(best.id)
		_cook(best, 0.0)
		DayStats.add_to(buffer, best.id, 1)


## 売り切れのあとに来たはずの客（営業画面と同じく、席が空いていない時に来た客は数えない）
func _count_missed_after(menu: Array[DishData], toppings: Array[DishData], from_t: float, interval_scale: float,
		tables_free_at: Array[float]) -> void:
	var seats: Array[float] = tables_free_at.duplicate()
	var t: float = from_t
	while t < _config.business_duration:
		var seat: int = _free_table(seats, t)
		if seat < 0:
			t += randf_range(_config.spawn_interval_min, _config.spawn_interval_max) * interval_scale
			continue
		seats[seat] = t + _config.missed_stay_time
		var customer_type: CustomerTypeData = _pick_customer_type()
		var wanted: DishData = OrderChooser.choose(customer_type, menu, _config)
		if wanted != null:
			GameState.record_missed(wanted.id, 1)
			if not toppings.is_empty() and OrderChooser.wants_topping(customer_type):
				var topping: DishData = OrderChooser.choose_topping(customer_type, toppings, _config)
				if topping != null:
					GameState.record_missed(topping.id, 1)
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
