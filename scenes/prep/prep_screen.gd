extends Control
## 営業準備画面: 今日のメニュー・食材の仕入れ・仕込み。

signal start_requested

const MENU_ROW_SCENE: PackedScene = preload("res://scenes/prep/menu_row.tscn")
const INGREDIENT_ROW_SCENE: PackedScene = preload("res://scenes/prep/ingredient_row.tscn")

var _menu_rows: Array[MenuRow] = []
var _ingredient_rows: Array[IngredientRow] = []

@onready var _menu_title: Label = %MenuTitle
@onready var _ingredient_title: Label = %IngredientTitle
@onready var _menu_list: VBoxContainer = %MenuList
@onready var _ingredient_list: VBoxContainer = %IngredientList
@onready var _prep_total_label: Label = %PrepTotalLabel
@onready var _message_label: Label = %MessageLabel
@onready var _pace_label: Label = %PaceLabel
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_menu_title.text = UIText.PREP_MENU_TITLE
	_ingredient_title.text = UIText.PREP_INGREDIENT_TITLE
	_start_button.text = UIText.PREP_START

	for dish: DishData in Database.dishes:
		var row: MenuRow = MENU_ROW_SCENE.instantiate() as MenuRow
		_menu_list.add_child(row)
		row.setup(dish)
		row.menu_toggled.connect(GameState.set_on_menu)
		row.prep_changed.connect(GameState.change_prep)
		_menu_rows.append(row)

	for ing: IngredientData in Database.ingredients:
		var row: IngredientRow = INGREDIENT_ROW_SCENE.instantiate() as IngredientRow
		_ingredient_list.add_child(row)
		row.setup(ing)
		row.buy_requested.connect(_on_buy_requested)
		_ingredient_rows.append(row)

	GameState.inventory_changed.connect(_refresh)
	GameState.money_changed.connect(func(_v: int) -> void: _refresh())
	_start_button.pressed.connect(_on_start_pressed)
	_refresh()


func _refresh() -> void:
	for row: MenuRow in _menu_rows:
		row.refresh()
	for row: IngredientRow in _ingredient_rows:
		row.refresh()
	_prep_total_label.text = UIText.PREP_TOTAL % [GameState.get_total_prep(), Database.config.shelf_capacity]
	var has_menu: bool = not GameState.today_menu.is_empty()
	_start_button.disabled = not has_menu
	_message_label.text = UIText.PREP_HINT if has_menu else UIText.PREP_NEED_MENU
	var cfg: GameConfig = Database.config
	_pace_label.text = UIText.PREP_PACE % [
		GameState.reputation,
		1.0 / cfg.get_spawn_interval_scale(GameState.reputation),
		cfg.get_average_spawn_interval(GameState.reputation),
	]


func _on_buy_requested(ingredient_id: String, count: int) -> void:
	GameState.buy_ingredient(ingredient_id, count)


func _on_start_pressed() -> void:
	if GameState.today_menu.is_empty():
		return
	start_requested.emit()
