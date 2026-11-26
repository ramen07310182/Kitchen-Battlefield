class_name ShelfPlanPanel
extends PanelContainer
## 営業準備画面の「開店時の置き場」。営業開始の時点で置き場に並べておく料理を決める（最大6個）。
## 下の料理ボタンを押すと空いている枠に並べ、並べた枠を押すと外す。並べた分は仕込み数から使う。
## 料理ボタンは仕込み数が1以上の料理だけ出し、入りきらなければ折り返す。

signal add_requested(dish_id: String)
signal remove_requested(index: int)
signal clear_requested

const SLOT_SIZE := Vector2(40, 28)

var _slot_buttons: Array[Button] = []
var _add_buttons: Dictionary = {}  # 料理id -> Button
var _clear_button: Button

@onready var _title_label: Label = %TitleLabel
@onready var _slots: HBoxContainer = %Slots
@onready var _add_row: HFlowContainer = %AddRow
@onready var _header: HBoxContainer = %Header


func _ready() -> void:
	add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.18, 0.19, 0.2)))
	for i: int in Database.config.shelf_capacity:
		var slot: Button = Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
		slot.add_theme_color_override("font_disabled_color", Color(0.1, 0.08, 0.05))
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.pressed.connect(func() -> void: remove_requested.emit(i))
		_slots.add_child(slot)
		_slot_buttons.append(slot)
	for dish: DishData in Database.dishes:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(56, 28)
		button.text = UIText.PREP_SHELF_ADD % dish.short_name
		button.pressed.connect(func() -> void: add_requested.emit(dish.id))
		_add_row.add_child(button)
		_add_buttons[dish.id] = button
	_clear_button = Button.new()
	_clear_button.custom_minimum_size = Vector2(64, 24)
	_clear_button.text = UIText.PREP_SHELF_CLEAR
	_clear_button.pressed.connect(clear_requested.emit)
	_header.add_child(_clear_button)


func refresh() -> void:
	var cfg: GameConfig = Database.config
	var plan: Array[String] = GameState.shelf_plan
	_title_label.text = UIText.PREP_SHELF_TITLE % [plan.size(), cfg.shelf_capacity]
	for i: int in _slot_buttons.size():
		var slot: Button = _slot_buttons[i]
		var dish: DishData = Database.get_dish(plan[i]) if i < plan.size() else null
		if dish == null:
			slot.text = ""
			slot.icon = null
			slot.disabled = true
			UIUtil.apply_button_style(slot, UIUtil.flat_box(Color(0.12, 0.13, 0.14), Color(0.35, 0.35, 0.35), 1))
		else:
			var icon: Texture2D = SpriteLibrary.get_icon(SpriteKeys.dish(dish.id))
			slot.icon = icon
			slot.text = "" if icon != null else dish.short_name
			slot.disabled = false
			UIUtil.apply_button_style(slot, UIUtil.flat_box(dish.color, dish.color.darkened(0.4), 1))
	for dish: DishData in Database.dishes:
		var button: Button = _add_buttons[dish.id]
		button.visible = GameState.is_on_menu(dish.id)
		button.disabled = not GameState.can_add_to_shelf_plan(dish.id)
	_clear_button.disabled = plan.is_empty()
