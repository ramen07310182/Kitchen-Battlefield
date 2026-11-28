class_name StaffShiftChecks
extends Node
## スモークテストの一部: スタッフの出勤（シフト）・出られない日・在籍日数と退職・研修・面接代。
##   - 休みのスタッフは働かず日給もかからない、出られない日は出勤にできない
##   - 在籍日数で退職する・予告が出る・雇い直しの待ち日数、研修で速さと日給が変わる、面接代が引かれる・足りないと雇えない
## GameState はこのテスト用のセーブの場所で使い、終わったら消す。

const BUSINESS_SCENE: PackedScene = preload("res://scenes/business/business.tscn")
const RESULT_SCENE: PackedScene = preload("res://scenes/result/result_screen.tscn")
const SAVE_PATH := "user://save_smoke_staff_shift.json"

## 結果を知らせる: func(name: String, ok: bool, detail: String)
var _check: Callable
## 最後まで確かめ終えたか
var completed: bool = false


func run(check: Callable) -> void:
	_check = check
	_check_shift_and_wage()
	_check_unavailable()
	await _check_business_uses_shift()
	await _check_tenure()
	_check_training()
	_check_interview_fee()
	GameState.delete_save()
	completed = true


func _fresh() -> void:
	GameState.use_save_path(SAVE_PATH)
	GameState.delete_save()
	GameState.use_save_path(SAVE_PATH)
	GameState.rank = 2


## 1日目は金曜日。佐藤さん（定休 月）・鈴木さん（定休 日）は出られる
func _check_shift_and_wage() -> void:
	_fresh()
	var hired: bool = GameState.hire_staff("sato") and GameState.hire_staff("suzuki")
	var both_on: bool = GameState.is_on_shift("sato") and GameState.is_on_shift("suzuki")
	GameState.begin_business()
	var before: int = GameState.money
	GameState.finish_business()
	var wage_both: int = Database.get_staff("sato").daily_wage + Database.get_staff("suzuki").daily_wage
	_check.call("出勤した2人の日給が人件費になる（雇ったばかりの人は出勤から始まる）",
		hired and both_on and GameState.today.labor_cost == wage_both
		and before - GameState.money == wage_both + GameState.today.other_expense
		and GameState.today.profit() == GameState.today.sales - GameState.today.ingredient_cost - GameState.today.other_expense - wage_both,
		"labor=%d" % GameState.today.labor_cost)
	GameState.advance_day()
	_clear_sudden_absence()
	var kept: bool = GameState.is_on_shift("sato") and GameState.is_on_shift("suzuki")
	var off_ok: bool = GameState.set_shift("suzuki", false)
	GameState.begin_business()
	GameState.finish_business()
	_check.call("休みにしたスタッフは働かず、日給もかからない（次の日は前回と同じ出勤から始まる）",
		kept and off_ok and not GameState.today.staff_worked.has("suzuki") and GameState.today.staff_worked.has("sato")
		and GameState.today.labor_cost == Database.get_staff("sato").daily_wage,
		"worked=%s labor=%d" % [GameState.today.staff_worked, GameState.today.labor_cost])
	GameState.advance_day()
	_clear_sudden_absence()
	_check.call("前回休みにした人は、次の日も休みから始まる（前回と同じ出勤）",
		not GameState.is_on_shift("suzuki") and GameState.is_on_shift("sato"))


## 「次の日へ」で決まる急な休み（確率）がテストの結果を変えないように、急な休みをなくして出勤を決め直す
func _clear_sudden_absence() -> void:
	for staff_id: String in GameState.hired_staff:
		GameState.get_staff_state(staff_id)["absent_day"] = 0
	GameState.call("_reset_shift_plan")


