extends Node
## 動作確認用のボット。準備 → 営業 → 結果 → 次の日 を自動で2日分まわし、主なルールを確かめる。
## 実行: Godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn [-- --only=staff,save]
##   --fixed-fps 60: 実時間を待たずにフレームを進める（ゲーム内の時間の進み方は同じで、10倍ほど速く終わる）
##   --only=<まとまり>: そのまとまりだけを実行する（カンマ区切りで複数。省略時は全部）。最後の「本物のセーブは変わっていない」は必ず確かめる
## まとまり（GROUPS）:
##   save    : セーブの移行（古い version から最新へ）
##   rules   : 画面を使わないルール（お金・仕入れ・仕込み・評判とランク・日付・設備・料理の確保・解放の日程・常連さん・売り逃し）
##   layout  : 客席の並び方（席の拡張の各レベル・相席）
##   staff   : トッピングとホールスタッフ（topping）、出勤・在籍日数・研修・面接代（shift）、厨房スタッフ（kitchen）
##             topping / shift / kitchen だけを指定してもよい
##   days    : 準備 → 営業 → 結果 → 強化 を画面で2日分まわす（準備・営業・結果・強化・記録の画面とセーブの中身）
## 本物のセーブ（user://save.json）は読み書きしない。テスト用のファイルに保存し、終わったら消す。
## 確かめる項目は [check] で始まる行に出し、1つでも失敗したら終了コード1で終わる。
##   1日目: 手順の行き来・食材不足で③に進めない・少なく仕込んで売り切れで早く閉店・置き場から外した料理が残りに戻る
##   2日目（5品を解放）: 「前回と同じ仕込み」・不足分を予定に入れる・確定式の仕入れ・仕入れ予定が残ったままの営業開始・廃棄

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const DINING_SCENE: PackedScene = preload("res://scenes/business/dining_area.tscn")
const CUSTOMER_SCENE: PackedScene = preload("res://scenes/business/customer.tscn")
## 16:9 の画面での客席エリアのおよその大きさ（640×360基準）
const DINING_SIZE_16X9 := Vector2(500, 216)
## タップできる範囲の最小（640×360基準のpx。iPhoneでは約1.08倍のptになる）
const MIN_TAP := Vector2(40, 40)
const DAYS_TO_RUN := 2
const TEST_SAVE_PATH := "user://save_smoke_test.json"

var _main: Node
var _days_done: int = 0
var _cooldown: float = 0.0
var _made_mistake: bool = false
var _return_tested: bool = false
## 準備画面で時間のかかる確認（長押し）をしている間は、次の操作をしない
var _busy: bool = false
## 2日目の準備を一度だけ行う
var _day2_prep_started: bool = false
var _upgrade_done: bool = false
var _equipment_checked: bool = false
var _last_screen: String = ""
var _failures: PackedStringArray = PackedStringArray()
## 本物のセーブがテストの前後で変わっていないか確かめるため
var _real_save_before: String = ""
## 営業画面の最後に見た残り時間（売り切れで早く終わったかの確認用）
var _last_time_left: float = 0.0
## 1日目の仕込み数と置き場（2日目の「前回と同じ仕込み」の確認用）
var _day1_prep: Dictionary = {}
var _day1_shelf: Array[String] = []
## 1日目の集計（2日目の売り逃しに1日目の分が入っていないかの確認用）
var _day1_stats: DayStats = null


const GROUPS: PackedStringArray = ["save", "rules", "layout", "topping", "shift", "kitchen", "days"]
## まとめて指定できる名前
const GROUP_ALIASES: Dictionary = { "staff": ["topping", "shift", "kitchen"] }

## 実行するまとまり
var _groups: PackedStringArray = GROUPS
## まとまりごとの開始時刻（実時間の ms。かかった時間を出す）
var _group_started: int = 0
var _days_started: int = 0


func _ready() -> void:
	_real_save_before = _read_real_save()
	_groups = _parse_groups()
	if not OS.get_cmdline_args().has("--fixed-fps"):
		print("[smoke] ヒント: --fixed-fps 60 を付けると、実時間を待たずに速く終わります")
	print("[smoke] groups: ", ",".join(_groups))
	# 前回のテストが途中で止まって残ったファイルがあれば消してから始める
	GameState.use_save_path(TEST_SAVE_PATH)
	GameState.delete_save()
	if _wants("save"):
		_begin_group()
		_check_migration()
		_end_group("save")
	GameState.delete_save()
	GameState.use_save_path(TEST_SAVE_PATH)
	if _wants("rules"):
		_begin_group()
		_check_rules()
		_check_unlock_schedule()
		_check_regulars()
		_check_missed_per_day()
		_end_group("rules")
	if _wants("layout"):
		_begin_group()
		await _check_seat_layouts()
		_end_group("layout")
	if _wants("topping"):
		_begin_group()
		var topping_staff: ToppingStaffChecks = ToppingStaffChecks.new()
		add_child(topping_staff)
		await topping_staff.run(_check)
		_check("トッピングと従業員の確認が最後まで進んだ（途中でエラーが出ていない）", topping_staff.completed)
		topping_staff.queue_free()
		_end_group("topping")
	if _wants("shift"):
		_begin_group()
		var staff_shift: StaffShiftChecks = StaffShiftChecks.new()
		add_child(staff_shift)
		await staff_shift.run(_check)
		_check("スタッフの出勤・在籍日数・研修の確認が最後まで進んだ（途中でエラーが出ていない）", staff_shift.completed)
		staff_shift.queue_free()
		_end_group("shift")
	if _wants("kitchen"):
		_begin_group()
		var kitchen_staff: KitchenStaffChecks = KitchenStaffChecks.new()
		add_child(kitchen_staff)
		await kitchen_staff.run(_check)
		_check("厨房スタッフの確認が最後まで進んだ（途中でエラーが出ていない）", kitchen_staff.completed)
		kitchen_staff.queue_free()
		_end_group("kitchen")
	if not _wants("days"):
		_finish()
		return
	# 画面で2日分まわす（ここから先は _process で進め、最後に _finish を呼ぶ）
	GameState.use_save_path(TEST_SAVE_PATH)
	GameState.delete_save()
	GameState.use_save_path(TEST_SAVE_PATH)
	_days_started = Time.get_ticks_msec()
	Engine.time_scale = 8.0
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	print("[smoke] start money=%d day=%d rep=%d inv=%s" % [GameState.money, GameState.day, GameState.reputation, GameState.inventory])


## --only=a,b を読む（staff は topping・shift・kitchen）。知らない名前があれば知らせて、全部を実行する
func _parse_groups() -> PackedStringArray:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--only="):
			continue
		var result: PackedStringArray = PackedStringArray()
		for raw: String in arg.trim_prefix("--only=").split(",", false):
			var name: String = raw.strip_edges()
			var names: Array = GROUP_ALIASES.get(name, [name])
			for n: String in names:
				if not GROUPS.has(n):
					push_error("[smoke] 知らないまとまり: %s（%s・staff）" % [n, ",".join(GROUPS)])
					return GROUPS
				if not result.has(n):
					result.append(n)
		return result
	return GROUPS


func _wants(group: String) -> bool:
	return _groups.has(group)


func _begin_group() -> void:
	_group_started = Time.get_ticks_msec()


func _end_group(group: String) -> void:
	print("[smoke] time %s: %dms" % [group, Time.get_ticks_msec() - _group_started])


func _check(name: String, ok: bool, detail: String = "") -> void:
	print("[check] %s %s %s" % ["OK  " if ok else "FAIL", name, detail])
	if not ok:
		_failures.append(name)


func _process(delta: float) -> void:
	if _main == null or _main.get_child_count() == 0:
		return
	var screen: Node = _main.get_child(_main.get_child_count() - 1)
	if screen.name != _last_screen:
		_last_screen = screen.name
		_cooldown = 0.5
		print("[smoke] screen: ", screen.name)
		if String(screen.name) == "Business" and _days_done == 1 and _day1_stats != null:
			_check("2日目の営業は、売り逃しが0から始まる（1日目の集計とは別）",
				GameState.today != _day1_stats and GameState.today.dish_missed.is_empty(),
				"missed=%s" % [GameState.today.dish_missed])
	if String(screen.name) == "Business":
		_last_time_left = float(screen.get("_time_left"))
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = 0.25
	match String(screen.name):
		"PrepScreen":
			_do_prep(screen)
		"Business":
			_do_business(screen)
		"ResultScreen":
			_do_result(screen)
		"UpgradeScreen":
			_do_upgrade(screen)


# ---------------------------------------------------------------
# 画面を使わないルールの確認
# ---------------------------------------------------------------

