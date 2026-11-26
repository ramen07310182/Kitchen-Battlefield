class_name DishSupply
extends RefCounted
## 営業中の料理の数の管理。
##   出せる数（units）: 仕込み数から、出した分を引いた数。「残り＋置き場＋調理中・調理待ち」と同じ
##   残り（remaining）: まだ店主が作っていない数
##   確保（reserved）:  注文が入って、まだ出していない数
## 客が注文できるのは「出せる数 − 確保」が1以上の料理だけ。

signal changed

var _units: Dictionary = {}
var _remaining: Dictionary = {}
var _reserved: Dictionary = {}


## prep: { 料理id: 仕込み数 }、shelf: 開店時に置き場に並べた料理
func _init(prep: Dictionary = {}, shelf: Array[String] = []) -> void:
	for dish_id: String in prep:
		_units[dish_id] = int(prep[dish_id])
		_remaining[dish_id] = int(prep[dish_id])
	for dish_id: String in shelf:
		_remaining[dish_id] = maxi(0, get_remaining(dish_id) - 1)


func get_remaining(dish_id: String) -> int:
	return int(_remaining.get(dish_id, 0))


func get_units(dish_id: String) -> int:
	return int(_units.get(dish_id, 0))


func get_reserved(dish_id: String) -> int:
	return int(_reserved.get(dish_id, 0))


## 新しい注文を受けられる数
func get_orderable(dish_id: String) -> int:
	return get_units(dish_id) - get_reserved(dish_id)


## メニューのうち、今注文できる料理
func filter_orderable(menu: Array[DishData]) -> Array[DishData]:
	var result: Array[DishData] = []
	for d: DishData in menu:
		if get_orderable(d.id) > 0:
			result.append(d)
	return result


func has_orderable(menu: Array[DishData]) -> bool:
	return not filter_orderable(menu).is_empty()


## 店主が作り始める（残りを1減らす）
func take_for_cooking(dish_id: String) -> bool:
	if get_remaining(dish_id) <= 0:
		return false
	_remaining[dish_id] = get_remaining(dish_id) - 1
	changed.emit()
	return true


## 置き場から外した料理を残りに戻す
func return_to_remaining(dish_id: String) -> void:
	_remaining[dish_id] = get_remaining(dish_id) + 1
	changed.emit()


## 注文が入ったので1個確保する
func reserve(dish_id: String) -> bool:
	if get_orderable(dish_id) <= 0:
		return false
	_reserved[dish_id] = get_reserved(dish_id) + 1
	changed.emit()
	return true


## 注文した客が帰ったので確保をやめる
func release(dish_id: String) -> void:
	_reserved[dish_id] = maxi(0, get_reserved(dish_id) - 1)
	changed.emit()


## 料理を出した（出せる数と確保を1ずつ減らす）
func serve(dish_id: String) -> void:
	_units[dish_id] = maxi(0, get_units(dish_id) - 1)
	_reserved[dish_id] = maxi(0, get_reserved(dish_id) - 1)
	changed.emit()


## 営業終了時に残っている料理 { 料理id: 数 }（廃棄する分）
func get_leftover() -> Dictionary:
	var result: Dictionary = {}
	for dish_id: String in _units:
		if get_units(dish_id) > 0:
			result[dish_id] = get_units(dish_id)
	return result