func _check_unavailable() -> void:
	_fresh()
	# 1日目（金曜）は田中さん（定休 金・土）は出られない
	GameState.hire_staff("tanaka")
	var fixed: bool = GameState.get_staff_absence("tanaka") == "fixed" and not GameState.set_shift("tanaka", true) \
		and not GameState.is_on_shift("tanaka")
	GameState.hire_staff("sato")
	GameState.get_staff_state("sato")["absent_day"] = GameState.day
	var sudden: bool = GameState.get_staff_absence("sato") == "sudden" and not GameState.set_shift("sato", true) \
		and not GameState.is_on_shift("sato")
	_check.call("出られない日（固定の休み・急な休み）は出勤にできない", fixed and sudden)
	GameState.begin_business()
	GameState.finish_business()
	_check.call("出られない日のスタッフは働かず、日給もかからない",
		GameState.today.staff_worked.is_empty() and GameState.today.labor_cost == 0)
	var text_fixed: String = UIText.PREP_STAFF_OFF_FIXED % UIText.weekday_list(Database.get_staff("tanaka").days_off)
	_check.call("固定の休みの曜日の書き方（「休み（定休：金・土）」）", text_fixed == "休み（定休：金・土）", text_fixed)


func _check_business_uses_shift() -> void:
	_fresh()
	GameState.rank = 4
	for id: String in ["watanabe", "sato"]:
		GameState.hire_staff(id)
	GameState.set_shift("sato", false)
	GameState.change_prep("karaage", 2)
	for ing: IngredientData in Database.ingredients:
		GameState.inventory[ing.id] = 20
	var business: Node = BUSINESS_SCENE.instantiate()
	add_child(business)
	(business.get("_spawner") as CustomerSpawner).stop()
	await get_tree().process_frame
	await get_tree().process_frame
	var staff: Array[HallStaff] = (business.get("_staff") as StaffDispatcher).get_staff()
	_check.call("営業画面には出勤したスタッフだけが出る（休みの人は働かない）",
		staff.size() == 1 and staff[0].data.id == "watanabe")
	business.queue_free()
	await get_tree().process_frame


## 在籍日数: 休みにした日も数え、在籍日数に達した日の営業結果で退職する。残りが少ないと予告が出る。結果画面に退職が出る
func _check_tenure() -> void:
	_fresh()
	var data: StaffData = Database.get_staff("sato")
	GameState.hire_staff("sato")
	var start_left: int = GameState.get_staff_days_left("sato")
	# 1日は休みにする（休みの日も在籍日数に数える）
	GameState.set_shift("sato", false)
	GameState.begin_business()
	GameState.finish_business()
	GameState.advance_day()
	_clear_sudden_absence()
	var after_off: int = GameState.get_staff_days_left("sato")
	_check.call("在籍日数は雇った日から数え、休みにした日も数える（あと%d日 → %d日）" % [start_left, after_off],
		start_left == data.tenure_days and after_off == data.tenure_days - 1)
	# 退職の予告: 残りが staff_retire_notice_days より少ないと出る
	var notice_days: int = Database.config.staff_retire_notice_days
	GameState.get_staff_state("sato")["enrolled"] = data.tenure_days - notice_days
	var no_notice: bool = not GameState.is_staff_retiring_soon("sato")
	GameState.get_staff_state("sato")["enrolled"] = data.tenure_days - (notice_days - 1)
	var panel: StaffShiftPanel = StaffShiftPanel.new()
	add_child(panel)
	panel.rebuild()
	var notice_text: String = ""
	for label: Node in panel.find_children("*", "Label", true, false):
		if (label as Label).text.contains("退職します"):
			notice_text = (label as Label).text
	panel.queue_free()
	_check.call("退職の予告: 残り%d日より少なくなると準備③に「あと○日で退職します」が出る" % notice_days,
		no_notice and GameState.is_staff_retiring_soon("sato")
		and notice_text == UIText.PREP_STAFF_RETIRE_NOTICE % [data.display_name, notice_days - 1], notice_text)
	# 最後の日の営業結果で退職する
	GameState.get_staff_state("sato")["enrolled"] = data.tenure_days - 1
	GameState.begin_business()
	GameState.finish_business()
	var retired: bool = GameState.today.staff_retired.has("sato") and not GameState.is_hired("sato")
	var result: Node = RESULT_SCENE.instantiate()
	add_child(result)
	await get_tree().process_frame
	var shown: bool = false
	for label: Node in result.find_children("StaffRetired*", "Label", true, false):
		if (label as Label).text == UIText.RESULT_STAFF_RETIRED % data.display_name:
			shown = true
	result.queue_free()
	await get_tree().process_frame
	_check.call("在籍日数に達した日の営業結果で退職し、結果画面に「佐藤さんが今日で退職しました（在籍期間が終わりました）」が出る",
		retired and shown)
	# 雇い直しの待ち日数
	var wait_days: int = Database.config.staff_rehire_wait_days
	var waiting: bool = not GameState.can_hire("sato") and GameState.get_hire_block("sato") == GameState.HireBlock.WAIT
	var wait_first: int = GameState.get_rehire_wait("sato")
	for i: int in wait_days:
		GameState.advance_day()
	var can_after: bool = GameState.can_hire("sato")
	_check.call("退職した人は、退職してから%d営業日は雇い直せず、そのあと雇える（最初は「%d日後から雇える」）" % [wait_days, wait_first],
		waiting and wait_first == wait_days and can_after, "wait=%d" % wait_first)
	GameState.staff_levels["sato"] = 3
	GameState.hire_staff("sato")
	_check.call("雇い直すと在籍日数は最初から数え直し、研修のレベルは引き継ぐ",
		GameState.get_staff_days_left("sato") == data.tenure_days and GameState.get_staff_level("sato") == 3)