func _check_rules() -> void:
	var cfg: GameConfig = Database.config
	# 仕入れ予定は確定するまでお金も在庫も変わらない。0未満にならない
	var money_before: int = GameState.money
	var rice_before: int = GameState.get_stock("rice")
	GameState.change_purchase("rice", 5)
	GameState.change_purchase("chicken", 2)
	GameState.change_purchase("fish", -3)
	_check("仕入れ予定では所持金も在庫も変わらない",
		GameState.money == money_before and GameState.get_stock("rice") == rice_before
		and GameState.get_planned_purchase("fish") == 0,
		"money=%d plan=%s" % [GameState.money, GameState.purchase_plan])
	var total: int = GameState.get_purchase_total()
	GameState.confirm_purchase()
	_check("「仕入れる」で合計金額が引かれ在庫が増える",
		GameState.money == money_before - total and GameState.get_stock("rice") == rice_before + 5
		and not GameState.has_purchase_plan(), "total=%d money=%d" % [total, GameState.money])
	# 所持金が足りなくても仕入れられ、所持金はマイナスになる（赤い表示）
	var before_negative: int = GameState.money
	GameState.change_purchase("fish", 1000)
	var big_total: int = GameState.get_purchase_total()
	var warned: bool = not GameState.can_afford_purchase() and GameState.get_money_after_purchase() < 0
	_check("所持金が足りなくても仕入れられ、所持金がマイナスになる（表示は赤）",
		warned and GameState.confirm_purchase() and GameState.money == before_negative - big_total and GameState.money < 0
		and UIText.money(GameState.money).begins_with("-¥") and UIText.money_color(GameState.money) == UIText.COLOR_NEGATIVE_MONEY,
		"money=%s" % UIText.money(GameState.money))
	GameState.add_money(before_negative - GameState.money)

	# 仕込み数の上限は99だけ（在庫では止まらない）。足りない食材は料理ごとにわかる
	var karaage: DishData = Database.get_dish("karaage")
	GameState.change_prep("karaage", 150)
	_check("仕込み数の上限は99だけ（在庫では止まらない）",
		GameState.get_prep_count("karaage") == cfg.max_prep_per_dish and not GameState.can_add_prep(karaage)
		and GameState.get_dish_shortage(karaage).has("chicken"),
		"prep=%d shortage=%s" % [GameState.get_prep_count("karaage"), GameState.get_dish_shortage(karaage)])
	# 不足分を予定に入れる → 確定すると足りる
	GameState.plan_prep_shortage()
	var covered: bool = true
	var shortage: Dictionary = GameState.get_prep_shortage()
	for ing_id: String in shortage:
		if GameState.get_planned_purchase(ing_id) < int(shortage[ing_id]):
			covered = false
	_check("「不足分を予定に入れる」で、足りない分が仕入れ予定に入る", covered and not shortage.is_empty(),
		"shortage=%s plan=%s" % [shortage, GameState.purchase_plan])
	GameState.add_money(100000)
	GameState.confirm_purchase()
	_check("予定どおり仕入れると不足がなくなる", not GameState.has_prep_shortage())
	# 在庫に合わせて減らす
	GameState.change_prep("yakizakana", 50)
	var fish_stock: int = GameState.get_stock("fish")
	GameState.reduce_prep_to_stock()
	# 一覧の下の料理から減らす（米も足りないので、焼き魚から先に減る）
	_check("「在庫に合わせて減らす」で、作れる数まで仕込み数が減る（一覧の下の料理から）",
		not GameState.has_prep_shortage() and GameState.get_prep_count("yakizakana") <= fish_stock
		and GameState.get_prep_count("karaage") == cfg.max_prep_per_dish,
		"yakizakana=%d fish=%d" % [GameState.get_prep_count("yakizakana"), fish_stock])

	# 開店時の置き場は合計6個まで、仕込み数を超えない
	GameState.change_prep("karaage", -999)
	GameState.change_prep("yakizakana", -999)
	GameState.change_prep("karaage", 2)
	for i: int in 4:
		GameState.add_to_shelf_plan("karaage")
	GameState.change_prep("yakizakana", 10)
	for i: int in 10:
		GameState.add_to_shelf_plan("yakizakana")
	_check("開店時の置き場は仕込み数を超えず、6枠まで",
		GameState.get_shelf_plan_count("karaage") == 2 and GameState.shelf_plan.size() == cfg.shelf_capacity,
		"plan=%s" % [GameState.shelf_plan])
	GameState.change_prep("yakizakana", -9)
	_check("仕込み数を減らすと置き場の初期配置も減る", GameState.get_shelf_plan_count("yakizakana") == 1, "plan=%s" % [GameState.shelf_plan])

	# 料理の解放
	var unlocked_ings: Array[IngredientData] = GameState.get_unlocked_ingredients()
	var has_egg: bool = false
	var has_onion: bool = false
	for ing: IngredientData in unlocked_ings:
		if ing.id == "egg":
			has_egg = true
		if ing.id == "onion":
			has_onion = true
	var first_toppings: Array[DishData] = GameState.get_unlocked_toppings()
	_check("最初は料理3品とトッピングの卵焼きだけ解放され、親子丼は仕込めず、仕入れ画面に卵は出て玉ねぎは出ない",
		GameState.get_unlocked_dishes().size() == 3 and first_toppings.size() == 1 and first_toppings[0].id == "tamagoyaki"
		and GameState.change_prep("oyakodon", 1) == 0 and has_egg and not has_onion)
	# 評判の計算: 客ごとの点数をその日の分だけ足し、営業結果のときに「点数 × ランクの倍率」で反映する
	GameState.today = DayStats.new()
	for i: int in 10:
		GameState.record_served("karaage", Satisfaction.Level.GREAT)
	var rep_before: int = GameState.reputation
	_check("営業中は評判が変わらない（営業結果のときにまとめて反映）", GameState.reputation == rep_before)
	GameState.finish_business()
	var expected_gain: int = roundi(10.0 * cfg.reputation_great * Database.ranks[0].reputation_gain_scale)
	_check("上手な日は「点数 × ランクの倍率」だけ評判が上がる",
		GameState.today.reputation_change == expected_gain and GameState.reputation == rep_before + expected_gain,
		"change=%d expected=%d" % [GameState.today.reputation_change, expected_gain])
	GameState.today = DayStats.new()
	GameState.record_served("karaage", Satisfaction.Level.GREAT)
	GameState.record_served("karaage", Satisfaction.Level.GREAT)
	for i: int in 3:
		GameState.record_angry()
	GameState.record_missed("karaage", 5)
	GameState.finish_business()
	_check("無名店では、怒って帰る客や売り逃しが多い日も評判は下がらない（常連さんの分に置き換わる。人気店からは少し下がる）",
		GameState.today.reputation_change >= 0 and GameState.today.reputation_change <= 1 and GameState.today.regular_applied
		and Database.get_reputation_delta(GameState.get_day_reputation_points(), 3) < 0,
		"change=%d" % GameState.today.reputation_change)

	# 店舗ランクと料理の解放
	_check("最初は「無名店」（ランク1）", GameState.rank == 1 and GameState.get_rank_name() == Database.get_rank_name(1))
	GameState.today = DayStats.new()
	GameState.add_reputation(Database.get_rank_threshold(2) - GameState.reputation)
	GameState.finish_business()
	_check("評判がしきい値に届くと、営業結果のあとにランクが上がり、そのランクの料理が解放される",
		GameState.rank == 2 and GameState.today.rank_up == 2 and GameState.is_unlocked("oyakodon")
		and GameState.today.new_unlocks.has("oyakodon") and not GameState.is_unlocked("yasaiitame"),
		"rank=%d unlocked=%s new=%s" % [GameState.rank, GameState.unlocked_dishes, GameState.today.new_unlocks])
	_check("ランクの進み具合（次のランクまで）は0〜1", GameState.get_rank_progress() >= 0.0 and GameState.get_rank_progress() < 1.0)
	GameState.add_reputation(-1000)
	GameState.today = DayStats.new()
	GameState.finish_business()
	GameState.save_game()
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("評判が下がっても、ランクと解放済みの料理はそのまま（セーブにも残る）",
		GameState.reputation == 0 and GameState.rank == 2 and GameState.is_unlocked("oyakodon")
		and GameState.change_prep("oyakodon", 1) == 1,
		"rep=%d rank=%d unlocked=%s" % [GameState.reputation, GameState.rank, GameState.unlocked_dishes])

	# カレンダー: 1日目は2027/1/1（金）、水曜日は定休日で飛ばす、年またぎ・うるう年
	var d1: Dictionary = GameCalendar.date_for_business_day(1)
	var d5: Dictionary = GameCalendar.date_for_business_day(5)
	var d6: Dictionary = GameCalendar.date_for_business_day(6)
	_check("1日目は2027/1/1（金）、5日目は1/5（火）、6日目は水曜を飛ばして1/7（木）",
		GameCalendar.format_date(d1) == "2027/1/1（金）" and GameCalendar.format_date(d5) == "2027/1/5（火）"
		and GameCalendar.format_date(d6) == "2027/1/7（木）" and GameCalendar.is_holiday_next(5) and not GameCalendar.is_holiday_next(6),
		"%s %s %s" % [GameCalendar.format_date(d1), GameCalendar.format_date(d5), GameCalendar.format_date(d6)])
	var round_trip_ok: bool = true
	var no_wednesday: bool = true
	for n: int in range(1, 900):
		var offset: int = GameCalendar.offset_for_business_day(n)
		if GameCalendar.business_day_for_offset(offset) != n:
			round_trip_ok = false
		if int(GameCalendar.date_for_offset(offset)["weekday"]) == GameCalendar.HOLIDAY_WEEKDAY:
			no_wednesday = false
	_check("営業日と日付の変換が往復で一致し、営業日に水曜日がない（900日分）", round_trip_ok and no_wednesday)
	var new_year: int = GameCalendar.business_day_for_offset(GameCalendar.offset_for_date(2028, 1, 1))
	var leap_offset: int = GameCalendar.offset_for_date(2028, 2, 29)
	var leap_date: Dictionary = GameCalendar.date_for_offset(leap_offset)
	_check("年をまたいでも、うるう年（2028/2/29）でも日付が正しく進む",
		GameCalendar.format_date(GameCalendar.date_for_business_day(new_year)) == "2028/1/1（土）"
		and int(leap_date["month"]) == 2 and int(leap_date["day"]) == 29
		and GameCalendar.days_in_month(2028, 2) == 29 and GameCalendar.days_in_month(2027, 2) == 28
		and int(GameCalendar.date_for_offset(leap_offset + 1)["month"]) == 3,
		"new_year_day=%d %s" % [new_year, GameCalendar.format_date(GameCalendar.date_for_business_day(new_year))])
	_check("カレンダーの利益の表示（色・短い書き方）",
		CalendarPopup.short_profit(12300) == "+12,300" and CalendarPopup.short_profit(-4500) == "-4,500"
		and CalendarPopup.short_profit(123456) == "+12.3万" and CalendarPopup.short_profit(0) == "0"
		and CalendarPopup.profit_color(100) == CalendarPopup.COLOR_PLUS and CalendarPopup.profit_color(-1) == CalendarPopup.COLOR_MINUS
		and CalendarPopup.profit_color(0) == CalendarPopup.COLOR_ZERO
		and String(CalendarPopup.describe_offset(GameCalendar.offset_for_date(2027, 1, 6))["kind"]) == "holiday")

	# 料理の解放条件に営業日数（○日目以降）
	var oyako_dish: DishData = Database.get_dish("oyakodon")
	var old_unlock_day: int = oyako_dish.unlock_day
	oyako_dish.unlock_day = 30
	GameState.unlocked_dishes.erase("oyakodon")
	GameState.call("_unlock_by_rank", 29)
	var locked_by_day: bool = not GameState.is_unlocked("oyakodon")
	GameState.call("_unlock_by_rank", 30)
	_check("料理の解放は「ランク」と「営業日数」の両方で決まる（ランク2でも30日目までは解放しない）",
		locked_by_day and GameState.is_unlocked("oyakodon") and PrepMenuStep.locked_text(oyako_dish).contains("30日目"))
	oyako_dish.unlock_day = old_unlock_day

	# 設備: 所持金不足・ランク不足・購入と効果（席数・枠数・調理時間）
	var money_now: int = GameState.money
	GameState.add_money(-money_now)
	_check("所持金が足りない設備は買えない", GameState.get_buy_block("seats") == GameState.BuyBlock.MONEY and not GameState.buy_equipment("seats"))
	GameState.add_money(1000000)
	var karaage_dish: DishData = Database.get_dish("karaage")
	var table_before: int = GameState.get_seat_count()
	var shelf_before: int = GameState.get_shelf_capacity()
	var cook_before: float = GameState.get_cook_time(karaage_dish)
	var money_before_buy: int = GameState.money
	var bought: bool = GameState.buy_equipment("seats") and GameState.buy_equipment("shelf") and GameState.buy_equipment("fryer")
	_check("設備を買うと、お金が減り、席数・置き場の枠・調理時間に効果が出る",
		bought and GameState.get_seat_count() == 6 and table_before == 4 and GameState.get_shelf_capacity() == shelf_before + 1
		and is_equal_approx(GameState.get_cook_time(karaage_dish), cook_before * Database.get_equipment("fryer").get_value(1))
		and is_equal_approx(GameState.get_cook_time(Database.get_dish("yakizakana")), Database.get_dish("yakizakana").cook_time)
		and GameState.money < money_before_buy,
		"tables %d->%d shelf %d->%d karaage %.2f->%.2f" % [table_before, GameState.get_seat_count(), shelf_before,
			GameState.get_shelf_capacity(), cook_before, GameState.get_cook_time(karaage_dish)])
	var saved_rank: int = GameState.rank
	GameState.rank = 1
	_check("必要なランクに届かない設備は買えない（テーブルの2つ目の追加は知る人ぞ知る店から）",
		GameState.get_buy_block("seats") == GameState.BuyBlock.RANK and not GameState.buy_equipment("seats"))
	GameState.rank = saved_rank
	GameState.equipment_levels.clear()

	# 履歴: 営業結果で1行増え、セーブして読み直しても残る
	GameState.today = DayStats.new()
	GameState.record_served("karaage", Satisfaction.Level.GREAT)
	GameState.record_payment("karaage", 980)
	GameState.finish_business()
	var row: PackedInt32Array = GameState.get_history(GameState.day)
	GameState.save_game()
	GameState.use_save_path(TEST_SAVE_PATH)
	var row2: PackedInt32Array = GameState.get_history(GameState.day)
	_check("日ごとの結果が履歴に残り、セーブして読み直しても同じ",
		not row.is_empty() and row[GameState.HISTORY_SALES] == 980 and row == row2,
		"row=%s row2=%s" % [row, row2])

	# 営業中の数の管理（DishSupply）
	var supply: DishSupply = DishSupply.new({"karaage": 3}, ["karaage"] as Array[String])
	supply.take_for_cooking("karaage")
	supply.reserve("karaage")
	supply.reserve("karaage")
	supply.reserve("karaage")
	_check("確保済みの料理は注文できない", supply.get_orderable("karaage") == 0 and not supply.reserve("karaage"))
	supply.return_to_remaining("karaage")
	_check("置き場から戻すと残りが1増える", supply.get_remaining("karaage") == 2)
	supply.serve("karaage")
	supply.release("karaage")
	_check("出した分は出せる数から引かれ、帰った客の確保は戻る", supply.get_units("karaage") == 2 and supply.get_orderable("karaage") == 1)
	# 状態を作り直す（テスト用のセーブを消してから、新しいゲームにする）
	GameState.delete_save()


