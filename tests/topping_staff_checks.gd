class_name ToppingStaffChecks
extends Node
## スモークテストの一部: トッピングとホールスタッフの確認（営業画面を直接作って動かす）。
##   - トッピング付きの注文、両方そろうまで食べない、違うトッピングはミス、会計は合計
##   - スタッフの自動配膳、プレイヤーとの取り合いが起きない、客が帰ったら料理が置き場に戻る、日給が人件費に入る
## 来店は止めて、お客さんはテストで直接入れる。GameState はテスト用のセーブの場所で使う（呼ぶ側で切り替えておく）。

const BUSINESS_SCENE: PackedScene = preload("res://scenes/business/business.tscn")
## このテストだけで使うセーブの場所（保存はしない。終わったら消す）
const SAVE_PATH := "user://save_smoke_topping_staff.json"

## 結果を知らせる: func(name: String, ok: bool, detail: String)
var _check: Callable
## 最後まで確かめ終えたか（途中でスクリプトのエラーが出ると false のまま）
var completed: bool = false


func run(check: Callable) -> void:
	_check = check
	var keep_scale: float = Engine.time_scale
	Engine.time_scale = 4.0
	_check_wage()
	await _check_toppings()
	await _check_staff()
	completed = true
	GameState.delete_save()
	Engine.time_scale = keep_scale


## 日給は営業した日ごとに人件費として引かれ、利益にも入る
func _check_wage() -> void:
	GameState.use_save_path(SAVE_PATH)
	GameState.rank = 2
	var hired_a: bool = GameState.hire_staff("tanaka")
	var hired_b: bool = GameState.hire_staff("suzuki")
	var over: bool = GameState.hire_staff("takahashi")
	var wage: int = Database.get_staff("tanaka").daily_wage + Database.get_staff("suzuki").daily_wage
	GameState.begin_business()
	var before: int = GameState.money
	GameState.finish_business()
	var paid: int = before - GameState.money
	var s: DayStats = GameState.today
	_check.call("従業員: 知る人ぞ知る店（ランク2）で2人まで雇え、日給の合計が人件費になって所持金と利益から引かれる",
		hired_a and hired_b and not over and s.labor_cost == wage and paid == wage + s.other_expense
		and s.profit() == s.sales - s.ingredient_cost - s.other_expense - wage and s.staff_count == 2,
		"labor=%d paid=%d" % [s.labor_cost, paid])
	var dismissed: bool = GameState.dismiss_staff("tanaka")
	GameState.rank = 1
	var full_at_rank1: bool = not GameState.can_hire("tanaka")
	GameState.hired_staff.clear()
	_check.call("従業員: やめてもらうと日給がかからない。無名店（ランク1）でも1人まで雇える",
		dismissed and full_at_rank1 and GameState.can_hire("sato") and GameState.hire_staff("sato")
		and not GameState.can_hire("tanaka") and Database.get_staff_limit(3) == 3 and Database.get_staff_limit(4) == 3)
	_check.call("従業員: 日給のいちばん安い候補は佐藤さん（¥1,500・ゆっくり）",
		Database.staff[0].id == "sato" and Database.staff[0].daily_wage == 1500
		and StaffRow.speed_name(Database.staff[0]) == UIText.UPGRADE_STAFF_SPEED_NAMES[0])
	GameState.hired_staff.clear()


func _start_business(hire: Array[String]) -> Node:
	GameState.use_save_path(SAVE_PATH)
	GameState.rank = 4
	GameState.hired_staff.clear()
	for id: String in hire:
		GameState.hire_staff(id)
	for ing: IngredientData in Database.ingredients:
		GameState.inventory[ing.id] = 50
	for id: String in ["karaage", "yakizakana", "shogayaki", "tamagoyaki", "potato_salad"]:
		if not GameState.is_unlocked(id):
			GameState.unlocked_dishes.append(id)
		GameState.change_prep(id, 5)
	var business: Node = BUSINESS_SCENE.instantiate()
	add_child(business)
	(business.get("_spawner") as CustomerSpawner).stop()
	await get_tree().process_frame
	await get_tree().process_frame
	return business


func _add_customer(business: Node, dish_id: String, topping_id: String) -> Customer:
	var order: Dictionary = {
		"dish": Database.get_dish(dish_id),
		"topping": Database.get_dish(topping_id) if topping_id != "" else null,
		"missed": [],
	}
	var customers: Array[Customer] = business.get("_customers")
	var before: int = customers.size()
	business.call("_on_spawn_requested", Database.customer_types[0], order)
	if customers.size() <= before:
		return null
	var c: Customer = customers[customers.size() - 1]
	# 席まで歩いて注文するのを待つ
	await _wait_until(func() -> bool: return c.is_waiting_food(), 10.0)
	return c


