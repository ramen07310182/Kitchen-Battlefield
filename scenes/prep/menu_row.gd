class_name MenuRow
extends PanelContainer
## 営業準備画面の1行: 料理の仕込み数（0〜99）。仕込み数が1以上なら今日出す料理になる。前回売れた数も小さく出す。
## 「－＋」は長押しで続けて増減する（HoldRepeatButton）。

signal prep_changed(dish_id: String, delta: int)
## ボタン以外の所を長押しした（詳細を出す）／指を離した（詳細を閉じる）
signal detail_requested(dish_id: String)
signal detail_closed

var dish: DishData
var _box_on: StyleBoxFlat
var _box_off: StyleBoxFlat

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
	_box_on = UIColors.card_box()
	_box_off = UIColors.card_box(UIColors.ROW_DIM, UIColors.ROW_DIM_BORDER)
	add_theme_stylebox_override("panel", _box_on)
	_minus_button.step_requested.connect(func(step: int) -> void: prep_changed.emit(dish.id, step))
	_plus_button.step_requested.connect(func(step: int) -> void: prep_changed.emit(dish.id, step))
	_long_press.long_pressed.connect(func() -> void: detail_requested.emit(dish.id))
	_long_press.finished.connect(detail_closed.emit)


## add_child の後に呼ぶ
func setup(data: DishData) -> void:
	dish = data
	_swatch.color = dish.color
	# トッピングは「卵焼き  +¥150」（料理に追加する金額）
	_name_label.text = "%s  %s%s" % [dish.display_name, "+" if dish.is_topping() else "", UIText.money(dish.price)]


## expected_orders: GameState.get_expected_orders() の結果
func refresh(expected_orders: Dictionary) -> void:
	var on: bool = GameState.is_on_menu(dish.id)
	# 仕込み数0（今日は出さない）の行は、少しくすんだカードにする
	add_theme_stylebox_override("panel", _box_on if on else _box_off)
	var count: int = GameState.get_prep_count(dish.id)
	_info_label.text = UIText.PREP_DISH_INFO % [
		UIText.money(Database.get_dish_cost(dish)),
		ceili(float(expected_orders.get(dish.id, 0.0))),
		Database.get_ingredient_names(dish),
	]
	# 仕込み数が0の料理（今日は出さない）は少し暗くする
	_name_label.add_theme_color_override("font_color", UIColors.TEXT if on else UIColors.TEXT_SUB)
	_info_label.add_theme_color_override("font_color", UIColors.TEXT_SUB)
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
		# 売り逃しの数は出さない（どれだけ仕込むかは自分で考える。結果画面ではその日の売り逃しを見られる）
		var prepared: int = int(GameState.last_prep_counts.get(dish.id, 0))
		if sold >= prepared and prepared > 0:
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
