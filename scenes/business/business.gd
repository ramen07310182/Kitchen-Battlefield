extends Control
## 営業画面。各部品（客席・厨房・完成品置き場・注文状況・来店）をつなぎ、
## 営業時間と配膳の判定を受け持つ。

signal business_finished

const CUSTOMER_SCENE: PackedScene = preload("res://scenes/business/customer.tscn")

var _config: GameConfig
var _time_left: float = 0.0
var _is_open: bool = true
var _finished: bool = false
var _customers: Array[Customer] = []
var _order_counter: int = 0

@onready var _top_bar: TopBar = %TopBar
@onready var _dining: DiningArea = %Dining
@onready var _kitchen: Kitchen = %Kitchen
@onready var _shelf: ReadyShelf = %ReadyShelf
@onready var _order_panel: OrderPanel = %OrderPanel
@onready var _spawner: CustomerSpawner = %CustomerSpawner
@onready var _end_label: Label = %EndLabel


func _ready() -> void:
	_config = Database.config
	_time_left = _config.business_duration
	_end_label.text = UIText.BUSINESS_END
	_end_label.hide()

	var prepared: Array[String] = GameState.begin_business()
	var menu: Array[DishData] = GameState.get_menu_dishes()

	_dining.setup(_config.table_count)
	_shelf.setup(_config.shelf_capacity)
	for dish_id: String in prepared:
		_shelf.add_dish(dish_id)
	_kitchen.setup(menu)

	_dining.table_tapped.connect(_on_table_tapped)
	_shelf.contents_changed.connect(_on_shelf_changed)
	_kitchen.dish_cooked.connect(_on_dish_cooked)
	_spawner.spawn_requested.connect(_on_spawn_requested)

	_on_shelf_changed()
	_spawner.start(_config, menu, GameState.reputation)


func _process(delta: float) -> void:
	if _finished:
		return
	if _is_open:
		_time_left = maxf(0.0, _time_left - delta)
		if _time_left <= 0.0:
			_is_open = false
			_spawner.stop()
	elif _customers.is_empty():
		_finish()
	_top_bar.set_time_left(_time_left, _is_open)
	_order_panel.show_orders(_collect_orders(), _config.great_ratio, _config.good_ratio, delta)
	_update_table_highlights()


# ---------------------------------------------------------------
# 来店
# ---------------------------------------------------------------

func _on_spawn_requested(customer_type: CustomerTypeData, dish: DishData) -> void:
	var table_index: int = _dining.find_free_table()
	if table_index < 0:
		return  # 席がいっぱいなら来店しない
	var customer: Customer = CUSTOMER_SCENE.instantiate() as Customer
	_dining.add_customer(customer, table_index)
	customer.setup(customer_type, dish, table_index, _config)
	customer.order_placed.connect(_on_customer_ordered)
	customer.paid.connect(_on_customer_paid)
	customer.left_angry.connect(_on_customer_left_angry)
	customer.seat_released.connect(_on_customer_seat_released)
	customer.exited.connect(_on_customer_exited)
	_customers.append(customer)
	GameState.record_visit()
	customer.start(_dining.get_entrance_position(), _dining.get_seat_position(table_index))


func _on_customer_ordered(customer: Customer) -> void:
	_order_counter += 1
	customer.order_sequence = _order_counter


func _on_customer_paid(customer: Customer) -> void:
	GameState.record_payment(customer.dish.price)


func _on_customer_left_angry(_customer: Customer) -> void:
	GameState.record_angry()


func _on_customer_seat_released(customer: Customer) -> void:
	_dining.release_table(customer.table_index)


func _on_customer_exited(customer: Customer) -> void:
	_customers.erase(customer)


# ---------------------------------------------------------------
# 調理・配膳
# ---------------------------------------------------------------

func _on_dish_cooked(dish_id: String) -> void:
	if not _shelf.add_dish(dish_id):
		push_warning("完成品置き場に空きがありません: " + dish_id)


func _on_shelf_changed() -> void:
	_kitchen.set_free_slots(_shelf.free_count())


func _on_table_tapped(table_index: int) -> void:
	var customer: Customer = _dining.get_occupant(table_index)
	if customer == null or not customer.is_waiting_food():
		return
	var held: String = _shelf.get_held_dish()
	if held == "":
		customer.show_popup(UIText.POPUP_NOT_HOLDING)
		return
	if held == customer.dish.id:
		_shelf.remove_held()
		var level: Satisfaction.Level = customer.serve()
		GameState.record_served(level)
		customer.show_popup(UIText.SATISFACTION_NAMES[level], Color(0.6, 1.0, 0.6))
	else:
		GameState.record_mistake()
		customer.show_popup(UIText.POPUP_WRONG, Color(1.0, 0.5, 0.4))


func _update_table_highlights() -> void:
	var held: String = _shelf.get_held_dish()
	for i: int in _dining.get_table_count():
		var c: Customer = _dining.get_occupant(i)
		_dining.set_table_highlight(i, held != "" and c != null and c.is_waiting_food() and c.dish.id == held)


func _collect_orders() -> Array[Dictionary]:
	var waiting: Array[Customer] = []
	for c: Customer in _customers:
		if c.is_waiting_food():
			waiting.append(c)
	waiting.sort_custom(func(a: Customer, b: Customer) -> bool: return a.order_sequence < b.order_sequence)
	var orders: Array[Dictionary] = []
	for c: Customer in waiting:
		orders.append({
			"table": c.table_index + 1,
			"dish": c.dish,
			"elapsed": c.wait_elapsed,
			"ratio": c.get_wait_ratio(),
		})
	return orders


# ---------------------------------------------------------------
# 営業終了
# ---------------------------------------------------------------

func _finish() -> void:
	_finished = true
	_end_label.show()
	await get_tree().create_timer(_config.end_delay).timeout
	business_finished.emit()
