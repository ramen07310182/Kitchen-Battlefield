class_name ReadyShelf
extends PanelContainer
## 完成品置き場。料理をタップすると「持つ」、もう一度タップすると持つのをやめる。
## 持っている料理は、提供するまで枠に残る（枠は空かない）。

signal contents_changed
signal held_changed(dish_id: String)

const COLUMNS := 3

var _slots: Array[String] = []
var _buttons: Array[Button] = []
var _held_index: int = -1

@onready var _title_label: Label = %TitleLabel
@onready var _held_panel: PanelContainer = %HeldPanel
@onready var _held_label: Label = %HeldLabel
@onready var _grid: GridContainer = %SlotGrid


func _ready() -> void:
	add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.22, 0.24, 0.26)))
	_title_label.text = UIText.SHELF_TITLE
	_grid.columns = COLUMNS


func setup(capacity: int) -> void:
	for i: int in capacity:
		_slots.append("")
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(46, 34)
		button.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
		button.add_theme_color_override("font_disabled_color", Color(0.1, 0.08, 0.05))
		button.pressed.connect(_on_slot_pressed.bind(i))
		_grid.add_child(button)
		_buttons.append(button)
	_refresh()


func add_dish(dish_id: String) -> bool:
	var index: int = _slots.find("")
	if index < 0:
		return false
	_slots[index] = dish_id
	_refresh()
	contents_changed.emit()
	return true


func free_count() -> int:
	return _slots.count("")


func get_held_dish() -> String:
	if _held_index < 0:
		return ""
	return _slots[_held_index]


## 持っている料理を提供したので枠から消す
func remove_held() -> void:
	if _held_index < 0:
		return
	_slots[_held_index] = ""
	_held_index = -1
	_refresh()
	contents_changed.emit()
	held_changed.emit("")


func _on_slot_pressed(index: int) -> void:
	if _slots[index] == "":
		return
	_held_index = -1 if _held_index == index else index
	_refresh()
	held_changed.emit(get_held_dish())


func _refresh() -> void:
	for i: int in _buttons.size():
		var button: Button = _buttons[i]
		var dish: DishData = Database.get_dish(_slots[i]) if _slots[i] != "" else null
		if dish == null:
			button.text = ""
			button.disabled = true
			UIUtil.apply_button_style(button, UIUtil.flat_box(Color(0.15, 0.16, 0.17), Color(0.35, 0.35, 0.35), 1))
		else:
			button.text = dish.short_name
			button.disabled = false
			var held: bool = i == _held_index
			var box: StyleBoxFlat = UIUtil.flat_box(dish.color, Color(1, 1, 1) if held else dish.color.darkened(0.4), 3 if held else 1)
			UIUtil.apply_button_style(button, box)
			button.modulate = Color(0.6, 0.6, 0.6) if _held_index >= 0 and not held else Color.WHITE

	var held_dish: DishData = Database.get_dish(get_held_dish()) if _held_index >= 0 else null
	if held_dish != null:
		_held_label.text = UIText.HOLDING % held_dish.display_name
		_held_panel.add_theme_stylebox_override("panel", UIUtil.flat_box(held_dish.color, Color.WHITE, 2))
		_held_label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	else:
		_held_label.text = UIText.HOLDING_NONE
		_held_panel.add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.15, 0.16, 0.17)))
		_held_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
