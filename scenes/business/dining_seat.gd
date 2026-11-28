class_name DiningSeat
extends Control
## 1人分の席（イス）。お客さん1人が座る。タップを受け取り、座っているお客さんへの配膳に使う。
## このノードの大きさがタップできる範囲（イスより広め。お客さんの体と吹き出しまで含む）。
## テーブルは複数の席で共有する（相席）。カウンターの席は table_index = -1。

signal tapped(seat_index: int)

enum Kind {
	## カウンター（お客さんはカウンターの手前に座る）
	COUNTER,
	## テーブルの奥側（お客さんはテーブルの後ろに座る）
	TABLE_TOP,
	## テーブルの手前側（お客さんはテーブルの手前に座る）
	TABLE_BOTTOM,
}

## お客さん（24×32）の大きさ
const CUSTOMER_SIZE := Vector2(24, 32)
## イスの代用品の大きさ
const CHAIR_SIZE := Vector2(26, 14)

var seat_index: int = 0
var seat_label: String = ""
var kind: Kind = Kind.COUNTER
## 座るテーブル（カウンターなら -1）
var table_index: int = -1
## 座っている（または向かっている）お客さん
var occupant: Customer = null
## お客さんの左上の位置（客席エリアの中の座標）
var customer_position: Vector2 = Vector2.ZERO

@onready var _chair: SpriteView = %Chair
@onready var _chair_shape: ColorRect = %ChairShape
@onready var _label: Label = %SeatLabel
@onready var _highlight: Panel = %Highlight
@onready var _tap_button: Button = %TapButton


func _ready() -> void:
	_highlight.add_theme_stylebox_override("panel", UIUtil.flat_box(Color(UIColors.BIZ_SEAT_HIGHLIGHT, 0.14), UIColors.BIZ_SEAT_HIGHLIGHT, 2, 4))
	_highlight.hide()
	UIUtil.apply_button_style(_tap_button, StyleBoxEmpty.new())
	_tap_button.pressed.connect(func() -> void: tapped.emit(seat_index))


## label: 席の番号（注文状況に出す。C1・T1-3 など）、short_label: 席の近くに出す短い番号（テーブルの席は 1〜4）
func setup(index: int, label: String, short_label: String, seat_kind: Kind, table: int) -> void:
	seat_index = index
	seat_label = label
	kind = seat_kind
	table_index = table
	_label.text = short_label
	_chair.sprite_key = SpriteKeys.STOOL if kind == Kind.COUNTER else SpriteKeys.CHAIR
	_chair_shape.color = UIColors.BIZ_STOOL if kind == Kind.COUNTER else UIColors.BIZ_CHAIR


## 席の置き場所を決める。tap_rect: タップできる範囲、customer_pos: お客さんの左上、chair_center: イスの中心（すべて客席エリアの座標）
func place(tap_rect: Rect2, customer_pos: Vector2, chair_center: Vector2, label_pos: Vector2) -> void:
	position = tap_rect.position.round()
	size = tap_rect.size.round()
	customer_position = customer_pos.round()
	_chair.position = (chair_center - CHAIR_SIZE * 0.5 - position).round()
	_chair.size = CHAIR_SIZE
	_label.position = (label_pos - position).round()


func is_free() -> bool:
	return occupant == null


## 座ったお客さんの描く順番（カウンターとテーブルの手前側は家具より手前、奥側は家具の後ろ）
func get_customer_z() -> int:
	return 0 if kind == Kind.TABLE_TOP else 2


## 持っている料理を出せる席を光らせる
func set_highlight(on: bool) -> void:
	_highlight.visible = on
