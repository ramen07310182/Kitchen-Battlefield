extends Control
## 営業準備画面: 今日のメニューと仕込み数・開店時の置き場・食材の仕入れ（予定を決めて確定）。
## 食材は「今日のメニューと仕込み数から見た必要数の目安」と、確定した在庫を比べ、足りなければ赤く表示する。

signal start_requested

enum Pending { NONE, PURCHASE, START }

const MENU_ROW_SCENE: PackedScene = preload("res://scenes/prep/menu_row.tscn")
const INGREDIENT_ROW_SCENE: PackedScene = preload("res://scenes/prep/ingredient_row.tscn")
const COLOR_MESSAGE := Color.WHITE
const COLOR_WARNING := Color(1.0, 0.45, 0.4)

var _menu_rows: Array[MenuRow] = []
var _ingredient_rows: Array[IngredientRow] = []
## ボタンを押した結果のお知らせ。次の操作をするまで表示する
var _notice: String = ""
## 確認ダイアログで何を聞いているか
var _pending: Pending = Pending.NONE

@onready var _menu_title: Label = %MenuTitle
@onready var _menu_help: Label = %MenuHelp
@onready var _ingredient_title: Label = %IngredientTitle
@onready var _ingredient_help: Label = %IngredientHelp
@onready var _menu_list: VBoxContainer = %MenuList
@onready var _ingredient_list: VBoxContainer = %IngredientList
@onready var _prep_total_label: Label = %PrepTotalLabel
@onready var _repeat_button: Button = %RepeatPrepButton
@onready var _shelf_plan: ShelfPlanPanel = %ShelfPlanPanel
@onready var _message_label: Label = %MessageLabel
@onready var _pace_label: Label = %PaceLabel
@onready var _purchase_total_label: Label = %PurchaseTotalLabel
@onready var _purchase_note_label: Label = %PurchaseNoteLabel
@onready var _purchase_button: Button = %PurchaseButton
@onready var _start_button: Button = %StartButton
@onready var _dialog: ConfirmDialog = %ConfirmDialog
@onready var _detail: DetailPopup = %DetailPopup


func _ready() -> void:
	_menu_title.text = UIText.PREP_MENU_TITLE
	_menu_help.text = UIText.PREP_MENU_HELP
	_ingredient_title.text = UIText.PREP_INGREDIENT_TITLE
	_ingredient_help.text = UIText.PREP_INGREDIENT_HELP
	_start_button.text = UIText.PREP_START
	_repeat_button.text = UIText.PREP_REPEAT
	_purchase_button.text = UIText.PREP_PURCHASE_BUTTON

	for dish: DishData in Database.dishes:
		var row: MenuRow = MENU_ROW_SCENE.instantiate() as MenuRow
		_menu_list.add_child(row)
		row.setup(dish)
		row.prep_changed.connect(_on_prep_changed)
		row.detail_requested.connect(_show_dish_detail)
		row.detail_closed.connect(_detail.close)
		_menu_rows.append(row)

	for ing: IngredientData in Database.ingredients:
		var row: IngredientRow = INGREDIENT_ROW_SCENE.instantiate() as IngredientRow
		_ingredient_list.add_child(row)
		row.setup(ing)
		row.purchase_changed.connect(_on_purchase_changed)
		row.detail_requested.connect(_show_ingredient_detail)
		row.detail_closed.connect(_detail.close)
		_ingredient_rows.append(row)

	_shelf_plan.add_requested.connect(_on_shelf_add)
	_shelf_plan.remove_requested.connect(_on_shelf_remove)
	_shelf_plan.clear_requested.connect(_on_shelf_clear)
	GameState.inventory_changed.connect(_refresh)
	GameState.money_changed.connect(func(_v: int) -> void: _refresh())
	_repeat_button.pressed.connect(_on_repeat_pressed)
	_purchase_button.pressed.connect(_on_purchase_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_dialog.answered.connect(_on_dialog_answered)
	_refresh()


func _refresh() -> void:
	var needs: Dictionary = GameState.get_ingredient_needs()
	var expected: Dictionary = GameState.get_expected_orders()
	var any_short: bool = false
	for row: MenuRow in _menu_rows:
		row.refresh(expected)
	for row: IngredientRow in _ingredient_rows:
		row.refresh(needs)
		if GameState.get_shortage(row.ingredient.id, needs) > 0:
			any_short = true
	_shelf_plan.refresh()

	_prep_total_label.text = UIText.PREP_TOTAL % GameState.get_total_prep()
	_repeat_button.disabled = not GameState.has_last_prep()
	_refresh_purchase()

	var has_prep: bool = GameState.get_total_prep() > 0
	_start_button.disabled = not has_prep
	if _notice != "":
		_set_message(_notice, COLOR_MESSAGE)
	elif not has_prep:
		_set_message(UIText.PREP_NEED_PREP, COLOR_WARNING)
	elif any_short:
		_set_message(UIText.PREP_SHORTAGE_WARNING, COLOR_WARNING)
	else:
		_set_message(UIText.PREP_HINT, COLOR_MESSAGE)

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
	var affordable: bool = GameState.can_afford_purchase()
	_purchase_note_label.visible = has_plan and not affordable
	if not affordable:
		_purchase_note_label.text = UIText.PREP_PURCHASE_SHORT_MONEY % UIText.money(total - GameState.money)
	_purchase_button.disabled = not has_plan or not affordable


func _set_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)