## 古いセーブ（version 1〜5）を読み込んで、今の version に移行できるか確かめる
func _check_migration() -> void:
	_write_test_save({"version": 1, "money": 4321, "day": 5, "reputation": 12, "inventory": {"rice": 7}})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v1 -> 最新（評判は今の範囲に換算）", GameState.money == 4321 and GameState.day == 5
		and GameState.reputation == roundi(12 * Database.config.legacy_reputation_scale)
		and GameState.get_stock("rice") == 7 and not GameState.has_last_prep() and GameState.last_shelf_plan.is_empty())
	_write_test_save({"version": 2, "money": 5000, "day": 3, "reputation": 5, "inventory": {"rice": 9},
		"last_prep": {"karaage": 2, "yakizakana": 1}})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v2 -> 最新（前回の仕込みを仕込み数と置き場の両方に）",
		GameState.get_stock("rice") == 9 and GameState.last_prep_counts == {"karaage": 2, "yakizakana": 1}
		and GameState.last_shelf_plan == (["karaage", "karaage", "yakizakana"] as Array[String]),
		"prep=%s shelf=%s" % [GameState.last_prep_counts, GameState.last_shelf_plan])
	_write_test_save({"version": 3, "money": 6000, "day": 4, "reputation": 8, "inventory": {"rice": 3},
		"last_prep": {"karaage": 1}, "last_shelf": ["karaage"]})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v3 -> 最新（前回売れた数は空）", GameState.money == 6000 and GameState.last_shelf_plan.size() == 1
		and GameState.last_sold_counts.is_empty() and GameState.get_last_sold("karaage") == -1)
	_write_test_save({"version": 4, "money": 7000, "day": 6, "reputation": 9,
		"inventory": {"rice": 4, "chicken": 2, "fish": 1, "pork": 0, "cabbage": 5},
		"last_prep": {"karaage": 1}, "last_shelf": [], "last_sold": {"karaage": 1}})
	GameState.use_save_path(TEST_SAVE_PATH)
	var cfg: GameConfig = Database.config
	_check("セーブ移行 v4 -> 最新（新しい食材に初期在庫が入り、既存の在庫はそのまま）",
		GameState.get_stock("egg") == int(cfg.start_inventory.get("egg", 0)) and GameState.get_stock("egg") > 0
		and GameState.get_stock("onion") == int(cfg.start_inventory.get("onion", 0))
		and GameState.get_stock("pork") == 0 and GameState.get_stock("rice") == 4
		and GameState.get_last_sold("karaage") == 1 and GameState.last_missed_counts.is_empty(),
		"egg=%d onion=%d" % [GameState.get_stock("egg"), GameState.get_stock("onion")])
	_write_test_save({"version": 5, "money": 8000, "day": 7, "reputation": 70,
		"inventory": {"rice": 4}, "last_prep": {}, "last_shelf": [], "last_sold": {}, "last_missed": {}})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v5 -> 最新（評判を換算し、そのランクで解放する）",
		GameState.reputation == roundi(70 * cfg.legacy_reputation_scale) and GameState.rank == Database.get_rank_for_reputation(GameState.reputation)
		and GameState.is_unlocked("karaage") and GameState.is_unlocked("oyakodon"),
		"rep=%d rank=%d unlocked=%s" % [GameState.reputation, GameState.rank, GameState.unlocked_dishes])
	_write_test_save({"version": 6, "money": 9000, "day": 8, "reputation": 20,
		"inventory": {"rice": 4}, "last_prep": {}, "last_shelf": [], "last_sold": {}, "last_missed": {},
		"unlocked": ["karaage", "yakizakana", "shogayaki", "oyakodon"]})
	GameState.use_save_path(TEST_SAVE_PATH)
	_write_test_save({"version": 8, "money": 9000, "day": 9, "reputation": 40,
		"inventory": {"rice": 4}, "last_prep": {}, "last_shelf": [], "last_sold": {}, "last_missed": {},
		"unlocked": ["karaage", "yakizakana", "shogayaki"], "rank": 2, "history": [], "equipment": {"tables": 4, "fryer": 1}})
	GameState.use_save_path(TEST_SAVE_PATH)
	var converted_8: int = GameState.get_equipment_level("seats")
	_write_test_save({"version": 8, "money": 9000, "day": 9, "reputation": 40,
		"inventory": {"rice": 4}, "unlocked": [], "rank": 2, "history": [], "equipment": {"tables": 3}})
	GameState.use_save_path(TEST_SAVE_PATH)
	var converted_7: int = GameState.get_equipment_level("seats")
	_write_test_save({"version": 9, "money": 9000, "day": 50, "reputation": 40,
		"inventory": {"rice": 4}, "unlocked": ["karaage", "yakizakana", "shogayaki", "oyakodon"], "rank": 2,
		"history": [], "equipment": {"seats": 1}})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v9 -> v10（従業員なしで始まり、トッピングは日数とランクで解放される。席の拡張はそのまま）",
		GameState.hired_staff.is_empty() and GameState.is_unlocked("tamagoyaki") and GameState.is_unlocked("potato_salad")
		and not GameState.is_unlocked("karaage_extra") and GameState.get_equipment_level("seats") == 1 and GameState.is_unlocked("oyakodon"),
		"unlocked=%s" % [GameState.unlocked_dishes])
	_write_test_save({"version": 10, "money": 9000, "day": 50, "reputation": 40,
		"inventory": {"rice": 4}, "unlocked": ["karaage"], "rank": 2, "history": [], "equipment": {}, "staff": ["sato"]})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v10 -> v11（常連さんの小数の持ち越しは 0 から。評判と従業員はそのまま）",
		GameState.reputation == 40 and is_zero_approx(GameState.reputation_progress) and GameState.is_hired("sato"))
	_write_test_save({"version": 11, "money": 9000, "day": 4, "reputation": 10, "inventory": {"rice": 4}, "unlocked": [],
		"rank": 1, "equipment": {}, "staff": [], "reputation_progress": 0.5,
		"history": [[1, 5000, 1000, 8, 40, 2], [2, 6000, 1500, 9, -1, 1], [3, 4000, -500, 7, 30, 0]]})
	GameState.use_save_path(TEST_SAVE_PATH)
	var old_rows_ok: bool = GameState.history.size() == 3
	for row: PackedInt32Array in GameState.history:
		if row.size() != GameState.HISTORY_SIZE or GameState.has_history_money(row):
			old_rows_ok = false
	var probe: RecordsChart = RecordsChart.new()
	probe.set_rows(GameState.history)
	probe.free()
	_check("セーブ移行 v11 -> v12（履歴の売上などはそのまま、所持金は「記録なし」。グラフは所持金の線を描かない）",
		old_rows_ok and GameState.get_history(2)[GameState.HISTORY_SALES] == 6000 and is_equal_approx(GameState.reputation_progress, 0.5))
	_write_test_save({"version": 13, "money": 9000, "day": 20, "reputation": 40, "inventory": {"rice": 4}, "unlocked": [],
		"rank": 2, "equipment": {}, "staff": ["sato", "suzuki"], "history": [],
		"staff_states": {"sato": {"mood": 12.0, "streak": 5, "bench": 0, "reasons": {"streak": 9.0}, "last_shift": false, "absent_day": 0}}})
	GameState.use_save_path(TEST_SAVE_PATH)
	var sato_state: Dictionary = GameState.get_staff_state("sato")
	_check("セーブ移行 v13 -> v14（今いるスタッフは移行した日から在籍日数を数え、Lv1。満足度は捨てる。出勤は前回のまま）",
		GameState.is_hired("sato") and GameState.is_hired("suzuki") and int(sato_state.get("enrolled", -1)) == 0
		and not sato_state.has("mood") and GameState.get_staff_level("sato") == 1
		and GameState.get_staff_days_left("sato") == Database.get_staff("sato").tenure_days
		and not GameState.is_on_shift("sato") and GameState.is_on_shift("suzuki"), "state=%s" % [sato_state])
	_write_test_save({"version": 14, "money": 9000, "day": 20, "reputation": 40, "inventory": {"rice": 4}, "unlocked": [],
		"rank": 2, "equipment": {}, "staff": ["sato"], "history": [], "staff_levels": {"sato": 2}, "staff_rehire_day": {},
		"staff_states": {"sato": {"enrolled": 5, "last_shift": true, "absent_day": 0}}})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v14 -> v15（今いるスタッフの担当はホール。在籍日数とレベルはそのまま）",
		GameState.is_hired("sato") and GameState.get_staff_role("sato") == GameState.ROLE_HALL and GameState.get_kitchen_staff() == null
		and str(GameState.get_staff_state("sato").get("last_role")) == GameState.ROLE_HALL
		and int(GameState.get_staff_state("sato").get("enrolled")) == 5 and GameState.get_staff_level("sato") == 2,
		"state=%s" % [GameState.get_staff_state("sato")])
	_check("セーブ移行 v8 -> v9（テーブル8卓→10席、7卓→6席。ほかの設備はそのまま）",
		converted_8 == 2 and converted_7 == 1, "8卓→Lv%d 7卓→Lv%d" % [converted_8, converted_7])
	_write_test_save({"version": 6, "money": 9000, "day": 8, "reputation": 20,
		"inventory": {"rice": 4}, "last_prep": {}, "last_shelf": [], "last_sold": {}, "last_missed": {},
		"unlocked": ["karaage", "yakizakana", "shogayaki", "oyakodon"]})
	GameState.use_save_path(TEST_SAVE_PATH)
	_check("セーブ移行 v6 -> v7（評判を換算してランクを決め、解放済みの料理はそのまま）",
		GameState.rank == 1 and GameState.reputation == roundi(20 * cfg.legacy_reputation_scale)
		and GameState.is_unlocked("oyakodon") and not GameState.is_unlocked("yasaiitame"),
		"rep=%d rank=%d unlocked=%s" % [GameState.reputation, GameState.rank, GameState.unlocked_dishes])


