class_name IngredientRow
extends PanelContainer
## 営業準備画面の1行: 食材の在庫と仕入れボタン。

signal buy_requested(ingredient_id: String, count: int)

var ingredient: IngredientData

@onready var _swatch: ColorRect = %Swatch
@onready var _name_label: Label = %NameLabel
@onready var _stock_label: Label = %StockLabel
@onready var _buy_small: Button = %BuySmallButton
@onready var _buy_large: Button = %BuyLargeButton


func _ready() -> void:
	add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.2, 0.17, 0.15)))
	var cfg: GameConfig = Database.config
	_buy_small.pressed.connect(func() -> void: buy_requested.emit(ingredient.id, cfg.buy_step_small))
	_buy_large.pressed.connect(func() -> void: buy_requested.emit(ingredient.id, cfg.buy_step_large))


## add_child の後に呼ぶ
func setup(data: IngredientData) -> void:
	ingredient = data
	_swatch.color = ingredient.color
	_name_label.text = "%s  %s" % [ingredient.display_name, UIText.money(ingredient.price)]
	refresh()


func refresh() -> void:
	var cfg: GameConfig = Database.config
	var stock: int = GameState.get_stock(ingredient.id)
	var reserved: int = GameState.get_reserved(ingredient.id)
	if reserved > 0:
		_stock_label.text = UIText.PREP_STOCK_RESERVED % [stock, reserved]
	else:
		_stock_label.text = UIText.PREP_STOCK % stock
	_buy_small.text = UIText.PREP_BUY % cfg.buy_step_small
	_buy_large.text = UIText.PREP_BUY % cfg.buy_step_large
	_buy_small.disabled = GameState.money < ingredient.price * cfg.buy_step_small
	_buy_large.disabled = GameState.money < ingredient.price * cfg.buy_step_large
