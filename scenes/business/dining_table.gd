class_name DiningTable
extends Control
## 1人用のテーブル。タップを受け取り、座っているお客さんへの配膳に使う。

signal tapped(table_index: int)

## お客さんが座る位置（テーブルの左上からの位置）。足元の6pxは机に隠れる
const SEAT_OFFSET := Vector2(28, 16)

var table_index: int = 0
## 座っている（または向かっている）お客さん
var occupant: Customer = null

@onready var _number_label: Label = %NumberLabel
@onready var _highlight: Panel = %Highlight
@onready var _tap_button: Button = %TapButton


func _ready() -> void:
	_highlight.add_theme_stylebox_override("panel", UIUtil.flat_box(Color(1.0, 0.9, 0.3, 0.12), Color(1.0, 0.9, 0.3), 2, 4))
	_highlight.hide()
	UIUtil.apply_button_style(_tap_button, StyleBoxEmpty.new())
	_tap_button.pressed.connect(func() -> void: tapped.emit(table_index))


func setup(index: int) -> void:
	table_index = index
	_number_label.text = "T%d" % (index + 1)


func is_free() -> bool:
	return occupant == null


func get_seat_position() -> Vector2:
	return position + SEAT_OFFSET


## 持っている料理を出せるテーブルを光らせる
func set_highlight(on: bool) -> void:
	_highlight.visible = on
