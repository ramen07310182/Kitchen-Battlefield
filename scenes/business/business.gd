extends Control
## 営業画面。各部品（客席・厨房・置き場・注文状況・来店）をつなぎ、
## 営業時間・売り切れと配膳の判定を受け持つ。
## 料理の数（残り・確保）は DishSupply で管理する。注文できる料理がなくなったら売り切れで閉店する。

signal business_finished

const CUSTOMER_SCENE: PackedScene = preload("res://scenes/business/customer.tscn")

var _config: GameConfig
var _time_left: float = 0.0
var _is_open: bool = true
var _finished: bool = false
var _customers: Array[Customer] = []
var _order_counter: int = 0
var _sold_out: bool = false
var _menu: Array[DishData] = []
var _supply: DishSupply

@onready var _top_bar: TopBar = %TopBar
@onready var _dining: DiningArea = %Dining
@onready var _kitchen: Kitchen = %Kitchen
@onready var _shelf: ReadyShelf = %ReadyShelf
@onready var _order_panel: OrderPanel = %OrderPanel
@onready var _spawner: CustomerSpawner = %CustomerSpawner
@onready var _end_label: Label = %EndLabel
@onready var _sold_out_label: Label = %SoldOutLabel


func _ready() -> void:
	_config = Database.config
	_time_left = _config.business_duration
	_end_label.text = UIText.BUSINESS_END
	_end_label.hide()
	_sold_out_label.text = UIText.SOLD_OUT
	_sold_out_label.hide()

	# 仕込み数の食材をまとめて使い、開店時の置き場に料理を並べる
	var opening: Dictionary = GameState.begin_business()
	var prep: Dictionary = opening["prep"]
	var shelf_items: Array[String] = opening["shelf"]
	_supply = DishSupply.new(prep, shelf_items)
	# 仕込み数が1以上の料理だけを今日のメニューとして出す
	for dish: DishData in Database.dishes:
		if int(prep.get(dish.id, 0)) > 0:
			_menu.append(dish)

	_dining.setup(GameState.get_table_count())
	_shelf.setup(GameState.get_shelf_capacity())
	for dish_id: String in shelf_items:
		_shelf.add_dish(dish_id)
	_kitchen.setup(_menu, _supply)

	_dining.table_tapped.connect(_on_table_tapped)
	_shelf.contents_changed.connect(_on_shelf_changed)
	_shelf.held_changed.connect(func(dish_id: String) -> void: _kitchen.set_holding(dish_id != ""))
	_kitchen.dish_cooked.connect(_on_dish_cooked)
	_kitchen.return_requested.connect(_on_return_requested)
	_spawner.spawn_requested.connect(_on_spawn_requested)

	_on_shelf_changed()
	_spawner.start(_config, _menu, GameState.reputation, _supply)


func _process(delta: float) -> void:
	if _finished:
		return
	if _is_open:
		_time_left = maxf(0.0, _time_left - delta)
		if _time_left <= 0.0:
			_close()
		elif not _supply.has_orderable(_menu):
			_close_sold_out()
	elif _customers.is_empty():
		_finish()
	_top_bar.set_time_left(_time_left, _is_open, _sold_out)
	_order_panel.show_orders(_collect_orders(), _config.great_ratio, _config.good_ratio, delta)
	_update_table_highlights()


# ---------------------------------------------------------------
# 来店
# ---------------------------------------------------------------

func _close() -> void:
	_is_open = false
	_spawner.stop()


## 注文できる料理がなくなったので、新しいお客さんを入れずに閉店する
func _close_sold_out() -> void:
	_sold_out = true
	GameState.record_sold_out()
	# 閉店しなければ営業時間の残りに来たはずの客を、売り逃しとして数える
	var missed: Dictionary = _spawner.simulate_missed(_time_left)
	for dish_id: String in missed:
		GameState.record_missed(dish_id, int(missed[dish_id]))
	_close()
	_sold_out_label.show()
	_sold_out_label.modulate = Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_sold_out_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_sold_out_label.hide)


func _on_spawn_requested(customer_type: CustomerTypeData, dish: DishData, missed_dish_id: String) -> void:
	if not _is_open:
		return
	var table_index: int = _dining.find_free_table()
	if table_index < 0:
		return  # 席がいっぱいなら来店しない
	# 注文が入った時点で料理を1個確保する（作れない料理の注文を出さないため）
	if not _supply.reserve(dish.id):
		return
	# 頼みたかった料理が売り切れていて、別の料理を頼んだ
	if missed_dish_id != "":
		GameState.record_missed(missed_dish_id, 1)
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
	GameState.record_payment(customer.dish.id, customer.dish.price)


func _on_customer_left_angry(customer: Customer) -> void:
	_supply.release(customer.dish.id)
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


## 置き場で持っている料理を外して、残りに戻す
func _on_return_requested() -> void:
	var held: String = _shelf.get_held_dish()
	if held == "":
		return
	_shelf.remove_held()
	_supply.return_to_remaining(held)


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
		_supply.serve(held)
		var level: Satisfaction.Level = customer.serve()
		GameState.record_served(held, level)
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
	# 残った料理（残り・置き場・調理中）は廃棄する
	GameState.record_waste(_supply.get_leftover())
	_end_label.show()
	await get_tree().create_timer(_config.end_delay).timeout
	business_finished.emit()