## 席の拡張（4→6→10→14→18席）: 席とテーブルの数、席の番号、タップの範囲が重ならず客席エリアに収まること、相席
func _check_seat_layouts() -> void:
	var expected_seats: Array[int] = [4, 6, 10, 14, 18]
	var expected_tables: Array[int] = [0, 0, 1, 2, 3]
	var e: EquipmentData = Database.get_equipment("seats")
	for level: int in expected_seats.size():
		GameState.equipment_levels["seats"] = level
		var count: int = GameState.get_seat_count()
		var dining: DiningArea = DINING_SCENE.instantiate() as DiningArea
		dining.size = DINING_SIZE_16X9
		add_child(dining)
		dining.size = DINING_SIZE_16X9
		dining.setup(count)
		await get_tree().process_frame
		var inside: bool = true
		var overlap: bool = false
		var min_size: Vector2 = Vector2(9999, 9999)
		var area: Rect2 = Rect2(Vector2.ZERO, dining.size)
		for i: int in dining.get_seat_count():
			var a: Rect2 = Rect2(dining.get_seat(i).position, dining.get_seat(i).size)
			min_size = Vector2(minf(min_size.x, a.size.x), minf(min_size.y, a.size.y))
			if not area.encloses(a):
				inside = false
			for j: int in range(i + 1, dining.get_seat_count()):
				var b: Rect2 = Rect2(dining.get_seat(j).position, dining.get_seat(j).size)
				if a.intersection(b).get_area() > 1.0:
					overlap = true
		var labels_ok: bool = dining.get_seat_label(0) == "C1" \
			and (count < 7 or dining.get_seat_label(6) == "T1-1") and (count < 18 or dining.get_seat_label(17) == "T3-4")
		_check("席の拡張 Lv%d: %d席・テーブル%d卓で、タップの範囲が重ならず収まる（最小 %dx%d）" % [level, count, dining.get_table_count(), int(min_size.x), int(min_size.y)],
			count == expected_seats[level] and dining.get_seat_count() == count and dining.get_table_count() == expected_tables[level]
			and inside and not overlap and labels_ok and min_size.x >= MIN_TAP.x and min_size.y >= MIN_TAP.y,
			"inside=%s overlap=%s labels=%s" % [inside, overlap, labels_ok])
		if count == 10:
			# 相席: テーブル1の4席は同じテーブル。3席に座っていても、4席目に次のお客さんが座れる
			var dummy: Customer = CUSTOMER_SCENE.instantiate() as Customer
			var target: int = -1
			for i: int in dining.get_seat_count():
				if dining.get_seat_label(i) == "T1-4":
					target = i
				else:
					dining.get_seat(i).occupant = dummy
			var same_table: bool = true
			for i: int in range(6, 10):
				if dining.get_seat(i).table_index != 0:
					same_table = false
			_check("相席: 同じテーブルの席に、別々のお客さんが座れる（空いている席は T1-4 だけ）",
				same_table and target >= 0 and dining.find_free_seat() == target)
			dummy.free()
		dining.queue_free()
		await get_tree().process_frame
	GameState.equipment_levels.clear()
	_check("「席の拡張」は 4→6→10→14→18席", e != null and e.get_max_level() == 4 and int(e.get_value(4)) == 18)


