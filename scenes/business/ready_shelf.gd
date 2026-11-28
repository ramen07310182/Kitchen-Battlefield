class_name ReadyShelf
extends PanelContainer
## 完成品置き場。料理をタップすると「持つ」、もう一度タップすると持つのをやめる。
## 持っている料理は、提供するまで枠に残る（枠は空かない）。
## ホールスタッフが取りに来る枠は「予約」になり、プレイヤーは持てない（暗く出す）。スタッフが取り終えると枠が空く。

signal contents_changed
signal held_changed(dish_id: String)

## 枠が6つまでは3列、それより多ければ4列に並べる
const COLUMNS := 3
const COLUMNS_WIDE := 4

var _slots: Array[String] = []
var _buttons: Array[Button] = []
var _held_index: int = -1
## スタッフが予約した枠 { 枠の番号: true }
var _reserved: Dictionary = {}
var _slot_size: Vector2 = Vector2(46, 32)

@onready var _title_label: Label = %TitleLabel
@onready var _held_panel: PanelContainer = %HeldPanel
@onready var _held_label: Label = %HeldLabel
@onready var _grid: GridContainer = %SlotGrid


func _ready() -> void:
	add_theme_stylebox_override("panel", UISkin.panel_box(SpriteKeys.PANEL, UIUtil.flat_box(UIColors.BIZ_PANEL)))
	_title_label.text = UIText.SHELF_TITLE


func setup(capacity: int) -> void:
	_grid.columns = COLUMNS if capacity <= 6 else COLUMNS_WIDE
	var slot_size: Vector2 = Vector2(46, 32) if capacity <= 6 else Vector2(40, 30)
	_slot_size = slot_size
	for i: int in capacity:
		_slots.append("")
		var button: Button = Button.new()
		button.custom_minimum_size = slot_size
		button.add_theme_color_override("font_color", UIColors.ON_ITEM)
		button.add_theme_color_override("font_disabled_color", UIColors.ON_ITEM)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
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


## スタッフが取れる枠（その料理があって、プレイヤーが持っておらず、予約されていない）。なければ -1
func find_available_slot(item_id: String) -> int:
	for i: int in _slots.size():
		if _slots[i] == item_id and i != _held_index and not _reserved.has(i):
			return i
	return -1


func is_reserved(index: int) -> bool:
	return _reserved.has(index)


## スタッフが取りに来る枠として予約する
func reserve_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	_reserved[index] = true
	_refresh()


func unreserve_slot(index: int) -> void:
	_reserved.erase(index)
	_refresh()


## 予約した枠から料理を取り出す（枠が空く）。取り出した料理のid
func take_reserved(index: int) -> String:
	if not _reserved.has(index):
		return ""
	_reserved.erase(index)
	var item_id: String = _slots[index]
	_slots[index] = ""
	_refresh()
	contents_changed.emit()
	return item_id


func _on_slot_pressed(index: int) -> void:
	if _slots[index] == "" or _reserved.has(index):
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
			button.icon = null
			button.disabled = true
			UIUtil.apply_button_style(button, UIUtil.flat_box(UIColors.BIZ_PANEL_DARK, UIColors.BIZ_SLOT_BORDER, 1))
		else:
			# 料理の絵があれば絵、なければ短い名前を出す
			var dish_icon: Texture2D = SpriteLibrary.get_icon(SpriteKeys.dish(dish.id))
			button.icon = dish_icon
			button.text = "" if dish_icon != null else dish.short_name
			button.add_theme_font_size_override("font_size", UIUtil.fit_font_size(dish.short_name, _slot_size.x - 6.0, 13))
			button.disabled = _reserved.has(i)
			var held: bool = i == _held_index
			var box: StyleBoxFlat = UIUtil.flat_box(dish.color, UIColors.BIZ_HELD_BORDER if held else dish.color.darkened(0.4), 3 if held else 1)
			UIUtil.apply_button_style(button, box)
			button.modulate = UIColors.BIZ_DIMMED if _held_index >= 0 and not held else Color(1, 1, 1, 1)
			if _reserved.has(i):
				# スタッフが取りに来ている枠
				button.modulate = UIColors.BIZ_RESERVED

	var held_dish: DishData = Database.get_dish(get_held_dish()) if _held_index >= 0 else null
	if held_dish != null:
		_held_label.text = UIText.HOLDING % held_dish.short_name
		_held_panel.add_theme_stylebox_override("panel", UIUtil.flat_box(held_dish.color, UIColors.BIZ_HELD_BORDER, 2))
		_held_label.add_theme_color_override("font_color", UIColors.ON_ITEM)
	else:
		_held_label.text = UIText.HOLDING_NONE
		_held_panel.add_theme_stylebox_override("panel", UIUtil.flat_box(UIColors.BIZ_PANEL_DARK))
		_held_label.add_theme_color_override("font_color", UIColors.BIZ_TEXT_SUB)
