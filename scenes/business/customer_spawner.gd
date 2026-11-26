class_name CustomerSpawner
extends Node
## 来店のタイミングと、来る客層・注文する料理を決める。
## 注文できるのは、今日のメニューのうち、まだ出せる数が残っている（DishSupply で注文できる）料理だけ。
## 実際に席へ案内して料理を確保するのは営業画面（business.gd）。
##
## 売り逃しの記録: 客はまず今日のメニュー全体から「頼みたい料理」を選ぶ（OrderChooser）。
## それが売り切れていたら、注文できる料理から選び直し、頼みたかった料理を missed_dish_id で知らせる。

## missed_dish_id: 頼みたかったのに売り切れていた料理のid（なければ ""）
signal spawn_requested(customer_type: CustomerTypeData, dish: DishData, missed_dish_id: String)

var active: bool = false

var _config: GameConfig
var _menu: Array[DishData] = []
var _supply: DishSupply = null
var _timer: float = 0.0
## 来店間隔の倍率（評判が高いほど小さい）。営業開始時の評判で決め、その日の間は変えない
var _interval_scale: float = 1.0


func start(config: GameConfig, menu: Array[DishData], reputation: int, supply: DishSupply) -> void:
	_config = config
	_menu = menu
	_supply = supply
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
	var order: Dictionary = choose_order(customer_type)
	var dish: DishData = order["dish"]
	if dish == null:
		return
	spawn_requested.emit(customer_type, dish, order["missed"])


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


## 注文を決める。戻り値: { "dish": 注文する料理（注文できる料理がなければ null）, "missed": 頼みたかったのに売り切れていた料理のid か "" }
## まず今日のメニュー全体から予算と好みで選び（確率は OrderChooser）、売り切れていたら注文できる料理から選び直す
func choose_order(customer_type: CustomerTypeData) -> Dictionary:
	var wanted: DishData = OrderChooser.choose(customer_type, _menu, _config)
	if wanted == null:
		return { "dish": null, "missed": "" }
	if _supply == null or _supply.get_orderable(wanted.id) > 0:
		return { "dish": wanted, "missed": "" }
	var available: Array[DishData] = _supply.filter_orderable(_menu)
	var dish: DishData = OrderChooser.choose(customer_type, available, _config) if not available.is_empty() else null
	return { "dish": dish, "missed": wanted.id }


## 売り切れで閉店したあと、営業時間の残り seconds 秒のあいだに来店しようとしたはずの客を、
## いつもと同じ間隔・選び方で数える。戻り値: { 料理id: 頼みたかった人数 }
func simulate_missed(seconds: float) -> Dictionary:
	var result: Dictionary = {}
	if _config == null or _menu.is_empty():
		return result
	var t: float = maxf(0.0, _timer)
	while t <= seconds:
		var customer_type: CustomerTypeData = _pick_customer_type()
		if customer_type != null:
			var wanted: DishData = OrderChooser.choose(customer_type, _menu, _config)
			if wanted != null:
				DayStats.add_to(result, wanted.id, 1)
		t += randf_range(_config.spawn_interval_min, _config.spawn_interval_max) * _interval_scale
	return result
