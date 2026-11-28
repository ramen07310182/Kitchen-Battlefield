extends Control
## 営業画面。各部品（客席・厨房・置き場・注文状況・来店・ホールスタッフ）をつなぎ、
## 営業時間・売り切れと配膳の判定を受け持つ。
## 料理・トッピングの数（残り・確保）は DishSupply で管理する。注文できる料理がなくなったら売り切れで閉店する
## （トッピングだけ残っていても閉店する）。
## 注文は料理1つ＋トッピング1つ（ないこともある）。料理とトッピングは別々に出してよく、全部そろったら食べ始める。

signal business_finished

const CUSTOMER_SCENE: PackedScene = preload("res://scenes/business/customer.tscn")

var _config: GameConfig
var _time_left: float = 0.0
var _is_open: bool = true
var _finished: bool = false
var _customers: Array[Customer] = []
var _order_counter: int = 0
var _sold_out: bool = false
## 今日出す料理（トッピングは含まない）と、今日出すトッピング
var _menu: Array[DishData] = []
var _toppings: Array[DishData] = []
var _supply: DishSupply
var _kitchen_free_slots: int = -1

@onready var _top_bar: TopBar = %TopBar
@onready var _dining: DiningArea = %Dining
@onready var _kitchen: Kitchen = %Kitchen
@onready var _shelf: ReadyShelf = %ReadyShelf
@onready var _order_panel: OrderPanel = %OrderPanel
@onready var _spawner: CustomerSpawner = %CustomerSpawner
@onready var _staff: StaffDispatcher = %StaffDispatcher
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
	# 仕込み数が1以上の料理・トッピングだけを今日のメニューとして出す
	var items: Array[DishData] = []
	for dish: DishData in Database.items:
		if int(prep.get(dish.id, 0)) > 0:
			items.append(dish)
			if dish.is_topping():
				_toppings.append(dish)
			else:
				_menu.append(dish)

	_dining.setup(GameState.get_seat_count())
	_shelf.setup(GameState.get_shelf_capacity())
	for dish_id: String in shelf_items:
		_shelf.add_dish(dish_id)
	_kitchen.setup(items, _supply)

	_dining.seat_tapped.connect(_on_seat_tapped)
	_shelf.contents_changed.connect(_update_kitchen_slots)
	_shelf.held_changed.connect(func(dish_id: String) -> void: _kitchen.set_holding(dish_id != ""))
	_kitchen.dish_cooked.connect(_on_dish_cooked)
	_kitchen.return_requested.connect(_on_return_requested)
	_spawner.spawn_requested.connect(_on_spawn_requested)

	_update_kitchen_slots()
	_spawner.start(_config, _menu, GameState.reputation, _supply, _toppings)
	# 画面の大きさが決まってから、スタッフを待機場所に置く
	await get_tree().process_frame
	_staff.setup(_dining, _shelf, _kitchen, GameState.get_working_staff(), _get_waiting_customers, deliver)


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
	_update_seat_highlights()
	_update_kitchen_slots()


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
	var seat_free_in: Array[float] = []
	for i: int in _dining.get_seat_count():
		var occupant: Customer = _dining.get_occupant(i)
		seat_free_in.append(occupant.get_estimated_stay() if occupant != null else 0.0)
	var missed: Dictionary = _spawner.simulate_missed(_time_left, seat_free_in)
	for dish_id: String in missed:
		GameState.record_missed(dish_id, int(missed[dish_id]))
	_close()
	_sold_out_label.show()
	_sold_out_label.modulate = Color(1, 1, 1, 1)
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_sold_out_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_sold_out_label.hide)


## order: CustomerSpawner.choose_order の戻り値
func _on_spawn_requested(customer_type: CustomerTypeData, order: Dictionary) -> void:
	if not _is_open:
		return
	var seat_index: int = _dining.find_free_seat()
	if seat_index < 0:
		return  # 席がいっぱいなら来店しない
	var dish: DishData = order["dish"]
	var topping: DishData = order.get("topping")
	var missed: Array = order.get("missed", [])
	# 注文が入った時点で料理を1個確保する（作れない料理の注文を出さないため）
	if dish == null or not _supply.reserve(dish.id):
		return
	if topping != null and not _supply.reserve(topping.id):
		missed.append(topping.id)
		topping = null
	# 頼みたかった料理・トッピングが売り切れていた
	for missed_id: Variant in missed:
		GameState.record_missed(String(missed_id), 1)
	var customer: Customer = CUSTOMER_SCENE.instantiate() as Customer
	_dining.add_customer(customer, seat_index)
	customer.setup(customer_type, dish, seat_index, _config, topping)
	customer.order_placed.connect(_on_customer_ordered)
	customer.paid.connect(_on_customer_paid)
	customer.left_angry.connect(_on_customer_left_angry)
	customer.seat_released.connect(_on_customer_seat_released)
	customer.exited.connect(_on_customer_exited)
	_customers.append(customer)
	GameState.record_visit()
	customer.start(_dining.get_entrance_position(), _dining.get_seat_position(seat_index))