## 研修: レベルが上がると速くなり、日給も上がる。代金が足りないと研修できない
func _check_training() -> void:
	_fresh()
	var data: StaffData = Database.get_staff("suzuki")
	var training: StaffTrainingData = Database.staff_training
	GameState.hire_staff("suzuki")
	var speed1: float = GameState.get_staff_walk_speed(data)
	var pick1: float = GameState.get_staff_pick_time(data)
	var wage1: int = GameState.get_staff_wage(data)
	var price: int = training.get_price(1)
	GameState.add_money(-GameState.money + price - 1)
	var blocked: bool = GameState.get_train_block("suzuki") == GameState.TrainBlock.MONEY and not GameState.train_staff("suzuki")
	GameState.add_money(1)
	var before: int = GameState.money
	var trained: bool = GameState.train_staff("suzuki")
	_check.call("研修で速くなり（歩く速さ↑・取るまで↓）、日給が少し上がる。代金が足りないと研修できない",
		blocked and trained and GameState.get_staff_level("suzuki") == 2 and before - GameState.money == price
		and GameState.get_staff_walk_speed(data) > speed1 and GameState.get_staff_pick_time(data) < pick1
		and GameState.get_staff_wage(data) == wage1 + training.get_wage_add(2),
		"Lv%d speed %.0f→%.0f wage %d→%d" % [GameState.get_staff_level("suzuki"), speed1, GameState.get_staff_walk_speed(data),
			wage1, GameState.get_staff_wage(data)])
	GameState.begin_business()
	GameState.finish_business()
	_check.call("研修したスタッフの日給（上がった分）が人件費になる", GameState.today.labor_cost == wage1 + training.get_wage_add(2))
	var lines: PackedStringArray = StaffRow.detail_lines(data)
	var text: String = "\n".join(lines)
	_check.call("従業員の詳細に、在籍日数と、今と研修後のレベル（速さ・日給）が出る",
		text.contains(UIText.UPGRADE_STAFF_DETAIL_TENURE % data.tenure_days) and text.contains("今：Lv2") and text.contains("研修後：Lv3"))


## 面接代: 雇うと引かれる。足りないと雇えない
func _check_interview_fee() -> void:
	_fresh()
	var fee: int = Database.config.staff_interview_fee
	GameState.add_money(-GameState.money + fee - 1)
	var blocked: bool = GameState.get_hire_block("sato") == GameState.HireBlock.MONEY and not GameState.hire_staff("sato")
	GameState.add_money(1)
	var hired: bool = GameState.hire_staff("sato")
	_check.call("雇うと面接代（¥%d）が引かれ、所持金が足りないと雇えない" % fee,
		blocked and hired and GameState.money == 0)
