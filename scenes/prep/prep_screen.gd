extends Control
## 営業準備画面。手順ごとに1つの作業を広く表示する。
##   ①仕込み（PrepMenuStep） → ②仕入れ（PrepPurchaseStep） → ③開店時の置き場（PrepShelfStep） → 営業開始
## 上に手順の表示（タップでその手順へ）、下に「戻る」「次へ」（③では「営業開始」）を置く。
## 入力した内容は GameState に入っているので、手順を行き来しても消えない。
## ③へ進むとき・営業開始のときは、仕込み数に対して食材が足りるか、仕入れ予定が残っていないかを確かめる。

signal start_requested

enum Step { MENU, PURCHASE, SHELF }
## 確認ダイアログで何を聞いているか
enum Pending { NONE, PURCHASE, SHORTAGE, PLAN_LEFT_TO_SHELF, PLAN_LEFT_TO_START }

const COLOR_MESSAGE := Color.WHITE
const COLOR_WARNING := Color(1.0, 0.45, 0.4)
const COLOR_STEP_CURRENT := Color(0.85, 0.65, 0.25)
const COLOR_STEP_OTHER := Color(0.22, 0.2, 0.19)

var _step: Step = Step.MENU
var _step_buttons: Array[Button] = []
var _calendar_button: Button
## ボタンを押した結果のお知らせ。次の操作をするまで表示する
var _notice: String = ""
var _pending: Pending = Pending.NONE
## 食材の確認のあとに進む先が営業開始か（false なら③）
var _after_check_start: bool = false

@onready var _step_bar: HBoxContainer = %StepBar
@onready var _menu_step: PrepMenuStep = %MenuStep
@onready var _purchase_step: PrepPurchaseStep = %PurchaseStep
@onready var _shelf_step: PrepShelfStep = %ShelfStep
@onready var _message_label: Label = %MessageLabel
@onready var _pace_label: Label = %PaceLabel
@onready var _purchase_texts: VBoxContainer = %PurchaseTexts
@onready var _purchase_total_label: Label = %PurchaseTotalLabel
@onready var _purchase_note_label: Label = %PurchaseNoteLabel
@onready var _purchase_button: Button = %PurchaseButton
@onready var _back_button: Button = %BackButton
@onready var _next_button: Button = %NextButton
@onready var _start_button: Button = %StartButton
@onready var _dialog: ConfirmDialog = %ConfirmDialog
@onready var _detail: DetailPopup = %DetailPopup
@onready var _calendar: CalendarPopup = %CalendarPopup