func _on_customer_ordered(customer: Customer) -> void:
	_order_counter += 1
	customer.order_sequence = _order_counter


## 会計は料理＋トッピングの合計（売上は料理ごとに記録する）
func _on_customer_paid(customer: Customer) -> void:
	GameState.record_payment(customer.dish.id, customer.dish.price)
	if customer.topping != null:
		GameState.record_payment(customer.topping.id, customer.topping.price)


func _on_customer_left_angry(customer: Customer) -> void:
	# まだ出していない分の確保をやめる（出した分はもう出せる数から引いてある）
	if not customer.dish_served:
		_supply.release(customer.dish.id)
	if customer.topping != null and not customer.topping_served:
		_supply.release(customer.topping.id)
	GameState.record_angry()
	_staff.on_customer_left(customer)


func _on_customer_seat_released(customer: Customer) -> void:
	_dining.release_seat(customer.seat_index)


func _on_customer_exited(customer: Customer) -> void:
	_customers.erase(customer)


# ---------------------------------------------------------------
# 調理・配膳
# ---------------------------------------------------------------

func _on_dish_cooked(dish_id: String) -> void:
	if not _shelf.add_dish(dish_id):
		push_warning("完成品置き場に空きがありません: " + dish_id)


## 厨房が作れる数 = 置き場の空き − スタッフが置き場に返そうとしている数
func _update_kitchen_slots() -> void:
	var free: int = maxi(0, _shelf.free_count() - _staff.get_returning_count())
	if free != _kitchen_free_slots:
		_kitchen_free_slots = free
		_kitchen.set_free_slots(free)


## 置き場で持っている料理を外して、残りに戻す
func _on_return_requested() -> void:
	var held: String = _shelf.get_held_dish()
	if held == "":
		return
	_shelf.remove_held()
	_supply.return_to_remaining(held)


## 席（座っているお客さん）をタップした
func _on_seat_tapped(seat_index: int) -> void:
	var customer: Customer = _dining.get_occupant(seat_index)
	if customer == null or not customer.is_waiting_food():
		return
	var held: String = _shelf.get_held_dish()
	if held == "":
		customer.show_popup(UIText.POPUP_NOT_HOLDING)
		return
	if customer.needs_item(held):
		_shelf.remove_held()
	deliver(customer, held)


## 料理かトッピングを1皿出す（プレイヤーとホールスタッフの両方が使う）。
## 注文していないもの（違う料理・違うトッピング・もう出したもの）はミスで、出したことにならない。出せたら true
func deliver(customer: Customer, item_id: String) -> bool:
	var result: Customer.Receive = customer.receive(item_id)
	if result == Customer.Receive.WRONG:
		GameState.record_mistake()
		customer.show_popup(UIText.POPUP_WRONG, UIColors.BIZ_POPUP_WRONG)
		return false
	_supply.serve(item_id)
	GameState.record_item_served(item_id)
	if result == Customer.Receive.COMPLETE:
		GameState.record_order_completed(customer.satisfaction)
		customer.show_popup(UIText.SATISFACTION_NAMES[customer.satisfaction], UIColors.BIZ_POPUP_GOOD)
	else:
		var names: PackedStringArray = PackedStringArray()
		for id: String in customer.get_needed_items():
			names.append(Database.get_dish(id).short_name)
		customer.show_popup(UIText.POPUP_PARTIAL % "・".join(names), UIColors.BIZ_POPUP_PARTIAL)
	return true


func _update_seat_highlights() -> void:
	var held: String = _shelf.get_held_dish()
	for i: int in _dining.get_seat_count():
		var c: Customer = _dining.get_occupant(i)
		_dining.set_seat_highlight(i, held != "" and c != null and c.needs_item(held))


## 料理を待っているお客さん（注文の古い順）
func _get_waiting_customers() -> Array[Customer]:
	var waiting: Array[Customer] = []
	for c: Customer in _customers:
		if c.is_waiting_food():
			waiting.append(c)
	waiting.sort_custom(func(a: Customer, b: Customer) -> bool: return a.order_sequence < b.order_sequence)
	return waiting


func _collect_orders() -> Array[Dictionary]:
	var orders: Array[Dictionary] = []
	for c: Customer in _get_waiting_customers():
		orders.append({
			"seat": _dining.get_seat_label(c.seat_index),
			"dish": c.dish,
			"topping": c.topping,
			"dish_served": c.dish_served,
			"topping_served": c.topping_served,
			"elapsed": c.wait_elapsed,
			"ratio": c.get_wait_ratio(),
		})
	return orders


# ---------------------------------------------------------------
# 営業終了
# ---------------------------------------------------------------

func _finish() -> void:
	_finished = true
	# 残った料理（残り・置き場・調理中・スタッフが持っている分）は廃棄する
	GameState.record_waste(_supply.get_leftover())
	_end_label.show()
	await get_tree().create_timer(_config.end_delay).timeout
	business_finished.emit()
