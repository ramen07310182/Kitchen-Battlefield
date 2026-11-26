class_name MenuRow
extends PanelContainer
## 営業準備画面の1行: 料理の仕込み数（0〜99）。仕込み数が1以上なら今日出す料理になる。前回売れた数も小さく出す。
## 「－＋」は長押しで続けて増減する（HoldRepeatButton）。

signal prep_changed(dish_id: String, delta: int)
## ボタン以外の所を長押しした（詳細を出す）／指を離した（詳細を閉じる）
signal detail_requested(dish_id: String)
signal detail_closed

var dish: DishData

@onready var _swatch: ColorRect = %Swatch
@onready var _name_label: Label = %NameLabel
@onready var _info_label: Label = %InfoLabel
@onready var _last_label: Label = %LastLabel
@onready var _warn_label: Label = %WarnLabel
@onready var _minus_button: HoldRepeatButton = %MinusButton
@onready var _count_label: Label = %CountLabel
@onready var _plus_button: HoldRepeatButton = %PlusButton
@onready var _long_press: LongPressDetector = %LongPress


func _ready() -> void:
	add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.2, 0.17, 0.15)))
	_minus_button.step_requested.connect(func(step: int) -> void: prep_changed.emit(dish.id, step))
	_plus_button.step_requested.connect(func(step: int) -> void: prep_changed.emit(dish.id, step))
	_long_press.long_pressed.connect(func() -> void: detail_requested.emit(dish.id))
	_long_press.finished.connect(detail_closed.emit)


## add_child の後に呼ぶ
func setup(data: DishData) -> void:
	dish = data
	_swatch.color = dish.color
	_name_label.text = "%s  %s" % [dish.display_name, UIText.money(dish.price)]


## expected_orders: GameState.get_expected_orders() の結果
func refresh(expected_orders: Dictionary) -> void:
	var on: bool = GameState.is_on_menu(dish.id)
	var count: int = GameState.get_prep_count(dish.id)
	_info_label.text = UIText.PREP_DISH_INFO % [
		UIText.money(Database.get_dish_cost(dish)),
		ceili(float(expected_orders.get(dish.id, 0.0))),
		Database.get_ingredient_names(dish),
	]
	# 仕込み数が0の料理（今日は出さない）は少し暗くする
	_name_label.modulate = Color.WHITE if on else Color(0.7, 0.7, 0.7)
	_info_label.modulate = _name_label.modulate
	_refresh_last_result()
	_refresh_shortage(on)
	_count_label.text = str(count)
	_minus_button.disabled = count <= 0
	_plus_button.disabled = not GameState.can_add_prep(dish)


## 「前回 ○食売れた」。前回の記録がない（1日目など）ときは出さない
func _refresh_last_result() -> void:
	if GameState.last_sold_counts.is_empty():
		_last_label.hide()
		return
	_last_label.show()
	var sold: int = GameState.get_last_sold(dish.id)
	if sold < 0:
		_last_label.text = UIText.PREP_LAST_NOT_SERVED
	else:
		var prepared: int = int(GameState.last_prep_counts.get(dish.id, 0))
		var missed: int = GameState.get_last_missed(dish.id)
		if missed > 0:
			_last_label.text = UIText.PREP_LAST_SOLD_MORE % [sold, missed]
		elif sold >= prepared and prepared > 0:
			_last_label.text = UIText.PREP_LAST_SOLD_ALL % sold
		else:
			_last_label.text = UIText.PREP_LAST_SOLD % sold


## 仕込み数に対して食材が足りなければ「食材が足りません（鶏肉 2不足）」と出す
func _refresh_shortage(on: bool) -> void:
	var shortage: Dictionary = GameState.get_dish_shortage(dish) if on else {}
	_warn_label.visible = not shortage.is_empty()
	if shortage.is_empty():
		return
	var parts: PackedStringArray = PackedStringArray()
	for ing: IngredientData in Database.ingredients:
		if shortage.has(ing.id):
			parts.append(UIText.PREP_DISH_SHORT_ITEM % [ing.display_name, int(shortage[ing.id])])
	_warn_label.text = UIText.PREP_DISH_SHORT % "・".join(parts)
