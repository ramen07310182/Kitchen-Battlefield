class_name OrderPanel
extends PanelContainer
## 注文状況パネル（画面の端に常に表示）。待ち時間が長い注文ほど目立つ色になる。

var _rows: Array[PanelContainer] = []
var _row_labels: Array[Label] = []
var _row_boxes: Array[StyleBoxFlat] = []
var _blink_time: float = 0.0

@onready var _title_label: Label = %TitleLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _list: VBoxContainer = %OrderList


func _ready() -> void:
	add_theme_stylebox_override("panel", UISkin.panel_box(SpriteKeys.PANEL, UIUtil.flat_box(Color(0.12, 0.12, 0.14, 0.95))))
	_title_label.text = UIText.ORDER_TITLE
	_empty_label.text = UIText.ORDER_EMPTY


## orders: [{ seat: String（席の番号。C1・T1-2 など）, dish: DishData, elapsed: float, ratio: float }]
func show_orders(orders: Array[Dictionary], great_ratio: float, good_ratio: float, delta: float) -> void:
	_blink_time += delta
	while _rows.size() < orders.size():
		_add_row()
	for i: int in _rows.size():
		var row: PanelContainer = _rows[i]
		if i >= orders.size():
			row.hide()
			continue
		var order: Dictionary = orders[i]
		var dish: DishData = order["dish"]
		var ratio: float = order["ratio"]
		row.show()
		_row_labels[i].text = UIText.ORDER_ROW % [String(order["seat"]), dish.display_name, int(order["elapsed"])]
		var box: StyleBoxFlat = _row_boxes[i]
		box.border_color = dish.color
		row.modulate = Color.WHITE
		if ratio <= great_ratio:
			box.bg_color = Color(0.2, 0.32, 0.22)
		elif ratio <= good_ratio:
			box.bg_color = Color(0.55, 0.45, 0.12)
		else:
			box.bg_color = Color(0.7, 0.18, 0.15)
			# 危ない注文は点滅させる
			row.modulate = Color(1, 1, 1, 0.65 + 0.35 * absf(sin(_blink_time * 6.0)))
	_empty_label.visible = orders.is_empty()


func _add_row() -> void:
	var row: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UIUtil.flat_box(Color(0.2, 0.32, 0.22), Color.WHITE, 0, 2)
	box.border_width_left = 5
	box.content_margin_left = 9
	row.add_theme_stylebox_override("panel", box)
	var label: Label = Label.new()
	row.add_child(label)
	_list.add_child(row)
	_rows.append(row)
	_row_labels.append(label)
	_row_boxes.append(box)
