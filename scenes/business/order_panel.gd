class_name OrderPanel
extends PanelContainer
## 注文状況パネル（画面の端に常に表示）。待ち時間が長い注文ほど目立つ色になる。
## 1行に「席の番号・料理＋トッピング・待ち時間」を出す。出し終えた料理・トッピングは薄くする。

const SERVED_ALPHA := 0.35

var _rows: Array[PanelContainer] = []
var _seat_labels: Array[Label] = []
var _dish_labels: Array[Label] = []
var _topping_labels: Array[Label] = []
var _wait_labels: Array[Label] = []
var _row_boxes: Array[StyleBoxFlat] = []
var _blink_time: float = 0.0

@onready var _title_label: Label = %TitleLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _list: VBoxContainer = %OrderList


func _ready() -> void:
	add_theme_stylebox_override("panel", UISkin.panel_box(SpriteKeys.PANEL, UIUtil.flat_box(Color(0.12, 0.12, 0.14, 0.95))))
	_title_label.text = UIText.ORDER_TITLE
	_empty_label.text = UIText.ORDER_EMPTY


## orders: [{ seat: String（席の番号。C1・T1-2 など）, dish: DishData, topping: DishData か null,
##   dish_served: bool, topping_served: bool, elapsed: float, ratio: float }]
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
		var topping: DishData = order.get("topping")
		var ratio: float = order["ratio"]
		row.show()
		_seat_labels[i].text = String(order["seat"])
		_dish_labels[i].text = dish.display_name
		_dish_labels[i].modulate.a = SERVED_ALPHA if bool(order.get("dish_served", false)) else 1.0
		_topping_labels[i].visible = topping != null
		if topping != null:
			_topping_labels[i].text = UIText.ORDER_TOPPING % topping.display_name
			_topping_labels[i].modulate.a = SERVED_ALPHA if bool(order.get("topping_served", false)) else 1.0
		_wait_labels[i].text = UIText.ORDER_WAIT % int(order["elapsed"])
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
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	row.add_child(vbox)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	vbox.add_child(line)
	var seat: Label = Label.new()
	line.add_child(seat)
	# 料理名が長くても注文状況の幅を広げない（入りきらない分は「…」）
	var dish_label: Label = _clipped_label(36)
	line.add_child(dish_label)
	# トッピングは2行目（待ち時間の横）に出す
	var second: HBoxContainer = HBoxContainer.new()
	second.add_theme_constant_override("separation", 6)
	vbox.add_child(second)
	var wait: Label = Label.new()
	second.add_child(wait)
	var topping_label: Label = _clipped_label(30)
	topping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	second.add_child(topping_label)
	_list.add_child(row)
	_rows.append(row)
	_seat_labels.append(seat)
	_dish_labels.append(dish_label)
	_topping_labels.append(topping_label)
	_wait_labels.append(wait)
	_row_boxes.append(box)


func _clipped_label(min_width: float) -> Label:
	var label: Label = Label.new()
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(min_width, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
