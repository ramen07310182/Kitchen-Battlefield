class_name PrepMenuStep
extends HBoxContainer
## 営業準備の手順①「仕込み」: 解放済みの料理の仕込み数（0〜99）を決める。
## 右の小さな欄に、仕込みに使う食材の「必要数／在庫」を出す（足りない食材は赤）。
## まだ解放していない料理は、一覧の最後に「評判 ○ で解放」と暗く出す。

## 行の長押し（kind は "dish"）／指を離した
signal detail_requested(kind: String, id: String)
signal detail_closed
## 画面の下に出すお知らせ
signal notice_requested(text: String)

const MENU_ROW_SCENE: PackedScene = preload("res://scenes/prep/menu_row.tscn")
const COLOR_OK := Color(0.85, 0.85, 0.85)
const COLOR_SHORT := Color(1.0, 0.45, 0.4)
const COLOR_LOCKED := Color(0.55, 0.55, 0.55)

var _menu_rows: Array[MenuRow] = []
var _locked_labels: Array[Label] = []

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
	_usage_panel.add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.17, 0.15, 0.14)))
	_repeat_button.pressed.connect(_on_repeat_pressed)
	_rebuild_rows()


## 解放済みの料理の行と、まだ解放していない料理の行を作り直す（解放が増えたときにも呼ぶ）
func _rebuild_rows() -> void:
	for child: Node in _menu_list.get_children():
		child.queue_free()
	_menu_rows.clear()
	_locked_labels.clear()
	for dish: DishData in GameState.get_unlocked_dishes():
		var row: MenuRow = MENU_ROW_SCENE.instantiate() as MenuRow
		_menu_list.add_child(row)
		row.setup(dish)
		row.prep_changed.connect(_on_prep_changed)
		row.detail_requested.connect(func(dish_id: String) -> void: detail_requested.emit("dish", dish_id))
		row.detail_closed.connect(detail_closed.emit)
		_menu_rows.append(row)
	for dish: DishData in GameState.get_locked_dishes():
		var panel: PanelContainer = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.15, 0.14, 0.13), Color(0.3, 0.3, 0.3), 1))
		var label: Label = Label.new()
		label.text = UIText.PREP_LOCKED % [dish.display_name, dish.unlock_reputation]
		label.modulate = COLOR_LOCKED
		panel.add_child(label)
		_menu_list.add_child(panel)
		_locked_labels.append(label)


func refresh() -> void:
	var expected: Dictionary = GameState.get_expected_orders()
	for row: MenuRow in _menu_rows:
		row.refresh(expected)
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
