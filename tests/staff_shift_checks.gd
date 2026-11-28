class_name StaffShiftChecks
extends Node
## スモークテストの一部: スタッフの出勤（シフト）・出られない日・満足度・辞めること。
##   - 休みのスタッフは働かず日給もかからない、出られない日は出勤にできない
##   - 連勤で満足度が下がり休みで上がる、満足度が低いと辞めることがある（理由が結果画面に出る）、辞めた人をまた雇える
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
	_check_mood()
	await _check_quit()
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
	var kept: bool = GameState.is_on_shift("sato") and GameState.is_on_shift("suzuki")
	var off_ok: bool = GameState.set_shift("suzuki", false)
	GameState.begin_business()
	GameState.finish_business()
	_check.call("休みにしたスタッフは働かず、日給もかからない（次の日は前回と同じ出勤から始まる）",
		kept and off_ok and not GameState.today.staff_worked.has("suzuki") and GameState.today.staff_worked.has("sato")
		and GameState.today.labor_cost == Database.get_staff("sato").daily_wage,
		"worked=%s labor=%d" % [GameState.today.staff_worked, GameState.today.labor_cost])
	GameState.advance_day()
	_check.call("前回休みにした人は、次の日も休みから始まる（前回と同じ出勤）",
		not GameState.is_on_shift("suzuki") and GameState.is_on_shift("sato"))


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


func _check_mood() -> void:
	_fresh()
	var cfg: GameConfig = Database.config
	var state: Dictionary = StaffMood.new_state(cfg)
	var start: float = float(state["mood"])
	for i: int in cfg.staff_streak_days + 1:
		StaffMood.update_day(state, true, true, 1, 10, false, cfg)
	var after_streak: float = float(state["mood"])
	StaffMood.update_day(state, false, true, 0, 0, false, cfg)
	var after_rest: float = float(state["mood"])
	_check.call("連勤が続くと満足度が下がり、理由は「連勤」。休むと上がる",
		after_streak < start and StaffMood.main_reason(state) == StaffMood.REASON_STREAK and after_rest > after_streak,
		"%.0f → %.0f → %.0f" % [start, after_streak, after_rest])
	var busy: Dictionary = StaffMood.new_state(cfg)
	StaffMood.update_day(busy, true, true, cfg.staff_busy_angry, 0, false, cfg)
	var calm: Dictionary = StaffMood.new_state(cfg)
	StaffMood.update_day(calm, true, true, 0, 5, true, cfg)
	_check.call("忙しすぎる日は下がり、落ち着いた日・ランクが上がった日は上がる",
		float(busy["mood"]) < start and float(calm["mood"]) > start)
	var bench: Dictionary = StaffMood.new_state(cfg)
	for i: int in cfg.staff_bench_days + 1:
		StaffMood.update_day(bench, false, true, 0, 0, false, cfg)
	_check.call("出られるのに出勤させない日が続くと下がる（理由は「出番がない」）",
		float(bench["mood"]) < start and StaffMood.main_reason(bench) == StaffMood.REASON_BENCH)
	# 満足度が低いと注意が出る
	GameState.hire_staff("sato")
	GameState.get_staff_state("sato")["mood"] = cfg.staff_mood_warn - 1.0
	GameState.get_staff_state("sato")["reasons"] = { StaffMood.REASON_STREAK: 10.0 }
	_check.call("満足度が低いと「最近疲れているようです」の注意が出る",
		GameState.get_staff_warning("sato") == StaffMood.REASON_STREAK
		and (UIText.STAFF_WARNINGS[StaffMood.REASON_STREAK] as String).contains("疲れている"))


func _check_quit() -> void:
	_fresh()
	var cfg: GameConfig = Database.config
	var keep_chance: float = cfg.staff_quit_chance
	cfg.staff_quit_chance = 1.0
	GameState.hire_staff("suzuki")
	var state: Dictionary = GameState.get_staff_state("suzuki")
	state["mood"] = cfg.staff_mood_quit - 10.0
	state["streak"] = cfg.staff_streak_days
	state["reasons"] = { StaffMood.REASON_STREAK: 30.0 }
	GameState.begin_business()
	GameState.finish_business()
	cfg.staff_quit_chance = keep_chance
	var quits: Array[Dictionary] = GameState.today.staff_quits
	_check.call("満足度が低いと営業結果で辞めることがあり、いちばん大きな理由が残る（連勤）",
		quits.size() == 1 and String(quits[0]["id"]) == "suzuki" and String(quits[0]["reason"]) == StaffMood.REASON_STREAK
		and not GameState.is_hired("suzuki"), "quits=%s" % [quits])
	# 結果画面に「鈴木さんが辞めました（連勤が続いたため）」が出る
	var result: Node = RESULT_SCENE.instantiate()
	add_child(result)
	await get_tree().process_frame
	var found: bool = false
	for label: Node in result.find_children("StaffQuit*", "Label", true, false):
		if (label as Label).text == UIText.RESULT_STAFF_QUIT % ["鈴木さん", UIText.STAFF_QUIT_REASONS[StaffMood.REASON_STREAK]]:
			found = true
	_check.call("結果画面に「鈴木さんが辞めました（連勤が続いたため）」が出る", found)
	result.queue_free()
	await get_tree().process_frame
	var rehired: bool = GameState.can_hire("suzuki") and GameState.hire_staff("suzuki")
	_check.call("辞めたスタッフはまた雇え、満足度は「ふつう」から始まる",
		rehired and is_equal_approx(GameState.get_staff_mood("suzuki"), cfg.staff_mood_start)
		and GameState.get_staff_mood_level("suzuki") == StaffMood.Level.NORMAL)
