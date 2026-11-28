class_name KitchenStaffChecks
extends Node
## スモークテストの一部: スタッフの担当（ホール／厨房）と、厨房での調理。
##   - 厨房に入れるのは1日1人まで、前回の担当から始まる、厨房担当は配膳しない、厨房手当が人件費に入る
##   - 店主とスタッフが同時に2つ作る、置き場の空き枠に2人分の調理中を数える
##   - スタッフの研修のレベルで調理時間と作れる難しさが変わる、作れない難しさの料理はスタッフが作らない（「店主のみ」の印）
## GameState はこのテスト用のセーブの場所で使い、終わったら消す。

const BUSINESS_SCENE: PackedScene = preload("res://scenes/business/business.tscn")
const SAVE_PATH := "user://save_smoke_kitchen_staff.json"

## 結果を知らせる: func(name: String, ok: bool, detail: String)
var _check: Callable
## 最後まで確かめ終えたか
var completed: bool = false


func run(check: Callable) -> void:
	_check = check
	_check_one_in_kitchen()
	_check_role_carried_over()
	_check_allowance()
	_check_cook_level()
	await _check_two_cooks_and_slots()
	await _check_difficulty()
	await _check_kitchen_staff_not_serving()
	GameState.delete_save()
	completed = true


## 1日目は金曜日。佐藤さん（定休 月）・鈴木さん（定休 日）・渡辺さん（定休 木・日）は出られる
func _fresh() -> void:
	GameState.use_save_path(SAVE_PATH)
	GameState.delete_save()
	GameState.use_save_path(SAVE_PATH)
	GameState.rank = 4


func _clear_sudden_absence() -> void:
	for staff_id: String in GameState.hired_staff:
		GameState.get_staff_state(staff_id)["absent_day"] = 0
	GameState.call("_reset_shift_plan")


## 厨房は1人まで: 2人目は厨房にできない（準備③のボタンも押せない）。休みの人は厨房にできない。
## 厨房の人を休みにすると、ほかの人を厨房にできる。休みから出勤に戻した人が厨房担当のままで、ほかに厨房の人がいればホールになる
func _check_one_in_kitchen() -> void:
	_fresh()
	GameState.hire_staff("sato")
	GameState.hire_staff("suzuki")
	var hall_first: bool = GameState.get_staff_role("sato") == GameState.ROLE_HALL and GameState.get_kitchen_staff() == null
	var first_ok: bool = GameState.set_staff_role("sato", GameState.ROLE_KITCHEN)
	var second_refused: bool = not GameState.set_staff_role("suzuki", GameState.ROLE_KITCHEN) \
		and GameState.get_kitchen_block("suzuki") == GameState.KitchenBlock.TAKEN
	var panel: StaffShiftPanel = StaffShiftPanel.new()
	add_child(panel)
	panel.rebuild()
	var buttons: Dictionary = panel.get("_role_buttons")
	var sato_button: Button = buttons["sato"]
	var suzuki_button: Button = buttons["suzuki"]
	var ui_ok: bool = sato_button.text == UIText.PREP_STAFF_KITCHEN and not sato_button.disabled \
		and suzuki_button.text == UIText.PREP_STAFF_HALL and suzuki_button.disabled
	# 準備③のボタンで厨房をやめると、ほかの人のボタンを押せるようになる
	sato_button.pressed.emit()
	var released: bool = GameState.get_kitchen_staff() == null and not suzuki_button.disabled
	suzuki_button.pressed.emit()
	var switched: bool = GameState.get_kitchen_staff() == Database.get_staff("suzuki") and sato_button.disabled
	panel.queue_free()
	_check.call("厨房に入れるのは1日1人まで（2人目は厨房にできず、準備③の担当のボタンも押せない）",
		hall_first and first_ok and second_refused and ui_ok and released and switched,
		"kitchen=%s" % [GameState.get_kitchen_staff()])
	# 休みの人は厨房にできない。厨房の人を休みにすると、ほかの人を厨房にできる
	GameState.set_shift("suzuki", false)
	var off_refused: bool = not GameState.set_staff_role("suzuki", GameState.ROLE_KITCHEN) or GameState.get_kitchen_staff() == null
	var sato_ok: bool = GameState.set_staff_role("sato", GameState.ROLE_KITCHEN)
	# 鈴木さんは厨房担当のまま休みにしていた。出勤に戻すと、佐藤さんが厨房なのでホールになる
	GameState.set_shift("suzuki", true)
	_check.call("休みの人は厨房にできず、休みから戻した人は、ほかの人が厨房ならホールになる",
		off_refused and sato_ok and GameState.get_staff_role("suzuki") == GameState.ROLE_HALL
		and GameState.get_kitchen_staff() == Database.get_staff("sato"),
		"suzuki=%s" % GameState.get_staff_role("suzuki"))


