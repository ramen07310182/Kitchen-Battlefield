class_name PrepMenuStep
extends HBoxContainer
## 営業準備の手順①「仕込み」: 解放済みの料理の仕込み数（0〜99）を決める。
## 右の小さな欄に、仕込みに使う食材の「必要数／在庫」を出す（足りない食材は赤）。
## まだ解放していない料理は、次に解放される数品だけ、料理の一覧の最後に「○○で解放」と暗く出す。
## 料理の一覧の下に区切りを入れて、トッピングの一覧（仕込み数の決め方は料理と同じ）を出す。

## 行の長押し（kind は "dish"）／指を離した
signal detail_requested(kind: String, id: String)
signal detail_closed
## 画面の下に出すお知らせ
signal notice_requested(text: String)

const MENU_ROW_SCENE: PackedScene = preload("res://scenes/prep/menu_row.tscn")
const COLOR_OK := UIColors.TEXT
const COLOR_SHORT := UIColors.DANGER
const COLOR_LOCKED := UIColors.TEXT_DISABLED
## 一覧の最後に出す「まだ解放していない料理」の数（次に解放される順）
const LOCKED_PREVIEW_COUNT := 3
## トッピングの一覧の最後に出す「まだ解放していないトッピング」の数
const LOCKED_TOPPING_PREVIEW_COUNT := 1

var _menu_rows: Array[MenuRow] = []
var _locked_labels: Array[Label] = []
var _topping_header: Label

@onready var _help_label: Label = %HelpLabel
@onready var _total_label: Label = %TotalLabel
@onready var _repeat_button: Button = %RepeatButton
@onready var _menu_list: VBoxContainer = %MenuList
@onready var _usage_panel: PanelContainer = %UsagePanel
@onready var _usage_title: Label = %UsageTitle
@onready var _usage_list: VBoxContainer = %UsageList


func _ready() -> void:
	_help_label.text = UIText.PREP_MENU_HELP
	_repeat_button.text = UIText.PREP_REPEAT
	_usage_title.text = UIText.PREP_USAGE_TITLE
	_usage_panel.add_theme_stylebox_override("panel", UIColors.panel_box(UIColors.PANEL))
	_repeat_button.pressed.connect(_on_repeat_pressed)
	_rebuild_rows()


## 解放済みの料理の行と、まだ解放していない料理の行を作り直す（解放が増えたときにも呼ぶ）
func _rebuild_rows() -> void:
	for child: Node in _menu_list.get_children():
		child.queue_free()
	_menu_rows.clear()
	_locked_labels.clear()
	_topping_header = null
	for dish: DishData in GameState.get_unlocked_dishes():
		_add_menu_row(dish)
	for dish: DishData in GameState.get_locked_dishes().slice(0, LOCKED_PREVIEW_COUNT):
		_add_locked_row(dish)
	# トッピング（区切りの見出しの下に並べる）
	var toppings: Array[DishData] = GameState.get_unlocked_toppings()
	var locked_toppings: Array[DishData] = GameState.get_locked_toppings().slice(0, LOCKED_TOPPING_PREVIEW_COUNT)
	if toppings.is_empty() and locked_toppings.is_empty():
		return
	_topping_header = Label.new()
	_topping_header.text = UIText.PREP_TOPPING_TITLE
	_topping_header.theme_type_variation = &"HeaderLabel"
	_topping_header.theme_type_variation = &"SectionLabel"
	var header_margin: MarginContainer = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_top", 8)
	header_margin.add_child(_topping_header)
	_menu_list.add_child(header_margin)
	for dish: DishData in toppings:
		_add_menu_row(dish)
	for dish: DishData in locked_toppings:
		_add_locked_row(dish)


func _add_menu_row(dish: DishData) -> void:
	var row: MenuRow = MENU_ROW_SCENE.instantiate() as MenuRow
	_menu_list.add_child(row)
	row.setup(dish)
	row.prep_changed.connect(_on_prep_changed)
	row.detail_requested.connect(func(dish_id: String) -> void: detail_requested.emit("dish", dish_id))
	row.detail_closed.connect(detail_closed.emit)
	_menu_rows.append(row)


func _add_locked_row(dish: DishData) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIColors.card_box(UIColors.ROW_DIM, UIColors.ROW_DIM_BORDER))
	var label: Label = Label.new()
	label.text = PrepMenuStep.locked_text(dish)
	label.add_theme_color_override("font_color", COLOR_LOCKED)
	panel.add_child(label)
	_menu_list.add_child(panel)
	_locked_labels.append(label)


func refresh() -> void:
	var expected: Dictionary = GameState.get_expected_orders()
	for row: MenuRow in _menu_rows:
		row.refresh(expected)
	var toppings: int = GameState.get_total_topping_prep()
	if toppings > 0:
		_total_label.text = UIText.PREP_TOTAL_WITH_TOPPING % [GameState.get_total_prep(), toppings]
	else:
		_total_label.text = UIText.PREP_TOTAL % GameState.get_total_prep()
	_repeat_button.disabled = not GameState.has_last_prep()
	_refresh_usage()


## 仕込みに使う食材の「必要数／在庫」
func _refresh_usage() -> void:
	for child: Node in _usage_list.get_children():
		child.queue_free()
	var any: bool = false
	for ing: IngredientData in Database.ingredients:
		var need: int = GameState.get_reserved(ing.id)
		if need <= 0:
			continue
		any = true
		var stock: int = GameState.get_stock(ing.id)
		var label: Label = Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.text = UIText.PREP_USAGE_ROW % [ing.display_name, need, stock]
		label.add_theme_color_override("font_color", COLOR_SHORT if need > stock else COLOR_OK)
		_usage_list.add_child(label)
	if not any:
		var none: Label = Label.new()
		none.theme_type_variation = &"SmallLabel"
		none.text = UIText.PREP_USAGE_NONE
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_color_override("font_color", COLOR_LOCKED)
		_usage_list.add_child(none)


func _on_prep_changed(dish_id: String, delta: int) -> void:
	notice_requested.emit("")
	GameState.change_prep(dish_id, delta)


func _on_repeat_pressed() -> void:
	var complete: bool = GameState.apply_last_prep()
	notice_requested.emit(UIText.PREP_REPEAT_DONE if complete else UIText.PREP_REPEAT_PARTIAL)


## まだ解放していない料理の説明（「人気店で解放」「30日目から解放」「人気店・30日目以降に解放」）
static func locked_text(dish: DishData) -> String:
	if dish.unlock_rank > 1 and dish.unlock_day > 0:
		return UIText.PREP_LOCKED_BOTH % [dish.display_name, Database.get_rank_name(dish.unlock_rank), dish.unlock_day]
	if dish.unlock_day > 0:
		return UIText.PREP_LOCKED_DAY % [dish.display_name, dish.unlock_day]
	return UIText.PREP_LOCKED % [dish.display_name, Database.get_rank_name(dish.unlock_rank)]
