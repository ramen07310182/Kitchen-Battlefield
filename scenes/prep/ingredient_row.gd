class_name IngredientRow
extends PanelContainer
## 営業準備画面の1行: 食材の在庫・必要数の目安・仕入れボタン。
## 目安より在庫が少ないときは赤く表示する。

signal buy_requested(ingredient_id: String, count: int)

const COLOR_OK := Color.WHITE
const COLOR_SUB := Color(0.7, 0.7, 0.7)
const COLOR_SHORT := Color(1.0, 0.4, 0.35)

var ingredient: IngredientData

var _box_normal: StyleBoxFlat
var _box_short: StyleBoxFlat

@onready var _swatch: ColorRect = %Swatch
@onready var _name_label: Label = %NameLabel
@onready var _stock_label: Label = %StockLabel
@onready var _need_label: Label = %NeedLabel
@onready var _buy_small: Button = %BuySmallButton
@onready var _buy_large: Button = %BuyLargeButton


func _ready() -> void:
	_box_normal = UIUtil.flat_box(Color(0.2, 0.17, 0.15))
	_box_short = UIUtil.flat_box(Color(0.3, 0.14, 0.13), COLOR_SHORT, 1)
	add_theme_stylebox_override("panel", _box_normal)
	var cfg: GameConfig = Database.config
	_buy_small.pressed.connect(func() -> void: buy_requested.emit(ingredient.id, cfg.buy_step_small))
	_buy_large.pressed.connect(func() -> void: buy_requested.emit(ingredient.id, cfg.buy_step_large))


## add_child の後に呼ぶ
func setup(data: IngredientData) -> void:
	ingredient = data
	_swatch.color = ingredient.color
	_name_label.text = "%s  %s" % [ingredient.display_name, UIText.money(ingredient.price)]


## needs: GameState.get_ingredient_needs() の結果
func refresh(needs: Dictionary) -> void:
	var cfg: GameConfig = Database.config
	var stock: int = GameState.get_stock(ingredient.id)
	var reserved: int = GameState.get_reserved(ingredient.id)
	var need: int = int(needs.get(ingredient.id, 0))
	var shortage: int = GameState.get_shortage(ingredient.id, needs)

	if reserved > 0:
		_stock_label.text = UIText.PREP_STOCK_RESERVED % [stock, reserved]
	else:
		_stock_label.text = UIText.PREP_STOCK % stock

	if need <= 0:
		_need_label.text = UIText.PREP_NEED_UNUSED
	elif shortage > 0:
		_need_label.text = UIText.PREP_NEED_SHORT % [need, shortage]
	else:
		_need_label.text = UIText.PREP_NEED % need

	var short: bool = shortage > 0
	_stock_label.add_theme_color_override("font_color", COLOR_SHORT if short else COLOR_OK)
	_need_label.add_theme_color_override("font_color", COLOR_SHORT if short else COLOR_SUB)
	add_theme_stylebox_override("panel", _box_short if short else _box_normal)

	_buy_small.text = UIText.PREP_BUY % cfg.buy_step_small
	_buy_large.text = UIText.PREP_BUY % cfg.buy_step_large
	_buy_small.disabled = GameState.money < ingredient.price * cfg.buy_step_small
	_buy_large.disabled = GameState.money < ingredient.price * cfg.buy_step_large