## 次の日の担当は前回と同じから始まる（出勤の初期値と同じ考え方）
func _check_role_carried_over() -> void:
	_fresh()
	GameState.hire_staff("sato")
	GameState.hire_staff("suzuki")
	GameState.set_staff_role("suzuki", GameState.ROLE_KITCHEN)
	GameState.begin_business()
	GameState.finish_business()
	GameState.advance_day()
	_clear_sudden_absence()
	_check.call("次の日の担当は前回と同じから始まる（前回厨房だった人は厨房）",
		GameState.get_staff_role("suzuki") == GameState.ROLE_KITCHEN and GameState.get_staff_role("sato") == GameState.ROLE_HALL
		and str(GameState.get_staff_state("suzuki").get("last_role")) == GameState.ROLE_KITCHEN)


## 厨房手当: 厨房担当の人の日給に上乗せされ、人件費に入る
func _check_allowance() -> void:
	_fresh()
	GameState.hire_staff("sato")
	GameState.hire_staff("suzuki")
	GameState.set_staff_role("sato", GameState.ROLE_KITCHEN)
	var sato: StaffData = Database.get_staff("sato")
	var suzuki: StaffData = Database.get_staff("suzuki")
	var allowance: int = Database.config.staff_kitchen_allowance
	var expected: int = sato.daily_wage + allowance + suzuki.daily_wage
	var planned: int = GameState.get_daily_wage_total()
	GameState.begin_business()
	GameState.finish_business()
	_check.call("厨房担当の人の日給に厨房手当（¥%d）が上乗せされ、人件費に入る" % allowance,
		allowance > 0 and planned == expected and GameState.today.labor_cost == expected and GameState.today.staff_kitchen == "sato",
		"labor=%d expected=%d" % [GameState.today.labor_cost, expected])


## スタッフの調理時間は「設備の効果を入れた調理時間 ÷ 調理の速さ」で、研修のレベルで短くなり、作れる難しさも上がる
func _check_cook_level() -> void:
	_fresh()
	var sato: StaffData = Database.get_staff("sato")
	var dish: DishData = Database.get_dish("karaage")
	var hard: DishData = Database.get_dish("yakizakana")
	GameState.hire_staff("sato")
	var time1: float = GameState.get_staff_cook_time(sato, dish)
	var can1: bool = GameState.can_staff_cook(sato, hard)
	GameState.staff_levels["sato"] = 3
	var time3: float = GameState.get_staff_cook_time(sato, dish)
	var can3: bool = GameState.can_staff_cook(sato, hard)
	var training: StaffTrainingData = Database.staff_training
	GameState.staff_levels["sato"] = training.get_max_level()
	var max_speed: float = GameState.get_staff_cook_speed(sato)
	GameState.staff_levels["sato"] = 1
	_check.call("スタッフの調理時間は研修のレベルで短くなり（Lv1 %.1f秒 → Lv3 %.1f秒）、店主より遅い。作れる難しさも上がる" % [time1, time3],
		time1 > GameState.get_cook_time(dish) and time3 < time1
		and is_equal_approx(time1, GameState.get_cook_time(dish) / sato.cook_speed)
		and not can1 and can3 and max_speed <= 1.1,
		"Lv1 難しさ%d可=%s Lv3可=%s 最大レベルの速さ=%.2f" % [hard.difficulty, can1, can3, max_speed])


## 営業画面を開く（客は来ない）。prep: { 料理id: 仕込み数 }
func _open_business(prep: Dictionary) -> Node:
	for dish_id: String in prep:
		GameState.change_prep(dish_id, int(prep[dish_id]))
	for ing: IngredientData in Database.ingredients:
		GameState.inventory[ing.id] = 30
	var business: Node = BUSINESS_SCENE.instantiate()
	add_child(business)
	(business.get("_spawner") as CustomerSpawner).stop()
	await get_tree().process_frame
	await get_tree().process_frame
	return business


func _close_business(business: Node) -> void:
	Engine.time_scale = 1.0
	business.queue_free()
	await get_tree().process_frame