func _hold_and_serve(business: Node, c: Customer, item_id: String) -> void:
	var shelf: ReadyShelf = business.get("_shelf")
	var slots: Array[String] = shelf.get("_slots")
	var buttons: Array[Button] = shelf.get("_buttons")
	var slot: int = slots.find(item_id)
	if slot < 0:
		return
	if int(shelf.get("_held_index")) != slot:
		buttons[slot].pressed.emit()
	var dining: DiningArea = business.get("_dining")
	(dining.get_seat(c.seat_index).get("_tap_button") as Button).pressed.emit()


func _check_toppings() -> void:
	var business: Node = await _start_business([])
	var shelf: ReadyShelf = business.get("_shelf")
	var supply: DishSupply = business.get("_supply")
	var c: Customer = await _add_customer(business, "karaage", "tamagoyaki")
	_check.call("トッピング付きの注文: 料理とトッピングを1つずつ確保し、注文状況に両方出る",
		c != null and c.topping != null and supply.get_reserved("karaage") == 1 and supply.get_reserved("tamagoyaki") == 1)
	var order_panel: OrderPanel = business.get("_order_panel")
	await _wait_until(func() -> bool: return (order_panel.get("_dish_labels") as Array).size() > 0, 2.0)
	var dish_label: Label = (order_panel.get("_dish_labels") as Array[Label])[0]
	var topping_label: Label = (order_panel.get("_topping_labels") as Array[Label])[0]
	_check.call("注文状況に「唐揚げ定食」「＋卵焼き」が出る",
		dish_label.text == "唐揚げ定食" and topping_label.visible and topping_label.text == "＋卵焼き",
		"%s / %s" % [dish_label.text, topping_label.text])

	for id: String in ["karaage", "potato_salad", "tamagoyaki"]:
		shelf.add_dish(id)
	var mistakes: int = GameState.today.mistakes
	_hold_and_serve(business, c, "potato_salad")
	_check.call("違うトッピング（ポテトサラダ）を出すとミスで、出したことにならない",
		GameState.today.mistakes == mistakes + 1 and c.is_waiting_food() and not c.topping_served
		and shelf.get("_slots").has("potato_salad"))
	shelf.call("_on_slot_pressed", (shelf.get("_slots") as Array[String]).find("potato_salad"))
	var completed: int = GameState.today.completed_orders
	_hold_and_serve(business, c, "karaage")
	# 注文状況は営業画面の次の _process で更新される
	await get_tree().process_frame
	await get_tree().process_frame
	_check.call("料理だけ出しても、トッピングがそろうまで食べない（待ち時間は続く。注文状況の料理は薄くなる）",
		c.dish_served and c.is_waiting_food() and GameState.today.completed_orders == completed
		and dish_label.modulate.a < 0.9 and topping_label.modulate.a > 0.9)
	var waited: float = c.wait_elapsed
	await get_tree().create_timer(0.3).timeout
	var still_waiting: bool = c.wait_elapsed > waited
	var sales: int = GameState.today.sales
	_hold_and_serve(business, c, "tamagoyaki")
	_check.call("トッピングも出すと食べ始め、注文1件の完了になる（料理とトッピングがそれぞれ売れた数に入る）",
		still_waiting and c.state == Customer.State.EATING and GameState.today.completed_orders == completed + 1
		and int(GameState.today.dish_sold.get("karaage", 0)) == 1 and int(GameState.today.dish_sold.get("tamagoyaki", 0)) == 1)
	c.set("_state_time", 999.0)
	await _wait_until(func() -> bool: return GameState.today.sales > sales, 1.0)
	_check.call("会計は料理＋トッピングの合計（¥980＋¥150）",
		GameState.today.sales - sales == 1130 and int(GameState.today.dish_sales.get("tamagoyaki", 0)) == 150,
		"+%d" % (GameState.today.sales - sales))

	# トッピングが売り切れていたら頼まない（売り逃し）
	var spawner: CustomerSpawner = business.get("_spawner")
	for i: int in 5:
		supply.reserve("tamagoyaki")
	var student: CustomerTypeData = Database.customer_types[0]
	var keep_rate: float = student.topping_rate
	student.topping_rate = 1.0
	var only_tamagoyaki: Array[DishData] = [Database.get_dish("tamagoyaki")]
	spawner.set("_toppings", only_tamagoyaki)
	var order: Dictionary = spawner.choose_order(student)
	student.topping_rate = keep_rate
	_check.call("トッピングが売り切れていたら頼まず、売り逃しとして数える",
		order["dish"] != null and order["topping"] == null and (order["missed"] as Array).has("tamagoyaki"))
	business.queue_free()
	await get_tree().process_frame