func _on_prep_changed(dish_id: String, delta: int) -> void:
	_notice = ""
	GameState.change_prep(dish_id, delta)


func _on_purchase_changed(ingredient_id: String, delta: int) -> void:
	_notice = ""
	GameState.change_purchase(ingredient_id, delta)


func _on_shelf_add(dish_id: String) -> void:
	_notice = ""
	GameState.add_to_shelf_plan(dish_id)


func _on_shelf_remove(index: int) -> void:
	_notice = ""
	GameState.remove_from_shelf_plan(index)


func _on_shelf_clear() -> void:
	_notice = ""
	GameState.clear_shelf_plan()


func _on_repeat_pressed() -> void:
	var complete: bool = GameState.apply_last_prep()
	_notice = UIText.PREP_REPEAT_DONE if complete else UIText.PREP_REPEAT_PARTIAL
	_refresh()


func _on_purchase_pressed() -> void:
	if not GameState.has_purchase_plan() or not GameState.can_afford_purchase():
		return
	_pending = Pending.PURCHASE
	_dialog.ask(UIText.PREP_PURCHASE_CONFIRM % UIText.money(GameState.get_purchase_total()),
		UIText.PREP_PURCHASE_OK, UIText.PREP_CANCEL)


func _on_start_pressed() -> void:
	if GameState.get_total_prep() <= 0:
		return
	if GameState.has_purchase_plan():
		_pending = Pending.START
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
				_notice = UIText.PREP_PURCHASE_DONE % UIText.money(total)
				_refresh()
		Pending.START:
			# 仕入れ予定は捨てて営業を始める
			GameState.clear_purchase_plan()
			start_requested.emit()


# ---------------------------------------------------------------
# 長押しの詳細
# ---------------------------------------------------------------

## 料理の詳細（料理の一覧は左側なので、右側に出す）
func _show_dish_detail(dish_id: String) -> void:
	var dish: DishData = Database.get_dish(dish_id)
	if dish == null:
		return
	var cost: int = Database.get_dish_cost(dish)
	var expected: Dictionary = GameState.get_expected_orders()
	var lines: PackedStringArray = PackedStringArray()
	lines.append(UIText.DETAIL_DISH_PRICE % [UIText.money(dish.price), UIText.money(cost), UIText.money(dish.price - cost)])
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


## 食材の詳細（食材の一覧は右側なので、左側に出す）
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
	for dish: DishData in Database.dishes:
		if dish.ingredients.has(ingredient_id):
			used = true
			lines.append(UIText.DETAIL_ING_USED_ROW % [dish.display_name, int(dish.ingredients[ingredient_id]), GameState.get_prep_count(dish.id)])
	if not used:
		lines.append(UIText.DETAIL_ING_UNUSED)
	_detail.open(ing.display_name, lines, DetailPopup.Placement.LEFT)


## 「米×1・鶏肉×1・キャベツ×1」（数も必ず出す）
func _ingredient_list_text(dish: DishData) -> String:
	var names: PackedStringArray = PackedStringArray()
	for ing: IngredientData in Database.ingredients:
		if dish.ingredients.has(ing.id):
			names.append("%s×%d" % [ing.display_name, int(dish.ingredients[ing.id])])
	return "・".join(names)
