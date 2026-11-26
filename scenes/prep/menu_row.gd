class_name MenuRow
extends PanelContainer
## 営業準備画面の1行: 料理を出す／出さない と、仕込みの個数。

signal menu_toggled(dish_id: String, on: bool)
signal prep_changed(dish_id: String, delta: int)

var dish: DishData

@onready var _swatch: ColorRect = %Swatch
@onready var _name_label: Label = %NameLabel
@onready var _info_label: Label = %InfoLabel
@onready var _toggle_button: Button = %ToggleButton
@onready var _minus_button: Button = %MinusButton
@onready var _count_label: Label = %CountLabel
@onready var _plus_button: Button = %PlusButton


func _ready() -> void:
	add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.2, 0.17, 0.15)))
	_toggle_button.pressed.connect(func() -> void: menu_toggled.emit(dish.id, not GameState.is_on_menu(dish.id)))
	_minus_button.pressed.connect(func() -> void: prep_changed.emit(dish.id, -1))
	_plus_button.pressed.connect(func() -> void: prep_changed.emit(dish.id, 1))


## add_child の後に呼ぶ
func setup(data: DishData) -> void:
	dish = data
	_swatch.color = dish.color
	_name_label.text = "%s  %s" % [dish.display_name, UIText.money(dish.price)]
	_info_label.text = UIText.PREP_DISH_INFO % [
		Database.get_ingredient_names(dish),
		UIText.money(Database.get_dish_cost(dish)),
	]
	refresh()


func refresh() -> void:
	var on: bool = GameState.is_on_menu(dish.id)
	var count: int = GameState.get_prep_count(dish.id)
	_toggle_button.text = UIText.PREP_ON if on else UIText.PREP_OFF
	_toggle_button.modulate = Color.WHITE if on else Color(0.7, 0.7, 0.7)
	_name_label.modulate = Color.WHITE if on else Color(0.55, 0.55, 0.55)
	_info_label.modulate = _name_label.modulate
	_count_label.text = str(count)
	_minus_button.disabled = not on or count <= 0
	_plus_button.disabled = not GameState.can_add_prep(dish)