## 常連さん: 無名店・知る人ぞ知る店では、評判の増え方が少ない日（マイナスの日も）は常連さんの分（小数は持ち越し）に置き換わる。
## 人気店からは常連さんの分がなく、マイナスの日は少し下がる
func _check_regulars() -> void:
	GameState.use_save_path(TEST_SAVE_PATH)
	GameState.rank = 1
	GameState.reputation = 10
	GameState.reputation_progress = 0.0
	var regular: float = Database.get_regular_reputation(1)
	var steps: Array[int] = []
	for i: int in 4:
		GameState.today = DayStats.new()
		GameState.today.reputation_points = -10.0
		GameState.finish_business()
		steps.append(GameState.reputation)
	var expected: int = 10 + floori(regular * 4.0 + 0.0001)
	_check("常連さん: 無名店では悪い日でも評判が下がらず、1日 %.2f ずつ育つ（4日で %d → %d）" % [regular, 10, GameState.reputation],
		regular > 0.0 and steps[0] >= 10 and GameState.reputation == expected and GameState.today.regular_applied,
		"steps=%s progress=%.2f" % [steps, GameState.reputation_progress])
	GameState.today = DayStats.new()
	GameState.today.reputation_points = 10.0
	var before_good: int = GameState.reputation
	GameState.finish_business()
	_check("常連さん: よい日はいつもどおり（点数 × 倍率）",
		GameState.reputation - before_good == Database.get_reputation_delta(10.0, 1) and not GameState.today.regular_applied)
	GameState.rank = 3
	GameState.reputation = 70
	GameState.today = DayStats.new()
	GameState.today.reputation_points = -10.0
	GameState.finish_business()
	_check("常連さん: 人気店からは常連さんの分がなく、マイナスの日は少し下がる",
		GameState.reputation == 70 + Database.get_reputation_delta(-10.0, 3) and GameState.reputation < 70)


## 売り逃しはその日の数: 2日目の集計・前回の売り逃し・評判の点数に1日目の分が入らない
func _check_missed_per_day() -> void:
	GameState.use_save_path(TEST_SAVE_PATH)
	# 前回の売り逃しは、その日に仕込んだ料理について覚える
	GameState.begin_business()
	GameState.today.dish_prepared = { "karaage": 1, "yakizakana": 1 }
	GameState.record_missed("karaage", 5)
	GameState.finish_business()
	var day1: int = GameState.get_last_missed("karaage")
	GameState.advance_day()
	GameState.begin_business()
	GameState.today.dish_prepared = { "karaage": 1, "yakizakana": 1 }
	var starts_empty: bool = GameState.today.dish_missed.is_empty()
	GameState.record_missed("karaage", 2)
	GameState.record_missed("yakizakana", 1)
	var points: float = GameState.get_day_reputation_points()
	GameState.finish_business()
	_check("売り逃しはその日の数（2日目は1日目の分を含まない。前回の売り逃し・評判の点数も2日目の数）",
		day1 == 5 and starts_empty and int(GameState.today.dish_missed.get("karaage", 0)) == 2
		and GameState.get_last_missed("karaage") == 2 and GameState.get_last_missed("yakizakana") == 1
		and is_equal_approx(points, 3.0 * Database.config.reputation_missed),
		"day2=%s" % [GameState.today.dish_missed])
	GameState.delete_save()


## 料理の解放日: 新しい20品が15〜340日目に順に散らばり、店主のおまかせ定食が最後（1年目の最後のほう）
func _check_unlock_schedule() -> void:
	var days: Array[int] = []
	var last_id: String = ""
	var last_day: int = -1
	for dish: DishData in Database.dishes:
		if dish.unlock_day > 0:
			days.append(dish.unlock_day)
			if dish.unlock_day > last_day:
				last_day = dish.unlock_day
				last_id = dish.id
	days.sort()
	var max_gap: int = 0
	for i: int in range(1, days.size()):
		max_gap = maxi(max_gap, days[i] - days[i - 1])
	_check("料理の解放日が1年に散らばる（20品・%d〜%d日目・間隔は最大%d日・最後はおまかせ定食）" % [days.front(), days.back(), max_gap],
		days.size() == 20 and days.front() >= 10 and days.back() >= 300 and days.back() <= 365 and max_gap <= 45
		and last_id == "omakase")


