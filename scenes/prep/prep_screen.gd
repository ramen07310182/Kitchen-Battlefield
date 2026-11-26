extends Control
## 営業準備画面: 今日のメニュー・食材の仕入れ・仕込み。
## 食材は「今日のメニューと仕込みから見た必要数の目安」と比べ、足りなさそうなら赤く表示する。

signal start_requested

const MENU_ROW_SCENE: PackedScene = preload("res://scenes/prep/menu_row.tscn")
const INGREDIENT_ROW_SCENE: PackedScene = preload("res://scenes/prep/ingredient_row.tscn")
const COLOR_MESSAGE := Color.WHITE
const COLOR_WARNING := Color(1.0, 0.45, 0.4)

var _menu_rows: Array[MenuRow] = []
var _ingredient_rows: Array[IngredientRow] = []
## ボタンを押した結果のお知らせ。次の操作をするまで表示する
var _notice: String = ""

@onready var _menu_title: Label = %MenuTitle
@onready var _ingredient_title: Label = %IngredientTitle
@onready var _menu_list: VBoxContainer = %MenuList
@onready var _ingredient_list: VBoxContainer = %IngredientList
@onready var _prep_total_label: Label = %PrepTotalLabel
@onready var _repeat_button: Button = %RepeatPrepButton
@onready var _message_label: Label = %MessageLabel
@onready var _pace_label: Label = %PaceLabel
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_menu_title.text = UIText.PREP_MENU_TITLE
	_ingredient_title.text = UIText.PREP_INGREDIENT_TITLE
	_start_button.text = UIText.PREP_START
	_repeat_button.text = UIText.PREP_REPEAT

	for dish: DishData in Database.dishes:
		var row: MenuRow = MENU_ROW_SCENE.instantiate() as MenuRow
		_menu_list.add_child(row)
		row.setup(dish)
		row.menu_toggled.connect(_on_menu_toggled)
		row.prep_changed.connect(_on_prep_changed)
		_menu_rows.append(row)

	for ing: IngredientData in Database.ingredients:
		var row: IngredientRow = INGREDIENT_ROW_SCENE.instantiate() as IngredientRow
		_ingredient_list.add_child(row)
		row.setup(ing)
		row.buy_requested.connect(_on_buy_requested)
		_ingredient_rows.append(row)

	GameState.inventory_changed.connect(_refresh)
	GameState.money_changed.connect(func(_v: int) -> void: _refresh())
	_repeat_button.pressed.connect(_on_repeat_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_refresh()


func _refresh() -> void:
	var needs: Dictionary = GameState.get_ingredient_needs()
	var any_short: bool = false
	for row: MenuRow in _menu_rows:
		row.refresh()
	for row: IngredientRow in _ingredient_rows:
		row.refresh(needs)
		if GameState.get_shortage(row.ingredient.id, needs) > 0:
			any_short = true

	_prep_total_label.text = UIText.PREP_TOTAL % [GameState.get_total_prep(), Database.config.shelf_capacity]
	_repeat_button.disabled = not GameState.has_last_prep()

	var has_menu: bool = not GameState.today_menu.is_empty()
	_start_button.disabled = not has_menu
	if not has_menu:
		_set_message(UIText.PREP_NEED_MENU, COLOR_WARNING)
	elif _notice != "":
		_set_message(_notice, COLOR_MESSAGE)
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


func _set_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)


func _on_menu_toggled(dish_id: String, on: bool) -> void:
	_notice = ""
	GameState.set_on_menu(dish_id, on)


func _on_prep_changed(dish_id: String, delta: int) -> void:
	_notice = ""
	GameState.change_prep(dish_id, delta)


func _on_buy_requested(ingredient_id: String, count: int) -> void:
	_notice = ""
	GameState.buy_ingredient(ingredient_id, count)


func _on_repeat_pressed() -> void:
	var complete: bool = GameState.apply_last_prep()
	_notice = UIText.PREP_REPEAT_DONE if complete else UIText.PREP_REPEAT_PARTIAL
	_refresh()


func _on_start_pressed() -> void:
	if GameState.today_menu.is_empty():
		return
	start_requested.emit()
