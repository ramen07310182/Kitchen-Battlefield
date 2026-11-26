class_name IngredientRow
extends PanelContainer
## 営業準備画面の1行: 食材の在庫と仕入れ予定、必要数の目安、仕入れ予定の増減ボタン。
## 「+1／+5」「-1／-5」は仕入れ予定を変えるだけで、お金と在庫は「仕入れる」まで変わらない。
## 目安より確定した在庫が少ないときは赤く表示し、予定どおり仕入れると足りるかも出す。

signal purchase_changed(ingredient_id: String, delta: int)

const COLOR_OK := Color.WHITE
const COLOR_SUB := Color(0.7, 0.7, 0.7)
const COLOR_SHORT := Color(1.0, 0.4, 0.35)
const COLOR_PLAN_OK := Color(1.0, 0.85, 0.45)
const COLOR_PLANNED := Color(0.55, 0.85, 1.0)

var ingredient: IngredientData

var _box_normal: StyleBoxFlat
var _box_short: StyleBoxFlat

@onready var _swatch: ColorRect = %Swatch
@onready var _name_label: Label = %NameLabel
@onready var _stock_label: Label = %StockLabel
@onready var _need_label: Label = %NeedLabel
@onready var _minus_large: Button = %MinusLargeButton
@onready var _minus_small: Button = %MinusSmallButton
@onready var _plus_small: Button = %PlusSmallButton
@onready var _plus_large: Button = %PlusLargeButton


func _ready() -> void:
	_box_normal = UIUtil.flat_box(Color(0.2, 0.17, 0.15))
	_box_short = UIUtil.flat_box(Color(0.3, 0.14, 0.13), COLOR_SHORT, 1)
	add_theme_stylebox_override("panel", _box_normal)
	var cfg: GameConfig = Database.config
	_minus_large.text = UIText.PREP_PURCHASE_STEP % -cfg.buy_step_large
	_minus_small.text = UIText.PREP_PURCHASE_STEP % -cfg.buy_step_small
	_plus_small.text = UIText.PREP_PURCHASE_STEP % cfg.buy_step_small
	_plus_large.text = UIText.PREP_PURCHASE_STEP % cfg.buy_step_large
	_minus_large.pressed.connect(func() -> void: purchase_changed.emit(ingredient.id, -cfg.buy_step_large))
	_minus_small.pressed.connect(func() -> void: purchase_changed.emit(ingredient.id, -cfg.buy_step_small))
	_plus_small.pressed.connect(func() -> void: purchase_changed.emit(ingredient.id, cfg.buy_step_small))
	_plus_large.pressed.connect(func() -> void: purchase_changed.emit(ingredient.id, cfg.buy_step_large))


## add_child の後に呼ぶ
func setup(data: IngredientData) -> void:
	ingredient = data
	_swatch.color = ingredient.color
	_name_label.text = "%s  %s" % [ingredient.display_name, UIText.money(ingredient.price)]


## needs: GameState.get_ingredient_needs() の結果
func refresh(needs: Dictionary) -> void:
	var stock: int = GameState.get_stock(ingredient.id)
	var reserved: int = GameState.get_reserved(ingredient.id)
	var planned: int = GameState.get_planned_purchase(ingredient.id)
	var need: int = int(needs.get(ingredient.id, 0))
	var shortage: int = GameState.get_shortage(ingredient.id, needs)
	var shortage_after: int = GameState.get_shortage_after_purchase(ingredient.id, needs)

	if reserved > 0:
		_stock_label.text = UIText.PREP_STOCK_RESERVED % [stock, reserved, planned]
	else:
		_stock_label.text = UIText.PREP_STOCK % [stock, planned]

	var short: bool = shortage > 0
	if need <= 0:
		_need_label.text = UIText.PREP_NEED_UNUSED
		_need_label.add_theme_color_override("font_color", COLOR_SUB)
	elif not short:
		_need_label.text = UIText.PREP_NEED % need
		_need_label.add_theme_color_override("font_color", COLOR_SUB)
	elif shortage_after <= 0:
		_need_label.text = UIText.PREP_NEED_SHORT_PLAN_OK % [need, shortage]
		_need_label.add_theme_color_override("font_color", COLOR_PLAN_OK)
	else:
		_need_label.text = UIText.PREP_NEED_SHORT % [need, shortage_after]
		_need_label.add_theme_color_override("font_color", COLOR_SHORT)

	var stock_color: Color = COLOR_SHORT if short else COLOR_OK
	if planned > 0:
		stock_color = COLOR_PLANNED if not short or shortage_after <= 0 else COLOR_SHORT
	_stock_label.add_theme_color_override("font_color", stock_color)
	add_theme_stylebox_override("panel", _box_short if short else _box_normal)

	_minus_large.disabled = planned <= 0
	_minus_small.disabled = planned <= 0