func _write_test_save(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


# ---------------------------------------------------------------
# 準備画面（①仕込み → ②仕入れ → ③置き場）
# ---------------------------------------------------------------

func _do_prep(screen: Node) -> void:
	var dialog: ConfirmDialog = screen.get("_dialog")
	if dialog.is_open() or _busy:
		return
	if _days_done == 0:
		_do_prep_day1(screen, dialog)
	else:
		_do_prep_day2(screen, dialog)


func _step_of(screen: Node) -> int:
	return int(screen.call("get_step"))


## 1日目: 手順の行き来・食材不足で③に進めないこと・在庫に合わせて減らす。少なめに仕込んで売り切れで早く閉店させる
func _do_prep_day1(screen: Node, dialog: ConfirmDialog) -> void:
	var menu_step: PrepMenuStep = screen.get("_menu_step")
	var purchase_step: PrepPurchaseStep = screen.get("_purchase_step")
	_check("準備画面は①仕込みから始まる", _step_of(screen) == 0)
	_check("1日目は「前回と同じ仕込み」を押せない", (menu_step.get("_repeat_button") as Button).disabled)
	var menu_rows: Array[MenuRow] = menu_step.get("_menu_rows")
	var locked: Array[Label] = menu_step.get("_locked_labels")
	var dish_rows: int = 0
	var topping_rows: int = 0
	for row: MenuRow in menu_rows:
		if row.dish.is_topping():
			topping_rows += 1
		else:
			dish_rows += 1
	var topping_header: Label = menu_step.get("_topping_header")
	_check("①には解放済みの3品と次に解放される料理（3品）、区切りの下にトッピング（卵焼き）と次のトッピング（1品）が出る",
		dish_rows == 3 and topping_rows == 1 and menu_rows[3].dish.id == "tamagoyaki"
		and locked.size() == PrepMenuStep.LOCKED_PREVIEW_COUNT + PrepMenuStep.LOCKED_TOPPING_PREVIEW_COUNT
		and locked[0].text.contains(Database.get_rank_name(2) + "で解放") and topping_header != null
		and topping_header.get_parent().get_index() > menu_rows[2].get_index()
		and topping_header.get_parent().get_index() < menu_rows[3].get_index(),
		"rows=%d+%d locked=%d" % [dish_rows, topping_rows, locked.size()])
	GameState.change_prep("karaage", 2)
	GameState.change_prep("yakizakana", 1)
	GameState.change_prep("shogayaki", 1)

	# 手順を行き来しても入力が消えない
	(screen.get("_next_button") as Button).pressed.emit()
	var at_purchase: bool = _step_of(screen) == 1
	var ing_rows: Array[IngredientRow] = purchase_step.get("_ingredient_rows")
	(ing_rows[0].get("_plus_small") as Button).pressed.emit()
	var prep_snapshot: Dictionary = GameState.prep_counts.duplicate()
	var plan_snapshot: Dictionary = GameState.purchase_plan.duplicate()
	(screen.get("_back_button") as Button).pressed.emit()
	var back_ok: bool = _step_of(screen) == 0
	var step_buttons: Array[Button] = screen.get("_step_buttons")
	step_buttons[1].pressed.emit()
	_check("「次へ」「戻る」「手順の表示」で行き来しても、仕込み数と仕入れ予定が消えない",
		at_purchase and back_ok and _step_of(screen) == 1 and GameState.prep_counts == prep_snapshot
		and GameState.purchase_plan == plan_snapshot and not plan_snapshot.is_empty())
	_check("②には解放済みの料理・トッピングで使う食材だけが出る（卵焼きの卵は出て、玉ねぎは出ない）",
		ing_rows.size() == GameState.get_unlocked_ingredients().size() and ing_rows.size() == 6)
	GameState.clear_purchase_plan()

	# 食材が足りないと③へ進めない →「在庫に合わせて減らす」で進む
	GameState.change_prep("karaage", 3)
	var row_warn: Label = menu_rows[0].get("_warn_label")
	menu_step.refresh()
	_check("①の料理の行に「食材が足りません（○○ ○不足）」が出る", row_warn.visible and row_warn.text.contains("鶏肉"),
		row_warn.text)
	(screen.get("_next_button") as Button).pressed.emit()
	_check("食材が足りないと③へ進めず、確認が出る", _step_of(screen) == 1 and dialog.is_open())
	(dialog.get("_alt_button") as Button).pressed.emit()
	_check("「在庫に合わせて減らす」で仕込み数が減り、③へ進む",
		not GameState.has_prep_shortage() and _step_of(screen) == 2 and GameState.get_prep_count("karaage") == GameState.get_stock("chicken"),
		"karaage=%d chicken=%d step=%d" % [GameState.get_prep_count("karaage"), GameState.get_stock("chicken"), _step_of(screen)])

	GameState.add_to_shelf_plan("karaage")
	GameState.add_to_shelf_plan("yakizakana")
	_day1_prep = GameState.prep_counts.duplicate()
	_day1_shelf = GameState.shelf_plan.duplicate()
	var stock_before: Dictionary = GameState.inventory.duplicate()
	var reserved_rice: int = GameState.get_reserved("rice")
	print("[smoke] day1 prep=%s shelf=%s" % [_day1_prep, _day1_shelf])
	(screen.get("_start_button") as Button).pressed.emit()
	_check("営業開始で仕込み数の食材がまとめて引かれる",
		GameState.get_stock("rice") == int(stock_before["rice"]) - reserved_rice,
		"rice %d -> %d" % [int(stock_before["rice"]), GameState.get_stock("rice")])


## 2日目（5品すべて解放した状態）: 前回の表示・前回と同じ仕込み・本物の入力の操作・不足分を予定に入れる・確定式の仕入れ
func _do_prep_day2(screen: Node, dialog: ConfirmDialog) -> void:
	if _day2_prep_started:
		return
	_day2_prep_started = true
	var menu_step: PrepMenuStep = screen.get("_menu_step")
	var purchase_step: PrepPurchaseStep = screen.get("_purchase_step")
	var menu_rows: Array[MenuRow] = menu_step.get("_menu_rows")
	_check("解放した料理が①に出る（料理5品＋トッピング1品）", menu_rows.size() == 6, "rows=%d" % menu_rows.size())

	# 準備画面の各料理に「前回 ○食売れた」が出る（1日目は出ない）
	var last_ok: bool = true
	for row: MenuRow in menu_rows:
		var label: Label = row.get("_last_label")
		var sold: int = GameState.get_last_sold(row.dish.id)
		if not label.visible or (sold >= 0 and not label.text.contains("%d食売れた" % sold)) or label.text.contains("あと"):
			last_ok = false
		print("[smoke] %s: %s" % [row.dish.id, label.text])
	_check("2日目の準備画面に「前回 ○食売れた」が出る（売り逃しの「あと○食」は出さない）", last_ok and not GameState.last_sold_counts.is_empty())

	# 「記録」ボタンで通算の記録を出す。グラフの日を押すと、その日の日付と金額が出る
	var records: RecordsPopup = screen.get("_records")
	(screen.get("_records_button") as Button).pressed.emit()
	await _frames(2)
	var stats_grid: GridContainer = records.get("_stats_grid")
	var first_value: Label = stats_grid.get_child(0).get_child(1) as Label
	var chart: RecordsChart = records.get("_chart")
	var chart_point: Vector2 = chart.get_global_rect().position + Vector2(chart.size.x * 0.5, chart.size.y * 0.5)
	_send_press_at(chart_point, true)
	await _frames(2)
	_send_press_at(chart_point, false)
	var detail_text: String = (records.get("_detail_label") as Label).text
	var day1_row: PackedInt32Array = GameState.get_history(1)
	_check("「記録」で通算の記録が開き、営業日数が出て、グラフを押すとその日の日付・売上・所持金が出る",
		records.is_open() and first_value.text == UIText.REC_DAYS_VALUE % GameState.history.size()
		and detail_text.contains("1日目") and detail_text.contains(UIText.money(day1_row[GameState.HISTORY_SALES]))
		and detail_text.contains(UIText.money(day1_row[GameState.HISTORY_MONEY])), detail_text)
	(records.get("_close_button") as Button).pressed.emit()
	_check("記録の画面を閉じられる", not records.is_open())

	# 所持金がマイナスのときは、上部バーの所持金が赤
	var top_bar: TopBar = screen.get_node("SafeArea/VBox/TopBar")
	var money_keep: int = GameState.money
	GameState.add_money(-money_keep - 12300)
	var money_label: Label = top_bar.get("_money_label")
	var red: bool = money_label.text == "-¥12,300" and money_label.get_theme_color("font_color") == UIColors.TOPBAR_DANGER
	GameState.add_money(money_keep + 12300)
	_check("所持金がマイナスのとき、上部バーに「-¥12,300」と赤で出る（プラスに戻ると白）",
		red and money_label.get_theme_color("font_color") == UIColors.TOPBAR_TEXT, money_label.text)

	(menu_step.get("_repeat_button") as Button).pressed.emit()
	_check("「前回と同じ仕込み」で仕込み数と置き場が前回と同じになる",
		GameState.prep_counts == _day1_prep and GameState.shelf_plan == _day1_shelf,
		"prep=%s shelf=%s" % [GameState.prep_counts, GameState.shelf_plan])

	# 本物の押す・動かす・離す操作を送って、タップ・長押し・スクロールの区別を確かめる。
	# 時間で決まる操作なので、この間だけ早送りをやめる（早送りだと1フレームが長すぎて長押しの途中が飛ぶ）
	_busy = true
	Engine.time_scale = 1.0
	var plus: Button = menu_rows[1].get("_plus_button")
	var before_tap: int = GameState.get_prep_count("yakizakana")
	_send_press(plus, true)
	await _frames(2)
	_send_press(plus, false)
	await _frames(2)
	_check("「＋」をタップすると1つ増える", GameState.get_prep_count("yakizakana") == before_tap + 1,
		"%d -> %d" % [before_tap, GameState.get_prep_count("yakizakana")])

	var prep_before: int = GameState.get_prep_count("yakizakana")
	_send_press(plus, true)
	await get_tree().create_timer(2.0).timeout
	_send_press(plus, false)
	await _frames(2)
	var held_gain: int = GameState.get_prep_count("yakizakana") - prep_before
	_check("「＋」を長押しすると続けて増える（途中から5ずつ）", held_gain >= 10,
		"%d -> %d" % [prep_before, GameState.get_prep_count("yakizakana")])
	GameState.change_prep("yakizakana", -held_gain - 1)

	# 料理の行（ボタン以外）を長押しすると詳細が出て、離すと閉じる
	var detail: DetailPopup = screen.get("_detail")
	var row_point: Vector2 = (menu_rows[0].get("_name_label") as Label).get_global_rect().get_center()
	_send_press_at(row_point, true)
	await get_tree().create_timer(Database.config.long_press_time + 0.2).timeout
	var opened: bool = detail.is_open()
	var title: String = (detail.get("_title_label") as Label).text
	var body: String = (detail.get("_body_label") as Label).text
	_check("料理の詳細に、前回の仕込み数・売れた数は出て、売り逃しの数は出ない",
		body.contains("前回: 仕込み") and not body.contains("売り逃し"), body.replace("\n", " / "))
	_send_press_at(row_point, false)
	await _frames(2)
	_check("料理の行を長押しすると詳細が出て、離すと閉じる", opened and title == menu_rows[0].dish.display_name and not detail.is_open(),
		"opened=%s title=%s" % [opened, title])

	# 一覧の上で「＋」を押したまま指を動かすと、スクロールになって数は変わらない
	# （テストの画面では全部の行が入ることがあるので、説明の行を一時的に高くして一覧を短くする）
	var scroll: DragScrollContainer = menu_step.get_node("%MenuScroll")
	var help: Control = menu_step.get_node("%HelpLabel")
	var old_min: Vector2 = help.custom_minimum_size
	help.custom_minimum_size.y = 200.0
	await _frames(3)
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var can_scroll: bool = bar.max_value > bar.page + 0.5
	scroll.scroll_vertical = 0
	await _frames(1)
	var plus_first: Button = menu_rows[0].get("_plus_button")
	var first_before: int = GameState.get_prep_count(menu_rows[0].dish.id)
	var start: Vector2 = plus_first.get_global_rect().get_center()
	_send_press_at(start, true)
	for i: int in 4:
		await _frames(1)
		_send_motion_at(start + Vector2(0, -3.0 * (i + 1)))
	await _frames(1)
	_send_press_at(start + Vector2(0, -12.0), false)
	await _frames(2)
	var first_after: int = GameState.get_prep_count(menu_rows[0].dish.id)
	_check("指が動いたらボタンの押下を取り消してスクロールにする",
		can_scroll and first_after == first_before and scroll.scroll_vertical > 0,
		"can_scroll=%s scroll=%d prep %d -> %d" % [can_scroll, scroll.scroll_vertical, first_before, first_after])
	scroll.scroll_vertical = 0
	await _frames(1)
	start = plus_first.get_global_rect().get_center()
	_send_press_at(start, true)
	await _frames(2)
	_send_press_at(start, false)
	await _frames(2)
	_check("スクロールのあとも、タップはふつうに効く", GameState.get_prep_count(menu_rows[0].dish.id) == first_before + 1)
	help.custom_minimum_size = old_min
	await _frames(2)

	# 多めに仕込んで（すべての料理）、残った分が廃棄になるようにする
	for dish: DishData in GameState.get_unlocked_dishes():
		GameState.change_prep(dish.id, 5)
	print("[smoke] day2 prep=%s shelf=%s prep_shortage=%s" % [GameState.prep_counts, GameState.shelf_plan, GameState.get_prep_shortage()])
	_check("2日目は解放済みの料理%d品をすべて仕込める（データは料理%d品・食材%d種類）" % [
		GameState.get_unlocked_dishes().size(), Database.dishes.size(), Database.ingredients.size()],
		GameState.prep_counts.size() == GameState.get_unlocked_dishes().size() and GameState.prep_counts.size() == 5
		and Database.dishes.size() == 25 and Database.ingredients.size() == 13)

	# ②仕入れ: 画面のボタンで予定を作る（まだお金は減らない）→ 不足分を予定に入れる → 確認して確定
	(screen.get("_next_button") as Button).pressed.emit()
	await _frames(3)
	var ing_rows: Array[IngredientRow] = purchase_step.get("_ingredient_rows")
	_check("②には解放した料理の食材（卵・玉ねぎも）が出る", ing_rows.size() == 7, "rows=%d" % ing_rows.size())
	var money_before: int = GameState.money
	(ing_rows[0].get("_plus_large") as Button).pressed.emit()
	_check("確定前の仕入れでは所持金が減らない", GameState.money == money_before and GameState.get_purchase_total() > 0)
	(purchase_step.get("_plan_button") as Button).pressed.emit()
	var shortage: Dictionary = GameState.get_prep_shortage()
	var covered: bool = true
	for ing_id: String in shortage:
		if GameState.get_planned_purchase(ing_id) < int(shortage[ing_id]):
			covered = false
	_check("「不足分を予定に入れる」ボタンで、①の仕込みに足りない分が予定に入る", covered and not shortage.is_empty(),
		"shortage=%s plan=%s" % [shortage, GameState.purchase_plan])
	# 食材の行を長押しすると詳細が出る
	_busy = true
	var ing_point: Vector2 = (ing_rows[1].get("_name_label") as Label).get_global_rect().get_center()
	_send_press_at(ing_point, true)
	await get_tree().create_timer(Database.config.long_press_time + 0.2).timeout
	var ing_opened: bool = detail.is_open() and (detail.get("_body_label") as Label).text.contains(UIText.DETAIL_ING_USED_BY)
	_send_press_at(ing_point, false)
	await _frames(2)
	_check("食材の行を長押しすると詳細（使う料理など）が出る", ing_opened)
	Engine.time_scale = 8.0
	_busy = false

	var total: int = GameState.get_purchase_total()
	(screen.get("_purchase_button") as Button).pressed.emit()
	_check("「仕入れる」で確認が出る", dialog.is_open())
	(dialog.get("_ok_button") as Button).pressed.emit()
	_check("確認して仕入れると所持金が減り、不足がなくなる",
		GameState.money == money_before - total and not GameState.has_purchase_plan() and not GameState.has_prep_shortage(),
		"money %d -> %d (total %d)" % [money_before, GameState.money, total])
	(screen.get("_next_button") as Button).pressed.emit()
	_check("食材が足りていれば③へ進める", _step_of(screen) == 2 and not dialog.is_open())

	# 仕入れ予定を残したまま営業開始 → 確認 →「仕入れずに開始」（予定は捨てる。お金は減らない）
	GameState.change_purchase("rice", 1)
	var money_at_start: int = GameState.money
	(screen.get("_start_button") as Button).pressed.emit()
	_check("仕入れ予定が残っていると営業開始の前に確認が出る", dialog.is_open())
	(dialog.get("_ok_button") as Button).pressed.emit()
	_check("「仕入れずに開始」では予定を捨て、所持金は減らない",
		GameState.money == money_at_start and not GameState.has_purchase_plan())


# ---------------------------------------------------------------
# 営業画面
# ---------------------------------------------------------------

func _do_business(screen: Node) -> void:
	var shelf: ReadyShelf = screen.get("_shelf")
	var kitchen: Kitchen = screen.get("_kitchen")
	var dining: DiningArea = screen.get("_dining")
	var supply: DishSupply = screen.get("_supply")
	var customers: Array[Customer] = screen.get("_customers")
	var slots: Array[String] = shelf.get("_slots")
	var shelf_buttons: Array[Button] = shelf.get("_buttons")

	# 2日目の最初に1回だけ: 強化画面で買った設備が営業画面に出ている（テーブル5卓・置き場7枠）
	if _days_done == 1 and not _equipment_checked:
		_equipment_checked = true
		_check("買った設備の効果が営業画面に出る（席・置き場の枠）",
			dining.get_seat_count() == GameState.get_seat_count() and dining.get_seat_count() == 6
			and slots.size() == GameState.get_shelf_capacity() and slots.size() == 7,
			"tables=%d slots=%d" % [dining.get_seat_count(), slots.size()])

	# 1日目の最初に1回だけ: 置き場の料理を持って「残りに戻す」
	if _days_done == 0 and not _return_tested:
		_return_tested = true
		var slot0: String = slots[0]
		var remaining_before: int = supply.get_remaining(slot0)
		var free_before: int = shelf.free_count()
		_hold(shelf, shelf_buttons, 0)
		(kitchen.get("_return_button") as Button).pressed.emit()
		_check("置き場から外した料理は残りに1戻り、枠が空く",
			supply.get_remaining(slot0) == remaining_before + 1 and shelf.free_count() == free_before + 1,
			"%s remaining %d -> %d, free %d -> %d" % [slot0, remaining_before, supply.get_remaining(slot0), free_before, shelf.free_count()])
		return

	var needed: Dictionary = {}
	for c: Customer in customers:
		if not c.is_waiting_food():
			continue
		var slot: int = slots.find(c.dish.id)
		if slot >= 0:
			# 1回だけわざと違う料理を出してミスを確認する
			if not _made_mistake:
				var wrong: int = -1
				for i: int in slots.size():
					if slots[i] != "" and slots[i] != c.dish.id:
						wrong = i
				if wrong >= 0:
					_hold(shelf, shelf_buttons, wrong)
					(dining.get_seat(c.seat_index).get("_tap_button") as Button).pressed.emit()
					_made_mistake = true
					print("[smoke] mistake test -> mistakes=%d" % GameState.today.mistakes)
			_hold(shelf, shelf_buttons, slot)
			(dining.get_seat(c.seat_index).get("_tap_button") as Button).pressed.emit()
			return
		needed[c.dish.id] = int(needed.get(c.dish.id, 0)) + 1
	var queue: Array[DishData] = kitchen.get("_queue")
	for d: DishData in queue:
		needed[d.id] = int(needed.get(d.id, 0)) - 1
	for d: DishData in kitchen.get_cooking():
		needed[d.id] = int(needed.get(d.id, 0)) - 1
	var buttons: Dictionary = kitchen.get("_buttons")
	for dish_id: String in needed:
		if int(needed[dish_id]) > 0 and buttons.has(dish_id):
			(buttons[dish_id] as Button).pressed.emit()
			return


## ボタンの真ん中を押す（pressed = true）・離す（false）操作を、本物の入力として送る
func _send_press(button: Button, pressed: bool) -> void:
	_send_press_at(button.get_global_rect().get_center(), pressed)


## 画面の point（640×360基準の座標）を押す・離す操作を、本物の入力として送る
func _send_press_at(point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.global_position = point
	get_viewport().push_input(event, true)


## 左ボタンを押したまま point へ動かす操作を送る
func _send_motion_at(point: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	event.global_position = point
	get_viewport().push_input(event, true)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _hold(shelf: ReadyShelf, buttons: Array[Button], slot: int) -> void:
	if int(shelf.get("_held_index")) != slot:
		buttons[slot].pressed.emit()


# ---------------------------------------------------------------
# 結果画面
# ---------------------------------------------------------------

func _do_result(screen: Node) -> void:
	var s: DayStats = GameState.today
	print("[smoke] result day=%d sales=%d cost=%d waste=%d(¥%d) other=%d profit=%d visitors=%d completed=%d angry=%d mistakes=%d sold_out=%s time_left=%.1f rep=%d money=%d" % [
		GameState.day, s.sales, s.ingredient_cost, s.waste_count, s.waste_cost, s.other_expense, s.profit(), s.visitors,
		s.completed_orders, s.left_angry, s.mistakes, s.sold_out, _last_time_left, GameState.reputation, GameState.money])
	_check_dish_breakdown(screen, s)
	# 所持金の増減 ＝ 売上 − その日の仕入れ代 − その他経費（食材原価は二重に引いていない）
	var change: int = GameState.money - s.day_start_money
	_check("所持金の増減は「売上 − 仕入れ代 − その他経費」（食材原価を二重に引いていない）",
		change == s.sales - s.purchase_cost - s.other_expense,
		"change=%d sales=%d purchase=%d other=%d profit=%d" % [change, s.sales, s.purchase_cost, s.other_expense, s.profit()])
	var stock_change: int = GameState.get_stock_value() - s.day_start_stock_value
	_check("利益 ＝ 所持金の増減 ＋ 在庫の増減（原価）", s.profit() == change + stock_change,
		"profit=%d change=%d stock=%d" % [s.profit(), change, stock_change])
	if _days_done == 0:
		var prepared: int = 0
		for dish_id: String in _day1_prep:
			prepared += int(_day1_prep[dish_id])
		_check("仕込み分を出し切ると売り切れで早く閉店する",
			s.sold_out and _last_time_left > 0.0 and s.completed_orders + s.left_angry >= prepared - s.waste_count,
			"time_left=%.1f" % _last_time_left)
		_check("注文は仕込み数を超えない", s.completed_orders <= prepared)
		var missed: int = 0
		for dish_id: String in s.dish_missed:
			missed += int(s.dish_missed[dish_id])
		_check("売り切れで閉店したあとの客を売り逃しとして数える", missed > 0, "missed=%s" % [s.dish_missed])
		var cfg: GameConfig = Database.config
		var bound: int = s.visitors + GameState.get_seat_count() * ceili(cfg.business_duration / cfg.missed_stay_time) * 2
		_check("売り切れのあとの売り逃しは、席の数の分までしか数えない（来客数に比べて多すぎない）",
			missed <= bound, "missed=%d visitors=%d bound=%d" % [missed, s.visitors, bound])
		_day1_stats = s
	else:
		var cost_check: int = 0
		for dish_id: String in GameState.last_prep_counts:
			cost_check += Database.get_dish_cost(Database.get_dish(dish_id)) * int(GameState.last_prep_counts[dish_id])
		_check("残った料理は廃棄として数え、原価に含める",
			s.waste_count > 0 and s.waste_cost > 0 and s.ingredient_cost == cost_check,
			"waste=%d cost=%d prep_cost=%d" % [s.waste_count, s.ingredient_cost, cost_check])
		_check("結果画面に廃棄の行が出る", _grid_has_text(screen.get("_profit_grid"), "　" + UIText.RESULT_WASTE % s.waste_count))
	if _days_done == 1 and _day1_stats != null:
		var missed_total: int = 0
		var same_as_last: bool = true
		for dish_id: String in s.dish_missed:
			missed_total += int(s.dish_missed[dish_id])
		for dish_id: String in GameState.last_missed_counts:
			if int(GameState.last_missed_counts[dish_id]) != int(s.dish_missed.get(dish_id, 0)):
				same_as_last = false
		var cfg2: GameConfig = Database.config
		var expected_points: float = s.reputation_points + missed_total * cfg2.reputation_missed + s.mistakes * cfg2.reputation_mistake
		_check("2日目の売り逃しは2日目の分だけ（保存する前回の売り逃し・評判の点数も同じ数を使う）",
			s != _day1_stats and same_as_last and is_equal_approx(GameState.get_day_reputation_points(), expected_points),
			"day1=%s day2=%s" % [_day1_stats.dish_missed, s.dish_missed])
	var history_row: PackedInt32Array = GameState.get_history(GameState.day)
	_check("営業結果で、その日の結果が履歴に入る（利益・来客数・営業が終わった時点の所持金）",
		not history_row.is_empty() and history_row[GameState.HISTORY_PROFIT] == s.profit()
		and history_row[GameState.HISTORY_VISITORS] == s.visitors
		and GameState.has_history_money(history_row) and history_row[GameState.HISTORY_MONEY] == GameState.money)
	if _days_done == 0:
		# 2日目は料理5種類で確かめるため、テストのために評判を上げて残りの料理を解放しておく
		# （解放の判定そのものは _check_rules で確かめている）
		GameState.add_reputation(200)
		GameState.call("_update_rank")
		GameState.call("_unlock_by_rank")
		# 1日目のあとは「お店を強化」へ進む
		(screen.get("_upgrade_button") as Button).pressed.emit()
		_days_done += 1
		return
	(screen.get("_next_button") as Button).pressed.emit()
	_days_done += 1
	if _days_done >= DAYS_TO_RUN:
		var saved: String = FileAccess.get_file_as_string(GameState.save_path)
		print("[smoke] save: ", saved.replace("\n", " "))
		_check("セーブは version 15 で、前回の置き場・売れた数・売り逃し・解放済みの料理・ランク・履歴・設備・従業員・常連さんの持ち越しを含む",
			saved.contains("\"version\": 15") and saved.contains("staff_states") and saved.contains("staff_levels") and saved.contains("reputation_progress") and saved.contains("\"staff\"") and saved.contains("\"history\"") and saved.contains("\"equipment\"") and saved.contains("last_shelf") and saved.contains("last_sold")
			and saved.contains("last_missed") and saved.contains("\"unlocked\"") and saved.contains("\"rank\""))
		_finish()


## 料理ごとの内訳: 合計が全体の数字と合うこと、表の行が仕込んだ料理の数だけあること
func _check_dish_breakdown(screen: Node, s: DayStats) -> void:
	var sold: int = 0
	var waste: int = 0
	var sales: int = 0
	var prepared: int = 0
	for dish_id: String in s.get_prepared_dish_ids():
		prepared += int(s.dish_prepared[dish_id])
		sold += int(s.dish_sold.get(dish_id, 0))
		waste += int(s.dish_waste.get(dish_id, 0))
		sales += int(s.dish_sales.get(dish_id, 0))
	print("[smoke] breakdown prepared=%s sold=%s waste=%s sales=%s" % [s.dish_prepared, s.dish_sold, s.dish_waste, s.dish_sales])
	var table: VBoxContainer = screen.get("_dish_table")
	_check("内訳の合計が全体と合う（売れた・廃棄・売上）",
		sold == s.completed_orders and waste == s.waste_count and sales == s.sales and sold + waste <= prepared,
		"sold=%d/%d waste=%d/%d sales=%d/%d" % [sold, s.completed_orders, waste, s.waste_count, sales, s.sales])
	_check("内訳の表に仕込んだ料理の行が出る", table.get_child_count() == s.get_prepared_dish_ids().size() + 1)
	# 結果画面には売り逃しを出さない（列も凡例も）
	var header_texts: PackedStringArray = PackedStringArray()
	for node: Node in table.get_child(0).find_children("*", "Label", true, false):
		header_texts.append((node as Label).text)
	var legend: String = (screen.get("_dish_legend") as Label).text
	_check("結果画面の内訳に「売り逃し」の列がなく、黄色は「完売」の意味になっている",
		not " ".join(header_texts).contains("売り逃し") and not legend.contains("売り逃し") and legend.contains("完売"),
		" ".join(header_texts))


## 強化画面: 画面のボタンで設備を買う（確認ダイアログを通す）→「次の日へ」
func _do_upgrade(screen: Node) -> void:
	if _upgrade_done:
		return
	_upgrade_done = true
	GameState.add_money(200000)
	var dialog: ConfirmDialog = screen.get("_dialog")
	var rows: Array[EquipmentRow] = screen.get("_rows")
	_check("強化画面に設備が5種類出る", rows.size() == Database.equipment.size() and rows.size() == 5)
	for row: EquipmentRow in rows:
		if row.equipment.id in ["seats", "shelf", "fryer"]:
			var money_before: int = GameState.money
			var price: int = row.equipment.get_price(GameState.get_equipment_level(row.equipment.id))
			(row.get("_buy_button") as Button).pressed.emit()
			var asked: bool = dialog.is_open()
			(dialog.get("_ok_button") as Button).pressed.emit()
			_check("「購入」で確認が出て、買うと所持金が価格の分だけ減る（%s）" % row.equipment.display_name,
				asked and GameState.money == money_before - price and GameState.get_equipment_level(row.equipment.id) == 1)
	(screen.get("_next_button") as Button).pressed.emit()


func _grid_has_text(grid: GridContainer, text: String) -> bool:
	for child: Node in grid.get_children():
		if child is Label and (child as Label).text == text:
			return true
	return false


func _shortages() -> Dictionary:
	var needs: Dictionary = GameState.get_ingredient_needs()
	var result: Dictionary = {}
	for ing: IngredientData in Database.ingredients:
		var lack: int = GameState.get_shortage(ing.id, needs)
		if lack > 0:
			result[ing.id] = lack
	return result


func _finish() -> void:
	if _days_started > 0:
		print("[smoke] time days: %dms" % (Time.get_ticks_msec() - _days_started))
	GameState.delete_save()
	var test_file_left: bool = FileAccess.file_exists(TEST_SAVE_PATH)
	var real_unchanged: bool = _read_real_save() == _real_save_before
	_check("テスト用のセーブを消した", not test_file_left)
	_check("本物のセーブは変わっていない", real_unchanged)
	var ok: bool = _failures.is_empty()
	print("[smoke] done" if ok else "[smoke] FAILED: " + ", ".join(_failures))
	get_tree().quit(0 if ok else 1)


func _read_real_save() -> String:
	if not FileAccess.file_exists(GameState.DEFAULT_SAVE_PATH):
		return "<なし>"
	return FileAccess.get_file_as_string(GameState.DEFAULT_SAVE_PATH)