func _ready() -> void:
	_build_step_bar()
	_back_button.text = UIText.PREP_BACK
	_next_button.text = UIText.PREP_NEXT
	_start_button.text = UIText.PREP_START
	_purchase_button.text = UIText.PREP_PURCHASE_BUTTON

	_menu_step.notice_requested.connect(_on_notice)
	_purchase_step.notice_requested.connect(_on_notice)
	_shelf_step.notice_requested.connect(_on_notice)
	_menu_step.detail_requested.connect(_on_detail_requested)
	_menu_step.detail_closed.connect(_detail.close)
	_purchase_step.detail_requested.connect(_on_detail_requested)
	_purchase_step.detail_closed.connect(_detail.close)

	GameState.inventory_changed.connect(_refresh)
	GameState.money_changed.connect(func(_v: int) -> void: _refresh())
	_back_button.pressed.connect(_on_back_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_purchase_button.pressed.connect(_on_purchase_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_dialog.answered.connect(_on_dialog_answered)
	_dialog.alt_chosen.connect(_on_dialog_alt)
	# 準備画面を開いたら①から始める
	_show_step(Step.MENU)


func get_step() -> Step:
	return _step


# ---------------------------------------------------------------
# 手順の表示と移動
# ---------------------------------------------------------------

func _build_step_bar() -> void:
	for i: int in UIText.PREP_STEP_NAMES.size():
		if i > 0:
			var sep: Label = Label.new()
			sep.text = UIText.PREP_STEP_SEPARATOR
			sep.modulate = Color(0.6, 0.6, 0.6)
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_step_bar.add_child(sep)
		var button: Button = Button.new()
		button.text = UIText.PREP_STEP_NAMES[i]
		button.custom_minimum_size = Vector2(96, 28)
		button.pressed.connect(_go_to.bind(i))
		_step_bar.add_child(button)
		_step_buttons.append(button)
	# 手順の表示の横に「カレンダー」
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	_step_bar.add_child(gap)
	var calendar_button: Button = Button.new()
	calendar_button.text = UIText.CAL_BUTTON
	calendar_button.custom_minimum_size = Vector2(88, 28)
	calendar_button.pressed.connect(_calendar.open)
	_step_bar.add_child(calendar_button)
	_calendar_button = calendar_button


func _on_back_pressed() -> void:
	_go_to(_step - 1)


func _on_next_pressed() -> void:
	_go_to(_step + 1)


## 手順を移る。③へ進むときは、食材と仕入れ予定を確かめてから
func _go_to(target: int) -> void:
	if target == _step or target < Step.MENU or target > Step.SHELF:
		return
	if target == Step.SHELF:
		_after_check_start = false
		if not _check_before_shelf():
			return
	_show_step(target as Step)


func _show_step(step: Step) -> void:
	_step = step
	_notice = ""
	_detail.close()
	_menu_step.visible = step == Step.MENU
	_purchase_step.visible = step == Step.PURCHASE
	_shelf_step.visible = step == Step.SHELF
	for i: int in _step_buttons.size():
		var current: bool = i == step
		var box: StyleBoxFlat = UIUtil.flat_box(COLOR_STEP_CURRENT if current else COLOR_STEP_OTHER,
			Color(1, 0.9, 0.6) if current else Color(0.4, 0.38, 0.36), 2 if current else 1, 4)
		UIUtil.apply_button_style(_step_buttons[i], box)
		var text_color: Color = Color(0.12, 0.08, 0.04) if current else Color(0.85, 0.85, 0.85)
		_step_buttons[i].add_theme_color_override("font_color", text_color)
		_step_buttons[i].add_theme_color_override("font_pressed_color", text_color)
		_step_buttons[i].add_theme_color_override("font_hover_color", text_color)
		_step_buttons[i].add_theme_color_override("font_focus_color", text_color)
	_refresh()


func _refresh() -> void:
	match _step:
		Step.MENU:
			_menu_step.refresh()
		Step.PURCHASE:
			_purchase_step.refresh()
		Step.SHELF:
			_shelf_step.refresh()
	_back_button.disabled = _step == Step.MENU
	_next_button.visible = _step != Step.SHELF
	_start_button.visible = _step == Step.SHELF
	_start_button.disabled = GameState.get_total_prep() <= 0
	_purchase_texts.visible = _step == Step.PURCHASE
	_purchase_button.visible = _step == Step.PURCHASE
	_refresh_purchase()
	_refresh_message()
	var cfg: GameConfig = Database.config
	_pace_label.text = UIText.PREP_PACE % [
		GameState.reputation,
		1.0 / cfg.get_spawn_interval_scale(GameState.reputation),
		cfg.get_average_spawn_interval(GameState.reputation),
	]


func _refresh_purchase() -> void:
	var total: int = GameState.get_purchase_total()
	var has_plan: bool = GameState.has_purchase_plan()
	_purchase_total_label.text = UIText.PREP_PURCHASE_TOTAL % UIText.money(total) if has_plan else UIText.PREP_PURCHASE_NONE
	# 所持金が足りなくても仕入れられる（所持金はマイナスになる）。そのときは注意だけ出す
	var after: int = GameState.get_money_after_purchase()
	_purchase_note_label.visible = has_plan and after < 0
	if after < 0:
		_purchase_note_label.text = UIText.PREP_PURCHASE_SHORT_MONEY % UIText.money(after)
	_purchase_button.disabled = not has_plan


func _refresh_message() -> void:
	if _notice != "":
		_set_message(_notice, COLOR_MESSAGE)
		return
	var short: bool = GameState.has_prep_shortage()
	match _step:
		Step.MENU:
			if short:
				_set_message(UIText.PREP_MENU_SHORT, COLOR_WARNING)
			else:
				_set_message(UIText.PREP_MENU_HINT, COLOR_MESSAGE)
		Step.PURCHASE:
			if short and _plan_covers_shortage():
				_set_message(UIText.PREP_PURCHASE_CONFIRM_NEEDED, COLOR_WARNING)
			elif short:
				_set_message(UIText.PREP_PURCHASE_SHORT, COLOR_WARNING)
			elif _purchase_step.has_estimate_shortage():
				_set_message(UIText.PREP_SHORTAGE_WARNING, COLOR_WARNING)
			else:
				_set_message(UIText.PREP_PURCHASE_HINT, COLOR_MESSAGE)
		Step.SHELF:
			if GameState.get_total_prep() <= 0:
				_set_message(UIText.PREP_NEED_PREP, COLOR_WARNING)
			else:
				_set_message(UIText.PREP_HINT, COLOR_MESSAGE)


## 仕込みに足りない分が、すべて仕入れ予定に入っているか
func _plan_covers_shortage() -> bool:
	var shortage: Dictionary = GameState.get_prep_shortage()
	for ing_id: String in shortage:
		if GameState.get_planned_purchase(ing_id) < int(shortage[ing_id]):
			return false
	return true


func _set_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)


func _on_notice(text: String) -> void:
	_notice = text
	_refresh_message()


# ---------------------------------------------------------------
# 先へ進むときの確認
# ---------------------------------------------------------------

## ③へ進む前の確認。食材が足りない・仕入れ予定が残っているときはダイアログを出して false
func _check_before_shelf() -> bool:
	if GameState.has_prep_shortage():
		_ask_shortage()
		return false
	if GameState.has_purchase_plan():
		_pending = Pending.PLAN_LEFT_TO_SHELF
		_dialog.ask(UIText.PREP_PLAN_LEFT % UIText.money(GameState.get_purchase_total()),
			UIText.PREP_PLAN_LEFT_OK, UIText.PREP_CANCEL)
		return false
	return true


## 「食材が足りません」: 不足分を予定に入れる／仕込み数を在庫に合わせて減らす／やめる
func _ask_shortage() -> void:
	var parts: PackedStringArray = PackedStringArray()
	var shortage: Dictionary = GameState.get_prep_shortage()
	for ing: IngredientData in Database.ingredients:
		if shortage.has(ing.id):
			parts.append(UIText.PREP_DISH_SHORT_ITEM % [ing.display_name, int(shortage[ing.id])])
	_pending = Pending.SHORTAGE
	_dialog.ask(UIText.PREP_SHORTAGE_DIALOG % "・".join(parts),
		UIText.PREP_PLAN_SHORTAGE, UIText.PREP_CANCEL, UIText.PREP_REDUCE_TO_STOCK)


func _on_purchase_pressed() -> void:
	if not GameState.has_purchase_plan():
		return
	_pending = Pending.PURCHASE
	var total_text: String = UIText.money(GameState.get_purchase_total())
	var after: int = GameState.get_money_after_purchase()
	var message: String = UIText.PREP_PURCHASE_CONFIRM % total_text if after >= 0 \
		else UIText.PREP_PURCHASE_CONFIRM_NEGATIVE % [total_text, UIText.money(after)]
	_dialog.ask(message, UIText.PREP_PURCHASE_OK, UIText.PREP_CANCEL)


func _on_start_pressed() -> void:
	if GameState.get_total_prep() <= 0:
		return
	_after_check_start = true
	if GameState.has_prep_shortage():
		_ask_shortage()
		return
	if GameState.has_purchase_plan():
		_pending = Pending.PLAN_LEFT_TO_START
		_dialog.ask(UIText.PREP_START_WITH_PLAN % UIText.money(GameState.get_purchase_total()),
			UIText.PREP_START_ANYWAY, UIText.PREP_CANCEL)
		return
	start_requested.emit()


func _on_dialog_answered(ok: bool) -> void:
	var pending: Pending = _pending
	_pending = Pending.NONE
	if not ok:
		return
	match pending:
		Pending.PURCHASE:
			var total: int = GameState.get_purchase_total()
			if GameState.confirm_purchase():
				_on_notice(UIText.PREP_PURCHASE_DONE % UIText.money(total))
				_refresh()
		Pending.SHORTAGE:
			# 不足分を予定に入れて、②仕入れで確定してもらう
			GameState.plan_prep_shortage()
			_show_step(Step.PURCHASE)
			_on_notice(UIText.PREP_PLAN_SHORTAGE_DONE)
		Pending.PLAN_LEFT_TO_SHELF:
			# 予定は残したまま③へ（営業開始のときにもう一度確かめる）
			_show_step(Step.SHELF)
		Pending.PLAN_LEFT_TO_START:
			# 仕入れ予定は捨てて営業を始める
			GameState.clear_purchase_plan()
			start_requested.emit()


## 「仕込み数を在庫に合わせて減らす」を選んだ
func _on_dialog_alt() -> void:
	var pending: Pending = _pending
	_pending = Pending.NONE
	if pending != Pending.SHORTAGE:
		return
	GameState.reduce_prep_to_stock()
	if _after_check_start:
		_on_start_pressed()
	elif _check_before_shelf():
		_show_step(Step.SHELF)
		_on_notice(UIText.PREP_REDUCED)
	else:
		_on_notice(UIText.PREP_REDUCED)


# ---------------------------------------------------------------
# 長押しの詳細
# ---------------------------------------------------------------

func _on_detail_requested(kind: String, id: String) -> void:
	if kind == "dish":
		_show_dish_detail(id)
	else:
		_show_ingredient_detail(id)


## 料理の詳細（料理の一覧は左側なので、右側に出す）
func _show_dish_detail(dish_id: String) -> void:
	var dish: DishData = Database.get_dish(dish_id)
	if dish == null:
		return
	var cost: int = Database.get_dish_cost(dish)
	var expected: Dictionary = GameState.get_expected_orders()
	var lines: PackedStringArray = PackedStringArray()
	lines.append(UIText.DETAIL_DISH_PRICE % [UIText.money(dish.price), UIText.money(cost), UIText.money(dish.price - cost)])
	var scale: float = GameState.get_cook_time_scale(dish)
	if scale < 0.999:
		lines.append(UIText.DETAIL_DISH_COOK_EQUIPPED % [GameState.get_cook_time(dish), roundi((1.0 - scale) * 100.0)])
	else:
		lines.append(UIText.DETAIL_DISH_COOK % roundi(dish.cook_time))
	lines.append(UIText.DETAIL_DISH_INGREDIENTS % _ingredient_list_text(dish))
	lines.append(UIText.DETAIL_DISH_EXPECTED % ceili(float(expected.get(dish_id, 0.0))))
	lines.append(UIText.DETAIL_DISH_PREP % [GameState.get_prep_count(dish_id), GameState.get_shelf_plan_count(dish_id)])
	if GameState.last_sold_counts.is_empty():
		lines.append(UIText.DETAIL_NO_RECORD)
	elif GameState.get_last_sold(dish_id) < 0:
		lines.append(UIText.DETAIL_DISH_LAST_NOT_SERVED)
	else:
		lines.append(UIText.DETAIL_DISH_LAST % [int(GameState.last_prep_counts.get(dish_id, 0)),
			GameState.get_last_sold(dish_id), GameState.get_last_missed(dish_id)])
	_detail.open(dish.display_name, lines, DetailPopup.Placement.RIGHT)


## 食材の詳細（押した行と重ならないよう、右側に出す）
func _show_ingredient_detail(ingredient_id: String) -> void:
	var ing: IngredientData = Database.get_ingredient(ingredient_id)
	if ing == null:
		return
	var stock: int = GameState.get_stock(ingredient_id)
	var reserved: int = GameState.get_reserved(ingredient_id)
	var planned: int = GameState.get_planned_purchase(ingredient_id)
	var lines: PackedStringArray = PackedStringArray()
	lines.append(UIText.DETAIL_ING_PRICE % UIText.money(ing.price))
	lines.append(UIText.DETAIL_ING_STOCK % [stock, reserved, stock - reserved])
	lines.append(UIText.DETAIL_ING_PLAN % [planned, UIText.money(planned * ing.price)])
	lines.append(UIText.DETAIL_ING_NEED % int(GameState.get_ingredient_needs().get(ingredient_id, 0)))
	lines.append(UIText.DETAIL_ING_USED_BY)
	var used: bool = false
	for dish: DishData in GameState.get_unlocked_items():
		if dish.ingredients.has(ingredient_id):
			used = true
			lines.append(UIText.DETAIL_ING_USED_ROW % [dish.display_name, int(dish.ingredients[ingredient_id]), GameState.get_prep_count(dish.id)])
	if not used:
		lines.append(UIText.DETAIL_ING_UNUSED)
	_detail.open(ing.display_name, lines, DetailPopup.Placement.RIGHT)


## 「米×1・鶏肉×1・キャベツ×1」（数も必ず出す）
func _ingredient_list_text(dish: DishData) -> String:
	var names: PackedStringArray = PackedStringArray()
	for ing: IngredientData in Database.ingredients:
		if dish.ingredients.has(ing.id):
			names.append("%s×%d" % [ing.display_name, int(dish.ingredients[ing.id])])
	return "・".join(names)
