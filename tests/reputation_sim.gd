extends Node
## バランス確認のための自動プレイ。何日分も遊ばせて、日ごとの評判・ランク・所持金・設備・来客数の推移を表で出す。
## 実行: Godot --headless --path . res://tests/reputation_sim.tscn -- --skill=good --days=15 --seed=1
##   --fast         : 画面を出さずに営業を計算する高速モード（FastDayModel の近似。365日分が数十秒）
##   --csv=<path>   : 日ごとの結果を CSV に書き出す（省略時は user://reputation_sim.csv。--fast では必ず書き出す）
##   --no-buy       : 設備を買わず、従業員も雇わない
##   --no-toppings  : トッピングを仕込まない（比べる用）
##   --no-train     : スタッフの研修をしない（比べる用）
##   --no-kitchen   : スタッフを厨房に入れない（比べる用）
## シフト: 出られない日は休み、出られる人は全員出勤。
## 担当: 調理が追いつかない日（最近の調理の量が営業時間の KITCHEN_LOAD 以上）は、出勤する人のうち調理のいちばん速い人を厨房に入れる
##   （ホールに残る人が足りるとき。上手なボットは配膳が速いので1人でも入れる。ほかは2人以上いるときだけ）。
## 研修: 設備を買ったあと、手元に BUY_RESERVE を残せれば、レベルの低い人から1日1回研修する（--no-train で研修しない）。
## 在籍日数が終わって退職したら、人手が足りないときにまた雇う（雇う条件は _hire_staff）。
## ボットは、営業結果のあとに「手元に一定のお金を残して」優先順位に沿って設備を買う（BUY_PRIORITY）。
## 従業員: 人手が足りないとき（怒って帰る客が多い・評価が低い）に、日給が売上に見合う人を1日1人ずつ雇う（_hire_staff）。
## 仕込み: 解放済みの料理とトッピングを、注文の目安 × 倍率だけ仕込む。
##   --skill=good   : 上手なボット（目安どおりに仕込み、すぐに作って出す。ミスをしない）
##   --skill=normal : ふつうのボット（仕込みは目安より少し少なめ、動きは少し遅い、たまに違う料理を出す）
##   --skill=sloppy : ミスの多いボット（仕込みが少なめ、動きが遅い、ときどき違う料理を出す）
## 本物のセーブ（user://save.json）は読み書きしない。テスト用のファイルを使い、終わったら消す。

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const SIM_SAVE_PATH := "user://save_reputation_sim.json"

## 設備を買う優先順位（上から順に、買えるものを買う）と、買ったあとに手元に残すお金
const BUY_PRIORITY: PackedStringArray = ["seats", "fryer", "stove", "shelf", "rice_cooker"]
const BUY_RESERVE := 10000
const RECENT_DAYS := 7
## 人手が足りないとみなす目安（最近7日の平均）
const HIRE_ANGRY := 0.5
const HIRE_STARS := 4.2
const DEFAULT_CSV := "user://reputation_sim.csv"
## 調理が追いつかないとみなす目安: 最近7日の「店主に換算した調理の時間 ÷ 営業時間」の平均
const KITCHEN_LOAD := 0.6

## ボットの設定（上手／ふつう／ミスが多い）
const SKILLS: Dictionary = {
	# kitchen_min_staff: 出勤する人がこの人数以上のときだけ、1人を厨房に入れる
	"good": { "prep_factor": 1.1, "reaction": 0.4, "wrong_rate": 0.0, "precook": true, "hire_ratio": 0.12, "kitchen_min_staff": 1 },
	"normal": { "prep_factor": 0.9, "reaction": 2.0, "wrong_rate": 0.05, "precook": false, "hire_ratio": 0.12, "kitchen_min_staff": 2 },
	# 操作の遅いボットは、配膳を手伝ってもらうため、売上が少なくても早めに安い人を雇う
	"sloppy": { "prep_factor": 0.6, "reaction": 5.0, "wrong_rate": 0.25, "precook": false, "hire_ratio": 0.2, "hire_cheap": true,
		"kitchen_min_staff": 2 },
}

