class_name DiningArea
extends Control
## 客席エリア。上側に横長のカウンターとイス6脚、下側に4人がけのテーブル3卓（1卓4席）を置く（最大18席）。
## 使える席の数（設備「席の拡張」）だけ、イスとテーブルを描く。使えない席・テーブルは描かない。
## 席の順番: カウンター C1〜C6 → テーブル1 T1-1〜T1-4 → テーブル2 → テーブル3
## （テーブルの席は 奥の左・奥の右・手前の左・手前の右）。入口は右側。

signal seat_tapped(seat_index: int)

const SEAT_SCENE: PackedScene = preload("res://scenes/business/dining_seat.tscn")
const COUNTER_SEATS := 6
const TABLE_COUNT := 3
const SEATS_PER_TABLE := 4
const MAX_SEATS := COUNTER_SEATS + TABLE_COUNT * SEATS_PER_TABLE

## カウンターの上（壁）の高さと、カウンターの高さ
const COUNTER_TOP := 34.0
const COUNTER_HEIGHT := 20.0
## カウンターに座ったお客さんの頭がカウンターに重なる量
const COUNTER_OVERLAP := 10.0
## お客さんの吹き出し（料理とトッピングの2段）のぶん、頭の上に空ける高さ
const BUBBLE_SPACE := 42.0
## テーブルの大きさと、テーブルの席どうしの間隔
const TABLE_SIZE := Vector2(100, 32)
const TABLE_SEAT_PITCH := 50.0
## 奥の席のお客さんの足元がテーブルに隠れる量・手前の席のお客さんの頭がテーブルに重なる量
const TABLE_HIDE_FEET := 10.0
const TABLE_OVERLAP_HEAD := 8.0

var _seats: Array[DiningSeat] = []
var _table_nodes: Array[Control] = []
var _counter: Control

@onready var _entrance: Control = %Entrance
@onready var _furniture_layer: Control = %Furniture
@onready var _seats_layer: Control = %Seats
@onready var _customers_layer: Control = %Customers


## seat_count: 使える席の数（4〜18）
func setup(seat_count: int) -> void:
	var count: int = clampi(seat_count, 1, MAX_SEATS)
	_counter = _make_furniture(SpriteKeys.COUNTER, Color(0.62, 0.45, 0.28), Color(0.45, 0.32, 0.2))
	var used_tables: int = clampi(ceili(float(count - COUNTER_SEATS) / SEATS_PER_TABLE), 0, TABLE_COUNT)
	for t: int in used_tables:
		var table: Control = _make_furniture(SpriteKeys.TABLE4, Color(0.7, 0.5, 0.3), Color(0.5, 0.35, 0.22))
		# テーブルの真ん中に「T1」。席の番号（1〜4）はテーブルの四隅に出す
		var name_label: Label = Label.new()
		name_label.text = UIText.TABLE_NAME % (t + 1)
		name_label.theme_type_variation = &"SmallLabel"
		name_label.add_theme_color_override("font_color", Color(0.3, 0.18, 0.1))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		table.add_child(name_label)
		_table_nodes.append(table)
	for i: int in count:
		var seat: DiningSeat = SEAT_SCENE.instantiate() as DiningSeat
		_seats_layer.add_child(seat)
		if i < COUNTER_SEATS:
			var counter_label: String = UIText.SEAT_COUNTER % (i + 1)
			seat.setup(i, counter_label, counter_label, DiningSeat.Kind.COUNTER, -1)
		else:
			var t: int = (i - COUNTER_SEATS) / SEATS_PER_TABLE
			var k: int = (i - COUNTER_SEATS) % SEATS_PER_TABLE
			var kind: DiningSeat.Kind = DiningSeat.Kind.TABLE_TOP if k < 2 else DiningSeat.Kind.TABLE_BOTTOM
			seat.setup(i, UIText.SEAT_TABLE % [t + 1, k + 1], str(k + 1), kind, t)
		seat.tapped.connect(seat_tapped.emit)
		_seats.append(seat)
	_layout()


## 家具（絵があれば絵、なければ天板と脚の四角）。家具はお客さん（奥の席）より手前に描く
func _make_furniture(key: String, top_color: Color, leg_color: Color) -> Control:
	var view: SpriteView = SpriteView.new()
	view.sprite_key = key
	view.mode = SpriteView.Mode.TILE if key == SpriteKeys.COUNTER else SpriteView.Mode.ANCHOR
	view.z_index = 1
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: ColorRect = ColorRect.new()
	top.color = top_color
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.offset_bottom = -4
	view.add_child(top)
	var legs: ColorRect = ColorRect.new()
	legs.color = leg_color
	legs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legs.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legs.offset_top = -4
	legs.offset_left = 4
	legs.offset_right = -4
	view.add_child(legs)
	_furniture_layer.add_child(view)
	return view


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout()


