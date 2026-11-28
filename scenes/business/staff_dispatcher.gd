class_name StaffDispatcher
extends Node
## ホールスタッフに仕事を割り当てる（営業画面の部品）。
##   - 手の空いたスタッフは、注文の古いお客さんから順に「まだ出していない料理・トッピング」を見て、
##     置き場に同じものがあれば（プレイヤーが持っている枠・ほかのスタッフが予約した枠は除く）その枠を予約して取りに行く。
##     同じお客さんの料理とトッピングが両方あれば、1回で両方運ぶ
##   - 同じお客さんの同じ料理を、2人以上が運ばない（取り合いにならない）
##   - 取り終えたら枠から外して席まで運び、まだ待っていれば配膳する（配膳と記録は営業画面の deliver に任せる）
##   - 運び先のお客さんが帰った・もう要らなくなったら、料理を持って戻り、置き場に返す
##     （置き場が満杯なら、空くまで持って待つ。厨房が作っている分の枠は空けておく）
## プレイヤーの操作は変えない。プレイヤーが持っている料理には手を出さない。

const STAFF_SCENE: PackedScene = preload("res://scenes/business/hall_staff.tscn")

var _staff: Array[HallStaff] = []
var _dining: DiningArea
var _shelf: ReadyShelf
var _kitchen: Kitchen
## 待っているお客さん（注文の古い順）を返す: func() -> Array[Customer]
var _waiting_customers: Callable
## 配膳する: func(customer: Customer, item_id: String) -> bool
var _deliver: Callable


func setup(dining: DiningArea, shelf: ReadyShelf, kitchen: Kitchen, staff_list: Array[StaffData],
		waiting_customers: Callable, deliver: Callable) -> void:
	_dining = dining
	_shelf = shelf
	_kitchen = kitchen
	_waiting_customers = waiting_customers
	_deliver = deliver
	for i: int in staff_list.size():
		var s: HallStaff = STAFF_SCENE.instantiate() as HallStaff
		_dining.add_staff(s)
		s.setup(staff_list[i], _home_for(i))
		s.picked.connect(_on_picked)
		s.arrived.connect(_on_arrived)
		s.arrived_home.connect(_on_arrived_home)
		_staff.append(s)


func get_staff() -> Array[HallStaff]:
	return _staff


## 置き場へ返そうとしている料理の数（戻る途中・置き場の空きを待っている分。厨房が作れる数から引く）
func get_returning_count() -> int:
	var count: int = 0
	for s: HallStaff in _staff:
		if s.state == HallStaff.State.RETURNING or s.state == HallStaff.State.WAITING_SHELF:
			count += s.items.size()
	return count


## お客さんが帰った（怒って帰った）。そのお客さんへ運ぶ途中・取っている途中のスタッフを戻す
func on_customer_left(customer: Customer) -> void:
	for s: HallStaff in _staff:
		if s.target != customer:
			continue
		if s.state == HallStaff.State.PICKING:
			for slot: int in s.slots:
				_shelf.unreserve_slot(slot)
			s.cancel_pick()
		elif s.state == HallStaff.State.CARRYING:
			s.go_home()


func _process(_delta: float) -> void:
	if _dining == null:
		return
	for i: int in _staff.size():
		_staff[i].set_home(_home_for(i))
	for s: HallStaff in _staff:
		if s.state == HallStaff.State.WAITING_SHELF:
			_try_return_to_shelf(s)
	for s: HallStaff in _staff:
		if s.is_idle():
			_assign(s)


## 待機場所: 客席エリアの下の端（置き場に近い側）。イスと重ならない所（DiningArea が決める）
func _home_for(index: int) -> Vector2:
	return _dining.get_staff_home(index, HallStaff.SIZE)


func _assign(s: HallStaff) -> void:
	var customers: Array[Customer] = _waiting_customers.call()
	for c: Customer in customers:
		var pick_slots: Array[int] = []
		var pick_items: Array[String] = []
		for item_id: String in c.get_needed_items():
			if pick_items.size() >= HallStaff.MAX_CARRY or _is_taken_care_of(c, item_id):
				continue
			var slot: int = _shelf.find_available_slot(item_id)
			if slot < 0:
				continue
			_shelf.reserve_slot(slot)
			pick_slots.append(slot)
			pick_items.append(item_id)
		if not pick_items.is_empty():
			s.begin_pick(pick_slots, pick_items, c)
			return


## ほかのスタッフが、そのお客さんのその料理を取りに行っている・運んでいる
func _is_taken_care_of(customer: Customer, item_id: String) -> bool:
	for s: HallStaff in _staff:
		if s.is_handling(customer, item_id):
			return true
	return false


func _on_picked(s: HallStaff) -> void:
	var c: Customer = s.target
	var carried: Array[String] = []
	for i: int in s.slots.size():
		var slot: int = s.slots[i]
		if c != null and is_instance_valid(c) and c.needs_item(s.items[i]):
			var taken: String = _shelf.take_reserved(slot)
			if taken != "":
				carried.append(taken)
		else:
			_shelf.unreserve_slot(slot)
	if carried.is_empty():
		s.cancel_pick()
		return
	s.carry_to(carried, _serve_position(c))


func _on_arrived(s: HallStaff) -> void:
	var c: Customer = s.target
	for item_id: String in s.items.duplicate():
		if c != null and is_instance_valid(c) and c.needs_item(item_id) and bool(_deliver.call(c, item_id)):
			s.remove_item(item_id)
			GameState.record_staff_delivery(s.data.id)
	# 渡せなかった料理（お客さんが帰った・もう出してあった）は持ったまま戻る
	s.go_home()


func _on_arrived_home(s: HallStaff) -> void:
	if s.state == HallStaff.State.WAITING_SHELF:
		_try_return_to_shelf(s)


## 持っている料理を置き場に返す（厨房が作っている分の枠は空けておく）
func _try_return_to_shelf(s: HallStaff) -> void:
	for item_id: String in s.items.duplicate():
		if _shelf.free_count() <= _kitchen.get_pending_count():
			return
		if _shelf.add_dish(item_id):
			s.returned_item(item_id)


## お客さんのそばに立つ位置（お客さんの横）
func _serve_position(c: Customer) -> Vector2:
	var side: float = -HallStaff.SIZE.x if c.position.x > HallStaff.SIZE.x + 4.0 else HallStaff.SIZE.x
	return (c.position + Vector2(side, 0.0)).round()
