class_name IngredientRow
extends PanelContainer
## 営業準備画面の1行: 食材の在庫と仕入れ予定、必要数の目安、仕入れ予定の増減ボタン。
## 「+1／+5」「-1／-5」は仕入れ予定を変えるだけで、お金と在庫は「仕入れる」まで変わらない。
## 目安より確定した在庫が少ないときは赤く表示し、予定どおり仕入れると足りるかも出す。

signal purchase_changed(ingredient_id: String, delta: int)
## ボタン以外の所を長押しした（詳細を出す）／指を離した（詳細を閉じる）
signal detail_requested(ingredient_id: String)
signal detail_closed

const COLOR_OK := UIColors.TEXT
const COLOR_SUB := UIColors.TEXT_SUB
const COLOR_SHORT := UIColors.DANGER
const COLOR_PLAN_OK := UIColors.WARNING
const COLOR_PLANNED := UIColors.PLUS

var ingredient: IngredientData

var _box_normal: StyleBoxFlat

@onready var _swatch: ColorRect = %Swatch
@onready var _name_label: Label = %NameLabel
@onready var _stock_label: Label = %StockLabel
@onready var _need_label: Label = %NeedLabel
@onready var _minus_large: Button = %MinusLargeButton
@onready var _minus_small: Button = %MinusSmallButton
@onready var _plus_small: Button = %PlusSmallButton
@onready var _plus_large: Button = %PlusLargeButton
@onready var _long_press: LongPressDetector = %LongPress


func _ready() -> void:
	_box_normal = UIColors.card_box()
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
	_long_press.long_pressed.connect(func() -> void: detail_requested.emit(ingredient.id))
	_long_press.finished.connect(detail_closed.emit)


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

	# 不足の行も白いカードのまま。左端の色の帯と、不足の文字（目安の行）だけを色にする
	# （足りない＝赤、予定でOK＝山吹）。在庫の文字はふつうの色（仕入れ予定があれば青）
	_stock_label.add_theme_color_override("font_color", COLOR_PLANNED if planned > 0 else COLOR_OK)
	if not short or need <= 0:
		_swatch.color = ingredient.color
	elif shortage_after <= 0:
		_swatch.color = UIColors.STATUS_PLAN_OK
	else:
		_swatch.color = UIColors.STATUS_SHORT
	add_theme_stylebox_override("panel", _box_normal)

	_minus_large.disabled = planned <= 0
	_minus_small.disabled = planned <= 0
