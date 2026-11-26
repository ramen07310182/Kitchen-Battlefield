extends Node
## 画面の切り替えだけを担当する。各画面とはシグナルでつながる。
## 営業準備 → 営業 → 営業結果 → （次の日）営業準備 …

const PREP_SCENE: PackedScene = preload("res://scenes/prep/prep_screen.tscn")
const BUSINESS_SCENE: PackedScene = preload("res://scenes/business/business.tscn")
const RESULT_SCENE: PackedScene = preload("res://scenes/result/result_screen.tscn")

var _current: Node = null


func _ready() -> void:
	_show_prep()


func _switch_to(scene: PackedScene) -> Node:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
	_current = scene.instantiate()
	add_child(_current)
	return _current


func _show_prep() -> void:
	var screen: Node = _switch_to(PREP_SCENE)
	screen.connect("start_requested", _show_business)


func _show_business() -> void:
	var screen: Node = _switch_to(BUSINESS_SCENE)
	screen.connect("business_finished", _on_business_finished)


func _on_business_finished() -> void:
	GameState.finish_business()
	var screen: Node = _switch_to(RESULT_SCENE)
	screen.connect("next_day_requested", _on_next_day)


func _on_next_day() -> void:
	GameState.advance_day()
	_show_prep()
