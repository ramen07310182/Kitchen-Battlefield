class_name DiningArea
extends Control
## 客席エリア。テーブルを並べ、お客さんの表示レイヤーと入口の位置を管理する。

signal table_tapped(table_index: int)

const TABLE_SCENE: PackedScene = preload("res://scenes/business/dining_table.tscn")

var _tables: Array[DiningTable] = []

@onready var _entrance: ColorRect = %Entrance
@onready var _tables_layer: Control = %Tables
@onready var _customers_layer: Control = %Customers


func setup(table_count: int) -> void:
	for i: int in table_count:
		var table: DiningTable = TABLE_SCENE.instantiate() as DiningTable
		_tables_layer.add_child(table)
		table.setup(i)
		table.tapped.connect(table_tapped.emit)
		_tables.append(table)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout()


func _layout() -> void:
	if _tables.is_empty():
		return
	var left: float = _entrance.position.x + _entrance.size.x + 12.0
	var step: float = (size.x - left - 8.0) / float(_tables.size())
	for i: int in _tables.size():
		var table: DiningTable = _tables[i]
		table.position = Vector2(
			roundf(left + step * (i + 0.5) - table.size.x * 0.5),
			roundf(size.y * 0.5 - table.size.y * 0.5 + 14.0)
		)
	# 座っているお客さんも新しい位置に合わせる
	for table: DiningTable in _tables:
		var c: Customer = table.occupant
		if c != null and (c.state == Customer.State.ORDERING or c.state == Customer.State.WAITING_FOOD or c.state == Customer.State.EATING):
			c.position = table.get_seat_position()


## 空いているテーブルをランダムに1つ選ぶ。なければ -1
func find_free_table() -> int:
	var free: Array[int] = []
	for table: DiningTable in _tables:
		if table.is_free():
			free.append(table.table_index)
	if free.is_empty():
		return -1
	return free.pick_random()


func add_customer(customer: Customer, table_index: int) -> void:
	_customers_layer.add_child(customer)
	_tables[table_index].occupant = customer


func release_table(table_index: int) -> void:
	_tables[table_index].occupant = null
	_tables[table_index].set_highlight(false)


func get_occupant(table_index: int) -> Customer:
	return _tables[table_index].occupant


func get_entrance_position() -> Vector2:
	return _entrance.position + Vector2(_entrance.size.x * 0.5 - 12.0, _entrance.size.y - 40.0)


func get_seat_position(table_index: int) -> Vector2:
	return _tables[table_index].get_seat_position()


func get_table_count() -> int:
	return _tables.size()


func set_table_highlight(table_index: int, on: bool) -> void:
	_tables[table_index].set_highlight(on)