var _skill_name: String = "good"
var _skill: Dictionary = {}
var _days_to_run: int = 15
var _main: Node
var _days_done: int = 0
var _cooldown: float = 0.0
var _last_screen: String = ""
var _prepared_today: bool = false
var _rows: PackedStringArray = PackedStringArray()
var _csv_rows: PackedStringArray = PackedStringArray()
var _csv_path: String = DEFAULT_CSV
var _fast: bool = false
var _buy: bool = true
var _toppings: bool = true
## スタッフの研修をするか（--no-train でしない。比べる用）
var _train: bool = true
## スタッフを厨房に入れるか（--no-kitchen で入れない。比べる用）
var _kitchen: bool = true
## 最近の調理の量（店主に換算した調理の時間 ÷ 営業時間）
var _recent_cook_load: Array[float] = []
## その日に買った設備・雇った従業員（表に出す）
var _bought_today: PackedStringArray = PackedStringArray()
## 最近の売上（雇うかどうかの判断）
var _recent_sales: Array[int] = []
var _recent_angry: Array[int] = []
var _recent_stars: Array[float] = []


func _ready() -> void:
	var seed_value: int = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--skill="):
			_skill_name = arg.trim_prefix("--skill=")
		elif arg.begins_with("--days="):
			_days_to_run = int(arg.trim_prefix("--days="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg == "--fast":
			_fast = true
		elif arg == "--no-buy":
			_buy = false
		elif arg == "--no-toppings":
			_toppings = false
		elif arg == "--no-train":
			_train = false
		elif arg == "--no-kitchen":
			_kitchen = false
		elif arg.begins_with("--csv="):
			_csv_path = arg.trim_prefix("--csv=")
	_skill = SKILLS.get(_skill_name, SKILLS["good"])
	seed(seed_value)
	GameState.use_save_path(SIM_SAVE_PATH)
	GameState.delete_save()
	GameState.use_save_path(SIM_SAVE_PATH)
	_rows.append("| 日 | 日付 | 来客 | 提供 | 怒って帰った | 売り逃し | ★ | 評判の増減 | 評判 | ランク | 利益 | 所持金 | 設備（卓・棚・コ・フ・炊） | 従業員 | 買った設備・雇った人 |")
	_rows.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	_csv_rows.append("day,date,reputation,reputation_change,rank,money,profit,visitors,served,angry,missed,stars,seats,shelf,stove,fryer,rice_cooker,unlocked_count,unlocked,bought,sales,labor,staff,topping_sold,worked,retired,levels,kitchen,cooked_chef,cooked_staff,cook_load")
	if _fast:
		_run_fast()
		return
	Engine.time_scale = 12.0
	# --headless では画面が正方形（640×640）になり、客席が実機よりずっと縦長になって歩く距離が変わるので、16:9 にしておく
	get_tree().root.size = Vector2i(1280, 720)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)


## 高速モード: 画面を出さずに、準備 → 営業（FastDayModel）→ 結果 → 強化 → 次の日 をくり返す
func _run_fast() -> void:
	var model: FastDayModel = FastDayModel.new(_skill)
	for i: int in _days_to_run:
		_plan_prep()
		model.run_day(GameState.begin_business())
		GameState.finish_business()
		_record_day()
		GameState.advance_day()
	_finish()


func _process(delta: float) -> void:
	if _main == null or _main.get_child_count() == 0:
		return
	var screen: Node = _main.get_child(_main.get_child_count() - 1)
	if screen.name != _last_screen:
		_last_screen = screen.name
		_cooldown = 0.5
		_prepared_today = false
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	match String(screen.name):
		"PrepScreen":
			_cooldown = 0.3
			_do_prep(screen)
		"Business":
			_cooldown = float(_skill["reaction"])
			_do_business(screen)
		"ResultScreen":
			_cooldown = 0.5
			_do_result(screen)


## 準備: 解放済みの料理を「注文の目安 × 倍率」だけ仕込み、足りない食材を仕入れ、置き場に並べて開始
func _do_prep(screen: Node) -> void:
	if _prepared_today:
		return
	_prepared_today = true
	_plan_prep()
	screen.call("_on_start_pressed")


## 今日の出勤を決める（出られない日は休み。連勤が続きそうな人・疲れている人は休ませる）
func _plan_shift() -> void:
	for data: StaffData in GameState.get_hired_staff():
		GameState.set_staff_role(data.id, GameState.ROLE_HALL)
		if GameState.is_staff_available(data.id):
			GameState.set_shift(data.id, true)
	_plan_kitchen()


## 調理が追いつかない日は、出勤する人のうち調理のいちばん速い人を厨房に入れる
func _plan_kitchen() -> void:
	var working: Array[StaffData] = GameState.get_working_staff()
	if not _kitchen or _recent_cook_load.is_empty() or working.size() < int(_skill["kitchen_min_staff"]):
		return
	var cook_load: float = 0.0
	for v: float in _recent_cook_load:
		cook_load += v
	cook_load /= _recent_cook_load.size()
	if cook_load < KITCHEN_LOAD:
		return
	var best: StaffData = null
	for data: StaffData in working:
		if best == null or GameState.get_staff_cook_speed(data) > GameState.get_staff_cook_speed(best):
			best = data
	GameState.set_staff_role(best.id, GameState.ROLE_KITCHEN)


func _plan_prep() -> void:
	var expected: Dictionary = GameState.get_expected_orders()
	for dish: DishData in GameState.get_unlocked_items():
		if dish.is_topping() and not _toppings:
			continue
		var target: int = maxi(1, ceili(float(expected.get(dish.id, 0.0)) * float(_skill["prep_factor"])))
		GameState.change_prep(dish.id, -999)
		GameState.change_prep(dish.id, target)
	# 足りない食材は、所持金がマイナスになっても仕入れる
	GameState.plan_prep_shortage()
	GameState.confirm_purchase()
	GameState.reduce_prep_to_stock()
	_plan_shift()
	var dishes: Array[DishData] = GameState.get_menu_dishes()
	var i: int = 0
	while dishes.size() > 0 and GameState.shelf_plan.size() < GameState.get_shelf_capacity() and i < 50:
		GameState.add_to_shelf_plan(dishes[i % dishes.size()].id)
		i += 1


func _do_business(screen: Node) -> void:
	var shelf: ReadyShelf = screen.get("_shelf")
	var kitchen: Kitchen = screen.get("_kitchen")
	var dining: DiningArea = screen.get("_dining")
	var supply: DishSupply = screen.get("_supply")
	var customers: Array[Customer] = screen.get("_customers")
	var slots: Array[String] = shelf.get("_slots")
	var shelf_buttons: Array[Button] = shelf.get("_buttons")
	var cook_buttons: Dictionary = kitchen.get("_buttons")

	# 待っている客（注文の古い順）に出せる料理・トッピングがあれば出す（スタッフが取りに来ている枠は使わない）
	var waiting: Array[Customer] = []
	for c: Customer in customers:
		if c.is_waiting_food():
			waiting.append(c)
	waiting.sort_custom(func(a: Customer, b: Customer) -> bool: return a.order_sequence < b.order_sequence)
	var needed: Dictionary = {}
	for c: Customer in waiting:
		for item_id: String in c.get_needed_items():
			var slot: int = _find_slot(shelf, slots, item_id)
			if slot >= 0:
				if randf() < float(_skill["wrong_rate"]):
					for j: int in slots.size():
						if slots[j] != "" and slots[j] != item_id and not shelf.is_reserved(j):
							slot = j
							break
				_hold(shelf, shelf_buttons, slot)
				(dining.get_seat(c.seat_index).get("_tap_button") as Button).pressed.emit()
				return
			DayStats.add_to(needed, item_id, 1)
	# 足りない料理を作る（作っている分・置き場の分を引く）
	var queue: Array[DishData] = kitchen.get("_queue")
	for d: DishData in queue:
		DayStats.add_to(needed, d.id, -1)
	for d: DishData in kitchen.get_cooking():
		DayStats.add_to(needed, d.id, -1)
	for dish_id: String in needed:
		if int(needed[dish_id]) > 0 and cook_buttons.has(dish_id) and supply.get_remaining(dish_id) > 0:
			(cook_buttons[dish_id] as Button).pressed.emit()
			return
	# 上手なボットは、手が空いたら残りの多い料理を先に作っておく（置き場に2枠は空けておく）
	if bool(_skill["precook"]) and kitchen.get_pending_count() == 0 and shelf.free_count() > 2:
		var best: String = ""
		for dish_id: String in cook_buttons:
			if supply.get_remaining(dish_id) > (supply.get_remaining(best) if best != "" else 0):
				best = dish_id
		if best != "":
			(cook_buttons[best] as Button).pressed.emit()


func _find_slot(shelf: ReadyShelf, slots: Array[String], item_id: String) -> int:
	for i: int in slots.size():
		if slots[i] == item_id and not shelf.is_reserved(i):
			return i
	return -1


func _hold(shelf: ReadyShelf, buttons: Array[Button], slot: int) -> void:
	if int(shelf.get("_held_index")) != slot:
		buttons[slot].pressed.emit()


func _do_result(screen: Node) -> void:
	_record_day()
	(screen.get("_next_button") as Button).pressed.emit()
	_days_done += 1
	if _days_done >= _days_to_run:
		_finish()


## 結果のあと: 設備を買い、その日の行を表と CSV に足す（GameState.finish_business() のあとに呼ぶ）
func _record_day() -> void:
	_bought_today.clear()
	_recent_sales.append(GameState.today.sales)
	_recent_angry.append(GameState.today.left_angry)
	_recent_stars.append(GameState.today.average_stars() if GameState.today.has_ratings() else 3.0)
	# 店主に換算した調理の時間（スタッフの分は調理の速さをかけて店主の時間に直す）
	var s0: DayStats = GameState.today
	var cook_work: float = s0.chef_cook_seconds
	if s0.staff_kitchen != "":
		cook_work += s0.staff_cook_seconds * GameState.get_staff_cook_speed(Database.get_staff(s0.staff_kitchen))
	_recent_cook_load.append(cook_work / Database.config.business_duration)
	if _recent_cook_load.size() > RECENT_DAYS:
		_recent_cook_load.pop_front()
	if _recent_sales.size() > RECENT_DAYS:
		_recent_sales.pop_front()
		_recent_angry.pop_front()
		_recent_stars.pop_front()
	if _buy:
		_buy_equipment()
		_hire_staff()
		if _train:
			_train_staff()
	var s: DayStats = GameState.today
	var missed: int = 0
	for dish_id: String in s.dish_missed:
		missed += int(s.dish_missed[dish_id])
	var stars: String = "%.1f" % s.average_stars() if s.has_ratings() else "-"
	var levels: PackedStringArray = PackedStringArray()
	for id: String in BUY_PRIORITY_ORDER_FOR_TABLE:
		levels.append(str(GameState.get_equipment_level(id)))
	var date_text: String = GameCalendar.format_date(GameCalendar.date_for_business_day(GameState.day))
	_rows.append("| %d | %s | %d | %d | %d | %d | %s | %s | %d | %d %s%s | %s | %s | %s | %s | %s |" % [
		GameState.day, date_text, s.visitors, s.completed_orders, s.left_angry, missed, stars,
		UIText.signed(s.reputation_change), GameState.reputation, GameState.rank, GameState.get_rank_name(),
		"（ランクアップ）" if s.rank_up > 0 else "", UIText.money(s.profit()), UIText.money(GameState.money),
		"・".join(levels), str(GameState.hired_staff.size()), "・".join(_bought_today) if not _bought_today.is_empty() else "-"])
	var unlocked: PackedStringArray = PackedStringArray()
	for dish: DishData in GameState.get_unlocked_items():
		unlocked.append(dish.id)
	var topping_sold: int = 0
	for dish: DishData in Database.toppings:
		topping_sold += int(s.dish_sold.get(dish.id, 0))
	var date: Dictionary = GameCalendar.date_for_business_day(GameState.day)
	var levels_text: PackedStringArray = PackedStringArray()
	for staff_id: String in GameState.hired_staff:
		levels_text.append("%s:%d" % [staff_id, GameState.get_staff_level(staff_id)])
	_csv_rows.append("%d,%04d-%02d-%02d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%d,%s,%s,%d,%d,%s,%d,%s,%s,%s,%s,%d,%d,%.3f" % [
		GameState.day, int(date["year"]), int(date["month"]), int(date["day"]), GameState.reputation, s.reputation_change,
		GameState.rank, GameState.money, s.profit(), s.visitors, s.completed_orders, s.left_angry, missed, stars,
		",".join(levels), unlocked.size(), "|".join(unlocked), "|".join(_bought_today), s.sales, s.labor_cost,
		"|".join(GameState.hired_staff), topping_sold, "|".join(s.staff_worked), "|".join(s.staff_retired), "|".join(levels_text),
		s.staff_kitchen, s.cooked_by_chef, s.cooked_by_staff, _recent_cook_load[_recent_cook_load.size() - 1]])


## 表の「設備」の列の並び（卓・棚・コンロ・フライヤー・炊飯器）
const BUY_PRIORITY_ORDER_FOR_TABLE: PackedStringArray = ["seats", "shelf", "stove", "fryer", "rice_cooker"]


## 優先順位の上から、手元に BUY_RESERVE を残して買えるものを買う（1日に何個でも）
func _buy_equipment() -> void:
	var bought: bool = true
	while bought:
		bought = false
		for id: String in BUY_PRIORITY:
			var e: EquipmentData = Database.get_equipment(id)
			if e == null or GameState.get_buy_block(id) != GameState.BuyBlock.NONE:
				continue
			if GameState.money - e.get_price(GameState.get_equipment_level(id)) < BUY_RESERVE:
				continue
			GameState.buy_equipment(id)
			_bought_today.append("%s→Lv%d" % [e.display_name, GameState.get_equipment_level(id)])
			bought = true
			break


## 人手が足りない（最近7日で、怒って帰る客が1日 HIRE_ANGRY 人以上か、評価の平均が HIRE_STARS 未満）ときに、
## 雇える人数に空きがあれば1日1人ずつ雇う。日給は「最近7日の売上の平均 × hire_ratio」以下の人から選ぶ
## （操作の遅いボットは安い人、ほかはいちばん速い人）
func _hire_staff() -> void:
	if _recent_sales.is_empty() or GameState.hired_staff.size() >= GameState.get_staff_limit():
		return
	var average: float = 0.0
	for v: int in _recent_sales:
		average += v
	average /= _recent_sales.size()
	var angry: float = 0.0
	for v: int in _recent_angry:
		angry += v
	angry /= maxi(1, _recent_angry.size())
	var stars: float = 0.0
	for v: float in _recent_stars:
		stars += v
	stars /= maxi(1, _recent_stars.size())
	if angry < HIRE_ANGRY and stars >= HIRE_STARS:
		return
	var best: StaffData = null
	for data: StaffData in Database.staff:
		if not GameState.can_hire(data.id) or data.daily_wage > average * float(_skill["hire_ratio"]):
			continue
		if best == null:
			best = data
		elif bool(_skill.get("hire_cheap", false)):
			if data.daily_wage < best.daily_wage:
				best = data
		elif data.walk_speed > best.walk_speed:
			best = data
	if best == null:
		return
	GameState.hire_staff(best.id)
	# CSV に入れるので、金額にカンマを入れない
	_bought_today.append("%s（日給%d）" % [best.display_name, best.daily_wage])


## 研修: 手元に BUY_RESERVE を残せれば、レベルのいちばん低い人を1日1回だけ研修する
func _train_staff() -> void:
	var best: StaffData = null
	for data: StaffData in GameState.get_hired_staff():
		if GameState.get_train_block(data.id) != GameState.TrainBlock.NONE:
			continue
		if best == null or GameState.get_staff_level(data.id) < GameState.get_staff_level(best.id):
			best = data
	if best == null:
		return
	var price: int = Database.staff_training.get_price(GameState.get_staff_level(best.id))
	if GameState.money - price < BUY_RESERVE:
		return
	GameState.train_staff(best.id)
	_bought_today.append("研修 %s→Lv%d" % [best.display_name, GameState.get_staff_level(best.id)])


func _finish() -> void:
	print("[sim] skill=%s fast=%s days=%d" % [_skill_name, _fast, _days_to_run])
	for row: String in _rows:
		print("[sim] ", row)
	var file: FileAccess = FileAccess.open(_csv_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_csv_rows) + "\n")
		file.close()
		print("[sim] csv: ", ProjectSettings.globalize_path(_csv_path))
	GameState.delete_save()
	get_tree().quit()
