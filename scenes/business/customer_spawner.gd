class_name CustomerSpawner
extends Node
## 来店のタイミングと、来る客層・注文する料理を決める。
## 実際に席へ案内するのは営業画面（business.gd）。

signal spawn_requested(customer_type: CustomerTypeData, dish: DishData)

var active: bool = false

var _config: GameConfig
var _menu: Array[DishData] = []
var _timer: float = 0.0
## 来店間隔の倍率（評判が高いほど小さい）。営業開始時の評判で決め、その日の間は変えない
var _interval_scale: float = 1.0


func start(config: GameConfig, menu: Array[DishData], reputation: int) -> void:
	_config = config
	_menu = menu
	_interval_scale = config.get_spawn_interval_scale(reputation)
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
	_timer = randf_range(_config.spawn_interval_min, _config.spawn_interval_max) * _interval_scale
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


## 今日のメニューから、予算内で好みに合わせて選ぶ（確率は OrderChooser にまとめてある）
func choose_dish(customer_type: CustomerTypeData) -> DishData:
	return OrderChooser.choose(customer_type, _menu, _config)