func _layout() -> void:
	if _counter == null:
		return
	var x0: float = 8.0
	var x1: float = _entrance.position.x - 10.0
	var width: float = maxf(60.0, x1 - x0)

	# カウンター（上側・横長）とイス6脚
	_counter.position = Vector2(x0, COUNTER_TOP).round()
	_counter.size = Vector2(width, COUNTER_HEIGHT).round()
	var pitch: float = width / COUNTER_SEATS
	var counter_customer_top: float = COUNTER_TOP + COUNTER_HEIGHT - COUNTER_OVERLAP
	for i: int in mini(COUNTER_SEATS, _seats.size()):
		var cx: float = x0 + pitch * (i + 0.5)
		var top: float = counter_customer_top - BUBBLE_SPACE
		var bottom: float = counter_customer_top + DiningSeat.CUSTOMER_SIZE.y + 8.0
		_seats[i].place(Rect2(cx - pitch * 0.5 + 2.0, top, pitch - 4.0, bottom - top),
			Vector2(cx - DiningSeat.CUSTOMER_SIZE.x * 0.5, counter_customer_top),
			Vector2(cx, counter_customer_top + DiningSeat.CUSTOMER_SIZE.y - 2.0),
			Vector2(cx - 8.0, bottom - 14.0))

	# テーブル（下側・3卓を横に並べる）。手前の席のお客さんの足元が、客席エリアの下端に来るように置く
	var bottom_customer_top: float = size.y - 4.0 - DiningSeat.CUSTOMER_SIZE.y
	var table_y: float = bottom_customer_top + TABLE_OVERLAP_HEAD - TABLE_SIZE.y
	var top_customer_top: float = table_y + TABLE_HIDE_FEET - DiningSeat.CUSTOMER_SIZE.y
	var table_pitch: float = width / TABLE_COUNT
	var table_mid: float = table_y + TABLE_SIZE.y * 0.5
	for t: int in _table_nodes.size():
		var center_x: float = x0 + table_pitch * (t + 0.5)
		_table_nodes[t].position = Vector2(center_x - TABLE_SIZE.x * 0.5, table_y).round()
		_table_nodes[t].size = TABLE_SIZE
	for i: int in range(COUNTER_SEATS, _seats.size()):
		var seat: DiningSeat = _seats[i]
		var t: int = seat.table_index
		var k: int = (i - COUNTER_SEATS) % SEATS_PER_TABLE
		var cx: float = x0 + table_pitch * (t + 0.5) + (k % 2 - 0.5) * TABLE_SEAT_PITCH
		var left: float = cx - TABLE_SEAT_PITCH * 0.5 + 1.0
		var w: float = TABLE_SEAT_PITCH - 2.0
		if seat.kind == DiningSeat.Kind.TABLE_TOP:
			var top2: float = top_customer_top - BUBBLE_SPACE
			seat.place(Rect2(left, top2, w, table_mid - top2),
				Vector2(cx - DiningSeat.CUSTOMER_SIZE.x * 0.5, top_customer_top),
				Vector2(cx, top_customer_top + 14.0),
				Vector2(cx - 3.0, table_y))
		else:
			seat.place(Rect2(left, table_mid, w, size.y - table_mid),
				Vector2(cx - DiningSeat.CUSTOMER_SIZE.x * 0.5, bottom_customer_top),
				Vector2(cx, size.y - 8.0),
				Vector2(cx - 3.0, table_y + TABLE_SIZE.y - 18.0))
	# 座っているお客さんも新しい位置に合わせる
	for seat: DiningSeat in _seats:
		var c: Customer = seat.occupant
		if c != null and (c.state == Customer.State.ORDERING or c.state == Customer.State.WAITING_FOOD or c.state == Customer.State.EATING):
			c.position = seat.customer_position


## 空いている席をランダムに1つ選ぶ。なければ -1（テーブルは相席してよい）
func find_free_seat() -> int:
	var free: Array[int] = []
	for seat: DiningSeat in _seats:
		if seat.is_free():
			free.append(seat.seat_index)
	if free.is_empty():
		return -1
	return free.pick_random()


func add_customer(customer: Customer, seat_index: int) -> void:
	_customers_layer.add_child(customer)
	customer.z_index = _seats[seat_index].get_customer_z()
	_seats[seat_index].occupant = customer


func release_seat(seat_index: int) -> void:
	_seats[seat_index].occupant = null
	_seats[seat_index].set_highlight(false)


## ホールスタッフを置く（お客さんと同じ層。家具より手前）
func add_staff(staff: HallStaff) -> void:
	_customers_layer.add_child(staff)


func get_occupant(seat_index: int) -> Customer:
	return _seats[seat_index].occupant


func get_entrance_position() -> Vector2:
	return _entrance.position + Vector2(_entrance.size.x * 0.5 - 12.0, _entrance.size.y - 40.0)


func get_seat_position(seat_index: int) -> Vector2:
	return _seats[seat_index].customer_position


func get_seat_label(seat_index: int) -> String:
	return _seats[seat_index].seat_label


func get_seat(seat_index: int) -> DiningSeat:
	return _seats[seat_index]


func get_seat_count() -> int:
	return _seats.size()


## 描いているテーブルの数（カウンターは含まない）
func get_table_count() -> int:
	return _table_nodes.size()


func set_seat_highlight(seat_index: int, on: bool) -> void:
	_seats[seat_index].set_highlight(on)