## 店主とスタッフが同時に2つ作る。置き場の空き枠の判定は、2人分の調理中と調理待ちを含めて数える
func _check_two_cooks_and_slots() -> void:
	_fresh()
	GameState.hire_staff("sato")
	GameState.set_staff_role("sato", GameState.ROLE_KITCHEN)
	var business: Node = await _open_business({"karaage": 4, "yakizakana": 3})
	var kitchen: Kitchen = business.get("_kitchen")
	var shelf: ReadyShelf = business.get("_shelf")
	var supply: DishSupply = business.get("_supply")
	# 置き場の空きを2枠にする
	while shelf.free_count() > 2:
		shelf.add_dish("karaage")
	await get_tree().process_frame
	var buttons: Dictionary = kitchen.get("_buttons")
	var karaage_before: int = supply.get_remaining("karaage")
	(buttons["yakizakana"] as Button).pressed.emit()
	(buttons["karaage"] as Button).pressed.emit()
	# 3つ目は置き場の空き（2枠）を超えるので作れない
	(buttons["karaage"] as Button).pressed.emit()
	var third_refused: bool = supply.get_remaining("karaage") == karaage_before - 1
	await get_tree().process_frame
	var cooking: Array[DishData] = kitchen.get_cooking()
	var cooks: Array = kitchen.get("_cooks")
	var chef_dish: DishData = (cooks[0] as Kitchen.Cook).current
	var staff_dish: DishData = (cooks[1] as Kitchen.Cook).current
	_check.call("店主とスタッフが同時に2つの料理を作る（店主は焼き魚、スタッフは唐揚げ）",
		cooking.size() == 2 and chef_dish != null and chef_dish.id == "yakizakana" and staff_dish != null and staff_dish.id == "karaage"
		and kitchen.get_kitchen_staff() == Database.get_staff("sato"),
		"cooking=%d" % cooking.size())
	_check.call("置き場の空き枠の判定に、2人分の調理中を含める（空き2枠で2つ作っていると3つ目は作れず、ボタンも押せない）",
		third_refused and kitchen.get_pending_count() == 2 and (buttons["karaage"] as Button).disabled,
		"pending=%d free=%d" % [kitchen.get_pending_count(), shelf.free_count()])
	# スタッフの調理時間は、研修のレベルを入れた時間
	var staff_cook: Kitchen.Cook = cooks[1]
	_check.call("厨房のスタッフの調理時間は、調理の速さと研修のレベルで決まる時間になる",
		is_equal_approx(staff_cook.duration, GameState.get_staff_cook_time(Database.get_staff("sato"), Database.get_dish("karaage")))
		and is_equal_approx((cooks[0] as Kitchen.Cook).duration, GameState.get_cook_time(Database.get_dish("yakizakana"))))
	await _close_business(business)


## スタッフは作れない難しさの料理を作らない（調理待ちの先頭から、作れる料理を探して作る）。ボタンに「店主のみ」の印が付く
func _check_difficulty() -> void:
	_fresh()
	GameState.hire_staff("sato")
	GameState.set_staff_role("sato", GameState.ROLE_KITCHEN)
	var business: Node = await _open_business({"karaage": 2, "yakizakana": 3})
	var kitchen: Kitchen = business.get("_kitchen")
	var buttons: Dictionary = kitchen.get("_buttons")
	var marks_ok: bool = kitchen.has_chef_only_mark("yakizakana") and not kitchen.has_chef_only_mark("karaage")
	(buttons["yakizakana"] as Button).pressed.emit()
	(buttons["yakizakana"] as Button).pressed.emit()
	(buttons["karaage"] as Button).pressed.emit()
	await get_tree().process_frame
	var cooks: Array = kitchen.get("_cooks")
	var staff_cook: Kitchen.Cook = cooks[1]
	var skipped: bool = staff_cook.current != null and staff_cook.current.id == "karaage"
	var queue: Array[DishData] = kitchen.get("_queue")
	var left_for_chef: bool = queue.size() == 1 and queue[0].id == "yakizakana"
	# 全部できあがるまで、スタッフが焼き魚を作らないことを見る
	Engine.time_scale = 10.0
	var staff_made_hard: bool = false
	var waited: float = 0.0
	while kitchen.get_pending_count() > 0 and waited < 5.0:
		if staff_cook.current != null and staff_cook.current.id == "yakizakana":
			staff_made_hard = true
		await get_tree().process_frame
		waited += get_process_delta_time() / Engine.time_scale
	_check.call("作れない難しさの料理（焼き魚）はスタッフが作らず、店主だけが作る（スタッフは後ろの唐揚げを先に作る）",
		skipped and left_for_chef and not staff_made_hard and kitchen.get_pending_count() == 0,
		"pending=%d" % kitchen.get_pending_count())
	_check.call("厨房のボタンで、スタッフが作れない料理にだけ「店主のみ」の印が付く", marks_ok)
	await _close_business(business)
	# スタッフが厨房にいない日は印を付けない
	_fresh()
	var business2: Node = await _open_business({"karaage": 1, "yakizakana": 1})
	var kitchen2: Kitchen = business2.get("_kitchen")
	_check.call("スタッフが厨房にいない日は、店主だけで作り、「店主のみ」の印も付けない",
		kitchen2.get_kitchen_staff() == null and not kitchen2.has_chef_only_mark("yakizakana")
		and (kitchen2.get("_cooks") as Array).size() == 1)
	await _close_business(business2)


## 厨房担当のスタッフは配膳しない（ホールのスタッフだけが営業画面のホールに出る）
func _check_kitchen_staff_not_serving() -> void:
	_fresh()
	GameState.hire_staff("sato")
	GameState.hire_staff("watanabe")
	GameState.set_staff_role("sato", GameState.ROLE_KITCHEN)
	var business: Node = await _open_business({"karaage": 2})
	var staff: Array[HallStaff] = (business.get("_staff") as StaffDispatcher).get_staff()
	_check.call("厨房担当のスタッフは配膳しない（ホールに出るのはホール担当の渡辺さんだけ）",
		staff.size() == 1 and staff[0].data.id == "watanabe" and GameState.get_hall_staff().size() == 1,
		"hall=%d" % staff.size())
	await _close_business(business)
