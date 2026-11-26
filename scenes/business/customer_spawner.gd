class_name CustomerSpawner
extends Node
## 来店のタイミングと、来る客層・注文する料理を決める。
## 実際に席へ案内するのは営業画面（business.gd）。

signal spawn_requested(customer_type: CustomerTypeData, dish: DishData)

var active: bool = false

var _config: GameConfig
var _menu: Array[DishData] = []
var _timer: float = 0.0


func start(config: GameConfig, menu: Array[DishData]) -> void:
	_config = config
	_menu = menu
	_timer = config.first_spawn_delay
	active = true


func stop() -> void:
	active = false


func _process(delta: float) -> void:
	if not active:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(_config.spawn_interval_min, _config.spawn_interval_max)
	var customer_type: CustomerTypeData = _pick_customer_type()
	if customer_type == null:
		return
	var dish: DishData = choose_dish(customer_type)
	if dish == null:
		return
	spawn_requested.emit(customer_type, dish)


func _pick_customer_type() -> CustomerTypeData:
	var types: Array[CustomerTypeData] = Database.customer_types
	if types.is_empty():
		return null
	var total: float = 0.0
	for t: CustomerTypeData in types:
		total += maxf(0.0, t.spawn_weight)
	var roll: float = randf() * total
	for t: CustomerTypeData in types:
		roll -= maxf(0.0, t.spawn_weight)
		if roll <= 0.0:
			return t
	return types[types.size() - 1]


## 今日のメニューから、予算内で好みに合わせて選ぶ。予算内がなければいちばん安いもの
func choose_dish(customer_type: CustomerTypeData) -> DishData:
	if _menu.is_empty():
		return null
	var candidates: Array[DishData] = []
	for d: DishData in _menu:
		if d.price <= customer_type.budget:
			candidates.append(d)
	if candidates.is_empty():
		var cheapest: DishData = _menu[0]
		for d: DishData in _menu:
			if d.price < cheapest.price:
				cheapest = d
		return cheapest
	var total: float = 0.0
	var weights: Array[float] = []
	for d: DishData in candidates:
		var w: float = _config.favorite_weight if customer_type.favorite_dishes.has(d.id) else 1.0
		weights.append(w)
		total += w
	var roll: float = randf() * total
	for i: int in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]