func _check_staff() -> void:
	var business: Node = await _start_business(["watanabe"])
	var dispatcher: StaffDispatcher = business.get("_staff")
	var shelf: ReadyShelf = business.get("_shelf")
	var supply: DishSupply = business.get("_supply")
	var staff_list: Array[HallStaff] = dispatcher.get_staff()
	_check.call("雇った従業員が営業画面に出る（待機場所は客席エリアの中）", staff_list.size() == 1
		and Rect2(Vector2.ZERO, (business.get("_dining") as DiningArea).size).has_point(staff_list[0].position))
	var staff: HallStaff = staff_list[0]

	# プレイヤーが持っている料理には手を出さない
	shelf.add_dish("yakizakana")
	var buttons: Array[Button] = shelf.get("_buttons")
	buttons[0].pressed.emit()
	var c1: Customer = await _add_customer(business, "yakizakana", "")
	for i: int in 10:
		await get_tree().process_frame
	_check.call("プレイヤーが持っている料理は、スタッフが取らない", staff.is_idle() and shelf.get_held_dish() == "yakizakana"
		and not shelf.is_reserved(0))
	buttons[0].pressed.emit()  # 持つのをやめる
	await get_tree().process_frame
	await get_tree().process_frame
	var reserved: bool = shelf.is_reserved(0) and staff.state == HallStaff.State.PICKING
	buttons[0].pressed.emit()
	_check.call("スタッフが取りに来ている枠は予約になり、プレイヤーは持てない（取り合いにならない）",
		reserved and shelf.get_held_dish() == "", "state=%d" % staff.state)
	var served: bool = await _wait_until(func() -> bool: return c1.state == Customer.State.EATING, 8.0)
	_check.call("スタッフが置き場の料理を取って運び、配膳する（料理が置き場から消える）",
		served and not (shelf.get("_slots") as Array[String]).has("yakizakana") and int(GameState.today.dish_sold.get("yakizakana", 0)) == 1,
		"served=%s slots=%s sold=%s c1=%d staff=%d items=%s pos=%s home=%s c1pos=%s spd=%s" % [served, shelf.get("_slots"), GameState.today.dish_sold,
			c1.state, staff.state, staff.items, staff.position, staff.home, c1.position, staff.data.walk_speed])
	await _wait_until(func() -> bool: return staff.is_idle(), 8.0)

	# トッピング付きの注文も、料理とトッピングの両方を運ぶ
	var c2: Customer = await _add_customer(business, "shogayaki", "tamagoyaki")
	shelf.add_dish("shogayaki")
	shelf.add_dish("tamagoyaki")
	var both: bool = await _wait_until(func() -> bool: return c2.state == Customer.State.EATING, 20.0)
	_check.call("スタッフはトッピング付きの注文も、料理とトッピングを順に運んで出し終える", both,
		"state=%d dish=%s top=%s staff=%d wait=%.1f" % [c2.state, c2.dish_served, c2.topping_served, staff.state, c2.wait_elapsed])
	await _wait_until(func() -> bool: return staff.is_idle(), 8.0)

	# 運び先の客が帰ったら、料理を置き場に戻す
	var c3: Customer = await _add_customer(business, "karaage", "")
	shelf.add_dish("karaage")
	var carrying: bool = await _wait_until(func() -> bool: return staff.state == HallStaff.State.CARRYING, 6.0)
	var on_shelf_while_carrying: bool = (shelf.get("_slots") as Array[String]).has("karaage")
	c3.call("_leave_angry")
	var returned: bool = await _wait_until(func() -> bool:
		return staff.is_idle() and (shelf.get("_slots") as Array[String]).has("karaage"), 10.0)
	_check.call("運び先の客が帰ったら、スタッフは料理を置き場に戻す（確保も外れる）",
		carrying and not on_shelf_while_carrying and returned and supply.get_reserved("karaage") == 0
		and supply.get_units("karaage") == 5)
	business.queue_free()
	await get_tree().process_frame
	GameState.hired_staff.clear()


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left: float = seconds
	while left > 0.0:
		if bool(condition.call()):
			return true
		await get_tree().create_timer(0.05).timeout
		left -= 0.05
	return bool(condition.call())
